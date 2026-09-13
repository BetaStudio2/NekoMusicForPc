/**
 * @file logindialog.cpp
 * @brief 登录/注册对话框实现
 */

#include "logindialog.h"
#include "authdialogchrome.h"
#include "forgotpassworddialog.h"
#include "slidercaptchadialog.h"
#include "core/apiclient.h"
#include "core/usermanager.h"
#include "core/i18n.h"
#include "core/vipqrcode.h"
#include "theme/theme.h"
#include "theme/thememanager.h"

#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLineEdit>
#include <QLabel>
#include <QPushButton>
#include <QStackedWidget>
#include <QGraphicsDropShadowEffect>
#include <QTimer>
#include <QNetworkReply>
#include <QColor>

LoginDialog::LoginDialog(QWidget *parent)
    : QDialog(parent)
    , m_api(new ApiClient(this))
{
    setStyleSheet(Theme::ThemeManager::instance().currentStyleSheet());
    setupUi();
    applyDialogTheme();

    setModal(true);
    setFixedWidth(AuthDialogChrome::kDialogWidth);
    updateDialogSize();
    setWindowFlags(windowFlags() | Qt::FramelessWindowHint);
    setAttribute(Qt::WA_TranslucentBackground);

    auto *shadow = new QGraphicsDropShadowEffect(this);
    shadow->setBlurRadius(30);
    shadow->setOffset(0, 4);
    shadow->setColor(QColor(0, 0, 0, 80));
    setGraphicsEffect(shadow);
}

LoginDialog::~LoginDialog()
{
    stopQrSession();
}

void LoginDialog::applyDialogTheme()
{
    const AuthDialogChrome::Palette p = AuthDialogChrome::currentPalette();

    if (m_card)
        m_card->setStyleSheet(AuthDialogChrome::cardStyleSheet(p));
    if (m_titleLabel)
        m_titleLabel->setStyleSheet(AuthDialogChrome::titleStyleSheet(p));
    if (m_msgLabel) {
        if (m_msgLabel->text().isEmpty()) {
            m_msgLabel->hide();
            m_msgLabel->setStyleSheet(AuthDialogChrome::msgStyleSheet(p.msgColor));
        } else {
            m_msgLabel->show();
        }
    }
    if (m_qrImageLabel)
        m_qrImageLabel->setStyleSheet(QStringLiteral(
            "QLabel#qrImageBox { background: #FFFFFF; border-radius: 12px; }"));
    if (m_qrTipLabel)
        m_qrTipLabel->setStyleSheet(AuthDialogChrome::bodyStyleSheet(p));
}

void LoginDialog::updateDialogSize()
{
    int minH = 420;
    if (m_page == Page::Register)
        minH = 540;
    else if (m_page == Page::Qr)
        minH = 520;
    adjustSize();
    const int h = qMax(minH, sizeHint().height());
    setMinimumHeight(minH);
    resize(AuthDialogChrome::kDialogWidth, h);
}

