/**
 * @file logindialog.cpp
 * @brief 登录/注册对话框实现
 */

#include "logindialog.h"
#include "authdialogchrome.h"
#include "forgotpassworddialog.h"
#include "slidercaptchadialog.h"
#include "legaldialog.h"
#include "core/apiclient.h"
#include "core/usermanager.h"
#include "core/i18n.h"
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
#include <QPixmap>
#include <QUrl>
#include <QStyle>
#include <QFrame>
#include <QCheckBox>
#include <QPalette>

namespace {

/** 解析服务端返回的 data:image/png;base64,... 图片；失败返回空 QPixmap。 */
QPixmap pixmapFromDataUrl(const QString &dataUrl)
{
    const int comma = dataUrl.indexOf(QLatin1Char(','));
    if (comma <= 0)
        return {};

    const QString header = dataUrl.left(comma);
    if (!header.startsWith(QLatin1String("data:image/")))
        return {};

    const QByteArray payload = dataUrl.mid(comma + 1).toLatin1();
    const QByteArray bytes = header.contains(QLatin1String(";base64"))
                                 ? QByteArray::fromBase64(payload)
                                 : QUrl::fromPercentEncoding(payload).toUtf8();
    if (bytes.isEmpty())
        return {};

    QPixmap pixmap;
    if (!pixmap.loadFromData(bytes))
        return {};
    return pixmap;
}

} // namespace

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

    refreshQrSession();

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
        m_card->setStyleSheet(AuthDialogChrome::cardStyleSheet(p)
                               + AuthDialogChrome::controlsStyleSheet(p));
    if (m_titleLabel)
        m_titleLabel->setStyleSheet(AuthDialogChrome::titleStyleSheet(p));
    if (m_subtitleLabel)
        m_subtitleLabel->setStyleSheet(AuthDialogChrome::subtitleStyleSheet(p));
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
    if (m_consentText) {
        m_consentText->setStyleSheet(QStringLiteral("QLabel { color: %1; font-size: 12.5px; }").arg(p.bodyColor));
        QPalette pal = m_consentText->palette();
        pal.setColor(QPalette::Link, QColor(p.accent));
        pal.setColor(QPalette::LinkVisited, QColor(p.accent));
        m_consentText->setPalette(pal);
    }
    if (m_consentCheck)
        m_consentCheck->setStyleSheet(QStringLiteral(
            "QCheckBox { spacing: 0px; }"
            "QCheckBox::indicator { width: 16px; height: 16px; border: 1px solid %1; border-radius: 4px; background: transparent; }"
            "QCheckBox::indicator:hover { border: 1px solid %2; }"
            "QCheckBox::indicator:checked { background: %2; border: 1px solid %2; }")
            .arg(p.cardBorder, p.accent));
}

