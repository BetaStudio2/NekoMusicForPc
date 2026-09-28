#include "localmusicmeta.h"

#include <QImage>
#include <QPixmap>
#include <QStringList>
#include <QAudioOutput>
#include <QDir>
#include <QEventLoop>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QMediaMetaData>
#include <QMediaPlayer>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QStringConverter>
#include <QVariant>

namespace LocalMusic {

namespace {

bool isPlaylistSuffix(const QString &suf)
{
    return suf == QLatin1String("m3u") || suf == QLatin1String("m3u8") || suf == QLatin1String("pls");
}

/** 可嵌入 M3U/PLS 的音频条目扩展名（不含列表本身） */
bool isEmbeddedAudioSuffix(const QString &suf)
{
    static const QStringList kExt = {
        QStringLiteral("mp3"),
        QStringLiteral("flac"),
        QStringLiteral("wav"),
        QStringLiteral("m4a"),
        QStringLiteral("aac"),
        QStringLiteral("ogg"),
        QStringLiteral("oga"),
        QStringLiteral("opus"),
        QStringLiteral("mp4"),
        QStringLiteral("wma"),
        QStringLiteral("mpc"),
        QStringLiteral("spx"),
        QStringLiteral("ra"),
        QStringLiteral("ram"),
    };
    return kExt.contains(suf);
}

QString firstLocalAudioFromM3u(const QString &m3uPath)
{
    QFile f(m3uPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    const QDir baseDir = QFileInfo(m3uPath).absoluteDir();

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;

        QString candidate;
        if (line.startsWith(QLatin1String("file:"), Qt::CaseInsensitive)) {
            QUrl u(line, QUrl::StrictMode);
            if (!u.isValid() || !u.isLocalFile())
                u = QUrl::fromUserInput(line);
            if (u.isLocalFile())
                candidate = QDir::cleanPath(u.toLocalFile());
        } else {
            QFileInfo item(line);
            if (item.isAbsolute())
                candidate = QDir::cleanPath(item.absoluteFilePath());
            else
                candidate = QDir::cleanPath(baseDir.filePath(line));
        }

        if (candidate.isEmpty())
            continue;
        QFileInfo fiCand(candidate);
        if (!fiCand.exists() || !fiCand.isFile())
            continue;
        const QString csuf = fiCand.suffix().toLower();
        if (isPlaylistSuffix(csuf))
            continue;
        if (isEmbeddedAudioSuffix(csuf))
            return candidate;
    }
    return {};
}

QString firstLocalAudioFromPls(const QString &plsPath)
{
    QFile f(plsPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.size() < 6)
            continue;
        if (!line.startsWith(QLatin1String("File"), Qt::CaseInsensitive))
            continue;
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq < 0)
            continue;
        const QString key = line.left(eq).trimmed();
        if (key.size() < 5)
            continue;
        // File1= ...
        QString val = line.mid(eq + 1).trimmed();
        if (val.isEmpty())
            continue;

        QString candidate;
        if (val.startsWith(QLatin1String("file:"), Qt::CaseInsensitive)) {
            QUrl u(val, QUrl::StrictMode);
            if (!u.isValid() || !u.isLocalFile())
                u = QUrl::fromUserInput(val);
            if (u.isLocalFile())
                candidate = QDir::cleanPath(u.toLocalFile());
        } else if (val.startsWith(QLatin1String("http://"), Qt::CaseInsensitive)
                   || val.startsWith(QLatin1String("https://"), Qt::CaseInsensitive)) {
            continue;
        } else {
            QFileInfo item(val);
            if (item.isAbsolute())
                candidate = QDir::cleanPath(item.absoluteFilePath());
            else
                candidate = QDir::cleanPath(QFileInfo(plsPath).absoluteDir().filePath(val));
        }

        if (candidate.isEmpty())
            continue;
        QFileInfo fiCand(candidate);
        if (!fiCand.exists() || !fiCand.isFile())
            continue;
        const QString csuf = fiCand.suffix().toLower();
        if (isPlaylistSuffix(csuf))
            continue;
        if (isEmbeddedAudioSuffix(csuf))
            return candidate;
    }
    return {};
}

} // namespace


QString normalizeOpenPathArgument(QString raw)
{
    raw = raw.trimmed();
    if (raw.size() >= 2) {
        const QChar a = raw.front();
        const QChar b = raw.back();
        if ((a == QLatin1Char('"') && b == QLatin1Char('"'))
            || (a == QLatin1Char('\'') && b == QLatin1Char('\'')))
            raw = raw.mid(1, raw.size() - 2).trimmed();
    }
    if (raw.startsWith(QLatin1String("file:"), Qt::CaseInsensitive)) {
        QUrl u = QUrl(raw, QUrl::StrictMode);
        if (!u.isValid() || !u.isLocalFile())
            u = QUrl::fromUserInput(raw);
        if (u.isLocalFile()) {
            const QString p = u.toLocalFile();
            if (!p.isEmpty())
                return QDir::cleanPath(p);
        }
        return {};
    }
    return QDir::cleanPath(raw);
}

bool isSupportedLocalAudioFile(const QString &filePath)
{
    static const QStringList kExt = {
        QStringLiteral("mp3"),
        QStringLiteral("flac"),
        QStringLiteral("wav"),
        QStringLiteral("m4a"),
        QStringLiteral("aac"),
        QStringLiteral("ogg"),
        QStringLiteral("oga"),
        QStringLiteral("opus"),
        QStringLiteral("mp4"),
        QStringLiteral("wma"),
        QStringLiteral("mpc"),
        QStringLiteral("spx"),
        QStringLiteral("ra"),
        QStringLiteral("ram"),
        QStringLiteral("m3u"),
        QStringLiteral("m3u8"),
        QStringLiteral("pls"),
    };
    const QString suf = QFileInfo(filePath).suffix().toLower();
    return kExt.contains(suf);
}