void LoginDialog::setupUi()
{
    auto *outer = new QVBoxLayout(this);
    outer->setContentsMargins(AuthDialogChrome::kOuterPad, AuthDialogChrome::kOuterPad,
                            AuthDialogChrome::kOuterPad, AuthDialogChrome::kOuterPad);
    outer->setSpacing(0);

    m_card = new QWidget(this);
    m_card->setObjectName(QStringLiteral("authDialogCard"));
    auto *mainLayout = new QVBoxLayout(m_card);
    mainLayout->setContentsMargins(AuthDialogChrome::kCardPadH, AuthDialogChrome::kCardPadV,
                                   AuthDialogChrome::kCardPadH, AuthDialogChrome::kCardPadV);
    mainLayout->setSpacing(AuthDialogChrome::kSectionSpacing);

    auto *closeBtn = new QPushButton(QStringLiteral("×"), m_card);
    closeBtn->setObjectName("dialogCloseBtn");
    closeBtn->setFixedSize(34, 34);
    closeBtn->setCursor(Qt::PointingHandCursor);
    connect(closeBtn, &QPushButton::clicked, this, &QDialog::reject);

    auto *headerRow = new QHBoxLayout();
    headerRow->setContentsMargins(0, 0, 0, 0);
    headerRow->addStretch();
    headerRow->addWidget(closeBtn);
    mainLayout->addLayout(headerRow);

    m_titleLabel = new QLabel(I18n::instance().tr("login"), m_card);
    m_titleLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(m_titleLabel);

    m_msgLabel = new QLabel(m_card);
    m_msgLabel->setAlignment(Qt::AlignCenter);
    m_msgLabel->setWordWrap(true);
    m_msgLabel->hide();
    mainLayout->addWidget(m_msgLabel);

    auto *loginWidget = new QWidget(m_card);
    auto *loginLayout = new QVBoxLayout(loginWidget);
    loginLayout->setContentsMargins(0, 0, 0, 0);
    loginLayout->setSpacing(AuthDialogChrome::kFieldSpacing);

    m_loginUserEdit = new QLineEdit(loginWidget);
    m_loginUserEdit->setPlaceholderText(I18n::instance().tr("email"));
    m_loginUserEdit->setObjectName("dialogEdit");
    m_loginUserEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    loginLayout->addWidget(m_loginUserEdit);

    m_loginPassEdit = new QLineEdit(loginWidget);
    m_loginPassEdit->setPlaceholderText(I18n::instance().tr("password"));
    m_loginPassEdit->setObjectName("dialogEdit");
    m_loginPassEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_loginPassEdit->setEchoMode(QLineEdit::Password);
    loginLayout->addWidget(m_loginPassEdit);

    auto *regWidget = new QWidget(m_card);
    auto *regLayout = new QVBoxLayout(regWidget);
    regLayout->setContentsMargins(0, 0, 0, 0);
    regLayout->setSpacing(AuthDialogChrome::kFieldSpacing);

    m_regUserEdit = new QLineEdit(regWidget);
    m_regUserEdit->setPlaceholderText(I18n::instance().tr("username"));
    m_regUserEdit->setObjectName("dialogEdit");
    m_regUserEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    regLayout->addWidget(m_regUserEdit);

    m_regPassEdit = new QLineEdit(regWidget);
    m_regPassEdit->setPlaceholderText(I18n::instance().tr("password"));
    m_regPassEdit->setObjectName("dialogEdit");
    m_regPassEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_regPassEdit->setEchoMode(QLineEdit::Password);
    regLayout->addWidget(m_regPassEdit);

    auto *emailRow = new QWidget(regWidget);
    auto *emailRowLayout = new QHBoxLayout(emailRow);
    emailRowLayout->setContentsMargins(0, 0, 0, 0);
    emailRowLayout->setSpacing(10);

    m_regEmailEdit = new QLineEdit(emailRow);
    m_regEmailEdit->setPlaceholderText(I18n::instance().tr("email"));
    m_regEmailEdit->setObjectName("dialogEdit");
    m_regEmailEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    emailRowLayout->addWidget(m_regEmailEdit, 1);

    m_sendCodeBtn = new QPushButton(I18n::instance().tr("sendCode"), emailRow);
    m_sendCodeBtn->setObjectName("dialogBtn");
    m_sendCodeBtn->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_sendCodeBtn->setMinimumWidth(108);
    connect(m_sendCodeBtn, &QPushButton::clicked, this, &LoginDialog::doSendVerificationCode);
    emailRowLayout->addWidget(m_sendCodeBtn);

    regLayout->addWidget(emailRow);

    m_regCodeEdit = new QLineEdit(regWidget);
    m_regCodeEdit->setPlaceholderText(I18n::instance().tr("verificationCode"));
    m_regCodeEdit->setObjectName("dialogEdit");
    m_regCodeEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    regLayout->addWidget(m_regCodeEdit);

    auto *qrWidget = new QWidget(m_card);
    auto *qrLayout = new QVBoxLayout(qrWidget);
    qrLayout->setContentsMargins(0, 0, 0, 0);
    qrLayout->setSpacing(AuthDialogChrome::kFieldSpacing);

    m_qrImageLabel = new QLabel(qrWidget);
    m_qrImageLabel->setObjectName(QStringLiteral("qrImageBox"));
    m_qrImageLabel->setAlignment(Qt::AlignCenter);
    m_qrImageLabel->setFixedSize(228, 228);
    qrLayout->addWidget(m_qrImageLabel, 0, Qt::AlignHCenter);

    m_qrTipLabel = new QLabel(I18n::instance().tr("qrLoginHint"), qrWidget);
    m_qrTipLabel->setAlignment(Qt::AlignCenter);
    m_qrTipLabel->setWordWrap(true);
    qrLayout->addWidget(m_qrTipLabel);

    m_qrHintLabel = new QLabel(qrWidget);
    m_qrHintLabel->setAlignment(Qt::AlignCenter);
    m_qrHintLabel->setWordWrap(true);
    qrLayout->addWidget(m_qrHintLabel);

    m_qrRefreshBtn = new QPushButton(I18n::instance().tr("qrLoginRefresh"), qrWidget);
    m_qrRefreshBtn->setObjectName("dialogBtn");
    m_qrRefreshBtn->setFixedHeight(AuthDialogChrome::kFieldHeight);
    connect(m_qrRefreshBtn, &QPushButton::clicked, this, &LoginDialog::refreshQrSession);
    qrLayout->addWidget(m_qrRefreshBtn);

    m_stack = new QStackedWidget(m_card);
    m_stack->addWidget(loginWidget);
    m_stack->addWidget(regWidget);
    m_stack->addWidget(qrWidget);
    m_stack->setCurrentIndex(0);
    mainLayout->addWidget(m_stack);

    mainLayout->addSpacing(4);

    m_submitBtn = new QPushButton(I18n::instance().tr("login"), m_card);
    m_submitBtn->setObjectName("dialogBtn");
    m_submitBtn->setFixedHeight(AuthDialogChrome::kPrimaryBtnHeight);
    connect(m_submitBtn, &QPushButton::clicked, this, [this]() {
        if (m_page == Page::Login)
            doLogin();
        else if (m_page == Page::Register)
            doRegister();
    });
    mainLayout->addWidget(m_submitBtn);

    auto *linksWrap = new QWidget(m_card);
    auto *linksLay = new QVBoxLayout(linksWrap);
    linksLay->setContentsMargins(0, 4, 0, 0);
    linksLay->setSpacing(10);

    m_switchBtn = new QPushButton(I18n::instance().tr("register"), linksWrap);
    m_switchBtn->setObjectName("dialogLinkBtn");
    m_switchBtn->setFixedHeight(AuthDialogChrome::kLinkBtnHeight);
    m_switchBtn->setCursor(Qt::PointingHandCursor);
    connect(m_switchBtn, &QPushButton::clicked, this, &LoginDialog::switchMode);
    linksLay->addWidget(m_switchBtn);

    m_qrLoginBtn = new QPushButton(I18n::instance().tr("qrLogin"), linksWrap);
    m_qrLoginBtn->setObjectName("dialogLinkBtn");
    m_qrLoginBtn->setFixedHeight(AuthDialogChrome::kLinkBtnHeight);
    m_qrLoginBtn->setCursor(Qt::PointingHandCursor);
    connect(m_qrLoginBtn, &QPushButton::clicked, this, &LoginDialog::showQrMode);
    linksLay->addWidget(m_qrLoginBtn);

    m_forgotBtn = new QPushButton(I18n::instance().tr("forgotPassword"), linksWrap);
    m_forgotBtn->setObjectName("dialogLinkBtn");
    m_forgotBtn->setFixedHeight(AuthDialogChrome::kLinkBtnHeight);
    m_forgotBtn->setCursor(Qt::PointingHandCursor);
    connect(m_forgotBtn, &QPushButton::clicked, this, &LoginDialog::showForgotPassword);
    linksLay->addWidget(m_forgotBtn);
    mainLayout->addWidget(linksWrap);

    outer->addWidget(m_card);
}

