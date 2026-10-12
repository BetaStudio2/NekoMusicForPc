# NekoMusic-EraASync — 定制分支 / 版本冻结声明（Fork Notice）

本目录是 NekoMusicForPc 对 ArchoeraMusic 原生音频引擎的**定制分支**，命名为
**NekoMusic-EraASync**。因为这是「为 NekoMusic 定制的音频框架」，故不再沿用上游
命名，而以延伸名 `NekoMusic-EraASync`（EraA = EraAudio，Sync = EraSync）承载。

## 来源与许可

- 上游：ArchoeraMusic `app/core/audio-engine`（内核名 `EraSync` / `EraAudio`）
- 冻结基准：`17f4e46`（v1.0.0）
- 许可：**AGPL-3.0-or-later**。本项目（NekoMusicForPc）同为 AGPL，故随项目分发；
  见 `LICENSE` 与 `THIRD-PARTY-LICENSES.md`（保留上游署名与第三方许可）。

## 命名约定

- 对外品牌 / C ABI 前缀统一为 **`NekoMusic-EraASync` / `neko_eraasync_*`**
  （含 `archoera_mediaengine_*`→`neko_eraasync_*`、`pipeline_*`→`neko_eraasync_pipeline_*`、
  `zk_*`→`neko_eraasync_zk_*`、库目标 `neko_eraasync_engine` / `neko_eraasync_kernel`）。
- 内部内核组件名 `EraAudio` 与 `era_*` 前缀**予以保留**。
- 完整映射见 `docs/seamless-playback-port.md`。

## 版本冻结（重要）

- 本分支**固定在上述 v1.0.0 基准**，作为 NekoMusicForPc 的稳定依赖。
- **不再跟随上游后续更新**：上游 ArchoeraMusic 的修复与新特性**不保证**合并进来，
  本目录**可能不会受到后期更新与维护**。
- 若确需同步上游，请以 `git diff` 方式人工挑选补丁，并重新验证
  （`zig build` + 引擎编译 + 整包构建 + 本地 HTTP 冒烟测试）。

## NekoMusic 定制点（相对上游 v1.0.0）

1. **曲间无缝（gapless）**：`prepare_source` 的 `"next_track": true`、
   `commit_source` 跨曲接管（`stage_next_track` 标志、不裁剪、位置基准归零）、
   `player.c::player_stream_rebase_zero`。
2. **MinGW `timespec_get` 兜底**：msvcrt 无 C11 实现时以 `GetSystemTimeAsFileTime`
   补齐（仅 `__MINGW32__`）。
3. **启用内核原生 HTTP(S)**（`kernel/net.zig`）并注入客户端标识头：
   在线源优先走内核自研网络栈，失败回退 FFmpeg AVIO
   （`NEKO_ERAASYNC_NATIVE_HTTP=0` 可关闭）。