void LoginDialog::updateDialogSize()
{
    // 协议勾选行占用固定高度；注册页字段更多，额外留高。
    int extra = 42;
    if (m_page == Page::Register)
        extra += 56;
    setFixedSize(AuthDialogChrome::kDialogWidth, AuthDialogChrome::kDialogHeight + extra);
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
    mainLayout->setContentsMargins(28, 24, 28, 24);
    mainLayout->setSpacing(0);

    auto *header = new QHBoxLayout();
    header->setContentsMargins(0, 0, 0, 12);
    header->addStretch();
    auto *closeBtn = new QPushButton(m_card);
    closeBtn->setObjectName("dialogCloseBtn");
    closeBtn->setFixedSize(32, 32);
    closeBtn->setIcon(style()->standardIcon(QStyle::SP_TitleBarCloseButton));
    closeBtn->setToolTip(I18n::instance().tr(QStringLiteral("close")));
    connect(closeBtn, &QPushButton::clicked, this, &QDialog::reject);
    header->addWidget(closeBtn);
    mainLayout->addLayout(header);

    auto *body = new QHBoxLayout();
    body->setContentsMargins(0, 0, 0, 0);
    body->setSpacing(26);

    auto *qrPane = new QWidget(m_card);
    qrPane->setFixedWidth(226);
    auto *qrLayout = new QVBoxLayout(qrPane);
    qrLayout->setContentsMargins(0, 0, 0, 0);
    qrLayout->setSpacing(10);
    auto *qrTitle = new QLabel(I18n::instance().tr(QStringLiteral("qrLoginTitle")), qrPane);
    qrTitle->setObjectName(QStringLiteral("authQrTitle"));
    qrTitle->setAlignment(Qt::AlignCenter);
    qrLayout->addWidget(qrTitle);
    m_qrImageLabel = new QLabel(qrPane);
    m_qrImageLabel->setObjectName(QStringLiteral("qrImageBox"));
    m_qrImageLabel->setAlignment(Qt::AlignCenter);
    m_qrImageLabel->setFixedSize(204, 204);
    qrLayout->addWidget(m_qrImageLabel, 0, Qt::AlignHCenter);
    m_qrTipLabel = new QLabel(I18n::instance().tr(QStringLiteral("qrLoginHint")), qrPane);
    m_qrTipLabel->setAlignment(Qt::AlignCenter);
    m_qrTipLabel->setWordWrap(true);
    qrLayout->addWidget(m_qrTipLabel);
    body->addWidget(qrPane);

    auto *divider = new QFrame(m_card);
    divider->setFrameShape(QFrame::VLine);
    divider->setFrameShadow(QFrame::Plain);
    divider->setFixedWidth(1);
    body->addWidget(divider);

    auto *formPane = new QWidget(m_card);
    auto *formLayout = new QVBoxLayout(formPane);
    formLayout->setContentsMargins(0, 0, 0, 0);
    formLayout->setSpacing(10);
    m_titleLabel = new QLabel(I18n::instance().tr("login"), formPane);
    m_titleLabel->setAlignment(Qt::AlignLeft | Qt::AlignVCenter);
    formLayout->addWidget(m_titleLabel);
    m_subtitleLabel = new QLabel(I18n::instance().tr(QStringLiteral("loginSubtitle")), formPane);
    m_subtitleLabel->setAlignment(Qt::AlignLeft | Qt::AlignVCenter);
    m_subtitleLabel->setWordWrap(true);
    formLayout->addWidget(m_subtitleLabel);
    m_msgLabel = new QLabel(formPane);
    m_msgLabel->setWordWrap(true);
    m_msgLabel->hide();
    formLayout->addWidget(m_msgLabel);

    auto *loginWidget = new QWidget(formPane);
    auto *loginLayout = new QVBoxLayout(loginWidget);
    loginLayout->setContentsMargins(0, 8, 0, 0);
    loginLayout->setSpacing(8);
    m_loginUserEdit = new QLineEdit(loginWidget);
    m_loginUserEdit->setPlaceholderText(I18n::instance().tr("email"));
    m_loginUserEdit->setObjectName("dialogEdit");
    m_loginUserEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_loginUserEdit->setClearButtonEnabled(true);
    loginLayout->addWidget(m_loginUserEdit);
    m_loginPassEdit = new QLineEdit(loginWidget);
    m_loginPassEdit->setPlaceholderText(I18n::instance().tr("password"));
    m_loginPassEdit->setObjectName("dialogEdit");
    m_loginPassEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_loginPassEdit->setEchoMode(QLineEdit::Password);
    m_loginPassEdit->setClearButtonEnabled(true);
    loginLayout->addWidget(m_loginPassEdit);

    auto *regWidget = new QWidget(formPane);
    auto *regLayout = new QVBoxLayout(regWidget);
    regLayout->setContentsMargins(0, 8, 0, 0);
    regLayout->setSpacing(8);
    m_regUserEdit = new QLineEdit(regWidget);
    m_regUserEdit->setPlaceholderText(I18n::instance().tr("nickname"));
    m_regUserEdit->setObjectName("dialogEdit");
    m_regUserEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    regLayout->addWidget(m_regUserEdit);
    m_regPassEdit = new QLineEdit(regWidget);
    m_regPassEdit->setPlaceholderText(I18n::instance().tr("password"));
    m_regPassEdit->setObjectName("dialogEdit");
    m_regPassEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_regPassEdit->setEchoMode(QLineEdit::Password);
    regLayout->addWidget(m_regPassEdit);
    auto *emailRow = new QHBoxLayout();
    emailRow->setContentsMargins(0, 0, 0, 0);
    emailRow->setSpacing(8);
    m_regEmailEdit = new QLineEdit(regWidget);
    m_regEmailEdit->setPlaceholderText(I18n::instance().tr("email"));
    m_regEmailEdit->setObjectName("dialogEdit");
    m_regEmailEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    emailRow->addWidget(m_regEmailEdit, 1);
    m_sendCodeBtn = new QPushButton(I18n::instance().tr("sendCode"), regWidget);
    m_sendCodeBtn->setObjectName("dialogBtn");
    m_sendCodeBtn->setFixedHeight(AuthDialogChrome::kFieldHeight);
    m_sendCodeBtn->setMinimumWidth(94);
    connect(m_sendCodeBtn, &QPushButton::clicked, this, &LoginDialog::doSendVerificationCode);
    emailRow->addWidget(m_sendCodeBtn);
    regLayout->addLayout(emailRow);
    m_regCodeEdit = new QLineEdit(regWidget);
    m_regCodeEdit->setPlaceholderText(I18n::instance().tr("verificationCode"));
    m_regCodeEdit->setObjectName("dialogEdit");
    m_regCodeEdit->setFixedHeight(AuthDialogChrome::kFieldHeight);
    regLayout->addWidget(m_regCodeEdit);

    m_stack = new QStackedWidget(formPane);
    m_stack->addWidget(loginWidget);
    m_stack->addWidget(regWidget);
    m_stack->setCurrentIndex(0);
    formLayout->addWidget(m_stack);
    auto *actionRow = new QHBoxLayout();
    actionRow->setContentsMargins(0, 6, 0, 0);
    actionRow->setSpacing(10);
    m_switchBtn = new QPushButton(I18n::instance().tr("register"), formPane);
    m_switchBtn->setObjectName("dialogSecondaryBtn");
    m_switchBtn->setFixedHeight(AuthDialogChrome::kPrimaryBtnHeight);
    connect(m_switchBtn, &QPushButton::clicked, this, &LoginDialog::switchMode);
    actionRow->addWidget(m_switchBtn, 1);
    m_submitBtn = new QPushButton(I18n::instance().tr("login"), formPane);
    m_submitBtn->setObjectName("dialogBtn");
    m_submitBtn->setFixedHeight(AuthDialogChrome::kPrimaryBtnHeight);
    connect(m_submitBtn, &QPushButton::clicked, this, [this]() {
        if (m_page == Page::Login) doLogin();
        else if (m_page == Page::Register) doRegister();
    });
    actionRow->addWidget(m_submitBtn, 1);
    formLayout->addLayout(actionRow);

    // 协议勾选：登录/注册前须阅读并同意用户协议与隐私政策
    auto *consentRow = new QHBoxLayout();
    consentRow->setContentsMargins(0, 6, 0, 0);
    consentRow->setSpacing(8);

    m_consentCheck = new QCheckBox(formPane);
    m_consentCheck->setCursor(Qt::PointingHandCursor);
    connect(m_consentCheck, &QCheckBox::toggled, this, [this](bool) { refreshSubmitEnabled(); });
    consentRow->addWidget(m_consentCheck, 0, Qt::AlignTop);

    m_consentText = new QLabel(formPane);
    m_consentText->setTextFormat(Qt::RichText);
    m_consentText->setText(I18n::instance().tr(QStringLiteral("consentLoginText")));
    m_consentText->setWordWrap(true);
    m_consentText->setTextInteractionFlags(Qt::LinksAccessibleByMouse);
    connect(m_consentText, &QLabel::linkActivated, this, [this](const QString &link) {
        if (link == QLatin1String("agreement"))
            LegalDialog::showUserAgreement(this);
        else
            LegalDialog::showPrivacyPolicy(this);
    });
    consentRow->addWidget(m_consentText, 1);
    formLayout->addLayout(consentRow);

    m_forgotBtn = new QPushButton(I18n::instance().tr("forgotPassword"), formPane);
    m_forgotBtn->setObjectName("dialogLinkBtn");
    connect(m_forgotBtn, &QPushButton::clicked, this, &LoginDialog::showForgotPassword);
    formLayout->addWidget(m_forgotBtn, 0, Qt::AlignLeft);
    body->addWidget(formPane, 1);
    mainLayout->addLayout(body, 1);
    outer->addWidget(m_card);

    setTabOrder(m_loginUserEdit, m_loginPassEdit);
    setTabOrder(m_loginPassEdit, m_submitBtn);
    setTabOrder(m_regUserEdit, m_regPassEdit);
    setTabOrder(m_regPassEdit, m_regEmailEdit);
    setTabOrder(m_regEmailEdit, m_regCodeEdit);
    setTabOrder(m_regCodeEdit, m_submitBtn);
    connect(m_loginUserEdit, &QLineEdit::returnPressed, this, &LoginDialog::doLogin);
    connect(m_loginPassEdit, &QLineEdit::returnPressed, this, &LoginDialog::doLogin);
    connect(m_regCodeEdit, &QLineEdit::returnPressed, this, &LoginDialog::doRegister);

    refreshSubmitEnabled();
}

