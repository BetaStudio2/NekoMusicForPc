/**
 * @file replaynonce.cpp
 * @brief 通用请求防重放 nonce 池实现
 */

#include "core/replaynonce.h"
#include "theme/theme.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

namespace {

/** 一次领取的数量；读 / 写各自上限与后端一致（64）。 */
constexpr int kBatch = 16;
/** 低于该水位就后台补一批。 */
constexpr int kLowWater = 4;
/** 本地提前作废时间（服务端 TTL 120 秒）。 */
constexpr qint64 kLocalMaxAgeMs = 90 * 1000;
/** 池空时同步补领的最长等待时间。 */
constexpr int kBlockingFetchTimeoutMs = 4000;

} // namespace

ReplayNonceStore &ReplayNonceStore::instance()
{
    static ReplayNonceStore store;
    return store;
}

const char *ReplayNonceStore::nonceHeader()
{
    return "X-Neko-Nonce";
}

const char *ReplayNonceStore::statusHeader()
{
    return "X-Neko-Replay-Status";
}

ReplayNonceStore::ReplayNonceStore(QObject *parent)
    : QObject(parent)
{
}

ReplayNonceStore::~ReplayNonceStore() = default;

QString ReplayNonceStore::take(bool write)
{
    if (QThread::currentThread() == thread())
        return takeLocal(write);

    // 其它线程（例如媒体 I/O 线程）也会发受保护请求：池本身跨线程安全，可以直接取；
    // 取不到就请所属线程补领并有限等待——QNetworkReply 只能在所属线程派发回调，这里
    // 既不能自己发请求，也不能无限期阻塞。
    QString nonce = pop(write);
    if (!nonce.isEmpty())
        return nonce;

    requestRefill();
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < kBlockingFetchTimeoutMs) {
        QThread::msleep(10);
        nonce = pop(write);
        if (!nonce.isEmpty())
            break;
    }
    return nonce;
}

QString ReplayNonceStore::takeLocal(bool write)
{
    QString nonce = pop(write);
    if (nonce.isEmpty()) {
        // 池已空：同步等一次领取（已有领取在途就等它，避免多头发请求）。
        // 解析槽先于 quit 执行，返回时池已填充。
        QNetworkReply *reply = startFetch(kBatch, kBatch);
        if (!reply)
            reply = pendingFetch();
        if (reply) {
            QPointer<QNetworkReply> guard(reply);
            QEventLoop loop;
            QTimer timer;
            timer.setSingleShot(true);
            QObject::connect(guard, &QNetworkReply::finished, &loop, &QEventLoop::quit);
            QObject::connect(&timer, &QTimer::timeout, &loop, [&loop, guard]() {
                if (guard)
                    guard->abort();
                loop.quit();
            });
            timer.start(kBlockingFetchTimeoutMs);
            loop.exec();
            nonce = pop(write);
        }
    }

    if (!nonce.isEmpty()) {
        bool low = false;
        {
            QMutexLocker locker(&m_mutex);
            low = (m_readPool.size() < kLowWater || m_writePool.size() < kLowWater);
        }
        // 注意：不能在持锁时补领（startFetch 会再次加锁）
        if (low)
            requestRefill();
    }
    return nonce;
}

void ReplayNonceStore::noteReplayRejected()
{
    {
        QMutexLocker locker(&m_mutex);
        m_readPool.clear();
        m_writePool.clear();
    }
    requestRefill();
}

QString ReplayNonceStore::pop(bool write)
{
    QMutexLocker locker(&m_mutex);
    QList<Entry> &pool = write ? m_writePool : m_readPool;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    while (!pool.isEmpty()) {
        const Entry entry = pool.takeFirst();
        if (now - entry.issuedAt < kLocalMaxAgeMs)
            return entry.value;
    }
    return QString();
}

QNetworkReply *ReplayNonceStore::startFetch(int read, int write)
{
    {
        QMutexLocker locker(&m_mutex);
        if (m_pendingFetch)
            return nullptr;
    }

    const QString base = QString::fromUtf8(Theme::kApiBase);
    if (base.isEmpty()) {
        return nullptr;
    }

    QUrl url(base + QStringLiteral("/api/replay/nonce"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("read"), QString::number(read));
    query.addQueryItem(QStringLiteral("write"), QString::number(write));
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setRawHeader("Cache-Control", "no-store");

    QNetworkReply *reply = m_nam.get(req);
    {
        QMutexLocker locker(&m_mutex);
        m_pendingFetch = reply; // get() 可能同步失败并返回已结束的回复，这里只做去重登记
    }
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleFetchReply(reply);
    });
    return reply;
}

QNetworkReply *ReplayNonceStore::pendingFetch()
{
    QMutexLocker locker(&m_mutex);
    return m_pendingFetch;
}

void ReplayNonceStore::handleFetchReply(QNetworkReply *reply)
{
    {
        QMutexLocker locker(&m_mutex);
        if (m_pendingFetch == reply)
            m_pendingFetch = nullptr;
    }

    const bool ok = (reply->error() == QNetworkReply::NoError);
    const QByteArray body = reply->readAll();
    const QString errorString = reply->errorString();
    reply->deleteLater();

    if (!ok) {
        qWarning() << "[replay] 领取防重放 nonce 失败:" << errorString;
        return;
    }

    const QJsonObject root = QJsonDocument::fromJson(body).object();
    const QJsonObject nonces = root.value(QStringLiteral("data")).toObject()
                                   .value(QStringLiteral("nonces")).toObject();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    QMutexLocker locker(&m_mutex);
    const auto append = [now](QList<Entry> &pool, const QJsonArray &array) {
        for (const auto &value : array) {
            const QString nonce = value.toString();
            if (!nonce.isEmpty())
                pool.append(Entry{nonce, now});
        }
    };
    append(m_readPool, nonces.value(QStringLiteral("read")).toArray());
    append(m_writePool, nonces.value(QStringLiteral("write")).toArray());
}

void ReplayNonceStore::requestRefill()
{
    if (QThread::currentThread() == thread()) {
        refill();
        return;
    }
    QMetaObject::invokeMethod(this, [this]() { refill(); }, Qt::QueuedConnection);
}

void ReplayNonceStore::refill()
{
    if (QThread::currentThread() != thread()) {
        requestRefill();
        return;
    }
    startFetch(kBatch, kBatch);
}
