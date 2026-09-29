#pragma once

/**
 * @file legaltext.h
 * @brief 用户协议与隐私政策文案，以及同意状态管理
 *
 * 文案随当前界面语言（中文 / 喵语回退中文 / 英文）返回，供设置页与首次启动
 * 弹窗展示。正文中的 `**文本**` 表示加粗，`\n` 表示换行，由展示层负责渲染。
 */

#include <QList>
#include <QString>

/** 文档中的一个分节：小标题 + 正文。 */
struct LegalSection
{
    QString title;
    QString body;
};

/** 一篇完整的法律文档。 */
struct LegalDocument
{
    QString title;                  ///< 文档标题
    QString version;                ///< 版本号展示文本
    QString updated;                ///< 最近更新展示文本
    QString intro;                  ///< 引言（支持 **加粗** 与换行）
    QList<LegalSection> sections;   ///< 分节正文
    QString footer;                 ///< 页脚备注
};

namespace Legal
{

/** 当前协议版本号；版本变化时用于重新征求用户同意。 */
constexpr const char *kVersion = "1.0";

/** 用户协议文案（跟随当前语言）。 */
LegalDocument userAgreement();

/** 隐私政策文案（跟随当前语言）。 */
LegalDocument privacyPolicy();

/** 是否已同意当前版本的用户协议与隐私政策。 */
bool hasAcceptedConsent();

/** 记录用户已同意当前版本的用户协议与隐私政策。 */
void acceptConsent();

} // namespace Legal
