#include "httpmediadevice.h"
#include "linuxtmpfscache.h"

#include <QDir>
#include <QMetaObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTemporaryFile>
#include <QThread>

namespace {

constexpr int kReadTimeoutMs = 20000;
constexpr int kSizeWaitMs = 4000;

/** Content-Range: bytes 0-123/456 → 456；解析失败返回 -1。 */
qint64 totalFromContentRange(const QByteArray &value)
{
    const int slash = value.lastIndexOf('/');
    if (slash < 0)
        return -1;
    bool ok = false;
    const qint64 total = value.mid(slash + 1).trimmed().toLongLong(&ok);
    return ok && total > 0 ? total : -1;
}

} // namespace

HttpMediaDevice::HttpMediaDevice(const QUrl &url, QObject *parent)
    : QIODevice(parent)
    , m_url(url)
{
    m_nam.setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);
}

HttpMediaDevice::~HttpMediaDevice()
{
    abort();
}

void HttpMediaDevice::start()
{
    if (m_reply)
        return;

    m_file = std::make_unique<QTemporaryFile>(QDir::tempPath() + QStringLiteral("/nekomusic-stream-XXXXXX"));
    if (!m_file->open()) {
        fail(QStringLiteral("无法创建音频流临时文件"));
        return;
    }

    QNetworkRequest req(m_url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    m_reply = m_nam.get(req);

    connect(m_reply, &QNetworkReply::readyRead, this, &HttpMediaDevice::onReadyRead);
    connect(m_reply, &QNetworkReply::finished, this, &HttpMediaDevice::onReplyFinished);
    connect(m_reply, &QNetworkReply::downloadProgress, this,
            [this](qint64, qint64 total) {
                if (total <= 0)
                    return;
                QMutexLocker locker(&m_mutex);
                if (m_total < 0)
                    m_total = total;
                m_cond.wakeAll();
            });
}

void HttpMediaDevice::abort()
{
    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    if (reply) {
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }
    QMutexLocker locker(&m_mutex);
    m_finished = true;
    m_cond.wakeAll();
}

qint64 HttpMediaDevice::size() const
{
    QMutexLocker locker(&m_mutex);
    // 解复用线程等响应头到达再回答，避免 FFmpeg 认为长度未知而算错时长；
    // 其它线程（如 UI）绝不能阻塞。
    if (m_total < 0 && QThread::currentThread() != thread()) {
        const int loops = kSizeWaitMs / 100;
        for (int i = 0; i < loops && m_total < 0 && !m_finished && !m_failed; ++i)
            m_cond.wait(&m_mutex, 100);
    }
    return m_total;
}

qint64 HttpMediaDevice::bytesAvailable() const
{
    QMutexLocker locker(&m_mutex);
    return qMax<qint64>(0, m_downloaded - m_position) + QIODevice::bytesAvailable();
}

bool HttpMediaDevice::atEnd() const
{
    QMutexLocker locker(&m_mutex);
    return m_finished && m_position >= m_downloaded;
}

qint64 HttpMediaDevice::pos() const
{
    QMutexLocker locker(&m_mutex);
    return m_position;
}

bool HttpMediaDevice::seek(qint64 position)
{
    QMutexLocker locker(&m_mutex);
    if (position < 0 || m_failed)
        return false;
    m_position = position;
    return true;
}

QString HttpMediaDevice::errorString() const
{
    QMutexLocker locker(&m_mutex);
    return m_error;
}

bool HttpMediaDevice::hasFailed() const
{
    QMutexLocker locker(&m_mutex);
    return m_failed;
}

QString HttpMediaDevice::appendChunk(const QByteArray &chunk)
{
    if (chunk.isEmpty())
        return QString();

    QMutexLocker locker(&m_mutex);
    if (m_failed || m_finished)
        return QString();
    if (m_downloaded + chunk.size() > LinuxTmpfsCache::kMaxAudioFileBytes)
        return QStringLiteral("音频体积超过 500 MiB，已取消播放");
    if (!m_file || !m_file->seek(m_downloaded) || m_file->write(chunk) != chunk.size())
        return QStringLiteral("写入音频流临时文件失败");
    m_file->flush();
    m_downloaded += chunk.size();
    m_cond.wakeAll();
    return QString();
}

qint64 HttpMediaDevice::readData(char *data, qint64 maxlen)
{
    if (maxlen <= 0)
        return 0;

    QMutexLocker locker(&m_mutex);
    while (!m_failed && !m_finished && m_position >= m_downloaded) {
        if (!m_cond.wait(&m_mutex, kReadTimeoutMs)) {
            locker.unlock();
            failFromAnyThread(QStringLiteral("音频流读取超时"));
            return -1;
        }
    }

    if (m_position >= m_downloaded) {
        if (m_finished && !m_failed)
            return 0; // 正常读完
        return -1;
    }

    if (!m_file || !m_file->seek(m_position))
        return -1;

    const qint64 toRead = qMin(maxlen, m_downloaded - m_position);
    const qint64 read = m_file->read(data, toRead);
    if (read > 0)
        m_position += read;
    return read;
}

void HttpMediaDevice::onReadyRead()
{
    if (!m_reply)
        return;

    {
        QMutexLocker locker(&m_mutex);
        if (m_total < 0) {
            const qint64 fromRange = totalFromContentRange(m_reply->rawHeader("Content-Range"));
            const qint64 fromHeader = m_reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
            m_total = fromRange > 0 ? fromRange : (fromHeader > 0 ? fromHeader : -1);
        }
    }

    const QString error = appendChunk(m_reply->readAll());
    if (!error.isEmpty())
        fail(error);
}

void HttpMediaDevice::onReplyFinished()
{
    QNetworkReply *reply = m_reply;
    if (!reply)
        return;
    m_reply = nullptr;

    const QString appendError = appendChunk(reply->readAll());
    const QNetworkReply::NetworkError error = reply->error();
    const QString errorText = reply->errorString();
    reply->deleteLater();

    if (!appendError.isEmpty()) {
        fail(appendError);
        return;
    }

    if (error == QNetworkReply::NoError) {
        QMutexLocker locker(&m_mutex);
        m_finished = true;
        m_cond.wakeAll();
        return;
    }

    if (error != QNetworkReply::OperationCanceledError)
        fail(QStringLiteral("音频流请求失败: %1").arg(errorText));
}

void HttpMediaDevice::fail(const QString &error)
{
    {
        QMutexLocker locker(&m_mutex);
        if (!m_failed) {
            m_failed = true;
            m_error = error;
        }
        m_finished = true;
        m_cond.wakeAll();
    }

    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    if (reply) {
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }

    if (!m_errorEmitted) {
        m_errorEmitted = true;
        emit fetchError(error);
    }
}

void HttpMediaDevice::failFromAnyThread(const QString &error)
{
    {
        QMutexLocker locker(&m_mutex);
        if (!m_failed) {
            m_failed = true;
            m_error = error;
        }
        m_finished = true;
        m_cond.wakeAll();
    }
    QMetaObject::invokeMethod(this, [this, error]() { fail(error); }, Qt::QueuedConnection);
}
