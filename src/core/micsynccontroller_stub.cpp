#include "micsynccontroller.h"

bool nekoMicSyncBackendAvailable()
{
    return false;
}

bool nekoMicSyncBackendStart(QString *error)
{
    if (error)
        *error = QStringLiteral("当前平台暂不支持麦克风同步");
    return false;
}

void nekoMicSyncBackendStop()
{
}
