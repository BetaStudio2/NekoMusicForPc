# 编译指南（详细版）

面向从源码构建 **Neko歌姬计划 PC 版（Flutter）** 的完整说明：依赖安装、逐平台构建、打包与常见问题。
脚本入口统一为 `scripts/`，CI 与本地同一套脚本。

---

## 0. 总览

| 平台 | 构建入口 | 产物 |
|---|---|---|
| Linux | `scripts/build.sh [debug\|release]` | `flutter/build/linux/x64/<mode>/bundle/` |
| macOS | `scripts/build.sh release` | `.app`（+ `Contents/Frameworks` 内置 Qt/mpv） |
| Windows | `scripts\build.bat [debug\|release]` | `flutter\build\windows\x64\runner\<mode>\` |

> 引擎（`libneko_engine` + `libneko_core`）会在 Flutter 构建前由同一脚本先行编译。

---

## 1. 通用依赖（所有平台）

| 依赖 | 要求 | 说明 |
|---|---|---|
| Flutter SDK | **3.44+**（官方稳定版即可，无需补丁） | 推荐 3.47.x |
| CMake | ≥ 3.20 | 引擎与平台工程 |
| Ninja | 任意近期版 | 生成器 |
| Git | — | — |

> ⚠️ **必须使用 `--no-tree-shake-icons`**（脚本已内置）。Release 构建默认会对图标字体做
> tree-shaking 子集化，会把我们自绘的 `neko_icons.ttf` 裁掉部分字形导致图标缺失/空白。

获取 Flutter（示例，Linux/macOS）：

```bash
# 已有 SDK 可跳过；确保 flutter doctor 无阻断项
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"
flutter doctor
```

---

## 2. Linux

### 2.1 系统依赖

**Debian / Ubuntu**

```bash
sudo apt update
sudo apt install -y cmake ninja-build qt6-base-dev libmpv-dev \
  libayatana-appindicator3-dev gir1.2-ayatanaappindicator3-0.1 \
  clang pkg-config libgtk-3-dev mpv zstd
```

**Arch**

```bash
sudo pacman -S --needed cmake ninja clang qt6-base mpv gtk3 \
  libayatana-appindicator zstd
