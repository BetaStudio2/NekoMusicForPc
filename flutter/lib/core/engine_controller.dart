import 'dart:ffi';

import 'package:flutter/foundation.dart';

import '../ffi/neko_engine.dart';

/// 引擎状态控制器：封装 FFI 调用 + 事件推送，向 UI 暴露响应式状态。
///
/// 事件模型：C 侧事件线程把事件写入有界队列后触发
/// [NativeCallable.listener] 回调（投递到主隔离区执行），本控制器随即
/// 一次性取空队列——全程无 Timer 轮询，UI 线程不因取事件而阻塞。
///
/// 若 neko_create/neko_initialize 失败（如 libmpv 加载异常），不会崩溃，
/// 而是将原因写入 [lastError] 供 UI 展示；此时播放相关操作安全降级为无操作。
class EngineController extends ChangeNotifier {
  EngineController() {
    try {
      _engine = NekoEngine();
      // listener：可从 mpv 事件线程等任意线程调用，回调投递到本隔离区执行
      _evCb = NativeCallable<Void Function(Pointer<Void>)>.listener(
          _onNativeEvent);
      _engine!.setEventCallback(_evCb!.nativeFunction.cast());
      _engine!.initialize(verbose: kDebugMode);
    } catch (e) {
      _engine = null;
      final hint = NekoEngine.fetchLastError();
      lastError = hint.isEmpty ? e.toString() : '$e\n$hint';
      debugPrint('[EngineController] init failed: $lastError');
    }
    // 兜底：拉取注册回调前可能已入队的事件（如初始化状态）
    _drain();
  }

  NekoEngine? _engine;
  NativeCallable<Void Function(Pointer<Void>)>? _evCb;
  bool _draining = false;

  NekoPlayState state = NekoPlayState.stopped;
  double position = 0;
  double duration = 0;
  double volume = 0.8;
  String title = '';
  String audioOutput = '';
  int bitrate = 0;
  String? lastError;

  bool _seeking = false;

  /// 曲目自然播完（EOF）后触发，供宿主（MainShell）切下一首
  void Function()? _onTrackEnded;
  set onTrackEnded(void Function()? v) => _onTrackEnded = v;

  /// 播放中途断流/出错（mpv END_FILE error）后触发，携带断点位置（秒），
  /// 供宿主（MainShell）实现 Qt 原版的「断点续播」：优先本地缓存续播，
  /// 否则有限次重试远程流，仍失败则切下一首。
  void Function(double position)? _onStreamFailure;
  set onStreamFailure(void Function(double position)? v) => _onStreamFailure = v;

  void init() {
    final e = _engine;
    if (e == null) return;
    volume = e.volume.clamp(0.0, 1.0).toDouble();
    audioOutput = e.audioOutput;
    notifyListeners();
  }

  /// 加载并播放（url 可为本地路径或 http(s) 流）
  void playUrl(String url) {
    final e = _engine;
    if (e == null) return;
    lastError = null;
    e.load(url);
    e.play();
    notifyListeners();
  }

  /// 从 [seconds] 断点续播：C 侧在加载完成后（MPV_EVENT_PLAYBACK_RESTART）
  /// 自动 seek 到该位置。用于在线断流后切本地缓存续播（对齐 Qt playLocalResuming）。
  void playUrlResuming(String url, double seconds) {
    final e = _engine;
    if (e == null) return;
    lastError = null;
    if (seconds > 0) e.setResumePosition(seconds);
    e.load(url);
    e.play();
    notifyListeners();
  }

  void togglePlayPause() {
    final e = _engine;
    if (e == null) return;
    if (state == NekoPlayState.playing) {
      e.pause();
    } else if (state == NekoPlayState.paused) {
      e.play();
    } else {
      return;
    }
    // 状态由推送事件回读
  }

  void seekTo(double seconds) {
    _engine?.seek(seconds, absolute: true);
  }

  void setVolume(double v) {
    final e = _engine;
    volume = v.clamp(0.0, 1.0);
    e?.setVolume(volume);
    notifyListeners();
  }

  /// 拖动进度条时标记，避免事件回读覆盖拖动中的位置
  void beginSeek() => _seeking = true;
  void endSeek() {
    final e = _engine;
    _seeking = false;
    if (e == null) return;
    position = e.position;
    notifyListeners();
  }

  /// C 侧事件入队后触发（listener 回调，投递到主隔离区执行）
  void _onNativeEvent(Pointer<Void> _) => _drain();

  /// 一次性取空事件队列；回调可能连续触发，用 [_draining] 防重入
  void _drain() {
    if (_draining) return;
    _draining = true;
    try {
      final e = _engine;
      if (e == null) return;
      var changed = false;
      while (true) {
        final ev = e.pollEvent();
        if (ev == null) break;
        switch (NekoEventType.fromValue(ev.type)) {
          case NekoEventType.state:
            final st = NekoPlayState.fromValue(ev.f64.round());
            if (st != state) {
              state = st;
              changed = true;
            }
            if (st == NekoPlayState.playing) {
              final ao = e.audioOutput;
              if (ao != audioOutput) {
                audioOutput = ao;
                changed = true;
              }
            }
            break;
          case NekoEventType.position:
            if (!_seeking) {
              position = ev.f64;
              changed = true;
            }
            break;
          case NekoEventType.duration:
            duration = ev.f64;
            changed = true;
            break;
          case NekoEventType.endFile:
            // mpv mpv_end_file_reason：0=EOF 2=stop 3=quit 4=error 5=redirect 6=replaced。
            // EOF 后自动切下一首；error（4）交给宿主做断点续播（Qt handleRemoteStreamFailure）。
            if (ev.i64 == 0) {
              _onTrackEnded?.call();
            } else if (ev.i64 == 4) {
              _onStreamFailure?.call(position);
            }
            break;
          case NekoEventType.audioMeta:
            bitrate = ev.i64;
            changed = true;
            break;
          case NekoEventType.title:
            title = ev.str;
            changed = true;
            break;
          case NekoEventType.error:
            lastError = ev.str;
            changed = true;
            break;
          case NekoEventType.ready:
          case NekoEventType.seek:
          case NekoEventType.none:
            break;
        }
      }
      if (changed) notifyListeners();
    } finally {
      _draining = false;
    }
  }

  @override
  void dispose() {
    final e = _engine;
    e?.setEventCallback(nullptr);
    e?.destroy();
    _evCb?.close();
    super.dispose();
  }
}
