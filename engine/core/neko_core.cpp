/**
 * neko_core.cpp
 * Qt 核心桥实现：QCoreApplication 工作线程 + 命令投递 + 结果队列。
 *
 * 线程模型：
 *  - worker 线程内构造 QCoreApplication + CoreWorker（ApiClient/UserManager/
 *    PlaylistDatabase/PlaylistManager 均在该线程构造，线程亲和正确）；
 *  - 主线程 neko_core_cmd_* 通过 QueuedConnection 把 Cmd 投递到 worker；
 *  - worker 执行完把扁平结果压入有界 C 队列，主线程 neko_core_poll 取走；
 *  - 同步查询（登录态/音频头）走 BlockingQueuedConnection。
 */

#include "neko_core.h"

#include "core/apiclient.h"
#include "core/usermanager.h"
#include "core/playlistdb.h"
#include "core/playlistmanager.h"
#include "core/musicinfo.h"
#include "theme/theme.h"

#include <QCoreApplication>
#include <QNetworkProxy>
#include <QNetworkProxyFactory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMutex>
#include <QMutexLocker>
#include <QMetaObject>
#include <QSemaphore>
#include <QString>
#include <QList>
#include <QSet>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

#include <atomic>
#include <cstring>
#include <deque>
#include <thread>

// ─── 内部状态 ────────────────────────────────────────────────────────

namespace {

// 前置声明：postSimple/postInt 在类定义前使用（仅需指针转换）
class CoreWorker;

// 命令类型
enum class CmdType {
    Login, Register, Logout,
    ChangePassword, SendVerification, SliderChallenge, SliderVerify,
    SendResetCode, ResetPassword,
    FetchRanking, FetchLatest, FetchDaily, SearchMusic,
    FetchMusicInfo, FetchLyrics, FetchFavorites, ToggleFavorite,
    QueueLoad, QueueClear, QueueAddAll, QueueSetIndex, QueueSetMode,
    RecentLoad, RecordRecent, DownloadsLoad, RecordDownload,
    PlaylistCreate, PlaylistDelete, PlaylistUpdate,
    PlaylistList, PlaylistDetail, PlaylistAddMusic, PlaylistRemoveMusic,
    FetchPlaylists, SearchArtists,
    FetchUserPlaylists, FetchFavoritePlaylists, FetchPlaylistMusic,
    FavoritePlaylist, UnfavoritePlaylist,
    CloudPlaylistCreate, CloudPlaylistDelete,
    FetchNeteasePlaylist, FetchQqPlaylist, BatchSearchMusic, BatchAddMusicToPlaylist,
    VipPricing, VipPayCreate, VipSyncStatus,
    DownloadMusic, DownloadCancel, DownloadsStatus,
};

struct Cmd {
    CmdType type = CmdType::Logout;
    int64_t seq = 0;
    QString s1, s2, s3, s4;      // 字符串参数
    int i1 = 0, i2 = 0, i3 = 0;  // 整型参数
    QList<MusicInfo> musicList;
    QString filePath;
};

// 结果队列（有界，队满丢最旧）
QMutex g_resultMutex;
std::deque<neko_core_result> g_results;
const size_t kMaxResults = 256;

// 结果入队回调（推送模式，替代宿主轮询）
std::atomic<neko_core_event_cb> g_evCb{nullptr};
void *g_evUser = nullptr;

std::atomic<int64_t> g_seq{0};
std::atomic<QObject *> g_worker{nullptr};
// 堆分配且从不随静态析构销毁：Flutter 桌面关窗直接 exit()，不走 Dart dispose →
// 若 g_thread 是栈上全局，进程退出静态析构时它仍 joinable，析构即 std::terminate
// （实际崩溃栈：std::thread::~thread → std::terminate → SIGABRT）。
std::thread *g_thread = nullptr;
QSemaphore g_workerReady(0);

int64_t nextSeq() { return g_seq.fetch_add(1) + 1; }

void pushResult(const neko_core_result &r)
{
    {
        QMutexLocker lock(&g_resultMutex);
        if (g_results.size() >= kMaxResults)
            g_results.pop_front();
        g_results.push_back(r);
    }
    // 解锁后触发回调，宿主（Flutter 主隔离区）据此拉取结果
    neko_core_event_cb cb = g_evCb.load(std::memory_order_acquire);
    if (cb)
        cb(g_evUser);
}

void copyStr(char *dst, size_t cap, const QString &src)
{
    if (!dst || cap == 0)
        return;
    const QByteArray u8 = src.toUtf8();
    const size_t n = static_cast<size_t>(u8.size());
    if (n >= cap) {
        std::memcpy(dst, u8.constData(), cap - 1);
        dst[cap - 1] = '\0';
    } else {
        std::memcpy(dst, u8.constData(), n);
        dst[n] = '\0';
    }
}

void fillRow(neko_core_music *row, const MusicInfo &m)
{
    std::memset(row, 0, sizeof(*row));
    row->id = m.id;
    copyStr(row->title, sizeof(row->title), m.title);
    copyStr(row->artist, sizeof(row->artist), m.artist);
    copyStr(row->album, sizeof(row->album), m.album);
    row->duration = m.duration;
    copyStr(row->cover_url, sizeof(row->cover_url), m.coverUrl);
    copyStr(row->local_path, sizeof(row->local_path), m.localPath);
    row->play_count = m.playCount;
    row->uploaded_at_ms = m.uploadedAtMs;
    row->lrc = m.lrc ? 1 : 0;
}

MusicInfo musicFromRow(const neko_core_music *row)
{
    MusicInfo m;
    if (!row)
        return m;
    m.id = static_cast<int>(row->id);
    m.title = QString::fromUtf8(row->title);
    m.artist = QString::fromUtf8(row->artist);
    m.album = QString::fromUtf8(row->album);
    m.duration = static_cast<int>(row->duration);
    m.coverUrl = QString::fromUtf8(row->cover_url);
    m.localPath = QString::fromUtf8(row->local_path);
    m.playCount = static_cast<int>(row->play_count);
    m.uploadedAtMs = row->uploaded_at_ms;
    m.lrc = row->lrc != 0;
    return m;
}

// API 返回的 QVariantMap → MusicInfo（与旧版 UI 一致：coverUrl 客户端拼接）
MusicInfo musicFromMap(const QVariantMap &map)
{
    MusicInfo info;
    info.id = map.value(QStringLiteral("id")).toInt();
    info.title = map.value(QStringLiteral("title")).toString();
    info.artist = map.value(QStringLiteral("artist")).toString();
    info.album = map.value(QStringLiteral("album")).toString();
    info.duration = map.value(QStringLiteral("duration")).toInt();
    info.coverUrl = map.value(QStringLiteral("coverUrl")).toString();
    if (info.coverUrl.isEmpty() && info.id > 0) {
        info.coverUrl = QString::fromUtf8("%1/api/music/cover/%2")
                            .arg(QString::fromUtf8(Theme::kApiBase))
                            .arg(info.id);
    }
    info.playCount = map.value(QStringLiteral("playCount"), -1).toInt();
    info.uploadedAtMs = map.value(QStringLiteral("uploadedAtMs"), 0).toLongLong();
    info.lrc = map.value(QStringLiteral("lrc")).toBool();
    return info;
}

void fillList(neko_core_result *r, const QList<QVariantMap> &list)
{
    int n = 0;
    for (const auto &m : list) {
        if (n >= NEKO_CORE_MAX_ROWS)
            break;
        fillRow(&r->rows[n++], musicFromMap(m));
    }
    r->nrows = n;
}

void fillMusicList(neko_core_result *r, const QList<MusicInfo> &list)
{
    int n = 0;
    for (const auto &m : list) {
        if (n >= NEKO_CORE_MAX_ROWS)
            break;
        fillRow(&r->rows[n++], m);
    }
    r->nrows = n;
}

void fillPlaylistRow(neko_core_playlist *p, const LocalPlaylistInfo &info, int musicCount)
{
    std::memset(p, 0, sizeof(*p));
    p->local_id = info.localId;
    copyStr(p->name, sizeof(p->name), info.name);
    copyStr(p->description, sizeof(p->description), info.description);
    p->cover_music_id = info.coverMusicId;
    p->music_count = musicCount;
    copyStr(p->created_at, sizeof(p->created_at), info.createdAt);
    copyStr(p->updated_at, sizeof(p->updated_at), info.updatedAt);
}

// API 返回的云端歌单 QVariantMap → neko_core_playlist（localId 放云端 id，
// coverMusicId 放 firstMusicId，封面 URL 由 Dart 侧用 {kApiBase}/api/music/cover/{id} 拼接）
void fillPlaylistMap(neko_core_playlist *p, const QVariantMap &pl)
{
    std::memset(p, 0, sizeof(*p));
    p->local_id = pl.value(QStringLiteral("id")).toLongLong();
    copyStr(p->name, sizeof(p->name), pl.value(QStringLiteral("name")).toString());
    copyStr(p->description, sizeof(p->description), pl.value(QStringLiteral("description")).toString());
    p->cover_music_id = pl.value(QStringLiteral("firstMusicId")).toLongLong();
    p->music_count = pl.value(QStringLiteral("musicCount")).toLongLong();
}

void fillPlaylistMapList(neko_core_result *r, const QList<QVariantMap> &list)
{
    int n = 0;
    for (const auto &pl : list) {
        if (n >= NEKO_CORE_MAX_PLAYLISTS)
            break;
        fillPlaylistMap(&r->playlists[n++], pl);
    }
    r->nplaylists = n;
}

// 阻塞式投递到 worker 线程执行（仅主线程调用；worker 线程内不可调用）
template <typename Fn>
void invokeBlocking(Fn fn)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (w)
        QMetaObject::invokeMethod(w, std::move(fn), Qt::BlockingQueuedConnection);
}

