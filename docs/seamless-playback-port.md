# 无缝播放移植说明（Qt / NekoMusicForPc）

> 分支：`qt-seamless-playback`　来源：ArchoeraMusic `app/core/audio-engine` @ `0b2556a`
>
> 目标：把 ArchoeraMusic 的「无缝播放」能力移植进 Qt 客户端——**音质无缝切换**与
> **曲间无缝（gapless）**——且**不改动项目既有的歌曲缓存/下载模式**。

## 1. 为什么不是简单照搬

ArchoeraMusic 的无缝依赖自研音频引擎的**单会话暂存源**机制（`prepare_source` /
`commit_source`）：旧源照常出声，新源在独立预取线程预解码进内存 stage，切档时按
「旧源解码游标」做**样本级裁剪**后把 PCM 续喂**同一个 ring buffer**，设备/会话不重建。
`QMediaPlayer` 拿不到解码 PCM，无法做这种桥接，因此本移植**引入原生引擎**作为播放后端。

按移植决策：

- **移植 Zig 解码内核（EraAudio）**：vendored 于
  `third_party/neko-audio-engine/kernel/`，由 `zig build` 产出 `libarchoera_kernel.a`
  并定义 `HAS_ARCHOERA_KERNEL`；逐格式接管解码（不支持/失败自动回退 FFmpeg），
  滤波/DSP 也优先走内核。可 `-DNEKO_ENABLE_ERAUDIO_KERNEL=OFF` 关闭；
  运行时 `NEKO_ERAUDIO=0` 强制回退 FFmpeg。
- **不链接 Rust tempo**：`HAS_TEMPO` 未定义，`tempo.c` 走旁通 stub。
- **不改动缓存模式**：App 的 `MusicDownloader` / `.part` 流式 / 后台缓存逻辑原样保留；
  引擎自身的会话临时目录（`stream.wav/.pcm`）与之无关，随会话清理。

## 2. 代码结构

| 文件 | 作用 |
|---|---|
| `third_party/neko-audio-engine/` | vendored 引擎（C 外壳 + Zig EraAudio 内核），静态库 `archoera_engine` |
| `third_party/neko-audio-engine/kernel/` | EraAudio Zig 解码内核源码（`build.zig` → `libarchoera_kernel.a`） |
| `src/core/audioengine.{h,cpp}` | 引擎的 Qt 封装：工作线程 create + `wait_event` 事件泵 + 命令下发 |
| `src/core/playerengine.h` | 播放门面（公共 API/信号不变），仅原生引擎实现 |
| `src/core/playerengine_native.cpp` | 原生引擎实现（无缝切换 + 曲间无缝） |
| `src/core/mediaprobe.{h,cpp}` | 本地文件标签/内嵌封面探测（直接用内嵌 FFmpeg，替代 QMediaPlayer） |

构建门控：必须提供 FFmpeg（推荐自建最小 FFmpeg，见 §6），定义 `NEKO_HAS_AUDIO_ENGINE`
并链接 `archoera_engine`；**QMediaPlayer 回退已移除**，未提供 FFmpeg 时配置直接失败。
EraAudio 内核需 Zig 0.16.0；未找到 `zig` 时仅内核不启用（解码/滤波回退 FFmpeg），
可用 `-DNEKO_ENABLE_ERAUDIO_KERNEL=OFF` 显式关闭。

## 3. 音质无缝切换

`PlayerEngine::switchSourceWithoutRestart(url)` →

1. `AudioEngine::prepareSource(url, nextTrack=false)`：引擎按**当前解码游标**预开新音质并预解码；
2. `source_ready` → `AudioEngine::commitSource()`；
3. `source_switched` → 更新 `m_currentUrl`，位置由引擎 ring 兜底无缝延续（曲目/时长不变）。

对齐源项目 `playback_notifier_session.dart::setQuality`（移除双播放器候选）。

## 4. 曲间无缝（gapless）

源引擎的 `prepare/commit` 裁剪公式是**为同一首歌**设计的（新源从"当前解码游标"续起）。
直接拿去接下一首会把下一首开头裁掉。移植时对 vendored 引擎做了**最小增补**：

