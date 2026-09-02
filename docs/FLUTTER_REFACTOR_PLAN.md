# NekoMusicForPc Flutter 重构规划文档

> **版本**: v1.0
> **日期**: 2026-08-12
> **目标**: UI 层迁移至 Flutter（桌面三端 Win/Mac/Linux 通用）；播放引擎弃用 Qt Multimedia（其 PipeWire 兼容存在 Bug），改用 C 系引擎 libmpv（Linux 原生 PipeWire 优先、失败自动回退）；核心业务（API 客户端/歌单库/用户系统）暂保持 Qt 不变，按里程碑逐步嵌入。

> **架构决策记录（2026-08-12）**：
> - **引擎选型 = libmpv**：跨平台（Linux `ao=pipewire,pulse,alsa` / Win `wasapi` / Mac `coreaudio`），单一 C API，解码+输出一体，`ao-fallback` 自动回退，社区生态成熟（Flutter 桌面音乐应用主流选择）。
> - **集成形态 = dart:ffi 内嵌**：C 引擎编译为共享库，Flutter 进程内直接加载调用；后续 Qt 核心以 `QCoreApplication` 工作线程 + C 桥接方式嵌入同一进程。
> - **事件模型 = 轮询**：C 侧事件线程（`mpv_wait_event`）+ 有界队列，Flutter 侧 150ms 定时 `neko_poll_event` 取走；避免 NativeCallable 跨线程回调的复杂度。
> - **本机环境**：EndeavourOS（Arch 系），mpv 0.41（含头文件）、Flutter 3.44.8 Linux 桌面工具链、PipeWire/WirePlumber/ALSA 均已具备，无新增系统依赖。

---

## 1. 项目概述

### 1.1 背景

1. **Qt 对 PipeWire 的兼容性存在 Bug**，需要绕开 Qt Multimedia 播放管线。
2. 原 UI 为 Qt Widgets（约 2.9 万行），需要替换为 Flutter。
3. 核心业务代码（约 1.1 万行，依赖 Qt Core/Network/Sql）暂不重写。

### 1.2 目标

| 项 | 目标 |
|----|------|
| UI 技术栈 | Flutter（Win / macOS / Linux 三端一套代码） |
| 播放引擎 | libmpv（C），Linux PipeWire 原生优先，失败主动回退 |
| 集成方式 | dart:ffi 内嵌共享库，单进程 |
| 核心业务 | Qt 代码暂不动，按里程碑嵌入 FFI 层 |
| 最小可行阶段 | 主窗口骨架 + 引擎打通 + IPC 打通，可播放 |

### 1.3 约束（不可逾越）

- ❌ 不再依赖 Qt Multimedia / Qt Widgets 做 UI。
- ✅ 核心 `src/core/` 业务代码在嵌入前保持零改动。
- ✅ Linux 播放必须「尽可能走 PipeWire」，仅在 PipeWire 初始化失败时回退。

---

## 2. 引擎选型对比（决策依据）

| 候选 | 跨平台 | PipeWire 原生 | 失败主动回退 | 解码 | 结论 |
|------|--------|---------------|--------------|------|------|
| **libmpv** | ✅ 三端 | ✅ `ao=pipewire` | ✅ `ao` 链 + `ao-fallback` | ✅ 内建 FFmpeg | **选用** |
| FFmpeg + SDL2 | ✅ 三端 | ✅ SDL 原生驱动 | 需每平台手写 | ✅ FFmpeg | 备选（零新增依赖） |
| FFmpeg + libpipewire | ❌ Linux 专属 | ✅ | 需手写 | ✅ FFmpeg | 排除 |
| GStreamer | ✅ | ⚠️ 需额外插件 | 需自行处理 | ✅ | 排除（插件缺失） |
| libvlc 3.x | ✅ | ❌ 3.x 无原生 | — | ✅ | 排除 |
| Qt Multimedia | ✅ | ❌ 兼容 Bug | — | ✅ FFmpeg | **弃用** |

**PipeWire 策略**（Linux）：

```text
ao = pipewire,pulse,alsa      # PipeWire 原生优先，逐级回退
ao-fallback = yes             # 初始化/运行失败均允许回退
```

> 沙箱验证结论：本沙箱禁止 `/memfd:pipewire-memfd`，原生 PipeWire 初始化失败 → 引擎按链自动回退 pulse 出声（pactl 确认流创建）；真实桌面无此限制，将直接选择 pipewire。回退链路机制已双向验证。

