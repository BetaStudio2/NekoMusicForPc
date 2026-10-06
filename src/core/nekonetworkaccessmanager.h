#pragma once

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QString>
#include <QSysInfo>

#include "version.h"

/**
 * 统一附加客户端标识标头的网络管理器：
 *   - X-Neko-Client: pc+<版本>
 *   - User-Agent:    NekoMusic-pc/<版本>(<系统>)，如 NekoMusic-pc/2026.105.48(Linux)
 *
 * 后端据此区分请求来自哪个客户端及其版本，因此本项目所有联网的
 * QNetworkAccessManager（API、封面、歌词、更新检查、音乐下载等）都改用本类，
 * 通过重写 createRequest 在请求发出前注入标头，避免逐处 setRawHeader 遗漏。
 */
class NekoNetworkAccessManager : public QNetworkAccessManager
{
public:
    explicit NekoNetworkAccessManager(QObject *parent = nullptr)
        : QNetworkAccessManager(parent) {}

    /** 客户端标识：`pc+<版本>`，版本取自 CMake 生成的 version.h */
    static QString clientValue()
    {
        static const QString value = QStringLiteral("pc+") + QString::fromUtf8(APP_VERSION);
        return value;
    }

    /** User-Agent 取值：`NekoMusic-pc/<版本>(<系统>)` */
    static QString userAgentValue()
    {
        static const QString value = QStringLiteral("NekoMusic-pc/") + QString::fromUtf8(APP_VERSION)
                                     + QLatin1Char('(') + systemLabel() + QLatin1Char(')');
        return value;
    }

    /** 运行系统类型标签，用于 User-Agent 后缀 */
    static QString systemLabel()
    {
#if defined(Q_OS_WIN)
        return QStringLiteral("Windows");
#elif defined(Q_OS_MACOS)
        return QStringLiteral("macOS");
#elif defined(Q_OS_LINUX)
        return QStringLiteral("Linux");
#else
        return QSysInfo::productType();
#endif
    }

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                                 QIODevice *outgoingData) override
    {
        QNetworkRequest tagged(request);
        tagged.setRawHeader("X-Neko-Client", clientValue().toUtf8());
        // 调用方显式设置的 User-Agent 优先（如封面缓存使用的 NekoMusic Qt）
        if (!tagged.hasRawHeader("User-Agent")) {
            tagged.setRawHeader("User-Agent", userAgentValue().toUtf8());
        }
        return QNetworkAccessManager::createRequest(op, tagged, outgoingData);
    }
};
