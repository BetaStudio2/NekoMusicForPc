#pragma once

#include "core/nekonetworkaccessmanager.h"

#include <QList>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QString>

class QNetworkReply;

/**
 * @file replaynonce.h
 * @brief 通用请求防重放：一次性 nonce 池
 *
 * 后端要求所有动态接口（`/api/` 前缀、`/loser/` 前缀）以及客户端版本检查 `/version` 携带一次性
 * 请求头 `X-Neko-Nonce`，同一个 nonce 只能消费一次；重复发送（重放）会被拒绝并返回
 * `409` + `X-Neko-Replay-Status`（`missing` / `invalid`）。
 *
 * 本类负责：
 *   1. 向 `GET /api/replay/nonce` 批量预取读 / 写两类 nonce 并缓存；
 *   2. 低水位时后台补齐；本地提前作废（服务端 TTL 120 秒，本地 90 秒）；
 *   3. 池空时在本对象所属线程同步补领，保证请求带得上 nonce；其它线程（如媒体 I/O 线程）
 *      发请求时改为请所属线程补领并有限等待——网络回调只能在所属线程派发；
 *   4. 被服务端判定为重放时（[noteReplayRejected]）清空旧池重新领取——典型场景是
 *      切换网络导致出口 IP 变化、或服务端重启，此时旧池整批失效。
 *
 * 豁免清单需与后端 `filter/ReplayProtectionFilter` 保持一致：不一致只会多领 nonce，不会误拦。
 * 领取请求自身走豁免路径，因此不会递归触发本类。
 */
class ReplayNonceStore : public QObject
{
    Q_OBJECT
public:
    static ReplayNonceStore &instance();

    /** 一次性 nonce 请求头名。 */
    static const char *nonceHeader();
    /** 失败原因响应头名（`missing` / `invalid` / `error`）。 */
    static const char *statusHeader();

    /**
     * 取一个尚未使用过的 nonce。
     *
     * 池中有可用值时立即返回；池空时：在 nonce 池所属线程同步补领（最多等待 4 秒），
     * 在其它线程则请所属线程补领并有限等待（同样最多 4 秒）。
     * 返回空串表示暂时取不到，调用方无需特殊处理（重放保护层会换新 nonce 重试一次）。
     */
    QString take(bool write);

    /** 服务端判定为重放后调用：清空旧池并重新领取。 */
    void noteReplayRejected();

private:
    explicit ReplayNonceStore(QObject *parent = nullptr);
    ~ReplayNonceStore() override;

    struct Entry {
        QString value;
        qint64 issuedAt = 0;
    };

    /** 在当前线程（nonce 池所属线程）取一个 nonce，必要时同步补领。 */
    QString takeLocal(bool write);

    /** 取一个未过期的 nonce 并从池中移除；不阻塞。 */
    QString pop(bool write);

    /** 发起一次领取；已有领取在途时返回 nullptr（可用 [pendingFetch] 拿到它）。 */
    QNetworkReply *startFetch(int read, int write);
    /** 当前在途的领取请求；没有则返回 nullptr。仅可在 nonce 池所属线程调用。 */
    QNetworkReply *pendingFetch();
    void handleFetchReply(QNetworkReply *reply);
    /** 后台补领；不在本对象所属线程时投递过去执行。 */
    void requestRefill();
    void refill();

    NekoNetworkAccessManager m_nam;
    mutable QMutex m_mutex;
    QList<Entry> m_readPool;
    QList<Entry> m_writePool;
    QPointer<QNetworkReply> m_pendingFetch;
};
