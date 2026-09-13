#pragma once

/**
 * @file logindialog.h
 * @brief 登录/注册对话框
 */

#include <QDialog>

class QLineEdit;
class QLabel;
class QPushButton;
class QStackedWidget;
class QWidget;
class ApiClient;
class QTimer;
class QNetworkReply;

class LoginDialog : public QDialog
{
    Q_OBJECT

public:
    explicit LoginDialog(QWidget *parent = nullptr);
    ~LoginDialog() override;

private:
    /** 当前页面：账号密码登录 / 注册 / 扫码登录 */
    enum class Page { Login, Register, Qr };

    void setupUi();
    void applyDialogTheme();
    void updateDialogSize();
    void applyMode();
    void switchMode();
    void showQrMode();
    void refreshQrSession();
    void startQrWatch(const QString &sessionId, int generation);
    void stopQrSession();
    void doLogin();
    void doRegister();
    void doSendVerificationCode();
    void onLoginResult(bool success, const QString &message,
                       const QString &token, const QVariantMap &user);
    void showForgotPassword();
    void setMsg(const QString &text, const QColor &color);

    QWidget *m_card = nullptr;
    QLabel *m_titleLabel = nullptr;
    QLabel *m_subtitleLabel = nullptr;
    QTimer *m_countdownTimer = nullptr;
    QStackedWidget *m_stack = nullptr;
    QLineEdit *m_loginUserEdit = nullptr;
    QLineEdit *m_loginPassEdit = nullptr;
    QLineEdit *m_regUserEdit = nullptr;
    QLineEdit *m_regPassEdit = nullptr;
    QLineEdit *m_regEmailEdit = nullptr;
    QLineEdit *m_regCodeEdit = nullptr;
    QPushButton *m_submitBtn = nullptr;
    QPushButton *m_switchBtn = nullptr;
    QPushButton *m_sendCodeBtn = nullptr;
    QPushButton *m_forgotBtn = nullptr;
    QLabel *m_msgLabel = nullptr;
    QLabel *m_qrImageLabel = nullptr;
    QLabel *m_qrTipLabel = nullptr;
    ApiClient *m_api = nullptr;
    QNetworkReply *m_qrReply = nullptr;
    Page m_page = Page::Login;
    /** 递增即作废在途的二维码请求/SSE 回调 */
    int m_qrGeneration = 0;
    int m_countdown = 0;
};
