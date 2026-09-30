# archoera-audio-engine (vendored)

ArchoeraMusic 原生音频引擎的 **FFmpeg-only** 精简副本，供 NekoMusicForPc 实现无缝播放。

- 上游：ArchoeraMusic `app/core/audio-engine/`
- 基准 commit：`0b2556a212eb651a8c337a4a09498b5ee0c6740e`
- 许可证：AGPL-3.0-or-later（见 `LICENSE`、`THIRD-PARTY-LICENSES.md`）

## 与上游的差异

1. **移除 Zig 内核**：不定义 `HAS_ARCHOERA_KERNEL`，`native_decoder.c` / `equalizer.c`
   编译期回退纯 FFmpeg 解码（不搬运 `kernel/*.zig`、`zig-out/`、`.zig-cache/`）。
2. **移除 Rust tempo**：不定义 `HAS_TEMPO`，`tempo.c` 走旁通 stub（不搬运 `tempo-rs/`）。
3. **仅静态库**：只产出 `archoera_engine`，不含 CLI（`main.c`）/ FFT 共享库 / 测试。
4. **曲间无缝增补**（NekoMusic 移植）：`prepare_source` 支持 `"next_track": true`
   与 `commit_source` 的跨曲接管（`stage_next_track` 标志、不裁剪、位置基准归零）；
   `player.c` 新增 `player_stream_rebase_zero`。详见 `docs/seamless-playback-port.md`。

## 构建

由主工程 `CMakeLists.txt` 经 `add_subdirectory` 引入。FFmpeg 依赖按平台解析：

- **Linux**：pkg-config（系统 FFmpeg，与 Qt 的 ffmpeg 插件同一套）；
- **macOS**：pkg-config（Homebrew/系统）或 `NEKO_FFMPEG_ROOT`；
- **Windows/MinGW**：必须 `-DNEKO_FFMPEG_ROOT=<FFmpeg开发树>`（**不查宿主 pkg-config**，
  避免交叉编译误用宿主库）；开发树需含 `include/` 与 `lib/`（或 `lib/<triple>/`）。

原则：同进程只加载一份 FFmpeg，构建期版本须与 Qt 运行时自带的 FFmpeg 一致。
未找到 FFmpeg 时自动跳过，播放回退 `QMediaPlayer`。可用 `-DNEKO_DISABLE_AUDIO_ENGINE=ON`
显式关闭。详见 `docs/seamless-playback-port.md` §6。

> 注：本目录文件按移植需要可继续修，但请保持上游 AGPL 归属与许可证文件完整；
> 若上游有重要修复，建议按 `git diff` 方式同步。
