#pragma once

/**
 * @file clientidentity.h
 * @brief 本站（NekoMusic）客户端标识常量。
 *
 * 与 origin/qt 的 `nekonetworkaccessmanager` 保持严格一致：
 *   - `User-Agent` 为官方锚定的桌面形状 `NekoMusic-PC/<版本>`（非空，版本以数字开头）；
 *   - `X-Neko-Client` 声明真实来源 `pc+<版本>`。
 *
 * 供原生音频引擎（原生 HTTP(S) / FFmpeg AVIO 在线源）携带，避免在线拉流因
 * 缺失/未知客户端标识被服务端降级。此头为纯常量，不产生链接依赖。
 */

#include <QByteArray>
#include <QString>

#include "version.h"

namespace ClientIdentity {

/** 出站 UA：`NekoMusic-PC/<版本>`。 */
inline QString userAgent()
{
    return QStringLiteral("NekoMusic-PC/%1").arg(QString::fromUtf8(APP_VERSION));
}

/** 客户端标识值：`pc+<版本>`（X-Neko-Client）。 */
inline QString nekoClient()
{
    return QStringLiteral("pc+%1").arg(QString::fromUtf8(APP_VERSION));
}

/** 引擎请求头块（`\n` 分行，供 create_with_headers / 原生 HTTP 与 AVIO 使用）。 */
inline QByteArray engineHeaders()
{
    return QStringLiteral("User-Agent: %1\nX-Neko-Client: %2")
        .arg(userAgent(), nekoClient())
        .toUtf8();
}

} // namespace ClientIdentity