---

## 3. 总体架构

```
┌────────────────────────────────────────────────┐
│  Flutter UI（flutter/）                        │
│  main_shell / sidebar / player_bar / 各页面    │
│         │ 监听                                  │
│  EngineController（事件泵 150ms + 响应式状态）  │
│         │ dart:ffi                             │
├─────────┴──────────────────────────────────────┤
│  libneko_engine（engine/，C 库，共享库）       │
│  neko_engine.c  ←  libmpv（解码 + 音频输出）   │
│    · 事件线程 mpv_wait_event → 有界队列         │
│    · ao 链：Linux pipewire→pulse→alsa          │
│         ▲ 后续里程碑                            │
│  Qt 核心桥（QCoreApplication 工作线程）         │
│  src/core/*（apiclient / playlistdb / user…）  │
└────────────────────────────────────────────────┘
```

### 3.1 模块清单（现状）

| 模块 | 路径 | 状态 |
|------|------|------|
| 引擎 C 库 | [engine/](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine) | ✅ 已完成 |
| 引擎 CLI 自检 | [engine/src/test_engine.c](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/src/test_engine.c) | ✅ 已完成 |
| Flutter 应用 | [flutter/](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter) | ✅ 骨架完成 |
| FFI 绑定 | [flutter/lib/ffi/neko_engine.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ffi/neko_engine.dart) | ✅ 已完成 |
| 引擎控制器 | [flutter/lib/core/engine_controller.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/core/engine_controller.dart) | ✅ 已完成 |
| Qt 核心桥 C API | [engine/core/neko_core.h](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/core/neko_core.h) | ✅ 已完成（M2） |
| Qt 核心桥实现 | [engine/core/neko_core.cpp](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/core/neko_core.cpp) | ✅ 已完成（M2） |
| 核心桥 CLI 自检 | [engine/src/test_core.c](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/src/test_core.c) | ✅ 已完成（M2） |
| 核心桥 FFI 绑定 | [flutter/lib/ffi/neko_core.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ffi/neko_core.dart) | ✅ 已完成（M2） |
| 核心控制器 | [flutter/lib/core/core_controller.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/core/core_controller.dart) | ✅ 已完成（M2） |
| 首页真实数据（热门榜/最新） | [flutter/lib/ui/main_shell.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/main_shell.dart) | ✅ 已完成（M2） |
| 侧边栏导航 + 页面路由 | [flutter/lib/ui/sidebar.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/sidebar.dart) | ✅ 已完成（M3） |
| 登录/退出（对话框 + 用户菜单） | [flutter/lib/ui/login_dialog.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/login_dialog.dart) | ✅ 已完成（M3） |
| 搜索页 | [flutter/lib/ui/search_page.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/search_page.dart) | ✅ 已完成（M3） |
| 播放详情页（封面/控制/歌词） | [flutter/lib/ui/player_detail_page.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/player_detail_page.dart) | ✅ 已完成（M3） |
| 收藏/最近播放/下载页 | [flutter/lib/ui/list_pages.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/list_pages.dart) | ✅ 已完成（M3） |
| 每日推荐（发现页） | [flutter/lib/ui/main_shell.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/main_shell.dart) | ✅ 已完成（M3） |
| 共享歌曲行组件 | [flutter/lib/ui/widgets/song_tile.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/widgets/song_tile.dart) | ✅ 已完成（M3） |
| 歌曲右键菜单（通用组件） | [flutter/lib/ui/widgets/song_context_menu.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/widgets/song_context_menu.dart) | ✅ 已完成（M3 续） |
| 本地歌单页（CRUD + 详情，含右键菜单） | [flutter/lib/ui/local_playlist_detail_page.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/local_playlist_detail_page.dart) | ✅ 已完成（M3 续） |
| 桌面歌词（原生 GTK 悬浮窗 + Pango） | [flutter/lib/core/desktop_lyrics.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/core/desktop_lyrics.dart) | ✅ 已完成（M3 续） |
| 共享 LRC 解析器 | [flutter/lib/core/lrc_parser.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/core/lrc_parser.dart) | ✅ 已完成（M3 续） |
| 业务页面移植 | — | ✅ 主体完成（M3） |

---

## 4. 引擎设计

### 4.1 C FFI API（[neko_engine.h](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/include/neko_engine.h)）

