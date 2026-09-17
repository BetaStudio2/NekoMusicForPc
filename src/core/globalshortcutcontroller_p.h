#pragma once

class InAppFallbackBackend;

struct GlobalShortcutControllerBackendImpl {
    /** Linux portal 后端；其它平台为 nullptr */
    void *portalLinux = nullptr;
    /** Windows RegisterHotKey 后端；其它平台为 nullptr */
    void *winRegister = nullptr;
    InAppFallbackBackend *fallback = nullptr;
};
