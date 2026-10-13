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

namespace {

/** 拆掉旧布局但不动其中的 widget（QHBoxLayout 只 QLayoutItem::takeAt 不会删 widget）。 */
void dropLayout(QLayout *lay)
{
    if (!lay)
        return;
    while (QLayoutItem *item = lay->takeAt(0))
        delete item;
    delete lay;
}

} // namespace

void BatchActionBar::setCompactTrigger(bool compact)
{
    if (m_compactTrigger == compact)
        return;
    m_compactTrigger = compact;

    // 先把所有控件从旧布局摘下来（removeWidget 不删控件），再换布局重新排
    for (QPushButton *btn : {m_selectAllBtn, m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn,
                             m_unfavoriteBtn, m_removeFromPlaylistBtn, m_exitBtn}) {
        if (btn && layout())
            layout()->removeWidget(btn);
    }
    if (m_countLbl && layout())
        layout()->removeWidget(m_countLbl);
    if (m_actionRow && layout())
        layout()->removeWidget(m_actionRow);

    dropLayout(layout());

    if (compact) {
        // 横向动作按钮全部收起，只留「已选 N 首」计数 + 「批量操作 ▾」触发按钮
        for (QPushButton *btn : {m_selectAllBtn, m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn,
                                 m_unfavoriteBtn, m_removeFromPlaylistBtn, m_exitBtn}) {
            if (btn)
                btn->hide();
        }

        m_actionRow = new QWidget(this);
        auto *row = new QHBoxLayout(m_actionRow);
        row->setContentsMargins(0, 0, 0, 0);
        row->setSpacing(10);

        m_countLbl->setParent(m_actionRow);
        m_countLbl->setMinimumWidth(0);
        row->addWidget(m_countLbl);

        m_triggerBtn = makeActionButton("Menu", "batchActions");
        m_triggerBtn->setFixedHeight(32);
        connect(m_triggerBtn, &QPushButton::clicked, this, &BatchActionBar::actionsRequested);
        row->addWidget(m_triggerBtn);
        row->addStretch();

        auto *lay = new QHBoxLayout(this);
        lay->setContentsMargins(0, 0, 0, 0);
        lay->setSpacing(0);
        lay->addWidget(m_actionRow);
        lay->addStretch();
    } else {
        if (m_triggerBtn) {
            m_triggerBtn->hide();
            m_triggerBtn->deleteLater();
            m_triggerBtn = nullptr;
        }
        if (m_actionRow) {
            m_actionRow->hide();
            m_actionRow->deleteLater();
            m_actionRow = nullptr;
        }

        auto *lay = new QHBoxLayout(this);
        lay->setContentsMargins(0, 0, 0, 0);
        lay->setSpacing(12);
        m_countLbl->setParent(this);
        m_countLbl->setMinimumWidth(96);
        lay->addWidget(m_countLbl);
        for (QPushButton *btn : {m_selectAllBtn, m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn,
                                 m_unfavoriteBtn, m_removeFromPlaylistBtn}) {
            if (btn) {
                btn->setParent(this);
                lay->addWidget(btn);
                btn->show();
            }
        }
        lay->addStretch();
        if (m_exitBtn) {
            m_exitBtn->setParent(this);
            lay->addWidget(m_exitBtn);
            m_exitBtn->show();
        }
    }

    retranslate();
    applyTheme();
}

void BatchActionBar::setSelectedCount(int count)
{
    m_selectedCount = qMax(0, count);
    updateCountLabels();

    const bool hasSelection = m_selectedCount > 0;
    for (QPushButton *btn : {m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn, m_unfavoriteBtn,
                             m_removeFromPlaylistBtn}) {
        if (btn)
            btn->setEnabled(hasSelection);
    }
}

/**
 * 「已选 N 首」的两处显示：横排的计数标签 + 紧凑模式的「批量操作 (N) ▾」触发按钮。
 * 必须由 setSelectedCount() 直接驱动——只靠 retranslate() 会漏掉 0→1 的变化
 * （setAllSelected() 状态没变就 return，走不到 retranslate）。
 */
void BatchActionBar::updateCountLabels()
{
    auto &i18n = I18n::instance();
    if (m_countLbl) {
        m_countLbl->setText(i18n.tr(QStringLiteral("batchSelected")).arg(m_selectedCount));
    }
    if (m_triggerBtn && m_compactTrigger) {
        m_triggerBtn->setText(i18n.tr(QStringLiteral("batchActionsCount")).arg(m_selectedCount));
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
    if (m_selectAllBtn) {
        m_selectAllBtn->setText(i18n.tr(m_allSelected ? QStringLiteral("batchCancelSelectAll")
                                                      : QStringLiteral("batchSelectAll")));
    }

    for (QPushButton *btn : {m_selectAllBtn, m_addToPlaylistBtn, m_addToQueueBtn, m_downloadBtn,
                             m_unfavoriteBtn, m_removeFromPlaylistBtn, m_exitBtn, m_triggerBtn}) {
        if (!btn)
            continue;
        const QString key = btn->property("batchTextKey").toString();
        if (key.isEmpty())
            continue;
        // 调用方给过覆盖文案的（如队列抽屉的「移出播放队列」）优先
        const auto overridden = m_textOverrides.constFind(key);
        btn->setText(overridden != m_textOverrides.constEnd() ? overridden.value() : i18n.tr(key));
    }

    updateCountLabels();
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

    // 紧凑模式的触发按钮：窄抽屉里的次级胶囊（文案长，不能再用 20px 大内边距）
    if (m_triggerBtn) {
        m_triggerBtn->setStyleSheet(QStringLiteral(
            "QPushButton {"
            "  background: %1;"
            "  color: %2;"
            "  border: none;"
            "  border-radius: 16px;"
            "  font-size: 13px;"
            "  font-weight: 500;"
            "  padding: 0 14px;"
            "}"
            "QPushButton:hover { background: rgba(230,57,80,0.15); }")
                                        .arg(secondaryBg, secondaryFg));
        m_triggerBtn->setIcon(Icons::renderNamed("Menu", 16, secondaryIc));
        m_triggerBtn->setIconSize(QSize(16, 16));
    }
}
