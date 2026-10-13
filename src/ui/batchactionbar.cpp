/**
 * @file batchactionbar.cpp
 * @brief 单曲列表批量编辑模式的操作条
 */

#include "batchactionbar.h"

#include "core/i18n.h"
#include "theme/theme.h"
#include "theme/thememanager.h"
#include "ui/svgicon.h"

#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>

BatchActionBar::BatchActionBar(QWidget *parent)
    : QWidget(parent)
{
    setObjectName(QStringLiteral("batchActionBar"));
    setFixedHeight(40);

    auto *lay = new QHBoxLayout(this);
    lay->setContentsMargins(0, 0, 0, 0);
    lay->setSpacing(12);

    m_countLbl = new QLabel(this);
    m_countLbl->setObjectName(QStringLiteral("batchCountLabel"));
    m_countLbl->setMinimumWidth(96);
    lay->addWidget(m_countLbl);

    m_selectAllBtn = makeActionButton("PlaylistAddCheck", "batchSelectAll");
    connect(m_selectAllBtn, &QPushButton::clicked, this, &BatchActionBar::selectAllToggled);
    lay->addWidget(m_selectAllBtn);

    m_addToPlaylistBtn = makeActionButton("PlaylistAdd", "batchAddToPlaylist");
    connect(m_addToPlaylistBtn, &QPushButton::clicked, this, &BatchActionBar::addToPlaylistRequested);
    lay->addWidget(m_addToPlaylistBtn);

    m_addToQueueBtn = makeActionButton("MusicList", "batchAddToQueue");
    connect(m_addToQueueBtn, &QPushButton::clicked, this, &BatchActionBar::addToQueueRequested);
    lay->addWidget(m_addToQueueBtn);

    m_downloadBtn = makeActionButton("Download", "batchDownload");
    connect(m_downloadBtn, &QPushButton::clicked, this, &BatchActionBar::downloadRequested);
    lay->addWidget(m_downloadBtn);

    m_unfavoriteBtn = makeActionButton("HeartBroken", "batchUnfavorite");
    connect(m_unfavoriteBtn, &QPushButton::clicked, this, &BatchActionBar::unfavoriteRequested);
    lay->addWidget(m_unfavoriteBtn);

    m_removeFromPlaylistBtn = makeActionButton("Delete", "batchRemoveFromPlaylist");
    connect(m_removeFromPlaylistBtn, &QPushButton::clicked, this,
            &BatchActionBar::removeFromPlaylistRequested);
    lay->addWidget(m_removeFromPlaylistBtn);

    lay->addStretch();

    m_exitBtn = makeActionButton("Close", "batchExit");
    connect(m_exitBtn, &QPushButton::clicked, this, &BatchActionBar::exitRequested);
    lay->addWidget(m_exitBtn);

    setCapabilities(false, true, true, false, false);
    retranslate();
    applyTheme();
}

QPushButton *BatchActionBar::makeActionButton(const char *iconName, const char *textKey)
{
    auto *btn = new QPushButton(this);
    btn->setCursor(Qt::PointingHandCursor);
    btn->setFixedHeight(40);
    btn->setProperty("batchIcon", QString::fromUtf8(iconName));
    btn->setProperty("batchTextKey", QString::fromUtf8(textKey));
    return btn;
}

void BatchActionBar::setCapabilities(bool canAddToPlaylist, bool canAddToQueue, bool canDownload,
                                     bool canUnfavorite, bool canRemoveFromPlaylist)
{
    if (m_addToPlaylistBtn)
        m_addToPlaylistBtn->setVisible(canAddToPlaylist);
    if (m_addToQueueBtn)
        m_addToQueueBtn->setVisible(canAddToQueue);
    if (m_downloadBtn)
        m_downloadBtn->setVisible(canDownload);
    if (m_unfavoriteBtn)
        m_unfavoriteBtn->setVisible(canUnfavorite);
    if (m_removeFromPlaylistBtn)
        m_removeFromPlaylistBtn->setVisible(canRemoveFromPlaylist);
    setSelectedCount(m_selectedCount);
}

void BatchActionBar::setActionText(const char *actionKey, const QString &text)
{
    const QString key = QString::fromUtf8(actionKey);
    m_textOverrides.insert(key, text);
    for (QPushButton *btn : {m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn, m_unfavoriteBtn,
                             m_removeFromPlaylistBtn}) {
        if (btn && btn->property("batchTextKey").toString() == key) {
            btn->setText(text);
            return;
        }
    }
}

