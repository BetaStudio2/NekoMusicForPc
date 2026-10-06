#pragma once

#include <QImage>
#include <QString>

/**
 * MediaProbe — 本地音频标签/内嵌封面探测（直接使用随包内嵌的 FFmpeg）。
 *
 * 替代原 QMediaPlayer/QMediaMetaData 方案：不再依赖 Qt Multimedia 的媒体后端，
 * 与原生播放引擎共用同一份最小 FFmpeg。仅用于本地文件。
 */
namespace MediaProbe {

struct Tags {
    QString title;
    QString artist;
    QString album;
};

/** 读取本地音频文件的标题/艺术家/专辑标签；返回是否成功打开文件。 */
bool readTags(const QString &path, Tags *tags);

/** 提取内嵌封面（attached_pic / FLAC picture）；无封面返回空 QImage。 */
QImage readEmbeddedCover(const QString &path);

} // namespace MediaProbe
