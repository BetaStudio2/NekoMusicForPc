#include "core/shufflebag.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>

namespace {

/** Fisher–Yates 洗牌：每个排列等概率，避免"只随机交换一次"带来的偏斜。 */
void shuffleKeys(QStringList &list) {
    for (int i = list.size() - 1; i > 0; --i) {
        const int j = QRandomGenerator::global()->bounded(i + 1);
        list.swapItemsAt(i, j);
    }
}

/** 构造去重集合与顺序列表，避免依赖各 Qt 版本容器的范围构造函数。 */
QSet<QString> setOf(const QStringList &list) {
    QSet<QString> set;
    for (const QString &key : list) {
        if (!key.isEmpty())
            set.insert(key);
    }
    return set;
}

QStringList listOf(const QSet<QString> &set) {
    QStringList list;
    list.reserve(set.size());
    for (const QString &key : set)
        list.append(key);
    return list;
}

QStringList toKeyList(const QJsonValue &value) {
    QStringList keys;
    const QJsonArray array = value.toArray();
    keys.reserve(array.size());
    for (const QJsonValue &item : array) {
        const QString key = item.toString();
        if (!key.isEmpty())
            keys.append(key);
    }
    return keys;
}

} // namespace

void ShuffleBag::syncPool(const QStringList &pool) {
    const QString sig = signatureOf(pool);
    if (m_hasSig && sig == m_poolSig)
        return;
    m_poolSig = sig;
    m_hasSig = true;
    m_poolSize = pool.size();

    const QSet<QString> poolSet = setOf(pool);

    QStringList remaining;
    QSet<QString> seen;
    for (int i = m_cursor; i < m_bag.size(); ++i) {
        const QString &key = m_bag.at(i);
        if (poolSet.contains(key) && !seen.contains(key)) {
            seen.insert(key);
            remaining.append(key);
        }
    }
    m_bag = remaining;
    m_cursor = 0;

    // 新增曲目补到队尾；本轮已播过的（recent）不再重复排入
    QSet<QString> played;
    for (const QString &key : m_recent)
        played.insert(key);

    QStringList fresh;
    for (const QString &key : pool) {
        if (seen.contains(key) || played.contains(key))
            continue;
        seen.insert(key);
        fresh.append(key);
    }
    if (!fresh.isEmpty()) {
        shuffleKeys(fresh);
        m_bag += fresh;
    }

    trimRecent();
}

QString ShuffleBag::peekNext(const QStringList &pool) {
    ensureCycle(pool);
    const QSet<QString> poolSet = setOf(pool);
    const int index = nextValidIndex(poolSet);
    return index < m_bag.size() ? m_bag.at(index) : QString();
}

QString ShuffleBag::commitNext(const QStringList &pool) {
    ensureCycle(pool);
    const QSet<QString> poolSet = setOf(pool);
    const int index = nextValidIndex(poolSet);
    if (index >= m_bag.size())
        return QString();
    const QString key = m_bag.at(index);
    m_cursor = index + 1;
    pushRecent(key);
    return key;
}

QString ShuffleBag::previous(const QStringList &pool) {
    if (m_recent.size() < 2)
        return QString();
    syncPool(pool);
    const QString current = m_recent.takeLast();
    const QString target = m_recent.last();
    removePending(target);
    insertPendingAtCursor(current);
    return target;
}

void ShuffleBag::onUserPicked(const QString &key, const QStringList &pool) {
    if (key.isEmpty())
        return;
    syncPool(pool);
    removePending(key);
    if (m_recent.isEmpty() || m_recent.last() != key)
        pushRecent(key);
}

void ShuffleBag::reset() {
    m_bag.clear();
    m_cursor = 0;
    m_recent.clear();
    m_poolSig.clear();
    m_hasSig = false;
    m_poolSize = 0;
}