// ─── CoreWorker：worker 线程亲和对象 ─────────────────────────────────

class CoreWorker : public QObject {
    Q_OBJECT
public:
    explicit CoreWorker(QObject *parent = nullptr)
        : QObject(parent)
    {
        // 复刻原 main.cpp 初始化序列（顺序敏感）：
        // 1) 应用元信息 —— PlaylistDatabase 依赖它计算 AppDataLocation
        QCoreApplication::setApplicationName(QStringLiteral("NekoMusic"));
        QCoreApplication::setApplicationVersion(QStringLiteral("1.0.0"));
        QCoreApplication::setOrganizationName(QStringLiteral("NekoMusic"));
        QCoreApplication::setOrganizationDomain(QStringLiteral("nekomusic.local"));

        // 2) 直连：不读取系统/环境变量代理
        QNetworkProxyFactory::setUseSystemConfiguration(false);
        QNetworkProxy::setApplicationProxy(QNetworkProxy(QNetworkProxy::NoProxy));

        // 3) 单例在此线程构造（QSettings/QSql 线程亲和）
        UserManager::instance();
        PlaylistDatabase::instance().init();
        PlaylistManager::instance().load();

        m_api = new ApiClient(this);
        m_nam = new QNetworkAccessManager(this);
    }

    void processCommand(Cmd *cmd)
    {
        if (!cmd)
            return;
        switch (cmd->type) {
        case CmdType::Login:
            doLogin(cmd);
            break;
        case CmdType::Register:
            doRegister(cmd);
            break;
        case CmdType::Logout:
            doLogout(cmd);
            break;
        case CmdType::FetchRanking:
            m_api->fetchRanking([seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch ranking failed"));
                pushResult(r);
            });
            break;
        case CmdType::FetchLatest:
            m_api->fetchLatest(cmd->i1, [seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch latest failed"));
                pushResult(r);
            });
            break;
        case CmdType::FetchDaily:
            m_api->fetchDailyRecommendations([seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch daily failed"));
                pushResult(r);
            });
            break;
        case CmdType::SearchMusic:
            m_api->searchMusic(cmd->s1, cmd->i1, cmd->i2,
                               [seq = cmd->seq](bool ok, int total, int, int,
                                                const QList<QVariantMap> &list) {
                                   neko_core_result r{};
                                   r.seq = seq;
                                   r.ok = ok ? 1 : 0;
                                   r.i64 = total;
                                   fillList(&r, list);
                                   if (!ok)
                                       copyStr(r.message, sizeof(r.message),
                                               QStringLiteral("search failed"));
                                   pushResult(r);
                               });
            break;
        case CmdType::FetchMusicInfo:
            m_api->fetchMusicInfo(cmd->i1, [seq = cmd->seq](bool ok, const QVariantMap &map) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                if (ok) {
                    const QJsonDocument doc(QJsonObject::fromVariantMap(map));
                    copyStr(r.str, sizeof(r.str),
                            QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
                } else {
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch music info failed"));
                }
                pushResult(r);
            });
            break;
        case CmdType::FetchLyrics:
            m_api->fetchLyrics(cmd->i1, [seq = cmd->seq](bool ok, const QString &lyrics) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.str, sizeof(r.str), lyrics);
                pushResult(r);
            });
            break;
        case CmdType::FetchFavorites:
            m_api->fetchFavorites([this, seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                if (ok) {
                    m_favIds.clear();
                    for (const auto &m : list)
                        m_favIds.insert(m.value(QStringLiteral("id")).toInt());
                }
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch favorites failed"));
                pushResult(r);
            });
            break;
        case CmdType::ToggleFavorite:
            doToggleFavorite(cmd);
            break;
        case CmdType::QueueLoad:
            doQueueLoad(cmd);
            break;
        case CmdType::QueueClear:
            PlaylistManager::instance().clearPlaylist();
            pushOk(cmd->seq);
            break;
        case CmdType::QueueAddAll: {
            PlaylistManager::instance().clearPlaylist();
            PlaylistManager::instance().addAllToPlaylist(cmd->musicList);
            PlaylistManager::instance().save();
            doQueueLoad(cmd);
            break;
        }
        case CmdType::QueueSetIndex:
            PlaylistManager::instance().setCurrentIndex(cmd->i1);
            pushOk(cmd->seq);
            break;
        case CmdType::QueueSetMode:
            PlaylistManager::instance().setPlayMode(cmd->s1);
            pushOk(cmd->seq);
            break;
        case CmdType::RecentLoad: {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 1;
            fillMusicList(&r, PlaylistDatabase::instance().getRecentPlays());
            pushResult(r);
            break;
        }
        case CmdType::RecordRecent: {
            MusicInfo tmp;
            if (!cmd->musicList.isEmpty())
                tmp = cmd->musicList.first();
            PlaylistDatabase::instance().recordRecentPlay(tmp);
            pushOk(cmd->seq);
            break;
        }
        case CmdType::DownloadsLoad: {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 1;
            fillMusicList(&r, PlaylistDatabase::instance().getDownloads());
            pushResult(r);
            break;
        }
        case CmdType::RecordDownload: {
            MusicInfo tmp;
            if (!cmd->musicList.isEmpty())
                tmp = cmd->musicList.first();
            PlaylistDatabase::instance().recordDownload(tmp, cmd->filePath);
            pushOk(cmd->seq);
            break;
        }
        case CmdType::PlaylistCreate: {
            const int id = PlaylistDatabase::instance()
                               .createPlaylist(cmd->s1, cmd->s2);
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = id > 0 ? 1 : 0;
            r.i64 = id;
            if (id <= 0)
                copyStr(r.message, sizeof(r.message), QStringLiteral("create playlist failed"));
            pushResult(r);
            break;
        }
        case CmdType::PlaylistDelete: {
            const bool ok = PlaylistDatabase::instance().deletePlaylist(cmd->i1);
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = ok ? 1 : 0;
            if (!ok)
                copyStr(r.message, sizeof(r.message), QStringLiteral("delete playlist failed"));
            pushResult(r);
            break;
        }
        case CmdType::PlaylistUpdate: {
            const bool ok = PlaylistDatabase::instance()
                                .updatePlaylist(cmd->i1, cmd->s1, cmd->s2);
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = ok ? 1 : 0;
            if (!ok)
                copyStr(r.message, sizeof(r.message), QStringLiteral("update playlist failed"));
            pushResult(r);
            break;
        }
        case CmdType::PlaylistList: {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 1;
            const auto playlists =
                PlaylistDatabase::instance().getAllPlaylists();
            int n = 0;
            for (const auto &p : playlists) {
                if (n >= NEKO_CORE_MAX_PLAYLISTS)
                    break;
                fillPlaylistRow(&r.playlists[n++], p,
                                PlaylistDatabase::instance().getPlaylistMusicCount(p.localId));
            }
            r.nplaylists = n;
            pushResult(r);
            break;
        }
        case CmdType::PlaylistDetail: {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 1;
            fillMusicList(&r, PlaylistDatabase::instance().getPlaylistMusic(cmd->i1));
            pushResult(r);
            break;
        }
        case CmdType::PlaylistAddMusic: {
            MusicInfo tmp;
            if (!cmd->musicList.isEmpty())
                tmp = cmd->musicList.first();
            const bool ok = PlaylistDatabase::instance().addMusic(cmd->i1, tmp);
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = ok ? 1 : 0;
            if (!ok)
                copyStr(r.message, sizeof(r.message), QStringLiteral("add music failed"));
            pushResult(r);
            break;
        }
        case CmdType::PlaylistRemoveMusic: {
            const bool ok = PlaylistDatabase::instance()
                                .removeMusic(cmd->i1, cmd->i2);
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = ok ? 1 : 0;
            if (!ok)
                copyStr(r.message, sizeof(r.message), QStringLiteral("remove music failed"));
            pushResult(r);
            break;
        }
        case CmdType::FetchPlaylists:
            m_api->fetchPlaylists(cmd->s1, [seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillPlaylistMapList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch playlists failed"));
                pushResult(r);
            });
            break;
        case CmdType::SearchArtists:
            m_api->searchArtists(cmd->s1, [seq = cmd->seq](bool ok, const QVariantMap &artist) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                if (ok && !artist.isEmpty()) {
                    const QJsonDocument doc(QJsonObject::fromVariantMap(artist));
                    copyStr(r.str, sizeof(r.str),
                            QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
                }
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("artist not found"));
                pushResult(r);
            });
            break;
        case CmdType::FetchUserPlaylists:
            m_api->fetchUserPlaylists([seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillPlaylistMapList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch user playlists failed"));
                pushResult(r);
            });
            break;
        case CmdType::FetchFavoritePlaylists:
            m_api->fetchFavoritePlaylists([seq = cmd->seq](bool ok, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillPlaylistMapList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch favorite playlists failed"));
                pushResult(r);
            });
            break;
        case CmdType::FetchPlaylistMusic:
            m_api->fetchPlaylistMusic(cmd->i1, [seq = cmd->seq](bool ok, int, const QList<QVariantMap> &list) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                fillList(&r, list);
                if (!ok)
                    copyStr(r.message, sizeof(r.message), QStringLiteral("fetch playlist music failed"));
                pushResult(r);
            });
            break;
        case CmdType::FavoritePlaylist:
            m_api->favoritePlaylist(cmd->i1, [seq = cmd->seq](bool ok, const QString &msg) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), msg);
                pushResult(r);
            });
            break;
        case CmdType::UnfavoritePlaylist:
            m_api->unfavoritePlaylist(cmd->i1, [seq = cmd->seq](bool ok, const QString &msg) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), msg);
                pushResult(r);
            });
            break;
        case CmdType::CloudPlaylistCreate:
            m_api->createPlaylist(cmd->s1, cmd->s2,
                                  [seq = cmd->seq](bool ok, const QString &msg, const QVariantMap &pl) {
                                      neko_core_result r{};
                                      r.seq = seq;
                                      r.ok = ok ? 1 : 0;
                                      r.i64 = pl.value(QStringLiteral("id")).toLongLong();
                                      copyStr(r.message, sizeof(r.message), msg);
                                      pushResult(r);
                                  });
            break;
        case CmdType::CloudPlaylistDelete:
            m_api->deletePlaylist(cmd->i1, [seq = cmd->seq](bool ok, const QString &msg) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), msg);
                pushResult(r);
            });
            break;
        case CmdType::FetchNeteasePlaylist:
            m_api->fetchNeteasePlaylist(cmd->s1.toLongLong(),
                                        [seq = cmd->seq](bool ok, const QString &msg, const ApiClient::NeteasePlaylistInfo &pl) {
                                            neko_core_result r{};
                                            r.seq = seq;
                                            r.ok = ok ? 1 : 0;
                                            copyStr(r.message, sizeof(r.message), msg);
                                            if (ok) {
                                                QJsonObject obj;
                                                obj.insert(QStringLiteral("name"), pl.name);
                                                QJsonArray tracks;
                                                for (const auto &t : pl.tracks) {
                                                    if (tracks.size() >= 60)
                                                        break;
                                                    QJsonObject to;
                                                    to.insert(QStringLiteral("name"), t.name);
                                                    to.insert(QStringLiteral("artist"), t.artist);
                                                    tracks.append(to);
                                                }
                                                obj.insert(QStringLiteral("tracks"), tracks);
                                                copyStr(r.str, sizeof(r.str),
                                                        QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
                                            }
                                            pushResult(r);
                                        });
            break;
        case CmdType::FetchQqPlaylist:
            m_api->fetchQqPlaylist(cmd->s1,
                                   [seq = cmd->seq](bool ok, const QString &msg, const ApiClient::QqPlaylistInfo &pl) {
                                       neko_core_result r{};
                                       r.seq = seq;
                                       r.ok = ok ? 1 : 0;
                                       copyStr(r.message, sizeof(r.message), msg);
                                       if (ok) {
                                           QJsonObject obj;
                                           obj.insert(QStringLiteral("name"), pl.name);
                                           QJsonArray tracks;
                                           for (const auto &t : pl.tracks) {
                                               if (tracks.size() >= 60)
                                                   break;
                                               QJsonObject to;
                                               to.insert(QStringLiteral("name"), t.name);
                                               to.insert(QStringLiteral("artist"), t.artist);
                                               tracks.append(to);
                                           }
                                           obj.insert(QStringLiteral("tracks"), tracks);
                                           copyStr(r.str, sizeof(r.str),
                                                   QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
                                       }
                                       pushResult(r);
                                   });
            break;
        case CmdType::BatchSearchMusic: {
            QList<ApiClient::BatchSearchItem> items;
            const QJsonArray arr =
                QJsonDocument::fromJson(cmd->s1.toUtf8()).array();
            for (const auto &v : arr) {
                const QJsonObject o = v.toObject();
                ApiClient::BatchSearchItem it;
                it.title = o.value(QStringLiteral("title")).toString();
                it.artist = o.value(QStringLiteral("artist")).toString();
                items.append(it);
                if (items.size() >= 60)
                    break;
            }
            m_api->batchSearchMusic(items, [seq = cmd->seq](bool ok, const ApiClient::BatchSearchResult &res) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), res.message);
                if (ok) {
                    QJsonObject obj;
                    QJsonArray ids;
                    for (const int id : res.matchedMusicIds)
                        ids.append(id);
                    obj.insert(QStringLiteral("matchedMusicIds"), ids);
                    obj.insert(QStringLiteral("successCount"), res.successCount);
                    obj.insert(QStringLiteral("failCount"), res.failCount);
                    copyStr(r.str, sizeof(r.str),
                            QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
                }
                pushResult(r);
            });
            break;
        }
        case CmdType::BatchAddMusicToPlaylist: {
            QList<int> ids;
            const QJsonArray arr =
                QJsonDocument::fromJson(cmd->s2.toUtf8()).array();
            for (const auto &v : arr)
                ids.append(v.toInt());
            m_api->batchAddMusicToPlaylist(cmd->i1, ids, [seq = cmd->seq](bool ok, const ApiClient::BatchAddResult &res) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), res.message);
                if (ok) {
                    QJsonObject obj;
                    obj.insert(QStringLiteral("addedCount"), res.addedCount);
                    copyStr(r.str, sizeof(r.str),
                            QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
                }
                pushResult(r);
            });
            break;
        }
        case CmdType::ChangePassword:
            m_api->changePassword(cmd->s1, cmd->s2, [seq = cmd->seq](bool ok, const QString &msg) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), msg);
                pushResult(r);
            });
            break;
        case CmdType::SendVerification:
            m_api->sendVerificationCode(cmd->s1, cmd->s2, cmd->s3,
                                        [seq = cmd->seq](bool ok, const QString &msg) {
                                            neko_core_result r{};
                                            r.seq = seq;
                                            r.ok = ok ? 1 : 0;
                                            copyStr(r.message, sizeof(r.message), msg);
                                            pushResult(r);
                                        });
            break;
        case CmdType::SliderChallenge:
            m_api->fetchSliderCaptchaChallenge(
                [seq = cmd->seq](bool ok, const QString &msg, const QVariantMap &data) {
                    neko_core_result r{};
                    r.seq = seq;
                    r.ok = ok ? 1 : 0;
                    copyStr(r.message, sizeof(r.message), msg);
                    if (ok) {
                        const QJsonDocument doc(QJsonObject::fromVariantMap(data));
                        copyStr(r.str, sizeof(r.str),
                                QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
                    }
                    pushResult(r);
                });
            break;
        case CmdType::SliderVerify:
            m_api->verifySliderCaptcha(cmd->s1, cmd->i1,
                                       [seq = cmd->seq](bool ok, const QString &msg, const QString &passToken) {
                                           neko_core_result r{};
                                           r.seq = seq;
                                           r.ok = ok ? 1 : 0;
                                           copyStr(r.message, sizeof(r.message), msg);
                                           if (ok)
                                               copyStr(r.str, sizeof(r.str), passToken);
                                           pushResult(r);
                                       });
            break;
        case CmdType::SendResetCode:
            m_api->sendResetCode(cmd->s1, [seq = cmd->seq](bool ok, const QString &msg) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), msg);
                pushResult(r);
            });
            break;
        case CmdType::ResetPassword:
            m_api->resetPassword(cmd->s1, cmd->s2, cmd->s3,
                                 [seq = cmd->seq](bool ok, const QString &msg) {
                                     neko_core_result r{};
                                     r.seq = seq;
                                     r.ok = ok ? 1 : 0;
                                     copyStr(r.message, sizeof(r.message), msg);
                                     pushResult(r);
                                 });
            break;
        case CmdType::VipPricing:
            m_api->fetchVipPricing([seq = cmd->seq](bool ok, const QString &msg, const QList<QVariantMap> &items) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                copyStr(r.message, sizeof(r.message), msg);
                if (ok) {
                    QJsonArray arr;
                    for (const auto &it : items)
                        arr.append(QJsonObject::fromVariantMap(it));
                    copyStr(r.str, sizeof(r.str),
                            QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
                }
                pushResult(r);
            });
            break;
        case CmdType::VipPayCreate:
            m_api->createVipPayOrder(cmd->i1, cmd->s1,
                                     [seq = cmd->seq](bool ok, const QString &msg, const QVariantMap &order) {
                                         neko_core_result r{};
                                         r.seq = seq;
                                         r.ok = ok ? 1 : 0;
                                         copyStr(r.message, sizeof(r.message), msg);
                                         if (ok) {
                                             const QJsonDocument doc(QJsonObject::fromVariantMap(order));
                                             copyStr(r.str, sizeof(r.str),
                                                     QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
                                         }
                                         pushResult(r);
                                     });
            break;
        case CmdType::VipSyncStatus:
            m_api->syncSessionVipStatus([seq = cmd->seq](bool ok, bool) {
                neko_core_result r{};
                r.seq = seq;
                r.ok = ok ? 1 : 0;
                QJsonObject obj;
                obj.insert(QStringLiteral("isVip"), UserManager::instance().isVip());
                obj.insert(QStringLiteral("vipExpiresAt"), UserManager::instance().vipExpiresAt());
                copyStr(r.str, sizeof(r.str),
                        QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
                pushResult(r);
            });
            break;
        case CmdType::DownloadMusic:
            doDownloadMusic(cmd);
            break;
        case CmdType::DownloadCancel:
            doDownloadCancel(cmd);
            break;
        case CmdType::DownloadsStatus:
            doDownloadsStatus(cmd);
            break;
        }
        delete cmd;
    }

