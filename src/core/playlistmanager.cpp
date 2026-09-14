#include "core/playlistmanager.h"
#include "core/playlistdb.h"

#include <QFileInfo>
#include <QSet>

PlaylistManager& PlaylistManager::instance() {
    static PlaylistManager manager;
    return manager;
}

void PlaylistManager::load() {
    // Load from SQLite
    m_playlist = PlaylistDatabase::instance().getQueue();
    m_currentIndex = PlaylistDatabase::instance().getQueueCurrentIndex();
    m_playMode = PlaylistDatabase::instance().getQueuePlayMode();

    // 恢复随机播放进度：重启后继续上一轮，而不是又从开头几首开始
    m_shuffleBag.restore(
        PlaylistDatabase::instance().getQueueStateValue(QStringLiteral("shuffleState")));
    m_shuffleBag.syncPool(poolKeys());
}

void PlaylistManager::save() {
    // Save to SQLite
    PlaylistDatabase::instance().setQueueMusic(m_playlist, m_currentIndex);
    PlaylistDatabase::instance().setQueuePlayMode(m_playMode);
    persistShuffleState();
}

void PlaylistManager::addToPlaylist(const MusicInfo& music) {
    const QString canon = music.isLocalFile()
        ? QFileInfo(music.localPath).canonicalFilePath()
        : QString();
    for (const auto& item : m_playlist) {
        if (!canon.isEmpty()) {
            const QString ic = QFileInfo(item.localPath).canonicalFilePath();
            if (!ic.isEmpty() && ic == canon)
                return;
        } else if (music.id > 0 && item.id == music.id) {
            return;
        }
    }
    m_playlist.append(music);
    if (m_currentIndex == -1) {
        m_currentIndex = 0;
    }
    PlaylistDatabase::instance().addToQueue(music);
    syncShufflePool();
    emit playlistChanged();
}

void PlaylistManager::addAllToPlaylist(const QList<MusicInfo>& musicList) {
    for (const auto& music : musicList) {
        bool exists = false;
        const QString canon = music.isLocalFile()
            ? QFileInfo(music.localPath).canonicalFilePath()
            : QString();
        for (const auto& item : m_playlist) {
            if (!canon.isEmpty()) {
                const QString ic = QFileInfo(item.localPath).canonicalFilePath();
                if (!ic.isEmpty() && ic == canon) {
                    exists = true;
                    break;
                }
            } else if (music.id > 0 && item.id == music.id) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            m_playlist.append(music);
            PlaylistDatabase::instance().addToQueue(music);
        }
    }
    if (m_currentIndex == -1 && !m_playlist.isEmpty()) {
        m_currentIndex = 0;
    }
    syncShufflePool();
    emit playlistChanged();
}

void PlaylistManager::replacePlaylist(const QList<MusicInfo>& musicList, int currentIndex) {
    // 按曲目稳定标识去重：本地文件用规范化路径参与，不能按 id <= 0 直接丢弃
    QList<MusicInfo> uniqueMusic;
    QSet<QString> seenKeys;
    for (const MusicInfo &music : musicList) {
        const QString key = musicKeyOf(music);
        if (key.isEmpty() || seenKeys.contains(key))
            continue;
        seenKeys.insert(key);
        uniqueMusic.append(music);
    }

    m_playlist = uniqueMusic;
    m_currentIndex = m_playlist.isEmpty()
        ? -1
        : qBound(0, currentIndex, m_playlist.size() - 1);
    PlaylistDatabase::instance().setQueueMusic(m_playlist, m_currentIndex);
    syncShufflePool();
    emit playlistChanged();
    emit currentIndexChanged(m_currentIndex);
}

void PlaylistManager::removeFromPlaylist(int localId) {
    int index = findIndexByLocalId(localId);
    if (index >= 0) {
        m_playlist.removeAt(index);
        if (m_currentIndex >= m_playlist.size()) {
            m_currentIndex = m_playlist.isEmpty() ? -1 : m_playlist.size() - 1;
        }
        // Rebuild queue in DB
        save();
        emit playlistChanged();
    }
}

void PlaylistManager::clearPlaylist() {
    m_playlist.clear();
    m_currentIndex = -1;
    m_shuffleBag.reset();
    PlaylistDatabase::instance().clearQueue();
    persistShuffleState();
    emit playlistChanged();
}

