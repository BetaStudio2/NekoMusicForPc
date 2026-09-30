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

- **不移植 Zig 内核**（EraAudio）：引擎以 `HAS_ARCHOERA_KERNEL` 未定义编译，
  解码恒走 FFmpeg（`engine_mode=0`）。
- **不链接 Rust tempo**：`HAS_TEMPO` 未定义，`tempo.c` 走旁通 stub。
- **不改动缓存模式**：App 的 `MusicDownloader` / `.part` 流式 / 后台缓存逻辑原样保留；
  引擎自身的会话临时目录（`stream.wav/.pcm`）与之无关，随会话清理。

## 2. 代码结构

| 文件 | 作用 |
|---|---|
| `third_party/archoera-audio-engine/` | vendored C 引擎（FFmpeg-only），静态库 `archoera_engine` |
| `src/core/audioengine.{h,cpp}` | 引擎的 Qt 封装：工作线程 create + `wait_event` 事件泵 + 命令下发 |
| `src/core/playerengine.h` | 播放门面（公共 API/信号不变），实现按 `NEKO_HAS_AUDIO_ENGINE` 二选一 |
| `src/core/playerengine_native.cpp` | 原生引擎实现（无缝切换 + 曲间无缝） |
| `src/core/playerengine_qtmedia.cpp` | QMediaPlayer 回退实现（无 FFmpeg 开发库 / Windows） |

构建门控：找到系统 FFmpeg 开发库时定义 `NEKO_HAS_AUDIO_ENGINE` 并链接 `archoera_engine`；
否则编译 QMediaPlayer 回退路径（行为与移植前一致）。

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

## 6. 已知限制 / 待办

- **Windows**：引擎未启用（回退 QMediaPlayer）；引擎上游 Windows 构建另走 vcpkg 脚本，未纳入。
- **码率探测**：原生引擎不暴露源码率，`audioBitRateBps()` 返回 0，播放页音质角标回退到文件头/所选档位。
- **输出设备映射**：Linux PulseAudio 下 `QAudioDevice.id()` 与引擎 sink id 一致，可直接映射；
  其他平台按描述名匹配，失败回退系统默认。
- 曲间无缝的预加载/提交时序常数（8s / 400ms）可在真机实测后微调。