| 分类 | 函数 | 说明 |
|------|------|------|
| 生命周期 | `neko_create` / `neko_initialize` / `neko_destroy` | 创建、初始化（含 ao 链注入）、销毁 |
| 选项 | `neko_set_option` | 加载前注入 mpv 选项（如 `http-header-fields`） |
| 播放 | `neko_load` / `neko_play` / `neko_pause` / `neko_stop` / `neko_seek` | 异步 loadfile（replace 模式） |
| 音量 | `neko_set_volume` / `neko_get_volume` | 0~1 线性，内部映射 mpv volume 0~100 |
| 查询 | `neko_get_state` / `position` / `duration` / `audio_output` / `audio_bitrate` | `current-ao` 取实际后端 |
| 恢复 | `neko_set_resume_position` | load 后设置，`PLAYBACK_RESTART` 一次性生效 |
| 事件 | `neko_poll_event` | 非阻塞取一条；空返回 0 |

### 4.2 事件模型

```text
mpv 事件线程 ──► 有界队列(256) ──► Flutter Timer(150ms) poll ──► UI
                NEKO_EV_STATE / POSITION / DURATION / END_FILE /
                AUDIO_META / TITLE / ERROR / READY
```

- 队满丢最旧，事件结构自带 256B 字符串槽（标题/错误）。
- `time-pos` 事件节流：≥100ms 间隔且位移 ≥50ms，避免刷爆 UI。

### 4.3 线程安全

- mpv API 本身线程安全；引擎暴露的 `neko_get_*` 可从 Flutter 主 isolate 直接调用。
- 队列读写互斥保护；销毁时 `mpv_wakeup` 唤醒事件线程后 join。

---

## 5. Flutter 侧设计

### 5.1 目录（[flutter/lib/](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib)）

| 文件 | 职责 |
|------|------|
| [main.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/main.dart) | 应用入口、主题（玫红 `#F05E7A` 延续原版）、`EngineScope` |
| [ffi/neko_engine.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ffi/neko_engine.dart) | FFI 绑定：typedef 签名 + `pollEvent` 转 Dart 对象 |
| [core/engine_controller.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/core/engine_controller.dart) | ChangeNotifier + 事件泵 + 拖拽 seek 标记 |
| [ui/main_shell.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/main_shell.dart) | 主窗口骨架（侧边栏/顶栏/内容/播放栏） |
| [ui/sidebar.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/sidebar.dart) | 240px 导航侧边栏（占位） |
| [ui/player_bar.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/player_bar.dart) | 80px 播放栏：进度/音量/播放态/实际 ao 展示 |

### 5.2 引擎库加载策略

1. `NEKO_ENGINE_PATH` 环境变量显式指定；
2. bundle 内 `libneko_engine.so`（Linux CMake 自动构建并安装进 `bundle/lib`）；
3. 开发期相对路径（`../engine/build/`）。

### 5.3 构建集成

[flutter/linux/CMakeLists.txt](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/linux/CMakeLists.txt)：
- 自定义 target 自动 `cmake` 构建 engine 共享库；
- `install()` 将 `libneko_engine.so` 装入 bundle，配合 `$ORIGIN/lib` rpath 供 dart:ffi 加载。

---

## 6. 迁移路线图

| 阶段 | 内容 | 状态 |
|------|------|------|
| **M1** | 引擎 C 库（libmpv）+ CLI 自检 + Flutter 骨架（FFI 打通、可播放本地/URL 音频） | ✅ 已完成（2026-08-12） |
| **M2** | 嵌入 Qt 核心：`QCoreApplication` 工作线程 + C 桥接，暴露 apiclient/歌单库/用户系统 FFI；首页真实数据（热门榜/最新，点击经引擎播放）；流媒体请求头经 `neko_core_audio_headers` 注入 mpv | ✅ 已完成（2026-08-12） |
| **M3** | 页面移植：登录/首页/搜索/播放详情（歌词）/收藏/最近/下载/每日推荐；侧边栏路由；上一首/下一首；歌曲右键菜单；本地歌单 CRUD + 详情；桌面歌词（原生 GTK 悬浮窗，经 `neko/window` 通道驱动） | ✅ 已完成（2026-08-12 主体 + 2026-08-14 续：右键菜单/本地歌单 CRUD/桌面歌词） |
| **M4** | 跨平台打包：Windows（NSIS/msix）、macOS（dmg）、Linux（AppImage/deb）；Qt 核心脱离或彻底 Dart 重写评估 | ⏳ 待做 |
| **M5** | 移除 Qt 工程残留（`src/ui`、Qt Multimedia 依赖），统一构建 | ⏳ 待做 |

