/**
 * @file kugouimportdialog.cpp
 * @brief 酷狗音乐歌单导入对话框实现
 */

#include "kugouimportdialog.h"

#include <QRegularExpression>

KugouImportDialog::KugouImportDialog(ApiClient *apiClient, QWidget *parent)
    : ExternalImportDialog(apiClient,
                           SourceConfig{QStringLiteral("kugou"),
                                        QStringLiteral("importKugouPlaylist"),
                                        QStringLiteral("importKugouDesc"),
                                        QStringLiteral("inputKugouLink"),
                                        QStringLiteral("invalidKugouLink"),
                                        QStringLiteral("emptyKugouPlaylist"),
                                        QStringLiteral("kugouPlaylistInfo")},
                           parent)
{
}

QString KugouImportDialog::parseInput(const QString &input) const
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty())
        return QString();

    // 数字 specialid / global_collection_id（collection_*）/ gcid_*
    static QRegularExpression digitsOnly(QStringLiteral("^\\d+$"));
    if (digitsOnly.match(trimmed).hasMatch())
        return trimmed;
    static QRegularExpression gidPattern(QStringLiteral("^collection_[A-Za-z0-9_]+$"));
    if (gidPattern.match(trimmed).hasMatch())
        return trimmed;
    static QRegularExpression gcidPattern(QStringLiteral("^gcid_[A-Za-z0-9]+$"));
    if (gcidPattern.match(trimmed).hasMatch())
        return trimmed;

    // 分享链接（含 special/single、gcid、share 单曲等）原样交给后端解析
    static QRegularExpression kugouUrl(QStringLiteral("kugou\\.com"),
                                       QRegularExpression::CaseInsensitiveOption);
    if (kugouUrl.match(trimmed).hasMatch())
        return trimmed;

    return QString();
}

void KugouImportDialog::fetchPlaylist(const QString &id, FetchCallback cb)
{
    apiClient()->fetchKugouPlaylist(
        id,
        [cb](bool success, const QString &message, const ApiClient::KugouPlaylistInfo &playlist) {
            PlaylistData data;
            data.id = playlist.listId;
            data.name = playlist.name;
            data.trackCount = playlist.trackCount;
            data.tracks = playlist.tracks;
            if (cb)
                cb(success, message, data);
        });
}
