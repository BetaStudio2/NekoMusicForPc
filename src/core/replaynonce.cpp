/**
 * @file replaynonce.cpp
 * @brief 通用请求防重放 nonce 池实现
 */

#include "core/replaynonce.h"
#include "theme/theme.h"

#include <QCryptographicHash>
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
#include <QtConcurrent>

#include <cstring>

namespace {

/** 一次领取的数量；读 / 写各自上限与后端一致（64）。 */
constexpr int kBatch = 16;
/** 低于该水位就后台补一批。 */
constexpr int kLowWater = 4;
/** 本地提前作废时间（服务端 TTL 120 秒）。 */
constexpr qint64 kLocalMaxAgeMs = 90 * 1000;
/** 池空时同步补领的最长等待时间。 */
constexpr int kBlockingFetchTimeoutMs = 4000;
/** 一轮领取里「换题 → 解题 → 兑换」的最大尝试次数。 */
constexpr int kClaimAttempts = 2;
/** 与服务端约定的解题算法标识；换题响应里的 algorithm 必须与它一致，否则不盲解。 */
constexpr char kPowAlgorithm[] = "sha256-leading-zero-bits";
/** 难度上限：服务端远低于此值，这里只是防止异常输入把线程卡死。 */
constexpr int kMaxDifficultyBits = 64;

/** 摘要的前导零比特数是否达到 bits（与后端 ReplayChallengeService.meetsDifficulty 一致）。 */
bool meetsDifficulty(const QByteArray &hash, int bits)
{
    const int fullBytes = bits / 8;
    const int remainingBits = bits % 8;
    if (hash.size() < fullBytes + (remainingBits > 0 ? 1 : 0))
        return false;
    for (int i = 0; i < fullBytes; ++i) {
        if (static_cast<quint8>(hash.at(i)) != 0)
            return false;
    }
    if (remainingBits == 0)
        return true;
    const int mask = (0xFF << (8 - remainingBits)) & 0xFF;
    return (static_cast<quint8>(hash.at(fullBytes)) & mask) == 0;
}

/**
 * 解出挑战题：找一个十进制计数器，使 SHA-256(seed + ":" + 计数器) 的前导零比特数达到 difficulty，
 * 返回计数器的十进制字符串作为 proof。
 *
 * 服务端只验一次哈希，客户端要试 2^difficulty 量级的次数——这种成本不对称正是该方案的基础，
 * 所以这里复用同一个哈希实例与消息缓冲区，不做多余分配。难度非法时返回空串。
 */
QString solveProof(const QString &seed, int difficulty)
{
    if (difficulty < 0 || difficulty > kMaxDifficultyBits)
        return QString();

    QByteArray message = seed.toUtf8();
    message.append(':');
    const int prefixLength = message.size();
    // 留出最长 19 位十进制计数器，随用随覆盖
    message.resize(prefixLength + 20);

    QCryptographicHash hash(QCryptographicHash::Sha256);
    for (quint64 counter = 0;; ++counter) {
        const QByteArray digits = QByteArray::number(counter);
        std::memcpy(message.data() + prefixLength, digits.constData(),
                    static_cast<size_t>(digits.size()));
        hash.reset();
        hash.addData(QByteArrayView(message.constData(), prefixLength + digits.size()));
        if (meetsDifficulty(hash.result(), difficulty))
            return QString::fromLatin1(digits);
    }
}

/** 领取链路（换题 / 兑换）的公共请求参数：不跟随跨域重定向、不走 HTTP/2、不缓存。 */
QNetworkRequest buildFetchRequest(const QUrl &url)
{
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setRawHeader("Cache-Control", "no-store");
    return req;
}

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
        // 池已空：同步等一轮领取（换题 → 解题 → 兑换）。已有一轮在途就等它结束，避免多头发
        // 请求；填充槽先于 quit 执行，返回时池已填好。超时只是不再等，在途请求照常填池。
        bool finished = false;
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        const QMetaObject::Connection roundDone = QObject::connect(
                this, &ReplayNonceStore::fetchRoundFinished, &loop, [&finished, &loop]() {
                    finished = true;
                    loop.quit();
                });
        QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timer.start(kBlockingFetchTimeoutMs);
        startRound(kBatch, kBatch);
        if (!finished)
            loop.exec();
        QObject::disconnect(roundDone);
        nonce = pop(write);
    }

    if (!nonce.isEmpty()) {
        bool low = false;
        {
            QMutexLocker locker(&m_mutex);
            low = (m_readPool.size() < kLowWater || m_writePool.size() < kLowWater);
        }
        // 注意：不能在持锁时补领（领取过程会再次加锁）
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

void ReplayNonceStore::startRound(int read, int write)
{
    if (m_roundActive)
        return;
    m_roundActive = true;
    requestChallenge(read, write, 0);
}

void ReplayNonceStore::requestChallenge(int read, int write, int attempt)
{
    const QString base = QString::fromUtf8(Theme::kApiBase);
    if (base.isEmpty()) {
        finishRound();
        return;
    }

    QUrl url(base + QStringLiteral("/api/replay/challenge"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("read"), QString::number(read));
    query.addQueryItem(QStringLiteral("write"), QString::number(write));
    url.setQuery(query);

    QNetworkReply *reply = m_nam.get(buildFetchRequest(url));
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, read, write, attempt]() {
        handleChallengeReply(reply, read, write, attempt);
    });
}