private:
    void pushOk(int64_t seq)
    {
        neko_core_result r{};
        r.seq = seq;
        r.ok = 1;
        pushResult(r);
    }

    void doLogin(Cmd *cmd)
    {
        m_api->login(cmd->s1, cmd->s2,
                     [seq = cmd->seq](bool ok, const QString &message, const QString &token,
                                      const QVariantMap &user) {
                         neko_core_result r{};
                         r.seq = seq;
                         if (ok) {
                             UserManager::instance().setLoginInfo(token, user);
                             r.ok = 1;
                             copyStr(r.token, sizeof(r.token), token);
                             const QJsonDocument doc(QJsonObject::fromVariantMap(user));
                             copyStr(r.str, sizeof(r.str),
                                     QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
                         } else {
                             r.ok = 0;
                             copyStr(r.message, sizeof(r.message), message);
                         }
                         pushResult(r);
                     });
    }

    void doRegister(Cmd *cmd)
    {
        m_api->registerUser(cmd->s1, cmd->s2, cmd->s3, cmd->s4,
                            [seq = cmd->seq](bool ok, const QString &message, const QString &token,
                                             const QVariantMap &user) {
                                neko_core_result r{};
                                r.seq = seq;
                                r.ok = ok ? 1 : 0;
                                if (ok) {
                                    UserManager::instance().setLoginInfo(token, user);
                                    copyStr(r.token, sizeof(r.token), token);
                                    const QJsonDocument doc(QJsonObject::fromVariantMap(user));
                                    copyStr(r.str, sizeof(r.str),
                                            QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
                                } else {
                                    copyStr(r.message, sizeof(r.message), message);
                                }
                                pushResult(r);
                            });
    }

    void doLogout(Cmd *cmd)
    {
        UserManager::instance().logout();
        m_favIds.clear();
        pushOk(cmd->seq);
    }

    void doQueueLoad(Cmd *cmd)
    {
        neko_core_result r{};
        r.seq = cmd->seq;
        r.ok = 1;
        r.current_index = PlaylistManager::instance().currentIndex();
        copyStr(r.play_mode, sizeof(r.play_mode), PlaylistManager::instance().playMode());
        fillMusicList(&r, PlaylistManager::instance().playlist());
        pushResult(r);
    }

    void doToggleFavorite(Cmd *cmd)
    {
        const int musicId = cmd->i1;
        if (musicId <= 0 || !UserManager::instance().isLoggedIn()) {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 0;
            copyStr(r.message, sizeof(r.message), QStringLiteral("not logged in"));
            pushResult(r);
            return;
        }
        const bool fav = m_favIds.contains(musicId);
        const QByteArray auth = UserManager::instance().token().toUtf8();

        if (fav) {
            const QUrl url(QString::fromUtf8("%1/api/user/favorites/%2")
                               .arg(QString::fromUtf8(Theme::kApiBase)).arg(musicId));
            QNetworkRequest req(url);
            req.setRawHeader("Authorization", auth);
            QNetworkReply *reply = m_nam->deleteResource(req);
            connect(reply, &QNetworkReply::finished, this,
                    [reply, seq = cmd->seq, musicId, this]() {
                        reply->deleteLater();
                        const bool ok = reply->error() == QNetworkReply::NoError;
                        if (ok)
                            m_favIds.remove(musicId);
                        neko_core_result r{};
                        r.seq = seq;
                        r.ok = ok ? 1 : 0;
                        r.i64 = musicId;
                        if (!ok)
                            copyStr(r.message, sizeof(r.message), reply->errorString());
                        pushResult(r);
                    });
        } else {
            const QUrl url(QString::fromUtf8("%1/api/user/favorites").arg(QString::fromUtf8(Theme::kApiBase)));
            QNetworkRequest req(url);
            req.setRawHeader("Authorization", auth);
            req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
            QJsonObject obj;
            obj.insert(QStringLiteral("musicId"), musicId);
            QNetworkReply *reply = m_nam->post(req, QJsonDocument(obj).toJson());
            connect(reply, &QNetworkReply::finished, this,
                    [reply, seq = cmd->seq, musicId, this]() {
                        reply->deleteLater();
                        const bool ok = reply->error() == QNetworkReply::NoError;
                        if (ok)
                            m_favIds.insert(musicId);
                        neko_core_result r{};
                        r.seq = seq;
                        r.ok = ok ? 1 : 0;
                        r.i64 = musicId;
                        if (!ok)
                            copyStr(r.message, sizeof(r.message), reply->errorString());
                        pushResult(r);
                    });
        }
    }

    // ─── 下载管理（串行队列；与 MusicDownloadManager 对齐） ──────────
    struct PendingDownload {
        MusicInfo music;
        int64_t seq = 0;
    };

    QString downloadDir() const
    {
        const QString base = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        const QString dir = base + QStringLiteral("/NekoMusic");
        QDir().mkpath(dir);
        return dir;
    }

    static QString sanitizeFileComponent(const QString &text)
    {
        return QString(text).replace(
            QRegularExpression(QStringLiteral("[/\\\\:*?\"<>|]")), QStringLiteral("_"));
    }

    static QString extensionFromBuffer(const QByteArray &head)
    {
        if (head.startsWith("fLaC"))
            return QStringLiteral("flac");
        if (head.startsWith("RIFF") && head.size() >= 12 && head.mid(8, 4) == "WAVE")
            return QStringLiteral("wav");
        if (head.startsWith("OggS"))
            return QStringLiteral("ogg");
        if (head.startsWith("ID3"))
            return QStringLiteral("mp3");
        if (head.size() >= 2) {
            const auto b0 = static_cast<unsigned char>(head[0]);
            const auto b1 = static_cast<unsigned char>(head[1]);
            if (b0 == 0xFF && (b1 & 0xE0) == 0xE0)
                return QStringLiteral("mp3");
        }
        return QStringLiteral("mp3");
    }

    static QString extensionFromContentType(const QString &contentType)
    {
        const QString ct = contentType.toLower();
        if (ct.contains(QStringLiteral("flac")))
            return QStringLiteral("flac");
        if (ct.contains(QStringLiteral("wav")))
            return QStringLiteral("wav");
        if (ct.contains(QStringLiteral("ogg")))
            return QStringLiteral("ogg");
        if (ct.contains(QStringLiteral("aac")))
            return QStringLiteral("aac");
        if (ct.contains(QStringLiteral("m4a")) || ct.contains(QStringLiteral("mp4")))
            return QStringLiteral("m4a");
        if (ct.contains(QStringLiteral("mpeg")) || ct.contains(QStringLiteral("mp3")))
            return QStringLiteral("mp3");
        return QStringLiteral("mp3");
    }

    static QString detectExtension(const QString &path, const QString &contentType = {})
    {
        QFile f(path);
        if (f.open(QIODevice::ReadOnly)) {
            const QString ext = extensionFromBuffer(f.read(16));
            if (!ext.isEmpty())
                return ext;
        }
        if (!contentType.isEmpty())
            return extensionFromContentType(contentType);
        return QStringLiteral("mp3");
    }

    static QString buildAudioFileName(const MusicInfo &music, const QString &extension)
    {
        const QString base = sanitizeFileComponent(
            QStringLiteral("%1 - %2").arg(music.artist, music.title));
        return base + QLatin1Char('.') + extension;
    }

    void doDownloadMusic(Cmd *cmd)
    {
        MusicInfo music;
        if (!cmd->musicList.isEmpty())
            music = cmd->musicList.first();
        if (music.id <= 0) {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 0;
            copyStr(r.message, sizeof(r.message), QStringLiteral("invalid music"));
            pushResult(r);
            return;
        }
        // 已下载：立即完成
        const QString done = PlaylistDatabase::instance().getDownloadFilePath(music.id);
        if (!done.isEmpty() && QFile::exists(done)) {
            neko_core_result r{};
            r.seq = cmd->seq;
            r.ok = 1;
            r.i64 = music.id;
            copyStr(r.str, sizeof(r.str), done);
            pushResult(r);
            return;
        }
        // 重复加入：直接确认（不重复排队）
        for (const auto &q : m_downloadQueue) {
            if (q.music.id == music.id) {
                pushOk(cmd->seq);
                return;
            }
        }
        if (m_downloadBusy && m_downloadCurrent.music.id == music.id) {
            pushOk(cmd->seq);
            return;
        }
        m_downloadQueue.append({ music, cmd->seq });
        if (!m_downloadBusy)
            startNextDownload();
    }

    void doDownloadCancel(Cmd *cmd)
    {
        const int musicId = cmd->i1;
        if (musicId <= 0)
            return;
        for (int i = 0; i < m_downloadQueue.size(); ++i) {
            if (m_downloadQueue[i].music.id == musicId) {
                neko_core_result r{};
                r.seq = m_downloadQueue[i].seq;
                r.ok = 0;
                copyStr(r.message, sizeof(r.message), QStringLiteral("cancelled"));
                pushResult(r);
                m_downloadQueue.removeAt(i);
                pushOk(cmd->seq);
                return;
            }
        }
        if (!m_downloadBusy || m_downloadCurrent.music.id != musicId) {
            pushOk(cmd->seq);
            return;
        }
        abortDownloadTransfer();
        const int64_t pendingSeq = m_downloadCurrent.seq;
        m_downloadCurrent = {};
        m_downloadBusy = false;
        neko_core_result r{};
        r.seq = pendingSeq;
        r.ok = 0;
        copyStr(r.message, sizeof(r.message), QStringLiteral("cancelled"));
        pushResult(r);
        pushOk(cmd->seq);
        startNextDownload();
    }

    void doDownloadsStatus(Cmd *cmd)
    {
        neko_core_result r{};
        r.seq = cmd->seq;
        r.ok = 1;
        int n = 0;
        if (m_downloadBusy && m_downloadCurrent.music.id > 0) {
            fillRow(&r.rows[n], m_downloadCurrent.music);
            r.rows[n].progress_received = m_downloadReceived;
            r.rows[n].progress_total = m_downloadTotal;
            ++n;
        }
        for (const auto &q : m_downloadQueue) {
            if (n >= NEKO_CORE_MAX_ROWS)
                break;
            fillRow(&r.rows[n++], q.music);
        }
        r.nrows = n;
        pushResult(r);
    }

    void startNextDownload()
    {
        if (m_downloadQueue.isEmpty()) {
            m_downloadBusy = false;
            m_downloadCurrent = {};
            return;
        }
        m_downloadBusy = true;
        m_downloadCurrent = m_downloadQueue.takeFirst();
        m_downloadReceived = 0;
        m_downloadTotal = 0;

        // 已下载：直接完成
        const QString done = PlaylistDatabase::instance().getDownloadFilePath(m_downloadCurrent.music.id);
        if (!done.isEmpty() && QFile::exists(done)) {
            finishDownload(true, done);
            return;
        }
        startNetworkDownload(m_downloadCurrent.music);
    }

    void startNetworkDownload(const MusicInfo &music)
    {
        m_downloadTempPath = downloadDir() + QLatin1Char('/') +
                             QString::number(music.id) + QStringLiteral(".part");
        QFile::remove(m_downloadTempPath);
        m_downloadFile = new QFile(m_downloadTempPath, this);
        if (!m_downloadFile->open(QIODevice::WriteOnly)) {
            delete m_downloadFile;
            m_downloadFile = nullptr;
            finishDownload(false, QStringLiteral("无法创建下载文件"));
            return;
        }
        const QUrl url(QString::fromUtf8("%1/api/music/file/%2")
                           .arg(QString::fromUtf8(Theme::kApiBase))
                           .arg(music.id));
        QNetworkRequest req(url);
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
        req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
        m_downloadReply = m_nam->get(req);
        connect(m_downloadReply, &QNetworkReply::downloadProgress,
                this, &CoreWorker::onDownloadProgress);
        connect(m_downloadReply, &QNetworkReply::readyRead,
                this, &CoreWorker::onDownloadReadyRead);
        connect(m_downloadReply, &QNetworkReply::finished,
                this, &CoreWorker::onDownloadFinished);
    }

    void onDownloadReadyRead()
    {
        if (m_downloadReply && m_downloadFile && m_downloadFile->isOpen())
            m_downloadFile->write(m_downloadReply->readAll());
    }

    void onDownloadProgress(qint64 received, qint64 total)
    {
        if (m_downloadCurrent.music.id <= 0)
            return;
        m_downloadReceived = received;
        m_downloadTotal = total;
        // 进度事件：seq=-1，i64 放音乐 id
        neko_core_result r{};
        r.seq = -1;
        r.ok = 1;
        r.i64 = m_downloadCurrent.music.id;
        r.progress_received = received;
        r.progress_total = total;
        pushResult(r);
    }

    void onDownloadFinished()
    {
        if (!m_downloadReply)
            return;
        QNetworkReply *reply = m_downloadReply;
        m_downloadReply = nullptr;
        const QString contentType =
            reply->header(QNetworkRequest::ContentTypeHeader).toString();
        const bool netErr = reply->error() != QNetworkReply::NoError;
        const QString errStr = reply->errorString();
        reply->deleteLater();

        if (netErr) {
            if (m_downloadFile) {
                m_downloadFile->close();
                delete m_downloadFile;
                m_downloadFile = nullptr;
            }
            QFile::remove(m_downloadTempPath);
            m_downloadTempPath.clear();
            finishDownload(false, errStr);
            return;
        }
        if (m_downloadFile && m_downloadFile->isOpen()) {
            m_downloadFile->write(reply->readAll());
            m_downloadFile->close();
        }
        if (!m_downloadFile) {
            finishDownload(false, QStringLiteral("下载文件写入失败"));
            return;
        }
        delete m_downloadFile;
        m_downloadFile = nullptr;

        const QString srcPath = m_downloadTempPath;
        m_downloadTempPath.clear();
        const QString ext = detectExtension(srcPath, contentType);
        const QString finalPath =
            downloadDir() + QLatin1Char('/') + buildAudioFileName(m_downloadCurrent.music, ext);
        if (QFile::exists(finalPath))
            QFile::remove(finalPath);
        bool moved = QFile::rename(srcPath, finalPath);
        if (!moved) {
            moved = QFile::copy(srcPath, finalPath);
            QFile::remove(srcPath);
        }
        if (!moved) {
            finishDownload(false, QStringLiteral("保存下载文件失败"));
            return;
        }
        PlaylistDatabase::instance().recordDownload(m_downloadCurrent.music, finalPath);
        saveLyricsForDownload(m_downloadCurrent.music);
        finishDownload(true, finalPath);
    }

    void saveLyricsForDownload(const MusicInfo &music)
    {
        m_api->fetchLyrics(music.id, [music](bool ok, const QString &lyrics) {
            if (!ok || lyrics.trimmed().isEmpty())
                return;
            const QString base =
                QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) +
                QStringLiteral("/NekoMusic");
            const QString path = base + QLatin1Char('/') +
                                 sanitizeFileComponent(QStringLiteral("%1 - %2.lrc")
                                                           .arg(music.artist, music.title));
            QSaveFile out(path);
            if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate))
                return;
            out.write(lyrics.toUtf8());
            out.commit();
        });
    }

    void abortDownloadTransfer()
    {
        if (m_downloadReply) {
            m_downloadReply->disconnect();
            m_downloadReply->abort();
            m_downloadReply->deleteLater();
            m_downloadReply = nullptr;
        }
        if (m_downloadFile) {
            if (m_downloadFile->isOpen())
                m_downloadFile->close();
            delete m_downloadFile;
            m_downloadFile = nullptr;
        }
        if (!m_downloadTempPath.isEmpty())
            QFile::remove(m_downloadTempPath);
        m_downloadTempPath.clear();
        m_downloadReceived = 0;
        m_downloadTotal = 0;
    }

    void finishDownload(bool success, const QString &pathOrError)
    {
        const int musicId = m_downloadCurrent.music.id;
        const int64_t seq = m_downloadCurrent.seq;
        m_downloadCurrent = {};
        m_downloadBusy = false;
        m_downloadReceived = 0;
        m_downloadTotal = 0;

        neko_core_result r{};
        r.seq = seq;
        r.ok = success ? 1 : 0;
        r.i64 = musicId;
        if (success) {
            copyStr(r.str, sizeof(r.str), pathOrError);
        } else {
            copyStr(r.message, sizeof(r.message), pathOrError);
        }
        pushResult(r);
        startNextDownload();
    }

    ApiClient *m_api = nullptr;
    QNetworkAccessManager *m_nam = nullptr;
    QSet<int> m_favIds;
    QList<PendingDownload> m_downloadQueue;
    PendingDownload m_downloadCurrent;
    QNetworkReply *m_downloadReply = nullptr;
    QFile *m_downloadFile = nullptr;
    QString m_downloadTempPath;
    qint64 m_downloadReceived = 0;
    qint64 m_downloadTotal = 0;
    bool m_downloadBusy = false;
};