```

> Qt 组件需求：`Core / Network / Sql / Gui`（核心桥 `neko_core.dll/.so` 使用）。
> `libayatana-appindicator` 为托盘所需（缺失时托盘降级为“直接退出”）。

### 2.2 构建

```bash
./scripts/build.sh release
# 产物: flutter/build/linux/x64/release/bundle/neko_music
#       （bundle 目录内运行：./neko_music）
```

### 2.3 打包

```bash
bash scripts/package-deb.sh      # .deb
bash scripts/package-rpm.sh      # .rpm
bash scripts/package-arch.sh     # .pkg.tar.zst
bash scripts/package-portable.sh # 便携 tar.gz
bash scripts/package.sh          # 聚合入口
# AppImage / Flatpak 由 CI 产出（见 .github/workflows/build-linux-flutter.yml）
```

---

## 3. macOS

### 3.1 依赖（Homebrew）

```bash
brew install cmake ninja mpv qt dylibbundler
```

> 需要 Xcode 命令行工具：`xcode-select --install`。

### 3.2 构建（脚本末尾自动完成 3 步后处理）

```bash
./scripts/build.sh release
```

脚本会：
1. CMake 编译引擎 → 拷贝 `libneko_engine.dylib` / `libneko_core.dylib` 进 `Contents/Frameworks`；
2. `macdeployqt`（**默认插件**：QtSql `sqldrivers`、QtGui `imageformats`、QtNetwork `tls`）；
3. `dylibbundler` 把 libmpv 及其依赖闭包拷入并改写为 `@executable_path/../Frameworks`；
4. **ad-hoc 签名**整个 `.app`（Apple Silicon 上 unsigned dylib 会被拒绝加载）。

产物：`flutter/build/macos/Build/Products/Release/*.app`

> 首次打开如被 Gatekeeper 拦截：`xattr -cr xxx.app`

---

## 4. Windows

### 4.1 依赖

| 组件 | 获取 |
|---|---|
| Visual Studio 2022（含 C++ 桌面开发工作负载） | 官方安装器 |
| Qt 6.8.x（msvc2022_64） | [qt.io](https://www.qt.io/download) 或 `aqtinstall`；记下根目录（`QT_ROOT_DIR`） |
| libmpv 开发包（含 `include/mpv/client.h` 与 MSVC 导入库） | [mpv-winbuild](https://github.com/shinchiro/mpv-winbuild-cmake/releases)（`mpv-dev-x86_64-*.7z`），解压后把其中的 `.a`/`.lib` 改名/拷贝为 `lib\mpv.lib` |
| NSIS（仅打包安装器需要） | `choco install nsis` |

环境变量：

```bat
set MPV_DIR=D:\path\to\mpv-dev
set NEKO_FLUTTER=D:\path\to\flutter\bin\flutter   (可选)
```

### 4.2 构建

在 **x64 Native Tools Command Prompt（或已运行 vcvars64）** 中：

```bat
scripts\build.bat release
```

脚本自动：清空并重建引擎（Ninja+MSVC）→ `flutter build windows --release --no-tree-shake-icons`。

### 4.3 运行时依赖打包（发布必须）

构建产物只是 Flutter runner + 引擎 DLL，**分发前必须补齐运行库**（CI 自动完成，手动流程如下）：

1. `windeployqt --release --no-translations --compiler-runtime flutter\build\windows\x64\runner\Release\neko_core.dll`
   —— 带出 `Qt6Core/Network/Sql.dll`、`sqldrivers\qsqlite.dll` 等；`--compiler-runtime` 带出 `msvcp140/vcruntime140.dll`
2. 拷贝 `mpv-2.dll`（或 `libmpv-2.dll`）到 Release 目录
3. 缺失检查清单：`neko_core.dll`、`neko_engine.dll`、`Qt6*.dll`、`mpv*.dll`、`msvcp140.dll`、`vcruntime140.dll`、`platforms\qwindows.dll*`、`sqldrivers\qsqlite.dll`
   （*qwindows 仅特定场景需要，通常 windeployqt 已带）

> 缺这些 DLL 的典型症状：**启动即崩/无窗口**（加载器找不到 Qt6*.dll），或托盘图标透明。
> NSIS 安装器与便携 zip 均从补齐后的 Release 目录打包。

### 4.4 打包

```bat
:: 安装器（可选 VERSION/OUT/STAGING 参数见 packaging\nekomusic.nsi）
makensis packaging\nekomusic.nsi
:: 便携 zip：直接压缩 Release 目录
```

---

## 5. 运行 & 开发

```bash
cd flutter
flutter pub get
flutter run -d linux          # 或 -d windows / macos
flutter analyze               # 应 0 error
flutter test                  # 图标字形渲染回归测试（inked>0）
```

自绘图标字体重建（改了 `resources/icons*/**.svg` 后）：

```bash
./scripts/build-icon-font.sh   # 依赖 Node(npm)：fantasticon
# 产出 flutter/assets/fonts/neko_icons.ttf 与 flutter/lib/ui/neko_icons.dart（有完整性守卫）
```

---

## 6. 常见问题（踩坑记录）

| 症状 | 原因 | 处理 |
|---|---|---|
| Release 下部分图标缺失/空白 | Flutter 图标 tree-shaking 裁掉了自绘字形 | 确认构建带 `--no-tree-shake-icons`（脚本已内置） |
| 启动即崩、无窗口（Windows） | 缺 `Qt6*.dll` / MSVC 运行库 / mpv dll | 见 4.3；CI 已自动补齐 |
| 图标字体更新后包内仍是旧字形 | `.dart_tool` 陈旧导致资产未刷新 | 删除 `flutter/build` 与 `flutter/.dart_tool/flutter_build` 后重编；必要时先 `flutter pub get` |
| `Failed to lookup symbol 'neko_core_cmd_*'` | 新增 C 导出未加 `NEKO_CORE_API` 头声明（`-fvisibility=hidden`） | 在 `engine/core/neko_core.h` 补声明 |
| 托盘图标透明 / 无右键菜单（Windows） | png 资产原生不可用 & 右键需手动弹出 | 已内置：`.ico` 落盘 + `popUpContextMenu()`；见 `lib/core/background_service.dart` |
| 前台窗口点 X 无反应（Windows） | `setPreventClose(true)` 但插件未就绪收不到 `onWindowClose` | 已内置：`main()` 首帧前 `windowManager.ensureInitialized()` |
| cmake 报 `build/native_assets/linux` 缺失 | 构建缓存被外部清空 | `flutter pub get` 后重试；或整删 `flutter/build` 与 `.dart_tool` 再编 |
| Windows 下 bat 输出乱码/被当命令执行 | 批处理含中文且为 LF | `build.bat` 保持 **ASCII+CRLF**（已固化） |
| Linux 托盘不可用 | 无 appindicator | 安装 `libayatana-appindicator`，否则自动降级为直接退出 |

---

## 7. CI

`.github/workflows/build-linux-flutter.yml`：
push/PR 到 `flutter` 分支自动构建全部平台并上传产物；
`workflow_dispatch` 支持 `only_windows=true` 仅跑 Windows。
产物断言（Windows 依赖清单 + 冒烟启动、macOS Qt/mpv/签名检查）内置，缺依赖直接红灯。