void BatchActionBar::setSelectedCount(int count)
{
    m_selectedCount = qMax(0, count);
    if (m_countLbl) {
        m_countLbl->setText(
            I18n::instance().tr(QStringLiteral("batchSelected")).arg(m_selectedCount));
    }

    const bool hasSelection = m_selectedCount > 0;
    for (QPushButton *btn : {m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn, m_unfavoriteBtn,
                             m_removeFromPlaylistBtn}) {
        if (btn)
            btn->setEnabled(hasSelection);
    }
}

void BatchActionBar::setAllSelected(bool allSelected)
{
    if (m_allSelected == allSelected)
        return;
    m_allSelected = allSelected;
    retranslate();
}

void BatchActionBar::retranslate()
{
    auto &i18n = I18n::instance();
    if (m_countLbl) {
        m_countLbl->setText(i18n.tr(QStringLiteral("batchSelected")).arg(m_selectedCount));
    }
    if (m_selectAllBtn) {
        m_selectAllBtn->setText(i18n.tr(m_allSelected ? QStringLiteral("batchCancelSelectAll")
                                                      : QStringLiteral("batchSelectAll")));
    }

    for (QPushButton *btn : {m_selectAllBtn, m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn,
                             m_unfavoriteBtn, m_removeFromPlaylistBtn, m_exitBtn}) {
        if (!btn)
            continue;
        const QString key = btn->property("batchTextKey").toString();
        if (key.isEmpty())
            continue;
        // 调用方给过覆盖文案的（如队列抽屉的「移出播放队列」）优先
        const auto overridden = m_textOverrides.constFind(key);
        btn->setText(overridden != m_textOverrides.constEnd() ? overridden.value() : i18n.tr(key));
    }
}

void BatchActionBar::applyTheme()
{
    const bool dark = Theme::ThemeManager::instance().isDarkMode();
    const QString titleFg = dark ? QString::fromUtf8(Theme::kTextMain) : QStringLiteral("#212529");

    const QString secondaryBg = dark ? QStringLiteral("#2a2a2a") : QStringLiteral("#f0f0f0");
    const QString secondaryFg = dark ? QString::fromUtf8(Theme::kTextMain) : QStringLiteral("#212529");
    const QColor secondaryIc = dark ? QColor(244, 246, 255, 200) : QColor(33, 37, 41, 200);
    const QColor primaryIc = dark ? QColor(255, 255, 255) : QColor(255, 255, 255);

    if (m_countLbl) {
        m_countLbl->setStyleSheet(QStringLiteral(
            "QLabel { font-size: 14px; font-weight: 600; color: %1; }").arg(titleFg));
    }

    // 与页面原有按钮排保持同一套胶囊样式：主操作（加入歌单）用品牌色，其余用次级底色
    const QString primaryStyle = QStringLiteral(
        "QPushButton {"
        "  background: #D84B63;"
        "  color: #ffffff;"
        "  border: none;"
        "  border-radius: 20px;"
        "  font-size: 14px;"
        "  font-weight: 500;"
        "  padding: 0 20px;"
        "}"
        "QPushButton:hover { background: #ff5070; }"
        "QPushButton:disabled { background: rgba(230,57,80,0.35); color: rgba(255,255,255,0.6); }");

    const QString secondaryStyle = QStringLiteral(
        "QPushButton {"
        "  background: %1;"
        "  color: %2;"
        "  border: none;"
        "  border-radius: 20px;"
        "  font-size: 14px;"
        "  font-weight: 500;"
        "  padding: 0 20px;"
        "}"
        "QPushButton:hover:enabled { background: rgba(230,57,80,0.15); }"
        "QPushButton:disabled { color: rgba(128,128,128,0.8); }")
                                        .arg(secondaryBg, secondaryFg);

    for (QPushButton *btn : {m_selectAllBtn, m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn,
                             m_unfavoriteBtn, m_removeFromPlaylistBtn, m_exitBtn}) {
        if (!btn)
            continue;
        const bool primary = (btn == m_addToPlaylistBtn);
        btn->setStyleSheet(primary ? primaryStyle : secondaryStyle);
        btn->setIcon(Icons::renderNamed(btn->property("batchIcon").toString().toUtf8().constData(), 18,
                                        primary ? primaryIc : secondaryIc));
        btn->setIconSize(QSize(18, 18));
    }
}
