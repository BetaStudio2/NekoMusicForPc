#include "globalshortcutcontroller_win.h"

#include "appshortcuts.h"
#include "globalshortcutcontroller.h"
#include "globalshortcutcontroller_p.h"
#include "core/i18n.h"

#include <QAbstractNativeEventFilter>
#include <QCoreApplication>
#include <QHash>
#include <QKeyCombination>
#include <QKeySequence>
#include <QStringList>

#include <windows.h>

namespace {

// 应用自定义热键 ID 必须落在 0x0000–0xBFFF 区间
constexpr int kHotkeyIdBase = 0x4E00;

int win32Modifiers(Qt::KeyboardModifiers modifiers)
{
    int result = 0;
    if (modifiers & Qt::ControlModifier)
        result |= MOD_CONTROL;
    if (modifiers & Qt::AltModifier)
        result |= MOD_ALT;
    if (modifiers & Qt::ShiftModifier)
        result |= MOD_SHIFT;
    if (modifiers & Qt::MetaModifier)
        result |= MOD_WIN;
#ifdef MOD_NOREPEAT
    result |= MOD_NOREPEAT;
#endif
    return result;
}

int virtualKeyFromQtKey(int key)
{
    // A–Z / 0–9 与 Win32 虚拟键码数值一致，可直接映射
    if ((key >= Qt::Key_A && key <= Qt::Key_Z) || (key >= Qt::Key_0 && key <= Qt::Key_9))
        return key;
    // F1–F24 在 Qt 里是连续段，Win32 侧 VK_F1 起同样连续
    if (key >= Qt::Key_F1 && key <= Qt::Key_F24)
        return VK_F1 + (key - Qt::Key_F1);

    switch (key) {
    case Qt::Key_Space:
        return VK_SPACE;
    case Qt::Key_Return:
    case Qt::Key_Enter:
        return VK_RETURN;
    case Qt::Key_Escape:
        return VK_ESCAPE;
    case Qt::Key_Tab:
        return VK_TAB;
    case Qt::Key_Backspace:
        return VK_BACK;
    case Qt::Key_Insert:
        return VK_INSERT;
    case Qt::Key_Delete:
        return VK_DELETE;
    case Qt::Key_Home:
        return VK_HOME;
    case Qt::Key_End:
        return VK_END;
    case Qt::Key_PageUp:
        return VK_PRIOR;
    case Qt::Key_PageDown:
        return VK_NEXT;
    case Qt::Key_Left:
        return VK_LEFT;
    case Qt::Key_Right:
        return VK_RIGHT;
    case Qt::Key_Up:
        return VK_UP;
    case Qt::Key_Down:
        return VK_DOWN;
    case Qt::Key_Comma:
        return VK_OEM_COMMA;
    case Qt::Key_Period:
        return VK_OEM_PERIOD;
    case Qt::Key_Minus:
        return VK_OEM_MINUS;
    case Qt::Key_Equal:
        return VK_OEM_PLUS;
    case Qt::Key_Semicolon:
        return VK_OEM_1;
    case Qt::Key_Apostrophe:
        return VK_OEM_7;
    case Qt::Key_BracketLeft:
        return VK_OEM_4;
    case Qt::Key_BracketRight:
        return VK_OEM_6;
    case Qt::Key_Backslash:
        return VK_OEM_5;
    case Qt::Key_Slash:
        return VK_OEM_2;
    case Qt::Key_QuoteLeft:
        return VK_OEM_3;
    case Qt::Key_MediaPlay:
        return VK_MEDIA_PLAY_PAUSE;
    case Qt::Key_MediaNext:
        return VK_MEDIA_NEXT_TRACK;
    case Qt::Key_MediaPrevious:
        return VK_MEDIA_PREV_TRACK;
    case Qt::Key_MediaStop:
        return VK_MEDIA_STOP;
    case Qt::Key_VolumeUp:
        return VK_VOLUME_UP;
    case Qt::Key_VolumeDown:
        return VK_VOLUME_DOWN;
    case Qt::Key_VolumeMute:
        return VK_VOLUME_MUTE;
    default:
        break;
    }
    return 0;
}

/** RegisterHotKey + WM_HOTKEY 后端；无窗口热键消息走 windows_dispatcher_MSG */
class GlobalShortcutWinBackend final : public QAbstractNativeEventFilter
{
public:
    explicit GlobalShortcutWinBackend(GlobalShortcutController *controller)
        : m_controller(controller)
    {
    }

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *) override
    {
        if (!m_controller)
            return false;
        if (eventType != QByteArrayLiteral("windows_generic_MSG")
            && eventType != QByteArrayLiteral("windows_dispatcher_MSG"))
            return false;

        auto *msg = static_cast<MSG *>(message);
        if (msg->message != WM_HOTKEY)
            return false;
        const auto it = m_idToPortalId.constFind(static_cast<int>(msg->wParam));
        if (it == m_idToPortalId.constEnd())
            return false;

        m_controller->dispatchAction(it.value());
        return true;
    }