void PlaylistManager::setPlayMode(const QString& mode) {
    m_playMode = mode;
    PlaylistDatabase::instance().setQueuePlayMode(mode);
    // 进出随机模式不重置洗牌袋：保留进度，只与当前队列对齐
    syncShufflePool();
    emit playModeChanged(mode);
}

void PlaylistManager::togglePlayMode() {
    if (m_playMode == "list") {
        m_playMode = "single";
    } else if (m_playMode == "single") {
        m_playMode = "random";
    } else {
        m_playMode = "list";
    }
    PlaylistDatabase::instance().setQueuePlayMode(m_playMode);
    syncShufflePool();
    emit playModeChanged(m_playMode);
}

void PlaylistManager::setCurrentIndex(int index) {
    if (m_currentIndex == index)
        return;
    // 随机播放：登记当前曲；用户手动点歌时会从待播队列摘掉，避免本轮重复随到。
    // 正常的"下一首"流程已经消费过游标，这里对同一首是幂等的。
    if (m_playMode == "random" && index >= 0 && index < m_playlist.size()) {
        m_shuffleBag.onUserPicked(musicKeyOf(m_playlist.at(index)), poolKeys());
        persistShuffleState();
    }
    m_currentIndex = index;
    PlaylistDatabase::instance().setQueueCurrentIndex(index);
    emit currentIndexChanged(index);
}

int PlaylistManager::nextIndex() {
    if (m_playlist.isEmpty()) return -1;

    if (m_playMode == "single") {
        return m_currentIndex;
    } else if (m_playMode == "random") {
        // 随机播放：由洗牌袋顺序决定，一轮内每首歌只播一次
        const QString key = m_shuffleBag.commitNext(poolKeys());
        persistShuffleState();
        const int index = indexOfKey(key);
        if (index < 0) {
            qWarning() << "[随机播放] 洗牌袋未能给出下一首，队列大小:" << m_playlist.size();
        } else {
            qDebug() << "[随机播放] 下一首:" << m_playlist.at(index).title
                     << "游标:" << m_shuffleBag.cursor() << "/" << m_shuffleBag.totalCount()
                     << "待播:" << m_shuffleBag.pendingCount();
        }
        return index;
    } else {
        // list mode: loop
        return (m_currentIndex + 1) % m_playlist.size();
    }
}

int PlaylistManager::previousIndex() {
    if (m_playlist.isEmpty()) return -1;

    if (m_playMode == "random") {
        // 随机播放：沿洗牌袋历史回退；没有历史时退化为列表顺序上一首
        const QString key = m_shuffleBag.previous(poolKeys());
        persistShuffleState();
        const int index = indexOfKey(key);
        if (index >= 0)
            return index;
    }

    // 列表循环 / 单曲循环：向前一个
    return (m_currentIndex - 1 + m_playlist.size()) % m_playlist.size();
}

QStringList PlaylistManager::poolKeys() const {
    QStringList keys;
    QSet<QString> seen;
    for (const MusicInfo &music : m_playlist) {
        const QString key = musicKeyOf(music);
        if (key.isEmpty() || seen.contains(key))
            continue;
        seen.insert(key);
        keys.append(key);
    }
    return keys;
}

int PlaylistManager::indexOfKey(const QString &key) const {
    if (key.isEmpty())
        return -1;
    for (int i = 0; i < m_playlist.size(); ++i) {
        if (musicKeyOf(m_playlist.at(i)) == key)
            return i;
    }
    return -1;
}

void PlaylistManager::syncShufflePool() {
    m_shuffleBag.syncPool(poolKeys());
    persistShuffleState();
}

void PlaylistManager::persistShuffleState() {
    PlaylistDatabase::instance().setQueueStateValue(QStringLiteral("shuffleState"),
                                                     m_shuffleBag.serialize());
}

int PlaylistManager::findIndexByLocalId(int localId) const {
    for (int i = 0; i < m_playlist.size(); ++i) {
        if (m_playlist[i].id == localId) {
            return i;
        }
    }
    return -1;
}

MusicInfo PlaylistManager::lastPlayedMusic() const {
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size()) {
        return m_playlist[m_currentIndex];
    }
    return MusicInfo();
}