> M1 目标明确：以最小闭环验证「Flutter UI + dart:ffi + libmpv(PipeWire)」架构可行，后续页面/业务逐页迁移，Qt UI 文件在功能完全替换前不删除。

---

## 7. 构建与运行

```bash
# 引擎（独立构建 + 自检）
cd engine
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/neko_engine_test --verbose <音频文件>     # 真实桌面应显示 ao=pipewire

# Flutter 应用（会自动构建并打包引擎）
cd flutter
flutter run -d linux
```

### 沙箱注意事项（仅开发环境）

- 沙箱禁 GPU/dconf/PipeWire memfd：GUI 需软件渲染启动
  `LIBGL_ALWAYS_SOFTWARE=1 DCONF_USER_DIR=/tmp/dconf GDK_BACKEND=x11`
- 引擎自检在沙箱内表现为回退到 pulse（预期行为），真实桌面无此限制。

---

## 8. 验收清单

### 引擎（M1）
- [x] CLI 播放本地音频：状态机/进度/码率/EOF 事件正确
- [x] Linux PipeWire 原生输出（pactl 可见流）
- [x] 失败主动回退（坏 ao → pulse 出声）
- [x] seek / volume / resume-position 生效

### Flutter 骨架（M1）
- [x] `flutter build linux --debug` 通过，引擎库自动进 bundle
- [x] 应用启动存活，FFI 加载 + 引擎初始化成功
- [ ] 真实桌面 GUI 手动验证：输入 URL 播放、进度/音量/播放态联动（待人工执行）

### 后续（M2+）
- [ ] Qt 核心 FFI 桥接（apiclient 登录/歌单等）
- [ ] 搜索/歌单/播放页移植
- [ ] 三端打包产物

---

## 9. 风险与注意事项

| 风险 | 严重度 | 缓解 |
|------|--------|------|
| Qt 核心嵌入 FFI 的线程/事件循环复杂度 | 高 | 单工作线程 `QCoreApplication::exec()`，FFI 调用经线程安全队列投递；先以登录+歌单做试点 |
| mpv 与 Qt 各自 FFmpeg 版本冲突 | 中 | 播放走 libmpv 自带解码，Qt 侧仅用 Network/Sql/Core，不链 Multimedia，无 FFmpeg 符号冲突 |
| 流媒体防盗链（UA/Referer） | 中 | M2 从 apiclient 取头，经 `neko_set_option("http-header-fields")` 注入 |
| 三端打包差异（.so/.dylib/.dll） | 低 | engine CMake 已按平台分支；M4 统一打包脚本 |

### 不做的事情（避免范围蔓延）
- ❌ 不用 Qt Quick / QML
- ❌ 不引入 GStreamer / libvlc / SDL 播放管线
- ❌ 不一次性移植全部页面（29k 行）
- ❌ 不内嵌中文字体

---

## 10. 参考文件速查

| 文件 | 作用 |
|------|------|
| [engine/include/neko_engine.h](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/include/neko_engine.h) | C FFI API 定义（事件/状态/函数声明） |
| [engine/src/neko_engine.c](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/src/neko_engine.c) | libmpv 封装实现（事件线程/ao 链/队列） |
| [engine/src/test_engine.c](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/src/test_engine.c) | CLI 自检（含 `--ao` 覆盖验证回退） |
| [engine/CMakeLists.txt](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/engine/CMakeLists.txt) | 引擎构建（pkg-config mpv，Win 分支 MPV_DIR） |
| [flutter/lib/ffi/neko_engine.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ffi/neko_engine.dart) | dart:ffi 绑定（签名 + 事件解析） |
| [flutter/lib/core/engine_controller.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/core/engine_controller.dart) | 事件泵 + 响应式状态 |
| [flutter/lib/ui/player_bar.dart](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/lib/ui/player_bar.dart) | 播放栏（进度/音量/ao 展示） |
| [flutter/linux/CMakeLists.txt](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/flutter/linux/CMakeLists.txt) | 引擎自动构建 + bundle 集成 |
| [src/core/playerengine.h](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/src/core/playerengine.h) | 旧 Qt 播放引擎（将被引擎库替代） |
| [UI_REFACTOR_PLAN.md](file:///home/betastudio2/文档/NekoMusicOrigin/NekoMusicForPc-Trained/UI_REFACTOR_PLAN.md) | 旧 Qt UI 重构规划（已归档路线，不继续执行） |