void LoginDialog::applyMode()
{
    const bool qr = (m_page == Page::Qr);

    if (m_page == Page::Login)
        m_stack->setCurrentIndex(0);
    else if (m_page == Page::Register)
        m_stack->setCurrentIndex(1);
    else
        m_stack->setCurrentIndex(2);

    m_submitBtn->setVisible(!qr);
    m_forgotBtn->setVisible(m_page == Page::Login);
    m_switchBtn->setVisible(!qr);
    m_qrLoginBtn->setText(qr ? I18n::instance().tr("qrLoginBack")
                             : I18n::instance().tr("qrLogin"));

    if (m_titleLabel) {
        if (qr)
            m_titleLabel->setText(I18n::instance().tr("qrLoginTitle"));
        else
            m_titleLabel->setText(I18n::instance().tr(m_page == Page::Login ? "login" : "register"));
    }

    if (m_page == Page::Register) {
        m_submitBtn->setText(I18n::instance().tr("register"));
        m_switchBtn->setText(I18n::instance().tr("login"));
    } else if (m_page == Page::Login) {
        m_submitBtn->setText(I18n::instance().tr("login"));
        m_switchBtn->setText(I18n::instance().tr("register"));
    }

    applyDialogTheme();
    updateDialogSize();
}

void LoginDialog::switchMode()
{
    m_page = (m_page == Page::Register) ? Page::Login : Page::Register;
    stopQrSession();
    m_msgLabel->clear();
    applyMode();
}