QString ShuffleBag::serialize() const {
    QJsonObject object;
    object.insert(QStringLiteral("cursor"), m_cursor);
    object.insert(QStringLiteral("bag"), QJsonArray::fromStringList(m_bag));
    object.insert(QStringLiteral("recent"), QJsonArray::fromStringList(m_recent));
    return QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

void ShuffleBag::restore(const QString &state) {
    if (state.trimmed().isEmpty())
        return;
    const QJsonDocument document = QJsonDocument::fromJson(state.toUtf8());
    if (!document.isObject())
        return;
    const QJsonObject object = document.object();
    m_cursor = qMax(0, object.value(QStringLiteral("cursor")).toInt());
    m_bag = toKeyList(object.value(QStringLiteral("bag")));
    m_recent = toKeyList(object.value(QStringLiteral("recent")));
    if (m_cursor > m_bag.size())
        m_cursor = m_bag.size();
    m_poolSize = qMax(m_bag.size(), m_recent.size());
    m_hasSig = false;
}

int ShuffleBag::pendingCount() const {
    return qMax(0, m_bag.size() - m_cursor);
}

QStringList ShuffleBag::pendingKeys() const {
    if (m_cursor >= m_bag.size())
        return QStringList();
    return m_bag.mid(m_cursor);
}

void ShuffleBag::ensureCycle(const QStringList &pool) {
    if (pool.isEmpty()) {
        m_bag.clear();
        m_cursor = 0;
        return;
    }
    syncPool(pool);
    if (m_cursor >= m_bag.size())
        newCycle(pool);
}

void ShuffleBag::newCycle(const QStringList &pool) {
    QStringList keys;
    QSet<QString> seen;
    for (const QString &key : pool) {
        if (key.isEmpty() || seen.contains(key))
            continue;
        seen.insert(key);
        keys.append(key);
    }
    if (keys.isEmpty()) {
        m_bag.clear();
        m_cursor = 0;
        return;
    }

    shuffleKeys(keys);

    // 接缝处理：新一轮第一首不要紧接着上一轮最后一首
    const QString last = m_recent.isEmpty() ? QString() : m_recent.last();
    if (keys.size() > 1 && !last.isEmpty() && keys.first() == last) {
        const int swapWith = 1 + QRandomGenerator::global()->bounded(keys.size() - 1);
        keys.swapItemsAt(0, swapWith);
    }

    m_bag = keys;
    m_cursor = 0;
}

int ShuffleBag::nextValidIndex(const QSet<QString> &poolSet) {
    int index = m_cursor;
    while (index < m_bag.size() && !poolSet.contains(m_bag.at(index)))
        ++index;
    if (index >= m_bag.size() && !poolSet.isEmpty()) {
        // 兜底：袋子里已没有可播的曲目，按当前池重洗一轮
        newCycle(listOf(poolSet));
        index = m_cursor;
        while (index < m_bag.size() && !poolSet.contains(m_bag.at(index)))
            ++index;
    }
    return index;
}

void ShuffleBag::pushRecent(const QString &key) {
    m_recent.append(key);
    trimRecent();
}

void ShuffleBag::trimRecent() {
    const int cap = qMax(kMinHistory, m_poolSize);
    while (m_recent.size() > cap)
        m_recent.removeFirst();
}

void ShuffleBag::removePending(const QString &key) {
    for (int i = m_cursor; i < m_bag.size();) {
        if (m_bag.at(i) == key)
            m_bag.removeAt(i);
        else
            ++i;
    }
}

void ShuffleBag::insertPendingAtCursor(const QString &key) {
    const int from = qBound(0, m_cursor, m_bag.size());
    if (m_bag.mid(from).contains(key))
        return;
    m_bag.insert(from, key);
}

QString ShuffleBag::signatureOf(const QStringList &pool) {
    const QSet<QString> unique = setOf(pool);
    // 顺序无关的哈希组合（boost hash_combine 风格），保证仅调整列表顺序时不重洗
    quint64 hash = 0;
    for (const QString &key : unique)
        hash ^= static_cast<quint64>(qHash(key)) + 0x9e3779b97f4a7c15ULL + (hash << 6) + (hash >> 2);
    return QString::number(unique.size()) + QStringLiteral(":") + QString::number(hash);
}

