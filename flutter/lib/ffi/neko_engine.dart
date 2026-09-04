import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// libneko_engine C API 的 Dart FFI 绑定。
/// 头文件：engine/include/neko_engine.h

/// C 侧事件结构（仅 FFI 内部使用，见 neko_engine.h）
final class _NativeNekoEvent extends Struct {
  @Int32()
  external int type;

  @Double()
  external double f64;

  @Int64()
  external int i64;

  @Array(256)
  external Array<Uint8> str;
}

/// Dart 侧事件（普通对象，非 native 内存）
class NekoEvent {
  final int type;
  final double f64;
  final int i64;
  final String str;

  const NekoEvent({
    required this.type,
    required this.f64,
    required this.i64,
    required this.str,
  });
}

enum NekoPlayState {
  stopped(0),
  playing(1),
  paused(2);

  const NekoPlayState(this.value);
  final int value;

  static NekoPlayState fromValue(int v) =>
      NekoPlayState.values.firstWhere((e) => e.value == v,
          orElse: () => NekoPlayState.stopped);
}

enum NekoEventType {
  none(0),
  state(1),
  position(2),
  duration(3),
  endFile(4),
  audioMeta(5),
  title(6),
  error(7),
  seek(8),
  ready(9);

  const NekoEventType(this.value);
  final int value;

  static NekoEventType fromValue(int v) =>
      NekoEventType.values.firstWhere((e) => e.value == v,
          orElse: () => NekoEventType.none);
}

// ---- Native 函数签名 typedef ----
typedef _create_t = Pointer<Void> Function();
typedef _initialize_t = Int32 Function(Pointer<Void>, Int32);
typedef _destroy_t = Int32 Function(Pointer<Void>);
typedef _set_option_t = Int32 Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _load_t = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef _set_resume_t = Int32 Function(Pointer<Void>, Double);
typedef _play_t = Int32 Function(Pointer<Void>);
typedef _pause_t = Int32 Function(Pointer<Void>);
typedef _stop_t = Int32 Function(Pointer<Void>);
typedef _seek_t = Int32 Function(Pointer<Void>, Double, Int32);
typedef _set_volume_t = Int32 Function(Pointer<Void>, Double);
typedef _get_volume_t = Double Function(Pointer<Void>);
typedef _get_state_t = Int32 Function(Pointer<Void>);
typedef _get_position_t = Double Function(Pointer<Void>);
typedef _get_duration_t = Double Function(Pointer<Void>);
typedef _get_ao_t = Void Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef _get_bitrate_t = Int64 Function(Pointer<Void>);
typedef _poll_event_t = Int32 Function(
    Pointer<Void>, Pointer<_NativeNekoEvent>);
typedef _last_error_t = Void Function(Pointer<Utf8>, Int32);
typedef _event_cb_t = Void Function(Pointer<Void>);
typedef _set_event_cb_t = Void Function(
    Pointer<Void>, Pointer<Void>, Pointer<Void>);

class NekoEngine {
  late final DynamicLibrary _lib;

