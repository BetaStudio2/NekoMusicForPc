#pragma once

class GlobalShortcutController;
struct GlobalShortcutControllerBackendImpl;

void nekoGlobalShortcutWinInit(GlobalShortcutControllerBackendImpl *impl,
                               GlobalShortcutController *controller);
bool nekoGlobalShortcutWinStart(GlobalShortcutControllerBackendImpl *impl,
                                GlobalShortcutController *controller);
void nekoGlobalShortcutWinStop(GlobalShortcutControllerBackendImpl *impl);