// 投递一个无参/单整型参数命令（worker 未启动返回 0）
int64_t postSimple(CmdType type)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = type;
    cmd->seq = nextSeq();
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t postInt(CmdType type, int value)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = type;
    cmd->seq = nextSeq();
    cmd->i1 = value;
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

// 工作线程主函数
void workerMain(int verbose)
{
    Q_UNUSED(verbose);
    // 关键修复：Flutter Linux embedder 中 GDK 已初始化并接管进程默认 glib
    // 主上下文；Qt 的 QEventDispatcherGlib 在 worker 线程构造时仍会 push
    // 该全局默认上下文（Qt 源码：app && 当前线程 == app->thread() 时用
    // g_main_context_default()）。glib 2.88 的 push 会 acquire，失败即
    // GLib-CRITICAL 中断，导致 postEventSource 等 4 个 GSource 永不 attach、
    // posted events 永不派发 → BlockingQueuedConnection 永久挂起 → Flutter
    // 首帧无法渲染（进程活着但窗口不显示）。
    // 解法：QT_NO_GLIB 强制 Qt 改用 QEventDispatcherUNIX（self-pipe 唤醒，
    // 不依赖任何 glib 主上下文），从根源避开与 GTK 主循环的冲突。
    qputenv("QT_NO_GLIB", "1");
    int argc = 1;
    static char kArg0[] = "neko_core";
    char *argv[] = { kArg0, nullptr };
    QCoreApplication app(argc, argv);

    CoreWorker worker;
    g_worker.store(&worker, std::memory_order_release);
    g_workerReady.release();

    app.exec();

    // exec 返回：清理（在 worker 线程内，DB 连接亲和）
    PlaylistDatabase::instance().close();
    g_worker.store(nullptr, std::memory_order_release);
}

} // namespace