QString resolveToPlayableLocalPath(const QString &normalizedLocalPath)
{
    QFileInfo fi(normalizedLocalPath);
    if (!fi.exists() || !fi.isFile())
        return {};
    const QString suf = fi.suffix().toLower();
    if (suf == QLatin1String("m3u") || suf == QLatin1String("m3u8"))
        return firstLocalAudioFromM3u(normalizedLocalPath);
    if (suf == QLatin1String("pls"))
        return firstLocalAudioFromPls(normalizedLocalPath);
    if (isSupportedLocalAudioFile(normalizedLocalPath))
        return normalizedLocalPath;
    return {};
}

int stableLocalTrackId(const QString &canonicalOrAbsolutePath)
{
    const uint h = qHash(canonicalOrAbsolutePath);
    int id = -static_cast<int>(h & 0x7FFFFFFFu);
    if (id >= 0)
        id = -1;
    return id;
}

static QString resolvePath(const QString &filePath)
{
    QFileInfo fi(filePath);
    QString c = fi.canonicalFilePath();
    if (c.isEmpty())
        c = fi.absoluteFilePath();
    return c;
}

static int durationSeconds(const QMediaMetaData &md, const QMediaPlayer &player)
{
    const QVariant v = md.value(QMediaMetaData::Duration);
    if (v.isValid()) {
        bool ok = false;
        const qint64 ms = v.toLongLong(&ok);
        if (ok && ms > 0)
            return static_cast<int>(ms / 1000);
    }
    const QString ds = md.stringValue(QMediaMetaData::Duration);
    bool ok = false;
    const qint64 ms2 = ds.toLongLong(&ok);
    if (ok && ms2 > 0)
        return static_cast<int>(ms2 / 1000);
    if (player.duration() > 0)
        return static_cast<int>(player.duration() / 1000);
    return 0;
}

QString cacheEmbeddedCover(const QImage &image, const QString &sourcePath)
{
    if (image.isNull())
        return {};

    const QByteArray key = QCryptographicHash::hash(sourcePath.toUtf8(), QCryptographicHash::Sha1).toHex();
    const QString dirPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
        + QStringLiteral("/nekomusic-cache/embedded-covers");
    QDir().mkpath(dirPath);
    const QString imagePath = dirPath + QLatin1Char('/') + QString::fromLatin1(key) + QStringLiteral(".png");
    if (!QFileInfo::exists(imagePath) && !image.save(imagePath, "PNG"))
        return {};
    return QUrl::fromLocalFile(imagePath).toString();
}

QImage embeddedCoverForFile(const QString &path, QMediaMetaData *metadata)
{
    if (!metadata)
        return {};

    QMediaPlayer player;
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    timeout.setInterval(1500);
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(&player, &QMediaPlayer::metaDataChanged, &loop, [&]() {
        *metadata = player.metaData();
        const auto value = metadata->value(QMediaMetaData::CoverArtImage);
        if (value.isValid() || metadata->value(QMediaMetaData::ThumbnailImage).isValid())
            loop.quit();
    });
    QObject::connect(&player, &QMediaPlayer::mediaStatusChanged, &loop,
                     [&](QMediaPlayer::MediaStatus status) {
                         if (status == QMediaPlayer::LoadedMedia || status == QMediaPlayer::InvalidMedia)
                             loop.quit();
                     });
    player.setSource(QUrl::fromLocalFile(path));
    timeout.start();
    loop.exec();
    *metadata = player.metaData();

    const QVariant cover = metadata->value(QMediaMetaData::CoverArtImage);
    const QVariant thumbnail = metadata->value(QMediaMetaData::ThumbnailImage);
    const QVariant value = cover.isValid() ? cover : thumbnail;
    if (value.canConvert<QImage>())
        return value.value<QImage>();
    if (value.canConvert<QPixmap>())
        return value.value<QPixmap>().toImage();
    return {};
}

MusicInfo probeAndBuildInfo(const QString &filePath)
{
    MusicInfo info;
    const QString path = resolvePath(filePath);
    if (path.isEmpty())
        return info;

    info.localPath = path;
    info.id = stableLocalTrackId(path);

    QFileInfo fi(path);
    const QString base = fi.completeBaseName().trimmed();
    const int sep = base.indexOf(QStringLiteral(" - "));
    if (sep > 0 && sep + 3 < base.size()) {
        info.artist = base.left(sep).trimmed();
        info.title = base.mid(sep + 3).trimmed();
    } else {
        info.title = base;
    }

    QMediaMetaData metadata;
    const QImage embeddedCover = embeddedCoverForFile(path, &metadata);
    if (!metadata.stringValue(QMediaMetaData::Title).isEmpty())
        info.title = metadata.stringValue(QMediaMetaData::Title);
    if (!metadata.stringValue(QMediaMetaData::Author).isEmpty())
        info.artist = metadata.stringValue(QMediaMetaData::Author);
    if (!metadata.stringValue(QMediaMetaData::AlbumTitle).isEmpty())
        info.album = metadata.stringValue(QMediaMetaData::AlbumTitle);
    info.coverUrl = cacheEmbeddedCover(embeddedCover, path);

    return info;
}

} // namespace LocalMusic