- `prepare_source` 支持可选字段 `"next_track": true`：新源 `start_offset_ms=0`（从 0 起），
  并置会话标志 `stage_next_track`；
- `commit_source` 在该标志下**不做交叠裁剪**（feed stage 全量），并把位置基准归零
  （`p_start_ms=0`、`session_offset_ms=0`、`player_stream_rebase_zero`），使新曲进度从 0 计。

Qt 侧接线（`MainWindow`）：

- `positionChanged`：剩余 ≤ 8s 且未预加载时，`peekNextIndex()` 预测下一首 → `prepareNextSource(url, info)`；
- 剩余 ≤ 400ms 且下一首已就绪 → `commitPreparedNext()`；曲尾兜底在 `player:ended` 再提交一次；
- `transitionedToNext(info)`：做 UI/元数据/歌词/历史/系统媒体切换与后台缓存触发（**不重启播放**）。
- `PlaylistManager::peekNextIndex()` 为新增的**非消费式**预测（随机模式用 `ShuffleBag::peekNext`），
  真正切换时 `nextIndex()` 消费，保证预加载与实际播放是同一首。

## 5. 验证

- C 引擎无头测试（`/tmp` 下临时工程，非仓库）：
  - 音质切换：`ready → source_ready → source_switched(position≈旧游标)`，跨采样率自动重采样锁定；
  - 曲间无缝：`source_switched(position=0)`，下一首从头完整播放。
- 整包 `cmake --build` 通过；`NekoMusic` 启动走原生引擎播放成功。

## 6. FFmpeg 依赖与打包（自建最小 FFmpeg · 随包内嵌）

原则：**不再复用 Qt / 系统的完整 FFmpeg**，而是自建一份**最小、仅音频、纯 LGPL**
的 FFmpeg 共享库，随包内嵌，与系统 FFmpeg 版本解耦。

构建脚本：`third_party/neko-audio-engine/tools/build-ffmpeg-minimal.sh`
（默认 `FFMPEG_VERSION=7.1.1`，对齐 Qt 6.10.x 自带 FFmpeg 大版本 / soname `61`）：

- `--disable-everything` 后仅启用**音频**解码器/解复用器/解析器 +
  `file,pipe,http,https,tcp,tls` 协议；**无** encoders/muxers（播放模式
  `skip_encoder=true`，WAV 头由引擎手写）、**无** swscale/avfilter/avdevice；
- `--disable-gpl --disable-nonfree --disable-autodetect`（纯 LGPL，无外部编解码库）；
- TLS 按平台用系统自带：**Linux `openssl`**、**macOS `securetransport`**、
  **Windows `schannel`**（`https` 远程流可用，无需额外 TLS 运行库）；
- 产物根目录：`third_party/ffmpeg-minimal/<target>/{include,lib,bin}`
  （macOS 通用架构用 `FFMPEG_UNIVERSAL=1`，输出 `macos-universal`）。

| 平台 | 构建 | 运行期内嵌方式 |
|---|---|---|
| **Linux** | 脚本在本机构建 | 装到 `/opt/nekomusic/lib`，`RUNPATH=$ORIGIN/lib`；DEB 经 `dpkg-shlibdeps` 补 `libssl3/libc` 等 |
| **Windows/MinGW** | CI 用 Qt 自带 MinGW 在 Git Bash 内构建 | `bin/*.dll` 拷到安装目录（NSIS 已含 `av*.dll` 通配）；schannel 无需 OpenSSL DLL |
| **macOS** | CI 构建 arm64+x86_64 通用库 | `macdeployqt` 收进 `Contents/Frameworks`，`INSTALL_RPATH=@loader_path/../Frameworks` |

CMake 开关：`-DNEKO_FFMPEG_ROOT=<产物根>` + `-DNEKO_FFMPEG_BUNDLE=ON`
（`NEKO_FFMPEG_BUNDLE` 打开随包内嵌：Linux 安装规则 + RUNPATH；macOS 设 RPATH；
Windows 由 CI 复制）。未给 `NEKO_FFMPEG_ROOT` 时回退 pkg-config（系统 FFmpeg）。

- `NEKO_FFMPEG_ROOT` 的手工定位同时支持 `lib/` 与 `lib/<triple>/`，并禁用
  `CMAKE_FIND_ROOT_PATH` 重定根（交叉编译下直接使用给定绝对路径）。
