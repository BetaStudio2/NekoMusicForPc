#include "micsynccontroller.h"

#include "core/i18n.h"

#include <QCoreApplication>

/** 平台后端：Linux 为 pactl，其它平台为 stub。 */
bool nekoMicSyncBackendAvailable();
bool nekoMicSyncBackendStart(QString *error);
void nekoMicSyncBackendStop();

MicSyncController &MicSyncController::instance()
{
    static MicSyncController inst;
    return inst;
}

MicSyncController::MicSyncController(QObject *parent)
    : QObject(parent)
{
    if (QCoreApplication *app = QCoreApplication::instance()) {
        connect(app, &QCoreApplication::aboutToQuit, this, [this]() {
            if (m_enabled) {
                nekoMicSyncBackendStop();
                m_enabled = false;
            }
        });
    }
}

MicSyncController::~MicSyncController()
{
    if (m_enabled)
        nekoMicSyncBackendStop();
}

bool MicSyncController::isSupported()
{
    return nekoMicSyncBackendAvailable();
}

QString MicSyncController::deviceName()
{
    return QStringLiteral("NekoMusicMic");
}

void MicSyncController::setEnabled(bool enabled)
{
    if (enabled == m_enabled)
        return;

    if (enabled) {
        QString error;
        if (!nekoMicSyncBackendStart(&error)) {
            emit failed(error.isEmpty()
                            ? I18n::instance().tr(QStringLiteral("micSyncFailed")).arg(deviceName())
                            : error);
            return;
        }
    } else {
        nekoMicSyncBackendStop();
    }

    m_enabled = enabled;
    emit enabledChanged(enabled);
}

void MicSyncController::toggle()
{
    if (!m_enabled && !isSupported()) {
        emit failed(I18n::instance().tr(QStringLiteral("micSyncUnsupported")));
        return;
    }
    setEnabled(!m_enabled);
}
