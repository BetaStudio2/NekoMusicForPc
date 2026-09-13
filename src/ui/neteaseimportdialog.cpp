/**
 * @file neteaseimportdialog.cpp
 * @brief 网易云歌单导入对话框实现
 */

#include "neteaseimportdialog.h"
#include "core/i18n.h"

#include <QRegularExpression>

NeteaseImportDialog::NeteaseImportDialog(ApiClient *apiClient, QWidget *parent)
    : ExternalImportDialog(apiClient,
                           SourceConfig{QStringLiteral("netease"),
                                        QStringLiteral("importNeteasePlaylist"),
                                        QStringLiteral("importNeteaseDesc"),
                                        QStringLiteral("inputNeteaseLink"),
                                        QStringLiteral("invalidNeteaseLink"),
                                        QStringLiteral("emptyNeteasePlaylist"),
                                        QStringLiteral("neteasePlaylistInfo")},
                           parent)
{
}

QString NeteaseImportDialog::parseInput(const QString &input) const
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty())
        return QString();

    static QRegularExpression digitsOnly(QStringLiteral("^\\d+$"));
    if (digitsOnly.match(trimmed).hasMatch())
        return trimmed;

    static QRegularExpression playlistQueryId(QStringLiteral("playlist\\?id=(\\d+)"), QRegularExpression::CaseInsensitiveOption);
    auto match = playlistQueryId.match(trimmed);
    if (match.hasMatch())
        return match.captured(1);

    static QRegularExpression urlIdParam(QStringLiteral("[?&]id=(\\d+)"), QRegularExpression::CaseInsensitiveOption);
    match = urlIdParam.match(trimmed);
    if (match.hasMatch())
        return match.captured(1);

    static QRegularExpression playlistPathId(QStringLiteral("playlist/(\\d+)"), QRegularExpression::CaseInsensitiveOption);
    match = playlistPathId.match(trimmed);
    if (match.hasMatch())
        return match.captured(1);

    return QString();
}

void NeteaseImportDialog::fetchPlaylist(const QString &id, FetchCallback cb)
{
    bool ok = false;
    const qint64 playlistId = id.toLongLong(&ok);
    if (!ok || playlistId <= 0) {
        if (cb)
            cb(false, I18n::instance().tr(QStringLiteral("invalidNeteaseLink")), {});
        return;
    }

    apiClient()->fetchNeteasePlaylist(
        playlistId,
        [cb](bool success, const QString &message, const ApiClient::NeteasePlaylistInfo &playlist) {
            PlaylistData data;
            data.id = QString::number(playlist.id);
            data.name = playlist.name;
            data.trackCount = playlist.trackCount;
            data.tracks = playlist.tracks;
            if (cb)
                cb(success, message, data);
        });
}