- 不再提供 QMediaPlayer 回退：`-DNEKO_DISABLE_AUDIO_ENGINE=ON` 会使配置直接失败。

> **关于视频/MV**：本客户端**无本地视频播放**（`VideoRenderDialog` 只是把所选片段
> 提交服务端做 MV 渲染的表单），故最小构建不含视频解码器不影响功能。
> 仍保留 Qt Multimedia 仅用于**音频设备枚举**（`QAudioDevice/QMediaDevices`，
> 供麦克风同步与输出设备选择）；`QMediaPlayer` 已移除。

### 本机三平台编译自检

`third_party/neko-audio-engine/tools/compile-check.sh`（仅 `-c` 编译，不链接）：
在本机用 **MSVC(wine)** 与 **macOS SDK + clang** 交叉编译全部引擎源，验证源码兼容性。

```bash
bash third_party/neko-audio-engine/tools/compile-check.sh all
#   host/cc : 20/20
#   win/msvc: 20/20   (NEKO_MSVC_CL=/opt/msvc/bin/x64/cl)
#   mac/clang: 40/40  (NEKO_MACOS_SDK=~/.local/share/macos-sdk/MacOSX*.sdk，x86_64+arm64)
```

### CI（`build-Releases` 三平台出包）

三平台均**自建最小 FFmpeg → 构建并链接原生引擎**（CI 断言，缺失即失败）：

- **Linux**：job 内装 `nasm/libssl-dev/pkg-config` → 跑脚本 → `NEKO_FFMPEG_BUNDLE=ON`；
  断言 `ldd build-linux/NekoMusic` 含 `libav*` 且 `readelf` 有 `RUNPATH`。
- **Windows**：Qt 自带 MinGW 在 Git Bash 内跑脚本（`--target-os=mingw32 --enable-schannel`）
  → 链接自建导入库；部署时拷 `bin/*.dll` 并按 `objdump` 导入表断言；另需 MinGW 系统库
  （ole32/winmm/avrt/uuid/bcrypt/secur32/ws2_32，CMake 已链接）。
- **macOS**：`FFMPEG_UNIVERSAL=1` 跑脚本建通用库 → 链接后由 `macdeployqt` 收集 dylib，
  并 `otool` 断言。

## 7. 已知限制 / 待办

- **随包内嵌 FFmpeg**：Linux/macOS 已与系统 FFmpeg 解耦（`$ORIGIN/lib`、`@loader_path`），
  FFmpeg 大版本升级只需重跑构建脚本，不再依赖目标发行版。
- **QMediaPlayer 已移除**：播放与本地标签/封面探测均走原生引擎 + 内嵌 FFmpeg
  （`src/core/mediaprobe.cpp`）；不再分发 Qt Multimedia 的媒体后端。Qt Multimedia
  仅保留 `QAudioDevice/QMediaDevices` 用于输出设备枚举（麦克风同步/设备选择）。
- **EraAudio 解码内核**：已移植 Zig 内核并**静态链接**（`libarchoera_kernel`），逐格式
  接管解码/滤波，未支持或失败自动回退 FFmpeg；需 Zig 0.16.0。可
  `-DNEKO_ENABLE_ERAUDIO_KERNEL=OFF` 构建期关闭，或运行时 `NEKO_ERAUDIO=0` 回退 FFmpeg。
  内核内自带 HTTP(S)（`net.zig`）未启用——流式仍走 FFmpeg AVIO 传输，保持既有缓存模式。
- **Windows**：CI 用 Qt 自带 MinGW 构建最小 FFmpeg；Qt 升级后仅需重跑脚本（不再依赖 BtbN 下载）。
- **码率探测**：原生引擎不暴露源码率，`audioBitRateBps()` 返回 0，播放页音质角标回退到文件头/所选档位。
- **输出设备映射**：Linux PulseAudio 下 `QAudioDevice.id()` 与引擎 sink id 一致，可直接映射；
  其他平台按描述名匹配，失败回退系统默认。
- 曲间无缝的预加载/提交时序常数（8s / 400ms）可在真机实测后微调。