  // 生命周期
  late final Pointer<Void> Function() _create;
  late final int Function(Pointer<Void>, int) _initialize;
  late final int Function(Pointer<Void>) _destroy;
  late final int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)
      _setOption;
  late final int Function(Pointer<Void>, Pointer<Utf8>) _load;
  late final int Function(Pointer<Void>, double) _setResumePosition;

  // 播放控制
  late final int Function(Pointer<Void>) _play;
  late final int Function(Pointer<Void>) _pause;
  late final int Function(Pointer<Void>) _stop;
  late final int Function(Pointer<Void>, double, int) _seek;
  late final int Function(Pointer<Void>, double) _setVolume;
  late final double Function(Pointer<Void>) _getVolume;

  // 查询
  late final int Function(Pointer<Void>) _getState;
  late final double Function(Pointer<Void>) _getPosition;
  late final double Function(Pointer<Void>) _getDuration;
  late final void Function(Pointer<Void>, Pointer<Utf8>, int) _getAudioOutput;
  late final int Function(Pointer<Void>) _getAudioBitrate;

  // 事件
  late final int Function(Pointer<Void>, Pointer<_NativeNekoEvent>) _pollEvent;
  late final void Function(Pointer<Void>, Pointer<Void>, Pointer<Void>)
      _setEventCb;

  late final Pointer<Void> _handle;

  NekoEngine() {
    _lib = _loadLibrary();

    _create = _lib.lookupFunction<_create_t, Pointer<Void> Function()>(
        'neko_create');
    _initialize =
        _lib.lookupFunction<_initialize_t, int Function(Pointer<Void>, int)>(
            'neko_initialize');
    _destroy =
        _lib.lookupFunction<_destroy_t, int Function(Pointer<Void>)>(
            'neko_destroy');
    _setOption = _lib.lookupFunction<
        _set_option_t,
        int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_set_option');
    _load = _lib.lookupFunction<_load_t, int Function(Pointer<Void>, Pointer<Utf8>)>(
        'neko_load');
    _setResumePosition = _lib.lookupFunction<
        _set_resume_t,
        int Function(Pointer<Void>, double)>('neko_set_resume_position');

    _play = _lib.lookupFunction<_play_t, int Function(Pointer<Void>)>(
        'neko_play');
    _pause = _lib.lookupFunction<_pause_t, int Function(Pointer<Void>)>(
        'neko_pause');
    _stop = _lib.lookupFunction<_stop_t, int Function(Pointer<Void>)>(
        'neko_stop');
    _seek = _lib.lookupFunction<
        _seek_t,
        int Function(Pointer<Void>, double, int)>('neko_seek');
    _setVolume = _lib.lookupFunction<
        _set_volume_t,
        int Function(Pointer<Void>, double)>('neko_set_volume');
    _getVolume = _lib.lookupFunction<_get_volume_t, double Function(Pointer<Void>)>(
        'neko_get_volume');

    _getState = _lib.lookupFunction<_get_state_t, int Function(Pointer<Void>)>(
        'neko_get_state');
    _getPosition = _lib
        .lookupFunction<_get_position_t, double Function(Pointer<Void>)>(
            'neko_get_position');
    _getDuration = _lib
        .lookupFunction<_get_duration_t, double Function(Pointer<Void>)>(
            'neko_get_duration');
    _getAudioOutput = _lib.lookupFunction<
        _get_ao_t,
        void Function(Pointer<Void>, Pointer<Utf8>, int)>(
        'neko_get_audio_output');
    _getAudioBitrate = _lib.lookupFunction<
        _get_bitrate_t,
        int Function(Pointer<Void>)>('neko_get_audio_bitrate');

    _pollEvent = _lib.lookupFunction<
        _poll_event_t,
        int Function(Pointer<Void>, Pointer<_NativeNekoEvent>)>(
        'neko_poll_event');
    _setEventCb = _lib.lookupFunction<
        _set_event_cb_t,
        void Function(Pointer<Void>, Pointer<Void>, Pointer<Void>)>(
        'neko_engine_set_event_cb');

    _handle = _create();
    if (_handle == nullptr) {
      final hint = NekoEngine.fetchLastError();
      throw StateError('neko_create failed${hint.isEmpty ? '' : ' | $hint'}');
    }
  }

  /// 读取 C 侧最近一次错误诊断（创建/初始化失败原因），失败或为空时返回空串。
  static String fetchLastError() {
    try {
      final lib = _loadLibrary();
      final fn = lib.lookupFunction<_last_error_t, void Function(Pointer<Utf8>, int)>(
          'neko_last_error');
      final buf = calloc<Uint8>(512);
      try {
        fn(buf.cast(), 512);
        final bytes = buf.cast<Uint8>().asTypedList(512);
        final end = bytes.indexOf(0);
        final len = end == -1 ? 512 : end;
        return utf8.decode(bytes.sublist(0, len), allowMalformed: true);
      } finally {
        calloc.free(buf);
      }
    } catch (_) {
      return '';
    }
  }

  void initialize({bool verbose = false}) {
    final rc = _initialize(_handle, verbose ? 1 : 0);
    if (rc != 0) {
      throw StateError('neko_initialize failed ($rc)');
    }
  }

  void destroy() {
    _destroy(_handle);
  }

  void setOption(String name, String value) {
    final n = name.toNativeUtf8();
    final v = value.toNativeUtf8();
    try {
      _setOption(_handle, n, v);
    } finally {
      calloc.free(n);
      calloc.free(v);
    }
  }

  void load(String url) {
    final u = url.toNativeUtf8();
    try {
      final rc = _load(_handle, u);
      if (rc != 0) {
        throw StateError('neko_load failed ($rc)');
      }
    } finally {
      calloc.free(u);
    }
  }

  void setResumePosition(double seconds) => _setResumePosition(_handle, seconds);

  void play() => _play(_handle);
  void pause() => _pause(_handle);
  void stop() => _stop(_handle);
  void seek(double seconds, {bool absolute = true}) =>
      _seek(_handle, seconds, absolute ? 1 : 0);
  void setVolume(double volume) => _setVolume(_handle, volume);

  double get volume => _getVolume(_handle);
  NekoPlayState get state => NekoPlayState.fromValue(_getState(_handle));
  double get position => _getPosition(_handle);
  double get duration => _getDuration(_handle);
  int get audioBitrate => _getAudioBitrate(_handle);

  String get audioOutput {
    final buf = calloc<Uint8>(128);
    try {
      _getAudioOutput(_handle, buf.cast(), 128);
      final bytes = buf.cast<Uint8>().asTypedList(128);
      final end = bytes.indexOf(0);
      final len = end == -1 ? 128 : end;
      return utf8.decode(bytes.sublist(0, len), allowMalformed: true);
    } finally {
      calloc.free(buf);
    }
  }

  /// 取出并消费一条事件；返回 null 表示队列为空。
  NekoEvent? pollEvent() {
    final ev = calloc<_NativeNekoEvent>();
    try {
      final rc = _pollEvent(_handle, ev);
      if (rc == 0) return null;
      final bytes = <int>[];
      for (var i = 0; i < 256; i++) {
        final c = ev.ref.str[i];
        if (c == 0) break;
        bytes.add(c);
      }
      return NekoEvent(
        type: ev.ref.type,
        f64: ev.ref.f64,
        i64: ev.ref.i64,
        str: utf8.decode(bytes, allowMalformed: true),
      );
    } finally {
      calloc.free(ev);
    }
  }

  /// 注册事件推送回调（替代轮询）。传 null 取消。
  /// 回调可能从任意线程触发，宿主应在回调中尽快 pollEvent 取走队列。
  void setEventCallback(Pointer<Void> cb) =>
      _setEventCb(_handle, cb, nullptr);

  static DynamicLibrary _loadLibrary() {
    final candidates = <String>[
      // 1) 环境变量显式指定
      Platform.environment['NEKO_ENGINE_PATH'] ?? '',
      // Windows bundle：DLL 随包分发在 exe 旁
      'neko_engine.dll',
      // 2) bundle / 标准搜索路径（flutter run 时 cwd 为项目目录）
      'libneko_engine.so',
      // 3) 开发时常见位置（相对 flutter 项目目录）
      '../engine/build/libneko_engine.so',
      '../engine/build/neko_engine.dll',
      '../engine/build/libneko_engine.dylib',
    ];
    for (final c in candidates) {
      if (c.isEmpty) continue;
      try {
        if (c.contains('/') || c.contains(r'\')) {
          if (File(c).existsSync()) return DynamicLibrary.open(c);
        } else {
          return DynamicLibrary.open(c);
        }
      } catch (_) {}
    }
    throw StateError(
        'libneko_engine not found. Build engine/ first, or set NEKO_ENGINE_PATH.');
  }
}