void LoginDialog::showQrMode()
{
    if (m_page == Page::Qr) {
        m_page = Page::Login;
        stopQrSession();
        applyMode();
        return;
    }

    m_page = Page::Qr;
    m_msgLabel->clear();
    applyMode();
    refreshQrSession();
}

void LoginDialog::refreshQrSession()
{
    stopQrSession();
    if (m_page != Page::Qr)
        return;

    const int generation = m_qrGeneration;
    m_qrImageLabel->clear();
    m_qrRefreshBtn->setEnabled(false);
    setQrHint(I18n::instance().tr("qrLoginLoading"), Theme::kTextSub);

    m_api->createQrLoginSession(
        [this, generation](bool ok, const QString &message, const ApiClient::QrLoginSession &session) {
            QTimer::singleShot(0, this, [this, generation, ok, message, session]() {
                if (generation != m_qrGeneration || m_page != Page::Qr)
                    return;

                if (!ok) {
                    m_qrRefreshBtn->setEnabled(true);
                    setQrHint(message.isEmpty() ? I18n::instance().tr("qrLoginFailed") : message,
                              Theme::kSakura);
                    return;
                }

                const QPixmap qr = VipQrCode::pixmapFromText(session.qrContent, 204);
                if (qr.isNull()) {
                    m_qrRefreshBtn->setEnabled(true);
                    setQrHint(I18n::instance().tr("qrLoginFailed"), Theme::kSakura);
                    return;
                }

                m_qrImageLabel->setPixmap(qr);
                m_qrRefreshBtn->setEnabled(true);
                setQrHint(I18n::instance().tr("qrLoginPending"), Theme::kTextSub);
                startQrWatch(session.sessionId, generation);
            });
        });
}

void LoginDialog::startQrWatch(const QString &sessionId, int generation)
{
    ApiClient::QrLoginSseCallbacks callbacks;

    callbacks.onStatus = [this, generation](const ApiClient::QrLoginStatus &status) {
        QTimer::singleShot(0, this, [this, generation, status]() {
            if (generation != m_qrGeneration || m_page != Page::Qr)
                return;

            if (status.status == QLatin1String("pending")) {
                setQrHint(I18n::instance().tr("qrLoginPending"), Theme::kTextSub);
            } else if (status.status == QLatin1String("scanned")) {
                setQrHint(I18n::instance().tr("qrLoginScanned"), Theme::kMint);
            } else if (status.status == QLatin1String("confirmed")) {
                if (status.token.isEmpty() || status.user.isEmpty()) {
                    m_qrImageLabel->clear();
                    setQrHint(I18n::instance().tr("qrLoginFailed"), Theme::kSakura);
                    return;
                }
                UserManager::instance().setLoginInfo(status.token, status.user);
                accept();
            } else if (status.status == QLatin1String("canceled")) {
                m_qrImageLabel->clear();
                setQrHint(I18n::instance().tr("qrLoginCanceled"), Theme::kSakura);
            } else {
                m_qrImageLabel->clear();
                setQrHint(I18n::instance().tr("qrLoginExpired"), Theme::kSakura);
            }
        });
    };

    callbacks.onError = [this, generation](const QString &) {
        QTimer::singleShot(0, this, [this, generation]() {
            if (generation != m_qrGeneration || m_page != Page::Qr)
                return;
            m_qrImageLabel->clear();
            setQrHint(I18n::instance().tr("qrLoginConnectionLost"), Theme::kSakura);
        });
    };

    m_qrReply = m_api->watchQrLoginStatus(sessionId, callbacks);
}

void LoginDialog::stopQrSession()
{
    ++m_qrGeneration; // 让在途回调失效

    if (!m_qrReply)
        return;
    QNetworkReply *reply = m_qrReply;
    m_qrReply = nullptr;
    if (!reply->isFinished())
        reply->abort();
}

void LoginDialog::setQrHint(const QString &text, const QString &color)
{
    if (!m_qrHintLabel)
        return;
    m_qrHintLabel->setText(text);
    m_qrHintLabel->setStyleSheet(
        QStringLiteral("QLabel { color: %1; font-size: 13px; min-height: 20px; }").arg(color));
}

