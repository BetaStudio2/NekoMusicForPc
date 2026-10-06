#include "mediaprobe.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/log.h>
}

namespace {

/** 探测期间静默 FFmpeg 日志，避免污染终端。 */
class QuietLog
{
public:
    QuietLog() : m_old(av_log_get_level()) { av_log_set_level(AV_LOG_QUIET); }
    ~QuietLog() { av_log_set_level(m_old); }
private:
    int m_old;
};

QString dictValue(AVDictionary *dict, const char *key)
{
    if (!dict)
        return {};
    const AVDictionaryEntry *e = av_dict_get(dict, key, nullptr, 0);
    if (!e || !e->value)
        return {};
    return QString::fromUtf8(e->value).trimmed();
}

} // namespace

namespace MediaProbe {

bool readTags(const QString &path, Tags *tags)
{
    if (!tags)
        return false;
    tags->title.clear();
    tags->artist.clear();
    tags->album.clear();

    QuietLog quiet;
    const QByteArray p = path.toUtf8();
    AVFormatContext *fmt = nullptr;
    if (avformat_open_input(&fmt, p.constData(), nullptr, nullptr) < 0)
        return false;

    // 标签多在容器头；find_stream_info 用于确保 MP4/ASF 等容器标签已解析。
    if (avformat_find_stream_info(fmt, nullptr) < 0) {
        avformat_close_input(&fmt);
        return false;
    }

    tags->title = dictValue(fmt->metadata, "title");
    tags->artist = dictValue(fmt->metadata, "artist");
    tags->album = dictValue(fmt->metadata, "album");
    if (tags->artist.isEmpty())
        tags->artist = dictValue(fmt->metadata, "album_artist");
    if (tags->artist.isEmpty())
        tags->artist = dictValue(fmt->metadata, "performer");

    avformat_close_input(&fmt);
    return true;
}

QImage readEmbeddedCover(const QString &path)
{
    QuietLog quiet;
    const QByteArray p = path.toUtf8();
    AVFormatContext *fmt = nullptr;
    if (avformat_open_input(&fmt, p.constData(), nullptr, nullptr) < 0)
        return {};

    if (avformat_find_stream_info(fmt, nullptr) < 0) {
        avformat_close_input(&fmt);
        return {};
    }

    QImage img;
    for (unsigned i = 0; i < fmt->nb_streams; ++i) {
        const AVStream *st = fmt->streams[i];
        if (!(st->disposition & AV_DISPOSITION_ATTACHED_PIC))
            continue;
        const AVPacket &pkt = st->attached_pic;
        if (pkt.data && pkt.size > 0) {
            img = QImage::fromData(pkt.data, pkt.size);
            if (!img.isNull())
                break;
        }
    }

    avformat_close_input(&fmt);
    return img;
}

} // namespace MediaProbe
