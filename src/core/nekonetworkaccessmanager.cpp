/**
 * @file nekonetworkaccessmanager.cpp
 * @brief 统一附加本站客户端标识的网络管理器实现
 */

#include "core/nekonetworkaccessmanager.h"
#include "theme/theme.h"
#include "version.h"

#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace {

/** 请求是否发往本站后端（与 Theme::kApiBase 同主机，大小写不敏感）。 */
bool isBackendRequest(const QUrl &url)
{
    const QUrl base(QString::fromUtf8(Theme::kApiBase));
    if (!base.isValid() || base.host().isEmpty()) {
        return true; // 后端未配置：保守带上标识，交服务端自行判断
    }
    return url.host().compare(base.host(), Qt::CaseInsensitive) == 0;
}

} // namespace

NekoNetworkAccessManager::NekoNetworkAccessManager(QObject *parent)
    : QNetworkAccessManager(parent)
{
}

QNetworkReply *NekoNetworkAccessManager::createRequest(Operation op,
                                                       const QNetworkRequest &request,
                                                       QIODevice *outgoingData)
{
    QNetworkRequest req(request);
    if (isBackendRequest(req.url())) {
        const QString version = QString::fromUtf8(APP_VERSION);
        // 已有显式 UA（如封面缓存 "NekoMusic Qt"）则不覆盖。
        if (req.header(QNetworkRequest::UserAgentHeader).isNull()) {
            req.setHeader(QNetworkRequest::UserAgentHeader,
                          QStringLiteral("NekoMusic-PC/%1").arg(version));
        }
        if (!req.hasRawHeader("X-Neko-Client")) {
            req.setRawHeader("X-Neko-Client",
                             QStringLiteral("pc+%1").arg(version).toUtf8());
        }
    }
    return QNetworkAccessManager::createRequest(op, req, outgoingData);
}