    void installFilter()
    {
        if (m_filterInstalled)
            return;
        if (QCoreApplication *app = QCoreApplication::instance()) {
            app->installNativeEventFilter(this);
            m_filterInstalled = true;
        }
    }

    void removeFilter()
    {
        if (!m_filterInstalled)
            return;
        if (QCoreApplication *app = QCoreApplication::instance())
            app->removeNativeEventFilter(this);
        m_filterInstalled = false;
    }

    /** 注册全部快捷键，返回失败的组合（含被其它程序占用、无法映射） */
    QStringList bind()
    {
        unbind();

        QStringList failed;
        const AppShortcuts &app = AppShortcuts::instance();
        for (int i = 0; i < AppShortcuts::ActionCount; ++i) {
            const auto action = static_cast<AppShortcuts::Action>(i);
            const QKeySequence sequence = app.sequence(action);
            if (sequence.isEmpty())
                continue;

            const QKeyCombination combination = sequence[0];
            const int virtualKey = virtualKeyFromQtKey(combination.key());
            const int id = kHotkeyIdBase + i;
            if (virtualKey == 0
                || !::RegisterHotKey(nullptr, id,
                                     static_cast<UINT>(win32Modifiers(combination.keyboardModifiers())),
                                     static_cast<UINT>(virtualKey))) {
                failed << sequence.toString(QKeySequence::NativeText);
                continue;
            }
            m_registeredIds.append(id);
            m_idToPortalId.insert(id, AppShortcuts::portalShortcutId(action));
        }
        return failed;
    }

    void unbind()
    {
        for (int id : m_registeredIds)
            ::UnregisterHotKey(nullptr, id);
        m_registeredIds.clear();
        m_idToPortalId.clear();
    }

    int registeredCount() const { return static_cast<int>(m_registeredIds.size()); }

private:
    GlobalShortcutController *m_controller = nullptr;
    QList<int> m_registeredIds;
    QHash<int, QString> m_idToPortalId;
    bool m_filterInstalled = false;
};

} // namespace

void nekoGlobalShortcutWinInit(GlobalShortcutControllerBackendImpl *impl,
                               GlobalShortcutController *controller)
{
    if (!impl || !controller || impl->winRegister)
        return;
    impl->winRegister = new GlobalShortcutWinBackend(controller);
}

bool nekoGlobalShortcutWinStart(GlobalShortcutControllerBackendImpl *impl,
                                GlobalShortcutController *controller)
{
    if (!impl || !impl->winRegister || !controller)
        return false;

    auto *backend = static_cast<GlobalShortcutWinBackend *>(impl->winRegister);
    backend->installFilter();
    const QStringList failed = backend->bind();

    if (failed.isEmpty()) {
        controller->activateBackend(GlobalShortcutController::Backend::WinRegister, true);
        return true;
    }

    const QString failedText = failed.join(QStringLiteral(", "));
    if (backend->registeredCount() > 0) {
        controller->activateBackend(GlobalShortcutController::Backend::WinRegister, true);
        controller->notifyBindingFailure(
            I18n::instance().tr(QStringLiteral("shortcutGlobalWinPartialFailed")).arg(failedText));
        return true;
    }

    controller->tryFallbackAfterWinFailure(failedText);
    backend->removeFilter();
    return true;
}

void nekoGlobalShortcutWinStop(GlobalShortcutControllerBackendImpl *impl)
{
    if (!impl || !impl->winRegister)
        return;
    auto *backend = static_cast<GlobalShortcutWinBackend *>(impl->winRegister);
    backend->unbind();
    backend->removeFilter();
}
