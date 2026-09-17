#pragma once

/**
 * @file settingspage.h
 * @brief 设置页面
 */

#include <QWidget>
#include "core/appshortcuts.h"
#include "theme/thememanager.h"

class QComboBox;
class QLabel;
class QPushButton;
class QResizeEvent;
class QScrollArea;
class QStackedWidget;
class QVBoxLayout;
class QWidget;
class ShortcutCaptureButton;
class ToggleSwitch;

class SettingsPage : public QWidget
{
    Q_OBJECT

public:
    explicit SettingsPage(QWidget *parent = nullptr);

signals:
    void languageChanged(int language);
    void checkForUpdatesRequested();

protected:
    void paintEvent(QPaintEvent *) override;
    void resizeEvent(QResizeEvent *event) override;

private:
    void setupUi();
    void retranslate();
    QWidget *createSettingsCard(QWidget *parent, QVBoxLayout **layoutOut = nullptr);
    QPushButton *createTabButton(const QString &text, const char *iconName, QWidget *parent);
    void setActiveSettingsTab(int index);
    void updateTabBarGeometry();
    void setupShortcutRow(QVBoxLayout *parentLayout, QWidget *cardBody, AppShortcuts::Action action,
                          QLabel **labelOut, ShortcutCaptureButton **captureOut, QPushButton **resetOut);
    void applyShortcutChange(AppShortcuts::Action action, const QKeySequence &seq,
                             ShortcutCaptureButton *editor);
    void refreshShortcutEditors();
    void refreshMicSyncRow();
    void setupPersonalizationSection(QVBoxLayout *cardLay, QWidget *cardBody);
    void updateBackdropOptionRows();
    void refreshBackdropPathLabel();
    void refreshBackdropColorSwatch();

    QComboBox *m_langCombo = nullptr;
    QComboBox *m_themeCombo = nullptr;
    QPushButton *m_generalTabBtn = nullptr;
    QPushButton *m_appearanceTabBtn = nullptr;
    QPushButton *m_shortcutsTabBtn = nullptr;
    QPushButton *m_aboutTabBtn = nullptr;
    QScrollArea *m_scrollArea = nullptr;
    QStackedWidget *m_settingsStack = nullptr;
    QWidget *m_tabBarWidget = nullptr;
    QLabel *m_titleLabel = nullptr;
    QLabel *m_descLabel = nullptr;
    QLabel *m_themeLabel = nullptr;
    QLabel *m_personalizeSectionLabel = nullptr;
    QLabel *m_backdropKindLabel = nullptr;
    QComboBox *m_backdropKindCombo = nullptr;
    QWidget *m_backdropImageRow = nullptr;
    QPushButton *m_backdropPickImageBtn = nullptr;
    QPushButton *m_backdropResetImageBtn = nullptr;
    QLabel *m_backdropPathLabel = nullptr;
    QWidget *m_backdropSolidRow = nullptr;
    QPushButton *m_backdropPickColorBtn = nullptr;
    QLabel *m_backdropColorSwatch = nullptr;
    QLabel *m_langLabel = nullptr;
    QLabel *m_micSyncSectionLabel = nullptr;
    QLabel *m_micSyncEnableLabel = nullptr;
    ToggleSwitch *m_micSyncToggle = nullptr;
    QLabel *m_micSyncHintLabel = nullptr;
    QLabel *m_shortcutsSectionLabel = nullptr;
    QLabel *m_shortcutPlayPauseLabel = nullptr;
    QLabel *m_shortcutPrevLabel = nullptr;
    QLabel *m_shortcutNextLabel = nullptr;
    QLabel *m_shortcutMicSyncLabel = nullptr;
    ShortcutCaptureButton *m_shortcutPlayPauseBtn = nullptr;
    ShortcutCaptureButton *m_shortcutPrevBtn = nullptr;
    ShortcutCaptureButton *m_shortcutNextBtn = nullptr;
    ShortcutCaptureButton *m_shortcutMicSyncBtn = nullptr;
    QPushButton *m_shortcutResetAllBtn = nullptr;
    QPushButton *m_shortcutResetPlayPauseBtn = nullptr;
    QPushButton *m_shortcutResetPrevBtn = nullptr;
    QPushButton *m_shortcutResetNextBtn = nullptr;
    QPushButton *m_shortcutResetMicSyncBtn = nullptr;
    QLabel *m_aboutLabel = nullptr;
    QLabel *m_versionLabel = nullptr;
    QLabel *m_systemLabel = nullptr;
    QPushButton *m_githubBtn = nullptr;
    QPushButton *m_apiDocsBtn = nullptr;
    QPushButton *m_checkUpdateBtn = nullptr;
};