void LoginDialog::applyMode()
{
    const bool qr = (m_page == Page::Qr);

    m_stack->setCurrentIndex(m_page == Page::Register ? 1 : 0);

    m_submitBtn->setVisible(!qr);
    m_forgotBtn->setVisible(m_page == Page::Login);
    m_switchBtn->setVisible(!qr);
    if (m_consentCheck)
        m_consentCheck->setVisible(!qr);
    if (m_consentText)
        m_consentText->setVisible(!qr);
    refreshSubmitEnabled();

    if (m_titleLabel) {
        if (qr)
            m_titleLabel->setText(I18n::instance().tr("qrLoginTitle"));
        else
            m_titleLabel->setText(I18n::instance().tr(m_page == Page::Login ? "login" : "register"));
    }

    if (m_subtitleLabel) {
        if (qr)
            m_subtitleLabel->setText(I18n::instance().tr(QStringLiteral("qrLoginSubtitle")));
        else if (m_page == Page::Register)
            m_subtitleLabel->setText(I18n::instance().tr(QStringLiteral("registerSubtitle")));
        else
            m_subtitleLabel->setText(I18n::instance().tr(QStringLiteral("loginSubtitle")));
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
    m_msgLabel->clear();
    applyMode();
}

void LoginDialog::showQrMode()
{
    m_msgLabel->clear();
    refreshQrSession();
}

void LoginDialog::refreshQrSession()
{
    stopQrSession();

    const int generation = m_qrGeneration;

    m_api->createQrLoginSession(
        [this, generation](bool ok, const QString &message, const ApiClient::QrLoginSession &session) {
            QTimer::singleShot(0, this, [this, generation, ok, message, session]() {
                if (generation != m_qrGeneration)
                    return;

                if (!ok || session.sessionId.isEmpty()) {
                    m_qrImageLabel->clear();
                    return;
                }

                // 纯服务端渲染：只展示后端返回的成品二维码（中心已合成软件图标）
                const QPixmap qr = pixmapFromDataUrl(session.qrImage);
                if (qr.isNull()) {
                    m_qrImageLabel->clear();
                    return;
                }

                m_qrImageLabel->setPixmap(qr.scaled(204, 204, Qt::KeepAspectRatio, Qt::SmoothTransformation));
                startQrWatch(session.sessionId, generation);
            });
        });
}

void LoginDialog::startQrWatch(const QString &sessionId, int generation)
{
    ApiClient::QrLoginSseCallbacks callbacks;

    callbacks.onStatus = [this, generation](const ApiClient::QrLoginStatus &status) {
        QTimer::singleShot(0, this, [this, generation, status]() {
            if (generation != m_qrGeneration)
                return;

            if (status.status == QLatin1String("confirmed")) {
                if (status.token.isEmpty() || status.user.isEmpty()) {
                    m_qrImageLabel->clear();
                    return;
                }
                UserManager::instance().setLoginInfo(status.token, status.user);
                accept();
            } else if (status.status == QLatin1String("expired")) {
                QTimer::singleShot(0, this, [this, generation]() {
                    if (generation == m_qrGeneration)
                        refreshQrSession();
                });
            } else if (status.status == QLatin1String("canceled")) {
                m_qrImageLabel->clear();
            }
        });
    };

    callbacks.onError = [this, generation](const QString &) {
        QTimer::singleShot(0, this, [this, generation]() {
            if (generation != m_qrGeneration)
                return;
            QTimer::singleShot(1500, this, [this, generation]() {
                if (generation == m_qrGeneration)
                    refreshQrSession();
            });
        });
    };

    m_qrReply = m_api->watchQrLoginStatus(sessionId, callbacks);
    if (m_qrReply) {
        QNetworkReply *reply = m_qrReply;
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            if (m_qrReply == reply)
                m_qrReply = nullptr;
        });
    }
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

