#include "defaultmusicappchecker.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>

#include <windows.h>
#include <objbase.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <shlwapi.h>

namespace {

constexpr const wchar_t *kAppRegisteredName = L"NekoMusic";
constexpr const wchar_t *kAppExeName = L"NekoMusic.exe";
constexpr const wchar_t *kAppProgId = L"NekoMusic.AudioFile";

struct MediaAssociation {
    const wchar_t *ext;
    const wchar_t *mime;
};

constexpr MediaAssociation kMediaAssociations[] = {
    {L".mp3", L"audio/mpeg"},
    {L".flac", L"audio/flac"},
    {L".wav", L"audio/x-wav"},
    {L".m4a", L"audio/mp4"},
    {L".aac", L"audio/aac"},
    {L".ogg", L"audio/ogg"},
    {L".oga", L"audio/ogg"},
    {L".opus", L"audio/opus"},
    {L".mp4", L"audio/mp4"},
    {L".wma", L"audio/x-ms-wma"},
    {L".mpc", L"audio/x-musepack"},
    {L".spx", L"audio/x-speex"},
    {L".ra", L"audio/vnd.rn-realaudio"},
    {L".ram", L"audio/vnd.rn-realaudio"},
    {L".m3u", L"audio/mpegurl"},
    {L".m3u8", L"audio/x-mpegurl"},
    {L".pls", L"audio/x-scpls"},
};

QString assocExecutableForExtension(const wchar_t *extWithDot)
{
    wchar_t buf[MAX_PATH * 4] = {};
    DWORD cch = DWORD(sizeof(buf) / sizeof(buf[0]));
    HRESULT hr = AssocQueryStringW(ASSOCF_INIT_IGNOREUNKNOWN, ASSOCSTR_EXECUTABLE, extWithDot, nullptr, buf, &cch);
    if (FAILED(hr) || !buf[0])
        return {};
    return QString::fromWCharArray(buf);
}

QString normalizeExe(const QString &path)
{
    if (path.isEmpty())
        return {};
    QFileInfo fi(path);
    QString c = fi.canonicalFilePath();
    if (c.isEmpty())
        c = fi.absoluteFilePath();
    return QDir::toNativeSeparators(c).toLower();
}

bool extensionDefaultsToOurExe(const wchar_t *ext)
{
    const QString handler = normalizeExe(assocExecutableForExtension(ext));
    if (handler.isEmpty())
        return false;
    const QString self = normalizeExe(QCoreApplication::applicationFilePath());
    if (self.isEmpty())
        return false;
    return handler == self;
}

bool writeRegString(HKEY root, const QString &subKey, const wchar_t *valueName, const QString &value)
{
    HKEY key = nullptr;
    const LONG rc = RegCreateKeyExW(root, reinterpret_cast<const wchar_t *>(subKey.utf16()), 0, nullptr,
                                    REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &key, nullptr);
    if (rc != ERROR_SUCCESS)
        return false;

    const QByteArray utf16(reinterpret_cast<const char *>(value.utf16()), (value.size() + 1) * int(sizeof(wchar_t)));
    const LONG wr = RegSetValueExW(key, valueName, 0, REG_SZ,
                                   reinterpret_cast<const BYTE *>(utf16.constData()), DWORD(utf16.size()));
    RegCloseKey(key);
    return wr == ERROR_SUCCESS;
}

bool deleteRegTree(HKEY root, const QString &subKey)
{
    const LONG rc = RegDeleteTreeW(root, reinterpret_cast<const wchar_t *>(subKey.utf16()));
    return rc == ERROR_SUCCESS || rc == ERROR_FILE_NOT_FOUND;
}

QString quotedOpenCommand()
{
    return QStringLiteral("\"%1\" \"%2\"").arg(QDir::toNativeSeparators(QCoreApplication::applicationFilePath()),
                                               QStringLiteral("%1"));
}

void registerCurrentUserFileAssociations()
{
    const QString appPath = QDir::toNativeSeparators(QCoreApplication::applicationFilePath());
    const QString appIcon = appPath + QStringLiteral(",0");
    const QString command = quotedOpenCommand();

    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\RegisteredApplications"), kAppRegisteredName,
                   QStringLiteral("Software\\NekoMusic\\Capabilities"));
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\NekoMusic\\Capabilities"), L"ApplicationName",
                   QStringLiteral("Neko歌姬计划"));
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\NekoMusic\\Capabilities"), L"ApplicationDescription",
                   QStringLiteral("NekoMusic audio player"));
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\NekoMusic\\Capabilities"), L"ApplicationIcon", appIcon);
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\NekoMusic.exe"),
                   nullptr, appPath);
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\NekoMusic.exe"),
                   L"Path", QDir::toNativeSeparators(QFileInfo(appPath).absolutePath()));

    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\Classes\\NekoMusic.AudioFile"), nullptr,
                   QStringLiteral("NekoMusic media file"));
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\Classes\\NekoMusic.AudioFile\\DefaultIcon"), nullptr,
                   appIcon);
    writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\Classes\\NekoMusic.AudioFile\\shell\\open\\command"),
                   nullptr, command);

    const QString appClassBase = QStringLiteral("Software\\Classes\\Applications\\%1").arg(QString::fromWCharArray(kAppExeName));
    writeRegString(HKEY_CURRENT_USER, appClassBase, L"FriendlyAppName", QStringLiteral("Neko歌姬计划"));
    writeRegString(HKEY_CURRENT_USER, appClassBase + QStringLiteral("\\DefaultIcon"), nullptr, appIcon);
    writeRegString(HKEY_CURRENT_USER, appClassBase + QStringLiteral("\\shell\\open\\command"), nullptr, command);

    for (const MediaAssociation &a : kMediaAssociations) {
        writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\NekoMusic\\Capabilities\\FileAssociations"), a.ext,
                       QString::fromWCharArray(kAppProgId));
        writeRegString(HKEY_CURRENT_USER, QStringLiteral("Software\\NekoMusic\\Capabilities\\MIMEAssociations"), a.mime,
                       QString::fromWCharArray(kAppProgId));
        writeRegString(HKEY_CURRENT_USER, appClassBase + QStringLiteral("\\SupportedTypes"), a.ext, QString());
        writeRegString(HKEY_CURRENT_USER,
                       QStringLiteral("Software\\Classes\\%1\\OpenWithProgids").arg(QString::fromWCharArray(a.ext)),
                       kAppProgId, QString());
    }
}