void ReplayNonceStore::handleChallengeReply(QNetworkReply *reply, int read, int write, int attempt)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const QNetworkReply::NetworkError error = reply->error();
    const QString errorString = reply->errorString();
    reply->deleteLater();

    if (!m_roundActive)
        return;

    // 服务端还没有挑战接口（分批发版期间）：回退为不带挑战的领取。新服务端会拒绝，
    // 拿不到 nonce 也没有副作用；旧服务端则能正常签发。
    if (status == 404) {
        requestClaim(QString(), QString(), read, write, attempt);
        return;
    }
    if (error != QNetworkReply::NoError || status != 200) {
        qWarning() << "[replay] 换题失败:" << status << errorString;
        finishRound();
        return;
    }

    const QJsonObject data = QJsonDocument::fromJson(body).object()
                                     .value(QStringLiteral("data")).toObject();
    const QString algorithm = data.value(QStringLiteral("algorithm")).toString();
    const QString challenge = data.value(QStringLiteral("challenge")).toString();
    const QString seed = data.value(QStringLiteral("seed")).toString();
    const int difficulty = data.value(QStringLiteral("difficulty")).toInt(-1);
    if (algorithm != QLatin1String(kPowAlgorithm) || challenge.isEmpty() || seed.isEmpty()
        || difficulty < 0) {
        qWarning() << "[replay] 换题响应无法识别，放弃本轮领取";
        finishRound();
        return;
    }

    // 解题要试 2^difficulty 量级的哈希，放到工作线程算，避免卡住用户界面
    QPointer<ReplayNonceStore> self(this);
    (void)QtConcurrent::run([self, challenge, seed, difficulty, read, write, attempt]() {
        const QString proof = solveProof(seed, difficulty);
        if (!self)
            return;
        QMetaObject::invokeMethod(
                self.data(),
                [self, challenge, proof, read, write, attempt]() {
                    if (!self || !self->m_roundActive)
                        return;
                    self->requestClaim(challenge, proof, read, write, attempt);
                },
                Qt::QueuedConnection);
    });
}

void ReplayNonceStore::requestClaim(const QString &challenge, const QString &proof, int read,
                                    int write, int attempt)
{
    const QString base = QString::fromUtf8(Theme::kApiBase);
    if (base.isEmpty()) {
        finishRound();
        return;
    }

    QUrl url(base + QStringLiteral("/api/replay/nonce"));
    QUrlQuery query;
    if (challenge.isEmpty()) {
        // 旧服务端回退路径：不带挑战直接领取
        query.addQueryItem(QStringLiteral("read"), QString::number(read));
        query.addQueryItem(QStringLiteral("write"), QString::number(write));
    } else {
        query.addQueryItem(QStringLiteral("challenge"), challenge);
        query.addQueryItem(QStringLiteral("proof"), proof);
    }
    url.setQuery(query);

    QNetworkReply *reply = m_nam.get(buildFetchRequest(url));
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, read, write, attempt]() {
        handleClaimReply(reply, read, write, attempt);
    });
}

void ReplayNonceStore::handleClaimReply(QNetworkReply *reply, int read, int write, int attempt)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const bool ok = (reply->error() == QNetworkReply::NoError);
    const QString errorString = reply->errorString();
    reply->deleteLater();

    if (!m_roundActive)
        return;

    if (!ok) {
        // 领取被拒（挑战失效 / 解答不合格 / 缺挑战）：换一道题重解一次。被限额（429）不在此列，
        // 立刻重试只会继续撞限额——本轮就此打住，交给下一次补领。
        if (attempt + 1 < kClaimAttempts && (status == 400 || status == 409)) {
            requestChallenge(read, write, attempt + 1);
            return;
        }
        qWarning() << "[replay] 领取防重放 nonce 失败:" << status << errorString;
        finishRound();
        return;
    }

    const QJsonObject nonces = QJsonDocument::fromJson(body).object()
                                       .value(QStringLiteral("data")).toObject()
                                       .value(QStringLiteral("nonces")).toObject();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    {
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
    finishRound();
}

void ReplayNonceStore::finishRound()
{
    if (!m_roundActive)
        return;
    m_roundActive = false;
    emit fetchRoundFinished();
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
    startRound(kBatch, kBatch);
}
