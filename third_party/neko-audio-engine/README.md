# neko-audio-engine (vendored)

ArchoeraMusic 原生音频引擎（C 外壳 + Zig **EraAudio** 解码内核）的精简副本，
供 NekoMusicForPc 实现无缝播放。

- 上游：ArchoeraMusic `app/core/audio-engine/`
- 基准 commit：`0b2556a212eb651a8c337a4a09498b5ee0c6740e`
- 许可证：AGPL-3.0-or-later（见 `LICENSE`、`THIRD-PARTY-LICENSES.md`）

## 与上游的差异

1. **已移植 Zig 内核（EraAudio）**：`kernel/**` 与 `build.zig`/`build.zig.zon` 已 vendored；
   CMake 调用 `zig build` 产出 `libarchoera_kernel.a` 并定义 `HAS_ARCHOERA_KERNEL`
   （逐格式接管解码与 DSP，未支持/失败自动回退 FFmpeg）。需 **Zig 0.16.0**；
   可用 `-DNEKO_ENABLE_ERAUDIO_KERNEL=OFF` 关闭，或运行时 `NEKO_ERAUDIO=0` 回退 FFmpeg。
2. **移除 Rust tempo**：不定义 `HAS_TEMPO`，`tempo.c` 走旁通 stub（不搬运 `tempo-rs/`）。
3. **仅静态库**：只产出 `archoera_engine`，不含 CLI（`main.c`）/ FFT 共享库 / 测试。
4. **曲间无缝增补**（NekoMusic 移植）：`prepare_source` 支持 `"next_track": true`
   与 `commit_source` 的跨曲接管（`stage_next_track` 标志、不裁剪、位置基准归零）；
   `player.c` 新增 `player_stream_rebase_zero`。详见 `docs/seamless-playback-port.md`。

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
`libarchoera_kernel.a` 并链接（Windows/MinGW 传 `-Dtarget=x86_64-windows-gnu`；
macOS 通用架构逐架构构建后 `lipo` 合成）。未找到 `zig` 时仅内核不启用（回退 FFmpeg）。

未找到 FFmpeg 时置 `ARCHOERRA_ENGINE_AVAILABLE=FALSE`（本仓库主工程此时配置**直接失败**：
QMediaPlayer 回退已移除）。`-DNEKO_DISABLE_AUDIO_ENGINE=ON` 同样会得到不可用结果。

> 注：本目录文件按移植需要可继续修，但请保持上游 AGPL 归属与许可证文件完整；
> 若上游有重要修复，建议按 `git diff` 方式同步。

## 三平台编译自检

```bash
bash tools/compile-check.sh all      # host + Windows/MSVC(wine) + macOS(SDK)
```

仅编译不链接，用于在 Linux 开发机上验证引擎对 MSVC / macOS clang 的源码兼容性
（MSVC 走 `NEKO_MSVC_CL`，macOS 走 `NEKO_MACOS_SDK`）。