void LoginDialog::doLogin()
{
    if (!ensureConsent())
        return;

    QString email = m_loginUserEdit->text().trimmed();
    QString password = m_loginPassEdit->text();

    if (email.isEmpty() || password.isEmpty()) {
        setMsg(I18n::instance().tr("fillEmailAndPassword"), Theme::kSakura);
        return;
    }
    if (password.length() > 128) {
        setMsg(I18n::instance().tr(QStringLiteral("passwordTooLong")), Theme::kSakura);
        return;
    }

    setMsg("", Qt::transparent);
    m_loading = true;
    m_submitBtn->setEnabled(false);
    m_submitBtn->setText(I18n::instance().tr(QStringLiteral("loadingShort")));

    m_api->login(email, password, [this](bool success, const QString &message,
                                             const QString &token, const QVariantMap &user) {
        QTimer::singleShot(0, this, [this, success, message, token, user]() {
            onLoginResult(success, message, token, user);
        });
    });
}

void LoginDialog::doRegister()
{
    if (!ensureConsent())
        return;

    QString nickname = m_regUserEdit->text().trimmed();
    QString password = m_regPassEdit->text();
    QString email = m_regEmailEdit->text().trimmed();
    QString code = m_regCodeEdit->text().trimmed();

    if (nickname.isEmpty() || password.isEmpty() || email.isEmpty() || code.isEmpty()) {
        setMsg(I18n::instance().tr("fillAllFields"), Theme::kSakura);
        return;
    }
    if (nickname.length() > 64 || password.length() > 128 || email.length() > 254) {
        setMsg(I18n::instance().tr(QStringLiteral("inputTooLong")), Theme::kSakura);
        return;
    }

    setMsg("", Qt::transparent);
    m_loading = true;
    m_submitBtn->setEnabled(false);
    m_submitBtn->setText(I18n::instance().tr(QStringLiteral("loadingShort")));

    m_api->registerUser(nickname, password, email, code,
                        [this](bool success, const QString &message,
                               const QString &token, const QVariantMap &user) {
        QTimer::singleShot(0, this, [this, success, message, token, user]() {
            onLoginResult(success, message, token, user);
        });
    });
}

