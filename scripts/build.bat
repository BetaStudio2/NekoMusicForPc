@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem  NekoMusic (Flutter) Windows one-shot build script
rem  Usage: scripts\build.bat [debug^|release]   (default debug)
rem
rem  Prereqs:
rem    - Flutter SDK 3.47+ (NEKO_FLUTTER env or on PATH)
rem    - CMake + Ninja
rem    - Qt6 (Core/Network/Sql/Gui, find_package(Qt6))
rem    - libmpv dev package (set MPV_DIR to its root)
rem  Note: keep this file ASCII-only + CRLF so cmd parses it cleanly.
rem ============================================================
set "MODE=%~1"
if "%MODE%"=="" set "MODE=debug"
if /I not "%MODE%"=="debug" if /I not "%MODE%"=="release" (
    echo Usage: %~nx0 [debug^|release]
    exit /b 1
)

set "ROOT_DIR=%~dp0.."
set "FLUTTER_DIR=%ROOT_DIR%\flutter"

rem --- Flutter SDK resolution (NEKO_FLUTTER -> PATH) ---
set "FLUTTER_BIN=%NEKO_FLUTTER%"
if "%FLUTTER_BIN%"=="" (
    where flutter >nul 2>nul && set "FLUTTER_BIN=flutter"
)
if "%FLUTTER_BIN%"=="" (
    echo ERROR: Flutter SDK not found. Set NEKO_FLUTTER to its bin/flutter.
    exit /b 1
)
echo == Flutter SDK: %FLUTTER_BIN%

where cmake >nul 2>nul || (echo ERROR: cmake missing & exit /b 1)
where ninja >nul 2>nul || (echo ERROR: ninja missing & exit /b 1)
if "%MPV_DIR%"=="" echo WARN: MPV_DIR unset (libmpv dev root) - engine config may fail

rem --- 1. Prebuild engine (neko_engine + neko_core) ---
rem Wipe old config to avoid cross-toolchain (mingw/MSVC) leftovers.
if exist "%ROOT_DIR%\engine\build" rmdir /s /q "%ROOT_DIR%\engine\build"
echo == Building C engine...
rem Must run inside an MSVC dev shell (vcvars64 / ilammy/msvc-dev-cmd);
rem libmpv must provide an MSVC import lib: lib\mpv.lib under MPV_DIR.
cmake -S "%ROOT_DIR%\engine" -B "%ROOT_DIR%\engine\build" -DCMAKE_BUILD_TYPE=%MODE% -G Ninja
if errorlevel 1 exit /b 1
cmake --build "%ROOT_DIR%\engine\build" --config %MODE% --target neko_engine neko_core --parallel
if errorlevel 1 exit /b 1

rem --- 2. Flutter app build ---
echo == Flutter build (%MODE%)...
pushd "%FLUTTER_DIR%"
rem Keep the FULL custom icon glyph set: disable icon tree-shaking
rem (tree-shaking subsets the font and drops custom glyphs).
flutter build windows --%MODE% --no-tree-shake-icons
if errorlevel 1 (popd & exit /b 1)
popd

echo.
echo == Done: %FLUTTER_DIR%\build\windows\x64\runner\%MODE%\
endlocal
