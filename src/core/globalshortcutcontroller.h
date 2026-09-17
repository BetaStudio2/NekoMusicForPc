#pragma once

#include <QObject>

class QWindow;
class QWidget;
class QTimer;
class AppShortcuts;

/** 全局播放快捷键：Windows 走 RegisterHotKey，Wayland 走 xdg-desktop-portal GlobalShortcuts。 */
class GlobalShortcutController final : public QObject
{
    Q_OBJECT

public:
    enum class Backend {
        None,
        Portal,
        WinRegister,
        X11Grab,
        InAppFallback
    };
    Q_ENUM(Backend)

    static GlobalShortcutController &instance();

    void setHostWindow(QWindow *window);
    void installFallback(QWidget *parentWidget);
    void start(bool requestConfigureUi = false);
    void rebind(bool requestSystemPermission = false);
    /** 设置页修改快捷键：Wayland 下防抖后重建 portal 会话并弹出授权 UI */
    void scheduleRebindAfterSettingsChange();
    void stop();
    void openSystemConfigureUi();

    /** 供平台胶水层调用 */
    void prepareHostWindowForPortal();
    void activateBackend(Backend backend, bool active);
    void tryFallbackAfterPortalFailure(const QString &reason);
    void tryFallbackAfterWinFailure(const QString &reason);
    /** 平台后端部分注册失败：仅上报，不改变当前后端 */
    void notifyBindingFailure(const QString &reason);
    void dispatchAction(const QString &portalId);
    void reportPortalConfigureFailed(const QString &reason);

    Backend activeBackend() const { return m_backend; }
    bool isActive() const { return m_active; }
    QString statusText() const;

signals:
    void playPauseTriggered();
    void nextTrackTriggered();
    void previousTrackTriggered();
    void micSyncTriggered();
    void bindingStateChanged(bool active, Backend backend);
    void bindingFailed(const QString &reason);

private:
    explicit GlobalShortcutController(QObject *parent = nullptr);
    bool installInAppFallback();
    void performSettingsRebind();

    QWindow *m_hostWindow = nullptr;
    Backend m_backend = Backend::None;
    bool m_active = false;
    QTimer *m_settingsRebindTimer = nullptr;

    struct BackendImpl;
    BackendImpl *m_impl = nullptr;
};
