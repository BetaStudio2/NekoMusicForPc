/**
 * @file mcpbridge.cpp
 */

#include "mcpbridge.h"

#include "core/apiclient.h"
#include "core/playerengine.h"
#include "core/playlistmanager.h"
#include "theme/theme.h"

#include <QJsonValue>
#include <QVariantMap>

namespace {

QJsonObject objSchema(const QJsonObject &properties, const QJsonArray &required = QJsonArray())
{
    QJsonObject schema{
        {QStringLiteral("type"), QStringLiteral("object")},
        {QStringLiteral("properties"), properties},
    };
    if (!required.isEmpty())
        schema.insert(QStringLiteral("required"), required);
    return schema;
}

QJsonObject toolDef(const QString &name, const QString &description, const QJsonObject &inputSchema)
{
    return QJsonObject{
        {QStringLiteral("name"), name},
        {QStringLiteral("description"), description},
        {QStringLiteral("inputSchema"), inputSchema},
    };
}

QJsonObject prop(const QString &type, const QString &description)
{
    return QJsonObject{{QStringLiteral("type"), type}, {QStringLiteral("description"), description}};
}

QJsonObject numProp(const QString &description, double minimum, double maximum)
{
    QJsonObject p = prop(QStringLiteral("number"), description);
    p.insert(QStringLiteral("minimum"), minimum);
    p.insert(QStringLiteral("maximum"), maximum);
    return p;
}

QString stateName(PlayerEngine::PlaybackState state)
{
    switch (state) {
    case PlayerEngine::Playing: return QStringLiteral("playing");
    case PlayerEngine::Paused: return QStringLiteral("paused");
    default: return QStringLiteral("stopped");
    }
}

} // namespace

