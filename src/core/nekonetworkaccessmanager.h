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
 * 拦截本管理器的全部出站请求，对与 `Theme::kApiBase` 同主机的请求强制注入：
 *   - User-Agent:    NekoMusic-PC/<APP_VERSION>
 *   - X-Neko-Client: pc+<APP_VERSION>
 *
 * 两个标头都是**强制统一**的：调用方即使自己设置过 User-Agent 也会被覆盖，
 * 保证全链路客户端标识与后端放行规则严格一致；第三方主机（更新检查 / CDN /
 * 天气等）不注入，避免身份外泄。版本取 CMake `PROJECT_VERSION`（`version.h`），
 * 非硬编码。
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