void LoginDialog::doSendVerificationCode()
{
    if (!ensureConsent())
        return;

    QString email = m_regEmailEdit->text().trimmed();
    if (email.isEmpty()) {
        setMsg(I18n::instance().tr("pleaseEnterEmail"), Theme::kSakura);
        return;
    }
    const QString nickname = m_regUserEdit->text().trimmed();
    if (nickname.isEmpty()) {
        setMsg(I18n::instance().tr(QStringLiteral("registerNeedNicknameForCode")), Theme::kSakura);
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

    m_api->sendVerificationCode(email, nickname, passToken, [this](bool success, const QString &message) {
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
                    m_sendCodeBtn->setText(I18n::instance().tr(QStringLiteral("countdownSeconds"))
                                                .arg(m_countdown));
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
    m_loading = false;
    refreshSubmitEnabled();
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

bool LoginDialog::ensureConsent()
{
    if (m_consentCheck && m_consentCheck->isChecked())
        return true;
    setMsg(I18n::instance().tr(QStringLiteral("consentRequired")), Theme::kSakura);
    return false;
}

void LoginDialog::refreshSubmitEnabled()
{
    const bool agreed = m_consentCheck ? m_consentCheck->isChecked() : true;
    if (m_submitBtn && !m_loading)
        m_submitBtn->setEnabled(agreed);
    if (m_sendCodeBtn && !m_loading && m_countdown == 0)
        m_sendCodeBtn->setEnabled(agreed);
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