// ─── C FFI 实现 ──────────────────────────────────────────────────────

extern "C" {

int neko_core_start(int verbose)
{
    if (g_worker.load(std::memory_order_acquire))
        return 1; // 已启动
    {
        QMutexLocker lock(&g_resultMutex);
        g_results.clear();
    }
    if (!g_thread)
        g_thread = new std::thread(workerMain, verbose);
    g_workerReady.acquire();
    // 进程退出兜底：宿主（Flutter）关窗直接 exit() 时保证 worker 被优雅 join，
    // 同时避免 joinable 线程在静态析构期析构触发 std::terminate → SIGABRT。
    static bool sExitHookRegistered = false;
    if (!sExitHookRegistered) {
        sExitHookRegistered = true;
        std::atexit([]() { neko_core_stop(); });
    }
    return g_worker.load(std::memory_order_acquire) ? 1 : 0;
}

int neko_core_stop(void)
{
    std::thread *t = g_thread;
    if (!t)
        return 0;
    // 停止后不再触发宿主回调，防止退出期回调访问已关闭的 Dart isolate
    g_evCb.store(nullptr, std::memory_order_release);
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (w) {
        // 投递退出：exec() 返回后 worker 函数自然清理并置空 g_worker
        QMetaObject::invokeMethod(w, []() { QCoreApplication::quit(); }, Qt::QueuedConnection);
    }
    if (t->joinable())
        t->join();
    g_thread = nullptr;
    delete t;
    return 1;
}

int64_t neko_core_cmd_login(const char *username, const char *password)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::Login;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(username ? username : "");
    cmd->s2 = QString::fromUtf8(password ? password : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_register(const char *username, const char *password,
                               const char *email, const char *code)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::Register;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(username ? username : "");
    cmd->s2 = QString::fromUtf8(password ? password : "");
    cmd->s3 = QString::fromUtf8(email ? email : "");
    cmd->s4 = QString::fromUtf8(code ? code : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_logout(void)
{
    return postSimple(CmdType::Logout);
}

int64_t neko_core_cmd_fetch_ranking(void)
{
    return postSimple(CmdType::FetchRanking);
}

int64_t neko_core_cmd_fetch_latest(int limit)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::FetchLatest;
    cmd->seq = nextSeq();
    cmd->i1 = limit;
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_fetch_daily(void)
{
    return postSimple(CmdType::FetchDaily);
}

int64_t neko_core_cmd_search_music(const char *query, int page, int page_size)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::SearchMusic;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(query ? query : "");
    cmd->i1 = page;
    cmd->i2 = page_size;
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_fetch_music_info(int music_id)
{
    return postInt(CmdType::FetchMusicInfo, music_id);
}

int64_t neko_core_cmd_fetch_lyrics(int music_id)
{
    return postInt(CmdType::FetchLyrics, music_id);
}

int64_t neko_core_cmd_fetch_favorites(void)
{
    return postSimple(CmdType::FetchFavorites);
}

int64_t neko_core_cmd_toggle_favorite(int music_id)
{
    return postInt(CmdType::ToggleFavorite, music_id);
}

int64_t neko_core_cmd_queue_load(void)
{
    return postSimple(CmdType::QueueLoad);
}

int64_t neko_core_cmd_queue_clear(void)
{
    return postSimple(CmdType::QueueClear);
}

int64_t neko_core_cmd_queue_add_all(const neko_core_music *list, int n)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::QueueAddAll;
    cmd->seq = nextSeq();
    for (int i = 0; i < n; ++i)
        cmd->musicList.append(musicFromRow(&list[i]));
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_queue_set_index(int index)
{
    return postInt(CmdType::QueueSetIndex, index);
}

int64_t neko_core_cmd_queue_set_mode(const char *mode)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::QueueSetMode;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(mode ? mode : "list");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_recent_load(void)
{
    return postSimple(CmdType::RecentLoad);
}

int64_t neko_core_cmd_record_recent(const neko_core_music *m)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::RecordRecent;
    cmd->seq = nextSeq();
    if (m)
        cmd->musicList.append(musicFromRow(m));
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_downloads_load(void)
{
    return postSimple(CmdType::DownloadsLoad);
}

int64_t neko_core_cmd_record_download(const neko_core_music *m, const char *file_path)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::RecordDownload;
    cmd->seq = nextSeq();
    if (m)
        cmd->musicList.append(musicFromRow(m));
    cmd->filePath = QString::fromUtf8(file_path ? file_path : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_playlist_create(const char *name, const char *description)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::PlaylistCreate;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(name ? name : "未命名歌单");
    cmd->s2 = QString::fromUtf8(description ? description : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_playlist_delete(int local_id)
{
    return postInt(CmdType::PlaylistDelete, local_id);
}

int64_t neko_core_cmd_playlist_update(int local_id, const char *name, const char *description)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::PlaylistUpdate;
    cmd->seq = nextSeq();
    cmd->i1 = local_id;
    cmd->s1 = QString::fromUtf8(name ? name : "未命名歌单");
    cmd->s2 = QString::fromUtf8(description ? description : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_playlist_list(void)
{
    return postSimple(CmdType::PlaylistList);
}

int64_t neko_core_cmd_playlist_detail(int local_id)
{
    return postInt(CmdType::PlaylistDetail, local_id);
}

int64_t neko_core_cmd_playlist_add_music(int local_id, const neko_core_music *m)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::PlaylistAddMusic;
    cmd->seq = nextSeq();
    cmd->i1 = local_id;
    if (m)
        cmd->musicList.append(musicFromRow(m));
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_playlist_remove_music(int local_id, int music_id)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::PlaylistRemoveMusic;
    cmd->seq = nextSeq();
    cmd->i1 = local_id;
    cmd->i2 = music_id;
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

// ── 云端歌单 / 歌手 / 导入 ──────────────────────────────────────────

int64_t neko_core_cmd_fetch_playlists(const char *query)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::FetchPlaylists;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(query ? query : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_search_artists(const char *query)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::SearchArtists;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(query ? query : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_fetch_user_playlists(void)
{
    return postSimple(CmdType::FetchUserPlaylists);
}

int64_t neko_core_cmd_fetch_favorite_playlists(void)
{
    return postSimple(CmdType::FetchFavoritePlaylists);
}

int64_t neko_core_cmd_fetch_playlist_music(int playlist_id)
{
    return postInt(CmdType::FetchPlaylistMusic, playlist_id);
}

int64_t neko_core_cmd_favorite_playlist(int playlist_id)
{
    return postInt(CmdType::FavoritePlaylist, playlist_id);
}

int64_t neko_core_cmd_unfavorite_playlist(int playlist_id)
{
    return postInt(CmdType::UnfavoritePlaylist, playlist_id);
}

int64_t neko_core_cmd_cloud_playlist_create(const char *name, const char *description)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::CloudPlaylistCreate;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(name ? name : "未命名歌单");
    cmd->s2 = QString::fromUtf8(description ? description : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_cloud_playlist_delete(int playlist_id)
{
    return postInt(CmdType::CloudPlaylistDelete, playlist_id);
}

int64_t neko_core_cmd_fetch_netease_playlist(const char *playlist_id)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::FetchNeteasePlaylist;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(playlist_id ? playlist_id : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_fetch_qq_playlist(const char *disstid)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::FetchQqPlaylist;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(disstid ? disstid : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_batch_search_music(const char *items_json)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::BatchSearchMusic;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(items_json ? items_json : "[]");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_batch_add_music_to_playlist(int playlist_id, const char *ids_json)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::BatchAddMusicToPlaylist;
    cmd->seq = nextSeq();
    cmd->i1 = playlist_id;
    cmd->s2 = QString::fromUtf8(ids_json ? ids_json : "[]");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

// ── 登录增强（改密 / 滑块验证 / 邮箱验证码 / 找回密码） ────────────────

int64_t neko_core_cmd_change_password(const char *old_password, const char *new_password)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::ChangePassword;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(old_password ? old_password : "");
    cmd->s2 = QString::fromUtf8(new_password ? new_password : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_send_verification(const char *email, const char *username,
                                        const char *captcha_pass_token)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::SendVerification;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(email ? email : "");
    cmd->s2 = QString::fromUtf8(username ? username : "");
    cmd->s3 = QString::fromUtf8(captcha_pass_token ? captcha_pass_token : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_slider_challenge(void)
{
    return postSimple(CmdType::SliderChallenge);
}

int64_t neko_core_cmd_slider_verify(const char *captcha_token, int offset_x)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::SliderVerify;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(captcha_token ? captcha_token : "");
    cmd->i1 = offset_x;
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_send_reset_code(const char *email)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::SendResetCode;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(email ? email : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_reset_password(const char *email, const char *code, const char *new_password)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::ResetPassword;
    cmd->seq = nextSeq();
    cmd->s1 = QString::fromUtf8(email ? email : "");
    cmd->s2 = QString::fromUtf8(code ? code : "");
    cmd->s3 = QString::fromUtf8(new_password ? new_password : "");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

// ── 会员中心 ─────────────────────────────────────────────────────────

int64_t neko_core_cmd_vip_pricing(void)
{
    return postSimple(CmdType::VipPricing);
}

int64_t neko_core_cmd_vip_pay_create(int pricing_id, const char *pay_type)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::VipPayCreate;
    cmd->seq = nextSeq();
    cmd->i1 = pricing_id;
    cmd->s1 = QString::fromUtf8(pay_type ? pay_type : "alipay");
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_vip_sync_status(void)
{
    return postSimple(CmdType::VipSyncStatus);
}

// ── 下载管理（串行队列） ─────────────────────────────────────────────

int64_t neko_core_cmd_download_music(const neko_core_music *m)
{
    QObject *w = g_worker.load(std::memory_order_acquire);
    if (!w)
        return 0;
    auto *cmd = new Cmd;
    cmd->type = CmdType::DownloadMusic;
    cmd->seq = nextSeq();
    if (m)
        cmd->musicList.append(musicFromRow(m));
    QMetaObject::invokeMethod(w,
                              [w, cmd]() { static_cast<CoreWorker *>(w)->processCommand(cmd); },
                              Qt::QueuedConnection);
    return cmd->seq;
}

int64_t neko_core_cmd_download_cancel(int music_id)
{
    return postInt(CmdType::DownloadCancel, music_id);
}

int64_t neko_core_cmd_downloads_status(void)
{
    return postSimple(CmdType::DownloadsStatus);
}

int neko_core_get_login_state(void)
{
    int state = 0;
    invokeBlocking([&state]() { state = UserManager::instance().isLoggedIn() ? 1 : 0; });
    return state;
}

int neko_core_get_login_info(char *buf, int buf_size)
{
    if (!buf || buf_size <= 0)
        return 0;
    QByteArray out;
    invokeBlocking([&out]() {
        if (UserManager::instance().isLoggedIn()) {
            const QJsonDocument doc(
                QJsonObject::fromVariantMap(UserManager::instance().userInfo()));
            out = doc.toJson(QJsonDocument::Compact);
        }
    });
    if (out.isEmpty())
        return 0;
    const size_t n = static_cast<size_t>(out.size());
    if (n >= static_cast<size_t>(buf_size))
        std::memcpy(buf, out.constData(), static_cast<size_t>(buf_size - 1));
    else
        std::memcpy(buf, out.constData(), n);
    buf[n >= static_cast<size_t>(buf_size) ? buf_size - 1 : n] = '\0';
    return 1;
}

int neko_core_audio_headers(char *buf, int buf_size)
{
    if (!buf || buf_size <= 0)
        return 0;
    QByteArray out;
    invokeBlocking([&out]() {
        if (UserManager::instance().isLoggedIn()) {
            out = "Authorization: ";
            out += UserManager::instance().token().toUtf8();
        }
    });
    if (out.isEmpty())
        return 0;
    const size_t n = static_cast<size_t>(out.size());
    if (n >= static_cast<size_t>(buf_size))
        std::memcpy(buf, out.constData(), static_cast<size_t>(buf_size - 1));
    else
        std::memcpy(buf, out.constData(), n);
    buf[n >= static_cast<size_t>(buf_size) ? buf_size - 1 : n] = '\0';
    return 1;
}

int neko_core_poll(neko_core_result *out)
{
    if (!out)
        return 0;
    QMutexLocker lock(&g_resultMutex);
    if (g_results.empty())
        return 0;
    *out = g_results.front();
    g_results.pop_front();
    return 1;
}

void neko_core_set_event_cb(neko_core_event_cb cb, void *user)
{
    g_evUser = user;
    g_evCb.store(cb, std::memory_order_release);
}

} // extern "C"

#include "neko_core.moc"