McpBridge::McpBridge(PlayerEngine *engine, ApiClient *api, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
    , m_api(api)
{
}

QJsonArray McpBridge::listTools() const
{
    QJsonArray tools;

    tools.append(toolDef(QStringLiteral("get_playback_state"),
                         QStringLiteral("获取当前播放状态：播放/暂停/停止、进度、时长、音量与播放模式。"),
                         objSchema(QJsonObject{})));

    tools.append(toolDef(QStringLiteral("get_current_track"),
                         QStringLiteral("获取当前正在播放的曲目信息（没有则返回 null）。"),
                         objSchema(QJsonObject{})));

    tools.append(toolDef(QStringLiteral("get_queue"),
                         QStringLiteral("获取当前播放队列（含每首曲目的 ID、标题、歌手）与当前下标。"),
                         objSchema(QJsonObject{})));

    tools.append(toolDef(QStringLiteral("play"),
                         QStringLiteral("开始/继续播放当前曲目。"), objSchema(QJsonObject{})));
    tools.append(toolDef(QStringLiteral("pause"),
                         QStringLiteral("暂停播放。"), objSchema(QJsonObject{})));
    tools.append(toolDef(QStringLiteral("toggle_playback"),
                         QStringLiteral("在播放与暂停之间切换。"), objSchema(QJsonObject{})));
    tools.append(toolDef(QStringLiteral("stop"),
                         QStringLiteral("停止播放。"), objSchema(QJsonObject{})));
    tools.append(toolDef(QStringLiteral("next_track"),
                         QStringLiteral("切到下一首。"), objSchema(QJsonObject{})));
    tools.append(toolDef(QStringLiteral("previous_track"),
                         QStringLiteral("切到上一首。"), objSchema(QJsonObject{})));

    tools.append(toolDef(QStringLiteral("seek"),
                         QStringLiteral("跳转到指定播放位置（秒）。"),
                         objSchema(QJsonObject{{QStringLiteral("position"),
                                                numProp(QStringLiteral("目标位置（秒）"), 0, 24 * 3600)}},
                                   QJsonArray{QStringLiteral("position")})));

    tools.append(toolDef(QStringLiteral("set_volume"),
                         QStringLiteral("设置音量（0-100）。"),
                         objSchema(QJsonObject{{QStringLiteral("volume"),
                                                numProp(QStringLiteral("音量百分比"), 0, 100)}},
                                   QJsonArray{QStringLiteral("volume")})));

    tools.append(toolDef(QStringLiteral("set_play_mode"),
                         QStringLiteral("设置播放模式：list=列表循环，single=单曲循环，random=随机。"),
                         objSchema(QJsonObject{{QStringLiteral("mode"),
                                                QJsonObject{
                                                    {QStringLiteral("type"), QStringLiteral("string")},
                                                    {QStringLiteral("description"), QStringLiteral("播放模式")},
                                                    {QStringLiteral("enum"),
                                                     QJsonArray{QStringLiteral("list"),
                                                                QStringLiteral("single"),
                                                                QStringLiteral("random")}}}}},
                                   QJsonArray{QStringLiteral("mode")})));

    tools.append(toolDef(QStringLiteral("search_music"),
                         QStringLiteral("按关键词搜索曲库，返回匹配的曲目列表（含 ID）。"),
                         objSchema(QJsonObject{{QStringLiteral("query"), prop(QStringLiteral("string"), QStringLiteral("搜索关键词"))},
                                                {QStringLiteral("limit"), numProp(QStringLiteral("返回数量，默认 10，最大 50"), 1, 50)}},
                                   QJsonArray{QStringLiteral("query")})));

    tools.append(toolDef(QStringLiteral("play_music"),
                         QStringLiteral("按曲目 ID 播放（ID 可由 search_music 获得）。"),
                         objSchema(QJsonObject{{QStringLiteral("music_id"),
                                                numProp(QStringLiteral("曲目 ID"), 1, 1e12)}},
                                   QJsonArray{QStringLiteral("music_id")})));

    tools.append(toolDef(QStringLiteral("play_search_result"),
                         QStringLiteral("搜索并按序号播放第一个/第 N 个结果（index 从 1 开始）。"),
                         objSchema(QJsonObject{{QStringLiteral("query"), prop(QStringLiteral("string"), QStringLiteral("搜索关键词"))},
                                                {QStringLiteral("index"), numProp(QStringLiteral("结果序号，默认 1"), 1, 50)}},
                                   QJsonArray{QStringLiteral("query")})));

    return tools;
}

void McpBridge::callTool(const QString &name, const QJsonObject &arguments, Done done)
{
    if (!done)
        return;

    auto fail = [done](const QString &message) { done(false, message, QJsonObject()); };
    auto ok = [done](const QString &text, const QJsonObject &structured = QJsonObject()) {
        done(true, text, structured);
    };

    if (!m_engine) {
        fail(QStringLiteral("播放引擎不可用"));
        return;
    }

    if (name == QLatin1String("get_playback_state") || name == QLatin1String("get_current_track")
        || name == QLatin1String("get_queue")) {
        const MusicInfo &current = m_engine->currentMusic();
        const bool hasTrack = !current.title.isEmpty() || current.id > 0;
        if (name == QLatin1String("get_playback_state")) {
            const QJsonObject state = playbackStateJson();
            ok(QStringLiteral("状态：%1，音量 %2%，进度 %3s/%4s")
                   .arg(state.value(QStringLiteral("state")).toString())
                   .arg(state.value(QStringLiteral("volume")).toInt())
                   .arg(state.value(QStringLiteral("position_seconds")).toInt())
                   .arg(state.value(QStringLiteral("duration_seconds")).toInt()),
               state);
            return;
        }
        if (name == QLatin1String("get_current_track")) {
            if (!hasTrack) {
                ok(QStringLiteral("当前没有正在播放的曲目"), QJsonObject{{QStringLiteral("track"), QJsonValue()}});
                return;
            }
            const QJsonObject track = trackJson(current);
            ok(QStringLiteral("正在播放：%1 - %2").arg(current.title, current.artist), track);
            return;
        }
        const QList<MusicInfo> &queue = PlaylistManager::instance().playlist();
        QJsonArray tracks;
        for (const MusicInfo &info : queue)
            tracks.append(trackJson(info));
        ok(QStringLiteral("队列共 %1 首，当前第 %2 首")
               .arg(queue.size())
               .arg(PlaylistManager::instance().currentIndex() + 1),
           QJsonObject{{QStringLiteral("current_index"), PlaylistManager::instance().currentIndex()},
                       {QStringLiteral("tracks"), tracks}});
        return;
    }

    if (name == QLatin1String("play")) {
        m_engine->play();
        ok(QStringLiteral("已继续播放"));
        return;
    }
    if (name == QLatin1String("pause")) {
        m_engine->pause();
        ok(QStringLiteral("已暂停"));
        return;
    }
    if (name == QLatin1String("toggle_playback")) {
        if (m_engine->playbackState() == PlayerEngine::Playing)
            m_engine->pause();
        else
            m_engine->play();
        ok(QStringLiteral("当前状态：%1").arg(stateName(m_engine->playbackState())));
        return;
    }
    if (name == QLatin1String("stop")) {
        m_engine->stop();
        ok(QStringLiteral("已停止播放"));
        return;
    }
    if (name == QLatin1String("next_track")) {
        if (!m_next) {
            fail(QStringLiteral("当前未接入切歌回调"));
            return;
        }
        m_next();
        ok(QStringLiteral("已切到下一首"));
        return;
    }
    if (name == QLatin1String("previous_track")) {
        if (!m_previous) {
            fail(QStringLiteral("当前未接入切歌回调"));
            return;
        }
        m_previous();
        ok(QStringLiteral("已切到上一首"));
        return;
    }
    if (name == QLatin1String("seek")) {
        const double seconds = arguments.value(QStringLiteral("position")).toDouble(-1);
        if (seconds < 0) {
            fail(QStringLiteral("缺少参数 position"));
            return;
        }
        m_engine->setPosition(static_cast<qint64>(seconds * 1000));
        ok(QStringLiteral("已跳转到 %1 秒").arg(seconds));
        return;
    }
    if (name == QLatin1String("set_volume")) {
        const double volume = arguments.value(QStringLiteral("volume")).toDouble(-1);
        if (volume < 0 || volume > 100) {
            fail(QStringLiteral("volume 需在 0-100 之间"));
            return;
        }
        m_engine->setVolume(static_cast<float>(volume / 100.0));
        ok(QStringLiteral("音量已设为 %1%").arg(static_cast<int>(volume)));
        return;
    }
    if (name == QLatin1String("set_play_mode")) {
        const QString mode = arguments.value(QStringLiteral("mode")).toString();
        if (mode != QLatin1String("list") && mode != QLatin1String("single") && mode != QLatin1String("random")) {
            fail(QStringLiteral("mode 仅支持 list / single / random"));
            return;
        }
        PlaylistManager::instance().setPlayMode(mode);
        ok(QStringLiteral("播放模式已设为 %1").arg(mode));
        return;
    }
    if (name == QLatin1String("search_music")) {
        const QString query = arguments.value(QStringLiteral("query")).toString().trimmed();
        if (query.isEmpty()) {
            fail(QStringLiteral("缺少参数 query"));
            return;
        }
        int limit = arguments.value(QStringLiteral("limit")).toInt(10);
        limit = qBound(1, limit, 50);
        runSearch(query, limit, [ok, fail](bool success, const QList<MusicInfo> &tracks, const QString &error) {
            if (!success) {
                fail(error);
                return;
            }
            QJsonArray arr;
            for (const MusicInfo &info : tracks)
                arr.append(trackJson(info));
            ok(QStringLiteral("找到 %1 首匹配曲目").arg(tracks.size()),
               QJsonObject{{QStringLiteral("tracks"), arr}});
        });
        return;
    }
    if (name == QLatin1String("play_music")) {
        const int musicId = arguments.value(QStringLiteral("music_id")).toInt(0);
        if (musicId <= 0) {
            fail(QStringLiteral("缺少有效的 music_id"));
            return;
        }
        if (!m_play) {
            fail(QStringLiteral("当前未接入播放回调"));
            return;
        }
        // 优先复用队列里已有的曲目信息，避免播放列表出现空白标题。
        const QList<MusicInfo> &queue = PlaylistManager::instance().playlist();
        for (const MusicInfo &item : queue) {
            if (item.id != musicId)
                continue;
            m_play(item);
            ok(QStringLiteral("已请求播放：%1 - %2").arg(item.title, item.artist));
            return;
        }
        // 队列中没有，则向服务端拉取曲目详情后再播放。
        if (m_api) {
            m_api->fetchMusicInfo(
                musicId, [this, musicId, ok, fail](bool success, const QVariantMap &data) {
                    MusicInfo info;
                    info.id = musicId;
                    if (success) {
                        info.title = data.value(QStringLiteral("title")).toString();
                        info.artist = data.value(QStringLiteral("artist")).toString();
                        info.album = data.value(QStringLiteral("album")).toString();
                        info.duration = data.value(QStringLiteral("duration")).toInt();
                        info.coverUrl = data.value(QStringLiteral("coverUrl")).toString();
                    }
                    if (!m_play) {
                        fail(QStringLiteral("当前未接入播放回调"));
                        return;
                    }
                    m_play(info);
                    if (success && !info.title.isEmpty())
                        ok(QStringLiteral("正在播放：%1 - %2").arg(info.title, info.artist));
                    else
                        ok(QStringLiteral("已请求播放曲目 %1").arg(musicId));
                });
            return;
        }
        MusicInfo info;
        info.id = musicId;
        m_play(info);
        ok(QStringLiteral("已请求播放曲目 %1").arg(musicId));
        return;
    }
    if (name == QLatin1String("play_search_result")) {
        const QString query = arguments.value(QStringLiteral("query")).toString().trimmed();
        if (query.isEmpty()) {
            fail(QStringLiteral("缺少参数 query"));
            return;
        }
        const int index = qMax(1, arguments.value(QStringLiteral("index")).toInt(1));
        if (!m_play) {
            fail(QStringLiteral("当前未接入播放回调"));
            return;
        }
        runSearch(query, index, [this, index, ok, fail](bool success, const QList<MusicInfo> &tracks, const QString &error) {
            if (!success) {
                fail(error);
                return;
            }
            if (tracks.size() < index) {
                fail(QStringLiteral("搜索结果不足 %1 条").arg(index));
                return;
            }
            const MusicInfo &info = tracks.at(index - 1);
            if (m_play)
                m_play(info);
            ok(QStringLiteral("正在播放：%1 - %2").arg(info.title, info.artist));
        });
        return;
    }

    fail(QStringLiteral("未知工具：%1").arg(name));
}

QJsonObject McpBridge::playbackStateJson() const
{
    const qint64 duration = m_engine->duration();
    const qint64 position = m_engine->position();
    QJsonObject state{
        {QStringLiteral("state"), stateName(m_engine->playbackState())},
        {QStringLiteral("volume"), static_cast<int>(m_engine->volume() * 100.0f + 0.5f)},
        {QStringLiteral("position_seconds"), static_cast<double>(position) / 1000.0},
        {QStringLiteral("duration_seconds"), static_cast<double>(duration) / 1000.0},
        {QStringLiteral("play_mode"), PlaylistManager::instance().playMode()},
    };
    const MusicInfo &current = m_engine->currentMusic();
    if (!current.title.isEmpty() || current.id > 0)
        state.insert(QStringLiteral("track"), trackJson(current));
    return state;
}

QJsonObject McpBridge::trackJson(const MusicInfo &info)
{
    return QJsonObject{
        {QStringLiteral("id"), info.id},
        {QStringLiteral("title"), info.title},
        {QStringLiteral("artist"), info.artist},
        {QStringLiteral("album"), info.album},
        {QStringLiteral("duration"), info.duration},
        {QStringLiteral("cover_url"), info.coverUrl},
    };
}

void McpBridge::runSearch(const QString &query, int limit,
                          std::function<void(bool, const QList<MusicInfo> &, const QString &)> done)
{
    if (!m_api) {
        done(false, {}, QStringLiteral("搜索接口不可用"));
        return;
    }
    m_api->searchMusic(query, 1, qBound(1, limit, 50),
                       [done](bool ok, int, int, int, const QList<QVariantMap> &results) {
                           if (!ok) {
                               done(false, {}, QStringLiteral("搜索失败，请稍后重试"));
                               return;
                           }
                           QList<MusicInfo> tracks;
                           for (const QVariantMap &map : results) {
                               MusicInfo info;
                               info.id = map.value(QStringLiteral("id")).toInt();
                               info.title = map.value(QStringLiteral("title")).toString();
                               info.artist = map.value(QStringLiteral("artist")).toString();
                               info.album = map.value(QStringLiteral("album")).toString();
                               info.duration = map.value(QStringLiteral("duration")).toInt();
                               if (info.id > 0)
                                   info.coverUrl = QString::fromUtf8("%1/api/music/cover/%2").arg(Theme::kApiBase).arg(info.id);
                               tracks.append(info);
                           }
                           done(true, tracks, QString());
                       });
}
