# NekoMusic-EraASync (vendored)

**NekoMusic-EraASync** —— NekoMusicForPc 对 ArchoeraMusic 原生音频引擎
（C 外壳 + Zig **EraAudio** 解码内核）的**定制分支**，供本项目实现无缝播放。

- 上游：ArchoeraMusic `app/core/audio-engine/`（内核名 `EraSync` / `EraAudio`）
- 冻结基准：`17f4e46`（v1.0.0）
- 许可证：AGPL-3.0-or-later（见 `LICENSE`、`THIRD-PARTY-LICENSES.md`）
- ⚠️ **版本冻结**：分支固定在该基准，**不再跟随上游更新，可能不会受到后期更新与维护**；
  详见 [`FORK-NOTICE.md`](FORK-NOTICE.md)。

## 与上游的差异

1. **已移植并启用 Zig 内核（EraAudio）**：`kernel/**` 与 `build.zig`/`build.zig.zon`
   已 vendored；CMake 调用 `zig build` 产出 `libneko_eraasync_kernel.a` 并定义
   `HAS_NEKO_ERAASYNC_KERNEL`（逐格式接管解码与 DSP，未支持/失败自动回退 FFmpeg）。
   需 **Zig 0.16.0**；可用 `-DNEKO_ENABLE_ERAUDIO_KERNEL=OFF` 关闭，或运行时
   `NEKO_ERAUDIO=0` 回退 FFmpeg。
2. **启用内核原生 HTTP(S)**（对齐上游 v1.0.0）：在线 `http(s)://` 源优先走
   内核自研网络栈（`kernel/net.zig`：TCP + Zig std TLS、Range 随机访问、断流
   重连/读超时），失败自动回退 FFmpeg AVIO。可用 `NEKO_ERAASYNC_NATIVE_HTTP=0`
   显式关闭。宿主经 `create_with_headers` / `neko_eraasync_pipeline_create_with_headers` 注入
   客户端标识头（如 `User-Agent` + `X-Neko-Client`）。
3. **移除 Rust tempo**：不定义 `HAS_TEMPO`，`tempo.c` 走旁通 stub（不搬运 `tempo-rs/`）。
4. **仅静态库**：只产出 `neko_eraasync_engine`，不含 CLI（`main.c`）/ FFT 共享库 / 测试
   （上游 `*_dump.zig` / `*_test.zig` / 样例数据未搬运）。
5. **曲间无缝增补**（NekoMusic 移植，上游没有）：`prepare_source` 支持
   `"next_track": true` 与 `commit_source` 的跨曲接管（`stage_next_track` 标志、
   不裁剪、位置基准归零）；`player.c` 新增 `player_stream_rebase_zero`；
   `mediaengine_lib.c` 另含 **MinGW `timespec_get` 兜底**（msvcrt 无 C11 实现）。
   详见 `docs/seamless-playback-port.md`。

## 构建

由主工程 `CMakeLists.txt` 经 `add_subdirectory` 引入。FFmpeg 依赖按平台解析：

- **推荐：自建最小 FFmpeg**（仅音频 · 纯 LGPL · 含 TLS）——
  `bash tools/build-ffmpeg-minimal.sh`，再以
  `-DNEKO_FFMPEG_ROOT=<third_party/ffmpeg-minimal/<target>> -DNEKO_FFMPEG_BUNDLE=ON` 构建；
  共享库随包内嵌（Linux `$ORIGIN/lib`、macOS `@loader_path`、Windows 拷 `bin/*.dll`），
  与系统 FFmpeg 解耦。详见 `docs/seamless-playback-port.md` §6。
- **回退：复用系统 / Qt 的 FFmpeg**
  - **Linux**：pkg-config（系统 FFmpeg）；
  - **macOS**：pkg-config（Homebrew/系统）或 `NEKO_FFMPEG_ROOT`；
  - **Windows/MinGW**：必须 `-DNEKO_FFMPEG_ROOT=<FFmpeg开发树>`（**不查宿主 pkg-config**，
    避免交叉编译误用宿主库）；开发树需含 `include/` 与 `lib/`（或 `lib/<triple>/`）。

### EraAudio Zig 内核

需 Zig **0.16.0**（见 `build.zig.zon` 的 `minimum_zig_version`）。CMake 配置时
`find_program(zig)`，找到则调用
`zig build --prefix ... -Doptimize=ReleaseFast [-Dcpu=baseline]` 生成
`libneko_eraasync_kernel.a` 并链接（Windows/MinGW 传 `-Dtarget=x86_64-windows-gnu`；
macOS 通用架构逐架构构建后 `lipo` 合成）。未找到 `zig` 时仅内核不启用（回退 FFmpeg）。

未找到 FFmpeg 时置 `NEKO_ERAASYNC_ENGINE_AVAILABLE=FALSE`（本仓库主工程此时配置**直接失败**：
QMediaPlayer 回退已移除）。`-DNEKO_DISABLE_AUDIO_ENGINE=ON` 同样会得到不可用结果。

> 注：本目录文件按移植需要可继续修，但请保持上游 AGPL 归属与许可证文件完整；
> 若上游有重要修复，建议按 `git diff` 方式同步。

## 三平台编译自检

```bash
bash tools/compile-check.sh all      # host + Windows/MSVC(wine) + macOS(SDK)
```

仅编译不链接，用于在 Linux 开发机上验证引擎对 MSVC / macOS clang 的源码兼容性
（MSVC 走 `NEKO_MSVC_CL`，macOS 走 `NEKO_MACOS_SDK`）。
