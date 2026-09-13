/**
 * @file qqimportdialog.cpp
 * @brief QQ 音乐歌单导入对话框实现
 */

#include "qqimportdialog.h"

#include <QRegularExpression>

QqImportDialog::QqImportDialog(ApiClient *apiClient, QWidget *parent)
    : ExternalImportDialog(apiClient,
                           SourceConfig{QStringLiteral("qq"),
                                        QStringLiteral("importQqPlaylist"),
                                        QStringLiteral("importQqDesc"),
                                        QStringLiteral("inputQqLink"),
                                        QStringLiteral("invalidQqLink"),
                                        QStringLiteral("emptyQqPlaylist"),
                                        QStringLiteral("qqPlaylistInfo")},
                           parent)
{
}

QString QqImportDialog::parseInput(const QString &input) const
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty())
        return QString();

    static QRegularExpression digitsOnly(QStringLiteral("^\\d+$"));
    if (digitsOnly.match(trimmed).hasMatch())
        return trimmed;

    static QRegularExpression urlIdParam(QStringLiteral("[?&]id=(\\d+)"), QRegularExpression::CaseInsensitiveOption);
    const auto match = urlIdParam.match(trimmed);
    if (match.hasMatch())
        return match.captured(1);

    return QString();
}

void QqImportDialog::fetchPlaylist(const QString &id, FetchCallback cb)
{
    apiClient()->fetchQqPlaylist(
        id,
        [cb](bool success, const QString &message, const ApiClient::QqPlaylistInfo &playlist) {
            PlaylistData data;
            data.id = playlist.disstid;
            data.name = playlist.name;
            data.trackCount = playlist.trackCount;
            data.tracks = playlist.tracks;
            if (cb)
                cb(success, message, data);
        });
}
