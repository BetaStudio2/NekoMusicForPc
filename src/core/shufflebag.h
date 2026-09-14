#ifndef SHUFFLEBAG_H
#define SHUFFLEBAG_H

#include <QSet>
#include <QString>
#include <QStringList>

/**
 * 洗牌袋（Shuffle Bag）。
 *
 * 随机播放不再"每次都从全库抽一首"，而是把整个曲库洗成一轮顺序后逐个消费：
 * - 一轮之内每首歌恰好播放一次，不会出现"40 首只有四五首在循环"；
 * - 一轮播完才洗下一轮，且新一轮首曲不会紧接着上一轮末曲；
 * - 曲库增删只影响未播部分，不会重置整轮进度；
 * - 游标与历史可持久化（serialize / restore），重启后继续，而不是又从头几首开始。
 *
 * key 使用 MusicInfo 的稳定标识（见 musicinfo.h 的 musicKeyOf）。
 */
class ShuffleBag {
public:
    /** 与当前曲库对齐：保留未播部分，把新出现的曲目洗牌后接到队尾。幂等。 */
    void syncPool(const QStringList &pool);

    /** 查看下一首但不消费（供预加载使用，保证预加载与实际播放是同一首）。 */
    QString peekNext(const QStringList &pool);

    /** 消费下一首：推进游标并记入历史。 */
    QString commitNext(const QStringList &pool);

    /**
     * 上一首：沿播放历史回退，并把当前曲插回待播队首，
     * 这样"上一首"之后再按"下一首"能回到刚才那首。
     */
    QString previous(const QStringList &pool);

    /** 用户手动选歌：从待播队列摘掉，并作为当前曲记入历史，避免短期内再次随到。 */
    void onUserPicked(const QString &key, const QStringList &pool);

    /** 清空列表时重置。 */
    void reset();

    /** 序列化为 JSON 字符串，存入 play_queue_state。 */
    QString serialize() const;

    /** 从 serialize() 的结果恢复。 */
    void restore(const QString &state);

    /** 本轮剩余待播曲目数。 */
    int pendingCount() const;

    /** 本轮总曲目数。 */
    int totalCount() const { return m_bag.size(); }

    /** 当前游标位置（用于日志观察）。 */
    int cursor() const { return m_cursor; }

    /** 最后播放的曲目 key。 */
    QString currentKey() const { return m_recent.isEmpty() ? QString() : m_recent.last(); }

    /** 待播队列快照（仅用于测试与日志）。 */
    QStringList pendingKeys() const;

    /** 播放历史快照（仅用于测试与日志）。 */
    QStringList recentKeys() const { return m_recent; }

private:
    void ensureCycle(const QStringList &pool);
    void newCycle(const QStringList &pool);
    int nextValidIndex(const QSet<QString> &poolSet);
    void pushRecent(const QString &key);
    void trimRecent();
    void removePending(const QString &key);
    void insertPendingAtCursor(const QString &key);

    /** 顺序无关的池签名：避免仅调整列表顺序就重洗一轮。 */
    static QString signatureOf(const QStringList &pool);

    /** 历史至少保留一整轮，保证"一轮内不重复"的判定不被裁剪破坏。 */
    static constexpr int kMinHistory = 64;

    QStringList m_bag;
    int m_cursor = 0;
    QStringList m_recent;
    QString m_poolSig;
    bool m_hasSig = false;
    int m_poolSize = 0;
};

#endif // SHUFFLEBAG_H
