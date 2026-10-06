#pragma once

/**
 * @file httpmediadevice.h
 * @brief 走应用统一网络栈的可 seek HTTP 音频流设备
 *
 * Qt 的 FFmpeg 后端在播放 QUrl 形式的 http(s) 源时，会绕过 Qt Network 直接由
 * libavformat 发起请求，默认 User-Agent 为 `Lavf/<版本>`：这不带客户端的
 * `User-Agent` / `X-Neko-Client`，会被后端防爬过滤器当成命令行工具而 302 到
 * SEO 页面，最终报 “Invalid data found when processing input”。
 *
 * 把本设备通过 QMediaPlayer::setSourceDevice() 交给播放器后，所有媒体字节都从
 * NekoNetworkAccessManager 取，客户端标识与其它接口严格一致；同时保持边下边播
 * 与随机 seek 能力（FFmpeg 需要回退 seek 做探测）。
 */

#include <QIODevice>
#include <QMutex>
#include <QString>
#include <QUrl>
#include <QWaitCondition>

#include <memory>

#include "nekonetworkaccessmanager.h"

class QNetworkReply;
class QTemporaryFile;

class HttpMediaDevice : public QIODevice
{
    Q_OBJECT
public:
    explicit HttpMediaDevice(const QUrl &url, QObject *parent = nullptr);
    ~HttpMediaDevice() override;

    /** 发起请求；需先 open(QIODevice::ReadOnly)。 */
    void start();
    /** 中止请求：让阻塞中的读取立即返回，并停止后台下载。 */
    void abort();

    QUrl url() const { return m_url; }
    QString errorString() const;
    bool hasFailed() const;

    bool isSequential() const override { return false; }
    qint64 size() const override;
    qint64 bytesAvailable() const override;
    bool atEnd() const override;
    qint64 pos() const override;
    bool seek(qint64 pos) override;

signals:
    void fetchError(const QString &error);

protected:
    qint64 readData(char *data, qint64 maxlen) override;
    qint64 writeData(const char *, qint64) override { return -1; }

private:
    /** 追加一段下载数据，成功返回空字符串。 */
    QString appendChunk(const QByteArray &chunk);
    void onReadyRead();
    void onReplyFinished();
    /** 设备所在线程内清理请求并广播错误。 */
    void fail(const QString &error);
    /** 任意线程上报错误：仅置位并唤醒，网络清理切回设备线程。 */
    void failFromAnyThread(const QString &error);

    QUrl m_url;
    NekoNetworkAccessManager m_nam;
    QNetworkReply *m_reply = nullptr;
    std::unique_ptr<QTemporaryFile> m_file;

    mutable QMutex m_mutex;
    mutable QWaitCondition m_cond;
    qint64 m_total = -1;
    qint64 m_downloaded = 0;
    qint64 m_position = 0;
    bool m_finished = false;
    bool m_failed = false;
    bool m_errorEmitted = false;
    QString m_error;
};
