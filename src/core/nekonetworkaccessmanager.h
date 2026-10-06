#pragma once

/**
 * @file nekonetworkaccessmanager.h
 * @brief 统一附加本站客户端标识的网络管理器
 */

#include <QNetworkAccessManager>

class QIODevice;
class QNetworkReply;
class QNetworkRequest;

/**
 * @brief 为发往**本站后端**的请求统一附加客户端标识
 *
 * 拦截本管理器的全部出站请求，对与 `Theme::kApiBase` 同主机的请求附加：
 *   - User-Agent:    NekoMusic-PC/<APP_VERSION>
 *   - X-Neko-Client: pc+<APP_VERSION>
 *
 * 服务端（CrawlerProtectionFilter）据此把官方桌面端与爬虫区分开，避免被浏览器
 * 完整性校验误伤；第三方主机（更新检查 / CDN / 天气等）不加，避免身份外泄。
 * 版本取 CMake `PROJECT_VERSION`（`version.h`），非硬编码。
 *
 * 全端所有 `QNetworkAccessManager` 统一改用本类，避免逐处遗漏。
 */
class NekoNetworkAccessManager : public QNetworkAccessManager
{
    Q_OBJECT
public:
    explicit NekoNetworkAccessManager(QObject *parent = nullptr);

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                                 QIODevice *outgoingData = nullptr) override;
};
