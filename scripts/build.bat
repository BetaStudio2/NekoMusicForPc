@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem  Neko歌姬计划（Flutter 版）Windows 一键构建
rem  用法:  scripts\build.bat [debug^|release]   （默认 debug）
rem
rem  依赖:
rem    - Flutter SDK 3.47+（NEKO_FLUTTER 环境变量或 PATH 中）
rem    - CMake + Ninja
rem    - Qt6（Core/Network/Sql/Gui，CMake 能 find_package(Qt6)）
rem    - libmpv 开发包（设置 MPV_DIR 指向开发包根目录）
rem  说明: 编译逻辑与本脚本保持一致，CI 仅调用本脚本。
rem ============================================================
set "MODE=%~1"
if "%MODE%"=="" set "MODE=debug"
if /I not "%MODE%"=="debug" if /I not "%MODE%"=="release" (
    echo 用法: %~nx0 [debug^|release]
    exit /b 1
)

set "ROOT_DIR=%~dp0.."
set "FLUTTER_DIR=%ROOT_DIR%\flutter"

rem ── Flutter SDK 解析（NEKO_FLUTTER → PATH）──
set "FLUTTER_BIN=%NEKO_FLUTTER%"
if "%FLUTTER_BIN%"=="" (
    where flutter >nul 2>nul && set "FLUTTER_BIN=flutter"
)
if "%FLUTTER_BIN%"=="" (
    echo 错误: 未找到 Flutter SDK，可设置 NEKO_FLUTTER 指定路径
    exit /b 1
)
echo == Flutter SDK: %FLUTTER_BIN%

where cmake >nul 2>nul || (echo 错误: 缺少 cmake & exit /b 1)
where ninja >nul 2>nul || (echo 错误: 缺少 ninja & exit /b 1)
if "%MPV_DIR%"=="" echo 警告: 未设置 MPV_DIR（libmpv 开发包根目录），引擎配置可能失败

rem ── 1. 预构建引擎（neko_engine + neko_core）──
echo == 构建 C 引擎...
cmake -S "%ROOT_DIR%\engine" -B "%ROOT_DIR%\engine\build" -DCMAKE_BUILD_TYPE=%MODE% -G Ninja
if errorlevel 1 exit /b 1
cmake --build "%ROOT_DIR%\engine\build" --config %MODE% --target neko_engine neko_core --parallel
if errorlevel 1 exit /b 1

rem ── 2. Flutter 应用构建 ──
echo == Flutter 构建 (%MODE%)...
pushd "%FLUTTER_DIR%"
flutter build windows --%MODE%
if errorlevel 1 (popd & exit /b 1)
popd

echo.
echo == 构建完成: %FLUTTER_DIR%\build\windows\x64\runner\%MODE%\
endlocal