bool setAssociationsViaWindowsApi()
{
    HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool shouldUninit = SUCCEEDED(init);
    if (init == RPC_E_CHANGED_MODE)
        init = S_OK;
    if (FAILED(init))
        return false;

    IApplicationAssociationRegistration *assoc = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_ApplicationAssociationRegistration, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IApplicationAssociationRegistration, reinterpret_cast<void **>(&assoc));
    if (FAILED(hr) || !assoc) {
        if (shouldUninit)
            CoUninitialize();
        return false;
    }

    bool ok = true;
    for (const MediaAssociation &a : kMediaAssociations) {
        ok = SUCCEEDED(assoc->SetAppAsDefault(kAppRegisteredName, a.ext, AT_FILEEXTENSION)) && ok;
        ok = SUCCEEDED(assoc->SetAppAsDefault(kAppRegisteredName, a.mime, AT_MIMETYPE)) && ok;
    }
    ok = SUCCEEDED(assoc->SetAppAsDefaultAll(kAppRegisteredName)) && ok;

    assoc->Release();
    if (shouldUninit)
        CoUninitialize();
    return ok;
}

void forceCurrentUserDefaultAssociations()
{
    for (const MediaAssociation &a : kMediaAssociations) {
        const QString ext = QString::fromWCharArray(a.ext);
        const QString extClass = QStringLiteral("Software\\Classes\\%1").arg(ext);
        const QString fileExtChoice = QStringLiteral("Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FileExts\\%1\\UserChoice").arg(ext);

        deleteRegTree(HKEY_CURRENT_USER, fileExtChoice);
        writeRegString(HKEY_CURRENT_USER, extClass, nullptr, QString::fromWCharArray(kAppProgId));
        writeRegString(HKEY_CURRENT_USER, extClass, L"Content Type", QString::fromWCharArray(a.mime));
        writeRegString(HKEY_CURRENT_USER, extClass, L"PerceivedType", QStringLiteral("audio"));
    }

    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}

} // namespace

namespace DefaultMusicAppChecker {

bool isDefaultMusicPlayer()
{
    int ok = 0;
    int total = 0;
    for (const MediaAssociation &a : kMediaAssociations) {
        QString h = normalizeExe(assocExecutableForExtension(a.ext));
        if (h.isEmpty())
            continue;
        total++;
        if (extensionDefaultsToOurExe(a.ext))
            ok++;
    }
    if (total == 0)
        return true;
    return ok == total;
}

void trySetAsDefaultMusicPlayer()
{
    registerCurrentUserFileAssociations();
    setAssociationsViaWindowsApi();
    forceCurrentUserDefaultAssociations();
}

} // namespace DefaultMusicAppChecker
