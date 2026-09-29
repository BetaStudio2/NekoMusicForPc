#pragma once

/**
 * @file legaldialog.h
 * @brief 用户协议 / 隐私政策展示弹窗与首次启动同意弹窗
 */

#include <QDialog>

#include "core/legaltext.h"

class QWidget;

/**
 * 只读长文弹窗：以可滚动的方式展示一篇法律文档（用户协议或隐私政策）。
 * 支持正文中的 `**加粗**`、换行与可点击的 http(s) 链接。
 */
class LegalDialog : public QDialog
{
    Q_OBJECT

public:
    explicit LegalDialog(const LegalDocument &document, QWidget *parent = nullptr);

    /** 打开「用户协议」弹窗。 */
    static void showUserAgreement(QWidget *parent);
    /** 打开「隐私政策」弹窗。 */
    static void showPrivacyPolicy(QWidget *parent);
};

/**
 * 首次启动的协议同意弹窗：需阅读并同意用户协议与隐私政策后方可使用。
 * 点击「同意并继续」返回 Accepted，点击「不同意并退出」返回 Rejected。
 */
class LegalConsentDialog : public QDialog
{
    Q_OBJECT

public:
    explicit LegalConsentDialog(QWidget *parent = nullptr);
};