void LoginDialog::doLogin()
{
    QString username = m_loginUserEdit->text().trimmed();
    QString password = m_loginPassEdit->text();

    if (username.isEmpty() || password.isEmpty()) {
        setMsg(I18n::instance().tr("fillUsernameAndPassword"), Theme::kSakura);
        return;
    }

    setMsg("", Qt::transparent);
    m_submitBtn->setEnabled(false);
    m_submitBtn->setText("...");

    m_api->login(username, password, [this](bool success, const QString &message,
                                             const QString &token, const QVariantMap &user) {
        QTimer::singleShot(0, this, [this, success, message, token, user]() {
            onLoginResult(success, message, token, user);
        });
    });
}

void LoginDialog::doRegister()
{
    QString username = m_regUserEdit->text().trimmed();
    QString password = m_regPassEdit->text();
    QString email = m_regEmailEdit->text().trimmed();
    QString code = m_regCodeEdit->text().trimmed();

    if (username.isEmpty() || password.isEmpty() || email.isEmpty() || code.isEmpty()) {
        setMsg(I18n::instance().tr("fillAllFields"), Theme::kSakura);
        return;
    }

    setMsg("", Qt::transparent);
    m_submitBtn->setEnabled(false);
    m_submitBtn->setText("...");

    m_api->registerUser(username, password, email, code,
                        [this](bool success, const QString &message,
                               const QString &token, const QVariantMap &user) {
        QTimer::singleShot(0, this, [this, success, message, token, user]() {
            onLoginResult(success, message, token, user);
        });
    });
}

void LoginDialog::doSendVerificationCode()
{
    QString email = m_regEmailEdit->text().trimmed();
    if (email.isEmpty()) {
        setMsg(I18n::instance().tr("pleaseEnterEmail"), Theme::kSakura);
        return;
    }
    const QString username = m_regUserEdit->text().trimmed();
    if (username.isEmpty()) {
        setMsg(I18n::instance().tr(QStringLiteral("registerNeedUsernameForCode")), Theme::kSakura);
        return;
    }

    m_sendCodeBtn->setEnabled(false);

    SliderCaptchaDialog captchaDlg(m_api, this);
    const int captchaResult = captchaDlg.exec();
    if (captchaResult != QDialog::Accepted) {
        m_sendCodeBtn->setEnabled(true);
        return;
    }
    const QString passToken = captchaDlg.captchaPassToken();
    if (passToken.isEmpty()) {
        m_sendCodeBtn->setEnabled(true);
        return;
    }

    m_api->sendVerificationCode(email, username, passToken, [this](bool success, const QString &message) {
        QTimer::singleShot(0, this, [this, success, message]() {
            if (success) {
                setMsg(message, Theme::kMint);
                if (m_countdownTimer) {
                    m_countdownTimer->stop();
                    m_countdownTimer->deleteLater();
                }
                m_countdown = 60;
                m_countdownTimer = new QTimer(this);
                connect(m_countdownTimer, &QTimer::timeout, this, [this]() {
                    m_countdown--;
                    m_sendCodeBtn->setText(QString("%1s").arg(m_countdown));
                    if (m_countdown <= 0) {
                        m_countdownTimer->stop();
                        m_countdownTimer->deleteLater();
                        m_countdownTimer = nullptr;
                        m_sendCodeBtn->setEnabled(true);
                        m_sendCodeBtn->setText(I18n::instance().tr("sendCode"));
                    }
                });
                m_countdownTimer->start(1000);
            } else {
                setMsg(message, Theme::kSakura);
                m_sendCodeBtn->setEnabled(true);
            }
        });
    });
}

void LoginDialog::onLoginResult(bool success, const QString &message,
                                 const QString &token, const QVariantMap &user)
{
    m_submitBtn->setEnabled(true);
    if (m_page == Page::Register) {
        m_submitBtn->setText(I18n::instance().tr("register"));
    } else {
        m_submitBtn->setText(I18n::instance().tr("login"));
    }

    if (success) {
        UserManager::instance().setLoginInfo(token, user);
        accept();
    } else {
        setMsg(message, Theme::kSakura);
    }
}

void LoginDialog::showForgotPassword()
{
    ForgotPasswordDialog dlg(this);
    dlg.exec();
}

void LoginDialog::setMsg(const QString &text, const QColor &color)
{
    m_msgLabel->setText(text);
    if (text.isEmpty()) {
        m_msgLabel->hide();
        applyDialogTheme();
        updateDialogSize();
        return;
    }
    m_msgLabel->show();
    m_msgLabel->setStyleSheet(AuthDialogChrome::msgStyleSheet(color.name()));
    updateDialogSize();
}
