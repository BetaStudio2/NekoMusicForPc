#ifndef MUSICINFO_H
#define MUSICINFO_H

#include <QtGlobal>
#include <QString>
#include <QFileInfo>

struct MusicInfo {
    int id = 0;
    QString title;
    QString artist;
    QString album;
    int duration = 0;
    QString coverUrl;
    /** 非空表示本机外部音频文件（绝对路径），此时 id 为负数占位，不走在线接口 */
    QString localPath;
    /** 热门榜播放量；<0 表示未设置 */
    int playCount = -1;
    /** 最新音乐上传时间（Unix 毫秒）；0 表示未设置 */
    qint64 uploadedAtMs = 0;
    /** 搜索 API：该曲是否有有效歌词（仅 query 搜索会设置） */
    bool lrc = false;

    bool isLocalFile() const { return !localPath.isEmpty(); }
};

/**
 * 曲目稳定标识：本地文件用规范化路径、在线曲目用 id。
 *
 * 供播放队列去重与随机播放洗牌袋使用——用 id 而不是队列下标，
 * 这样播放列表增删后，已经洗好的顺序不会指向错误的歌。
 */
inline QString musicKeyOf(const MusicInfo &info) {
    if (info.isLocalFile()) {
        const QString canonical = QFileInfo(info.localPath).canonicalFilePath();
        return QStringLiteral("L:") + (canonical.isEmpty() ? info.localPath : canonical);
    }
    return QStringLiteral("R:") + QString::number(info.id);
}

#endif // MUSICINFO_H
