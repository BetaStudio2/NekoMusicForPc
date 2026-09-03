import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// libneko_core C API 的 Dart FFI 绑定。
/// 头文件：engine/core/neko_core.h

/// C 侧音乐行（仅 FFI 内部使用）
final class _NativeNekoCoreMusic extends Struct {
  @Int64()
  external int id;

  @Array(256)
  external Array<Uint8> title;

  @Array(256)
  external Array<Uint8> artist;

  @Array(256)
  external Array<Uint8> album;

  @Int64()
  external int duration;

  @Array(1024)
  external Array<Uint8> coverUrl;

  @Array(1024)
  external Array<Uint8> localPath;

  @Int64()
  external int playCount;

  @Int64()
  external int uploadedAtMs;

  @Int32()
  external int lrc;

  @Int64()
  external int progressReceived;

  @Int64()
  external int progressTotal;
}

/// C 侧本地歌单信息（仅 FFI 内部使用）
final class _NativeNekoCorePlaylist extends Struct {
  @Int64()
  external int localId;

  @Array(256)
  external Array<Uint8> name;

  @Array(512)
  external Array<Uint8> description;

  @Int64()
  external int coverMusicId;

  @Int64()
  external int musicCount;

  @Array(32)
  external Array<Uint8> createdAt;

  @Array(32)
  external Array<Uint8> updatedAt;
}

/// C 侧命令结果（仅 FFI 内部使用）
final class _NativeNekoCoreResult extends Struct {
  @Int64()
  external int seq;

  @Int32()
  external int ok;

  @Int32()
  external int nrows;

  @Int32()
  external int currentIndex;

  @Array(16)
  external Array<Uint8> playMode;

  @Array(64)
  external Array<_NativeNekoCoreMusic> rows;

  @Int32()
  external int nplaylists;

  @Array(64)
  external Array<_NativeNekoCorePlaylist> playlists;

  @Array(256)
  external Array<Uint8> message;

  @Array(256)
  external Array<Uint8> token;

  @Array(4096)
  external Array<Uint8> str;

  @Int64()
  external int i64;

  @Int64()
  external int progressReceived;

  @Int64()
  external int progressTotal;
}

/// Dart 侧音乐信息（普通对象，非 native 内存）
class NekoCoreMusic {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String coverUrl;
  final String localPath;
  final int playCount;
  final int uploadedAtMs;
  final bool lrc;
  final int progressReceived;
  final int progressTotal;

  const NekoCoreMusic({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.coverUrl,
    required this.localPath,
    required this.playCount,
    required this.uploadedAtMs,
    required this.lrc,
    this.progressReceived = 0,
    this.progressTotal = 0,
  });

  /// API 返回的 coverUrl 可能是相对路径，补全为绝对地址。
  String get fullCoverUrl =>
      coverUrl.startsWith('http') ? coverUrl : 'https://music.cnmsb.xin$coverUrl';

  /// 播放流地址（与旧版一致：{kApiBase}/api/music/file/{id}）
  String playUrl() => 'https://music.cnmsb.xin/api/music/file/$id';

  void toNative(Pointer<_NativeNekoCoreMusic> p) {
    p.ref.id = id;
    _writeCStr(p.ref.title, _kMaxTitle, title);
    _writeCStr(p.ref.artist, _kMaxArtist, artist);
    _writeCStr(p.ref.album, _kMaxAlbum, album);
    p.ref.duration = duration;
    _writeCStr(p.ref.coverUrl, _kMaxCover, coverUrl);
    _writeCStr(p.ref.localPath, _kMaxPath, localPath);
    p.ref.playCount = playCount;
    p.ref.uploadedAtMs = uploadedAtMs;
    p.ref.lrc = lrc ? 1 : 0;
    p.ref.progressReceived = progressReceived;
    p.ref.progressTotal = progressTotal;
  }
}

// 与 neko_core.h 的数组长度保持一致
const _kMaxTitle = 256;
const _kMaxArtist = 256;
const _kMaxAlbum = 256;
const _kMaxCover = 1024;
const _kMaxPath = 1024;
const _kMaxPlayMode = 16;
const _kMaxMessage = 256;
const _kMaxToken = 256;
const _kMaxStr = 4096;
const _kMaxPlaylistName = 256;
const _kMaxPlaylistDesc = 512;
const _kMaxTimeStr = 32;

void _writeCStr(Array<Uint8> arr, int maxLen, String value) {
  // C 侧按 UTF-8 接收（QString::fromUtf8），必须编码为 UTF-8 字节；
  // 之前误用 codeUnits（UTF-16 码元）导致中文参数（搜索词/歌单名）乱码。
  final bytes = utf8.encode(value);
  final n = bytes.length < maxLen - 1 ? bytes.length : maxLen - 1;
  for (var i = 0; i < n; i++) {
    arr[i] = bytes[i];
  }
  arr[n] = 0;
}

String _readCStr(Array<Uint8> arr, int maxLen) {
  // C 侧写入的是 UTF-8 字节（copyStr → toUtf8），须按 UTF-8 解码；
  // 之前逐字节 String.fromCharCodes（Latin-1）导致中文标题乱码。
  final bytes = <int>[];
  for (var i = 0; i < maxLen; i++) {
    final c = arr[i];
    if (c == 0) break;
    bytes.add(c);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _readPtrCStr(Pointer<Uint8> p, int maxLen) {
  final bytes = p.asTypedList(maxLen);
  final end = bytes.indexOf(0);
  final len = end == -1 ? maxLen : end;
  return utf8.decode(bytes.sublist(0, len), allowMalformed: true);
}

/// Dart 侧命令结果
class NekoCoreResult {
  final int seq;
  final bool ok;
  final List<NekoCoreMusic> rows;
  final int currentIndex;
  final String playMode;
  final List<NekoCorePlaylist> playlists;
  final String message;
  final String token;
  final String str;
  final int i64;
  final int progressReceived;
  final int progressTotal;

  const NekoCoreResult({
    required this.seq,
    required this.ok,
    required this.rows,
    required this.currentIndex,
    required this.playMode,
    required this.playlists,
    required this.message,
    required this.token,
    required this.str,
    required this.i64,
    this.progressReceived = 0,
    this.progressTotal = 0,
  });
}

/// Dart 侧本地歌单信息
class NekoCorePlaylist {
  final int localId;
  final String name;
  final String description;
  final int coverMusicId;
  final int musicCount;
  final String createdAt;
  final String updatedAt;

  const NekoCorePlaylist({
    required this.localId,
    required this.name,
    required this.description,
    required this.coverMusicId,
    required this.musicCount,
    required this.createdAt,
    required this.updatedAt,
  });
}

// ---- Native 函数签名 typedef ----
typedef _start_t = Int32 Function(Int32);
typedef _stop_t = Int32 Function();
typedef _cmd_2s_t = Int64 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _cmd_4s_t = Int64 Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _cmd_3s_t =
    Int64 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _cmd_1s_int_t = Int64 Function(Pointer<Utf8>, Int32);
typedef _cmd_1s_t = Int64 Function(Pointer<Utf8>);
typedef _cmd_0_t = Int64 Function();
typedef _cmd_int_t = Int64 Function(Int32);
typedef _cmd_3_t = Int64 Function(Pointer<Utf8>, Int32, Int32);
typedef _cmd_list_t = Int64 Function(Pointer<_NativeNekoCoreMusic>, Int32);
typedef _cmd_music_t = Int64 Function(Pointer<_NativeNekoCoreMusic>);
typedef _cmd_music_path_t =
    Int64 Function(Pointer<_NativeNekoCoreMusic>, Pointer<Utf8>);
typedef _cmd_i2s_t = Int64 Function(Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef _cmd_i1s_t = Int64 Function(Int32, Pointer<Utf8>);
typedef _cmd_music_i_t = Int64 Function(Int32, Pointer<_NativeNekoCoreMusic>);
typedef _cmd_i2_t = Int64 Function(Int32, Int32);
typedef _get_state_t = Int32 Function();
typedef _get_str_t = Int32 Function(Pointer<Utf8>, Int32);
typedef _poll_t = Int32 Function(Pointer<_NativeNekoCoreResult>);
typedef _core_event_cb_t = Void Function(Pointer<Void>);
typedef _set_core_event_cb_t = Void Function(Pointer<Void>, Pointer<Void>);

class NekoCore {
  late final DynamicLibrary _lib;

  late final int Function(int) _start;
  late final int Function() _stop;
  late final int Function(Pointer<Utf8>, Pointer<Utf8>) _login;
  late final int Function(
          Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)
      _register;
  late final int Function() _logout;
  late final int Function(Pointer<Utf8>, Pointer<Utf8>) _changePassword;
  late final int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)
      _sendVerification;
  late final int Function() _sliderChallenge;
  late final int Function(Pointer<Utf8>, int) _sliderVerify;
  late final int Function(Pointer<Utf8>) _sendResetCode;
  late final int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)
      _resetPassword;
  late final int Function() _vipPricing;
  late final int Function(int, Pointer<Utf8>) _vipPayCreate;
  late final int Function() _vipSyncStatus;
  late final int Function(Pointer<_NativeNekoCoreMusic>) _downloadMusic;
  late final int Function(int) _downloadCancel;
  late final int Function() _downloadsStatus;
  late final int Function() _fetchRanking;
  late final int Function(int) _fetchLatest;
  late final int Function() _fetchDaily;
  late final int Function(Pointer<Utf8>, int, int) _searchMusic;
  late final int Function(int) _fetchMusicInfo;
  late final int Function(int) _fetchLyrics;
  late final int Function() _fetchFavorites;
  late final int Function(int) _toggleFavorite;
  late final int Function() _queueLoad;
  late final int Function() _queueClear;
  late final int Function(Pointer<_NativeNekoCoreMusic>, int) _queueAddAll;
  late final int Function(int) _queueSetIndex;
  late final int Function(Pointer<Utf8>) _queueSetMode;
  late final int Function() _lanStart;
  late final int Function() _lanStop;
  late final int Function(Pointer<Utf8>) _lanSelectDevice;
  late final int Function(int) _lanSetAccount;
  late final int Function(int, int) _lanSetPlayerState;
  late final int Function() _lanPoll;
  late final int Function() _recentLoad;
  late final int Function(Pointer<_NativeNekoCoreMusic>) _recordRecent;
  late final int Function() _downloadsLoad;
  late final int Function(Pointer<_NativeNekoCoreMusic>, Pointer<Utf8>)
      _recordDownload;
  late final int Function(Pointer<Utf8>, Pointer<Utf8>) _createPlaylist;
  late final int Function(int) _deletePlaylist;
  late final int Function(int, Pointer<Utf8>, Pointer<Utf8>) _updatePlaylist;
  late final int Function() _loadPlaylists;
  late final int Function(int) _playlistDetail;
  late final int Function(int, Pointer<_NativeNekoCoreMusic>) _playlistAddMusic;
  late final int Function(int, int) _playlistRemoveMusic;
  late final int Function(Pointer<Utf8>) _fetchPlaylists;
  late final int Function(Pointer<Utf8>) _searchArtists;
  late final int Function() _fetchUserPlaylists;
  late final int Function() _fetchFavoritePlaylists;
  late final int Function(int) _fetchPlaylistMusic;
  late final int Function(int) _favoritePlaylist;
  late final int Function(int) _unfavoritePlaylist;
  late final int Function(Pointer<Utf8>, Pointer<Utf8>) _cloudCreatePlaylist;
  late final int Function(int) _cloudDeletePlaylist;
  late final int Function(Pointer<Utf8>) _fetchNeteasePlaylist;
  late final int Function(Pointer<Utf8>) _fetchQqPlaylist;
  late final int Function(Pointer<Utf8>) _batchSearchMusic;
  late final int Function(int, Pointer<Utf8>) _batchAddMusicToPlaylist;
  late final int Function() _getLoginState;
  late final int Function(Pointer<Utf8>, int) _getLoginInfo;
  late final int Function(Pointer<Utf8>, int) _audioHeaders;
  late final int Function(Pointer<_NativeNekoCoreResult>) _poll;
  late final void Function(Pointer<Void>, Pointer<Void>) _setEventCb;

  NekoCore() {
    _lib = _loadLibrary();

    _start = _lib.lookupFunction<_start_t, int Function(int)>('neko_core_start');
    _stop = _lib.lookupFunction<_stop_t, int Function()>('neko_core_stop');
    _login = _lib.lookupFunction<_cmd_2s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>)>('neko_core_cmd_login');
    _register = _lib.lookupFunction<
        _cmd_4s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
            Pointer<Utf8>)>('neko_core_cmd_register');
    _logout = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_logout');
    _changePassword = _lib.lookupFunction<
        _cmd_2s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_core_cmd_change_password');
    _sendVerification = _lib.lookupFunction<
        _cmd_3s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_core_cmd_send_verification');
    _sliderChallenge = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_slider_challenge');
    _sliderVerify = _lib.lookupFunction<
        _cmd_1s_int_t,
        int Function(Pointer<Utf8>, int)>('neko_core_cmd_slider_verify');
    _sendResetCode = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_send_reset_code');
    _resetPassword = _lib.lookupFunction<
        _cmd_3s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_core_cmd_reset_password');
    _vipPricing = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_vip_pricing');
    _vipPayCreate = _lib.lookupFunction<
        _cmd_i1s_t,
        int Function(int, Pointer<Utf8>)>('neko_core_cmd_vip_pay_create');
    _vipSyncStatus = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_vip_sync_status');
    _downloadMusic = _lib.lookupFunction<
        _cmd_music_t,
        int Function(Pointer<_NativeNekoCoreMusic>)>(
        'neko_core_cmd_download_music');
    _downloadCancel = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_download_cancel');
    _downloadsStatus = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_downloads_status');
    _fetchRanking = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_fetch_ranking');
    _fetchLatest = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_fetch_latest');
    _fetchDaily = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_fetch_daily');
    _searchMusic = _lib.lookupFunction<
        _cmd_3_t,
        int Function(Pointer<Utf8>, int, int)>('neko_core_cmd_search_music');
    _fetchMusicInfo = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_fetch_music_info');
    _fetchLyrics = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_fetch_lyrics');
    _fetchFavorites = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_fetch_favorites');
    _toggleFavorite = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_toggle_favorite');
    _queueLoad = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_queue_load');
    _queueClear = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_queue_clear');
    _queueAddAll = _lib.lookupFunction<
        _cmd_list_t,
        int Function(Pointer<_NativeNekoCoreMusic>, int)>(
        'neko_core_cmd_queue_add_all');
    _queueSetIndex = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_queue_set_index');
    _queueSetMode = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_queue_set_mode');
    _lanStart = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_lan_start');
    _lanStop = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_lan_stop');
    _lanSelectDevice = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_lan_select_device');
    _lanSetAccount = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_lan_set_account');
    _lanSetPlayerState = _lib.lookupFunction<_cmd_i2_t, int Function(int, int)>(
        'neko_core_cmd_lan_set_player_state');
    _lanPoll = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_lan_poll');
    _recentLoad = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_recent_load');
    _recordRecent = _lib.lookupFunction<
        _cmd_music_t,
        int Function(Pointer<_NativeNekoCoreMusic>)>(
        'neko_core_cmd_record_recent');
    _downloadsLoad = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_downloads_load');
    _recordDownload = _lib.lookupFunction<
        _cmd_music_path_t,
        int Function(Pointer<_NativeNekoCoreMusic>, Pointer<Utf8>)>(
        'neko_core_cmd_record_download');
    _createPlaylist = _lib.lookupFunction<
        _cmd_2s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_core_cmd_playlist_create');
    _deletePlaylist = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_playlist_delete');
    _updatePlaylist = _lib.lookupFunction<
        _cmd_i2s_t,
        int Function(int, Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_core_cmd_playlist_update');
    _loadPlaylists = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_playlist_list');
    _playlistDetail = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_playlist_detail');
    _playlistAddMusic = _lib.lookupFunction<
        _cmd_music_i_t,
        int Function(int, Pointer<_NativeNekoCoreMusic>)>(
        'neko_core_cmd_playlist_add_music');
    _playlistRemoveMusic = _lib.lookupFunction<_cmd_i2_t, int Function(int, int)>(
        'neko_core_cmd_playlist_remove_music');
    _fetchPlaylists = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_fetch_playlists');
    _searchArtists = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_search_artists');
    _fetchUserPlaylists = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_fetch_user_playlists');
    _fetchFavoritePlaylists = _lib.lookupFunction<_cmd_0_t, int Function()>(
        'neko_core_cmd_fetch_favorite_playlists');
    _fetchPlaylistMusic = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_fetch_playlist_music');
    _favoritePlaylist = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_favorite_playlist');
    _unfavoritePlaylist = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_unfavorite_playlist');
    _cloudCreatePlaylist = _lib.lookupFunction<
        _cmd_2s_t,
        int Function(Pointer<Utf8>, Pointer<Utf8>)>(
        'neko_core_cmd_cloud_playlist_create');
    _cloudDeletePlaylist = _lib.lookupFunction<_cmd_int_t, int Function(int)>(
        'neko_core_cmd_cloud_playlist_delete');
    _fetchNeteasePlaylist = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_fetch_netease_playlist');
    _fetchQqPlaylist = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_fetch_qq_playlist');
    _batchSearchMusic = _lib.lookupFunction<
        _cmd_1s_t,
        int Function(Pointer<Utf8>)>('neko_core_cmd_batch_search_music');
    _batchAddMusicToPlaylist = _lib.lookupFunction<
        _cmd_i1s_t,
        int Function(int, Pointer<Utf8>)>(
        'neko_core_cmd_batch_add_music_to_playlist');
    _getLoginState =
        _lib.lookupFunction<_get_state_t, int Function()>('neko_core_get_login_state');
    _getLoginInfo = _lib.lookupFunction<_get_str_t, int Function(Pointer<Utf8>, int)>(
        'neko_core_get_login_info');
    _audioHeaders = _lib.lookupFunction<_get_str_t, int Function(Pointer<Utf8>, int)>(
        'neko_core_audio_headers');
    _poll = _lib.lookupFunction<_poll_t, int Function(Pointer<_NativeNekoCoreResult>)>(
        'neko_core_poll');
    _setEventCb = _lib.lookupFunction<
        _set_core_event_cb_t,
        void Function(Pointer<Void>, Pointer<Void>)>(
        'neko_core_set_event_cb');
  }

  /// 启动 Qt 核心工作线程
  void start({bool verbose = false}) {
    final rc = _start(verbose ? 1 : 0);
    if (rc != 1) {
      throw StateError('neko_core_start failed ($rc)');
    }
  }

  void stop() => _stop();

  /// 注册结果推送回调（替代轮询）。传 null 取消。
  /// 回调可能从 worker 线程触发，宿主应在回调中尽快 poll 取走结果。
  void setEventCallback(Pointer<Void> cb) => _setEventCb(cb, nullptr);

  int login(String username, String password) {
    final u = username.toNativeUtf8();
    final p = password.toNativeUtf8();
    try {
      return _login(u, p);
    } finally {
      calloc.free(u);
      calloc.free(p);
    }
  }

  int register(String username, String password, String email, String code) {
    final u = username.toNativeUtf8();
    final p = password.toNativeUtf8();
    final e = email.toNativeUtf8();
    final c = code.toNativeUtf8();
    try {
      return _register(u, p, e, c);
    } finally {
      calloc.free(u);
      calloc.free(p);
      calloc.free(e);
      calloc.free(c);
    }
  }

  int logout() => _logout();

  int changePassword(String oldPassword, String newPassword) {
    final o = oldPassword.toNativeUtf8();
    final n = newPassword.toNativeUtf8();
    try {
      return _changePassword(o, n);
    } finally {
      calloc.free(o);
      calloc.free(n);
    }
  }

  int sendVerification(String email, String username, String captchaPassToken) {
    final e = email.toNativeUtf8();
    final u = username.toNativeUtf8();
    final t = captchaPassToken.toNativeUtf8();
    try {
      return _sendVerification(e, u, t);
    } finally {
      calloc.free(e);
      calloc.free(u);
      calloc.free(t);
    }
  }

  int sliderChallenge() => _sliderChallenge();

  int sliderVerify(String captchaToken, int offsetX) {
    final t = captchaToken.toNativeUtf8();
    try {
      return _sliderVerify(t, offsetX);
    } finally {
      calloc.free(t);
    }
  }

  int sendResetCode(String email) {
    final e = email.toNativeUtf8();
    try {
      return _sendResetCode(e);
    } finally {
      calloc.free(e);
    }
  }

  int resetPassword(String email, String code, String newPassword) {
    final e = email.toNativeUtf8();
    final c = code.toNativeUtf8();
    final n = newPassword.toNativeUtf8();
    try {
      return _resetPassword(e, c, n);
    } finally {
      calloc.free(e);
      calloc.free(c);
      calloc.free(n);
    }
  }

  // ── 会员中心 ──

  int vipPricing() => _vipPricing();

  int vipPayCreate(int pricingId, {String payType = 'alipay'}) {
    final p = payType.toNativeUtf8();
    try {
      return _vipPayCreate(pricingId, p);
    } finally {
      calloc.free(p);
    }
  }

  int vipSyncStatus() => _vipSyncStatus();

  // ── 下载管理 ──

  int downloadMusic(NekoCoreMusic music) {
    final ptr = calloc<_NativeNekoCoreMusic>();
    try {
      music.toNative(ptr);
      return _downloadMusic(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  int downloadCancel(int musicId) => _downloadCancel(musicId);
  int downloadsStatus() => _downloadsStatus();
  int fetchRanking() => _fetchRanking();
  int fetchLatest(int limit) => _fetchLatest(limit);
  int fetchDaily() => _fetchDaily();

  int searchMusic(String query, {int page = 1, int pageSize = 20}) {
    final q = query.toNativeUtf8();
    try {
      return _searchMusic(q, page, pageSize);
    } finally {
      calloc.free(q);
    }
  }

  int fetchMusicInfo(int musicId) => _fetchMusicInfo(musicId);
  int fetchLyrics(int musicId) => _fetchLyrics(musicId);
  int fetchFavorites() => _fetchFavorites();
  int toggleFavorite(int musicId) => _toggleFavorite(musicId);
  int queueLoad() => _queueLoad();
  int queueClear() => _queueClear();

  int queueAddAll(List<NekoCoreMusic> list) {
    if (list.isEmpty) return _queueAddAll(nullptr, 0);
    final ptr = calloc<_NativeNekoCoreMusic>(list.length);
    try {
      for (var i = 0; i < list.length; i++) {
        list[i].toNative(ptr.elementAt(i));
      }
      return _queueAddAll(ptr, list.length);
    } finally {
      calloc.free(ptr);
    }
  }

  int queueSetIndex(int index) => _queueSetIndex(index);

  int queueSetMode(String mode) {
    final m = mode.toNativeUtf8();
    try {
      return _queueSetMode(m);
    } finally {
      calloc.free(m);
    }
  }

  int lanStart() => _lanStart();
  int lanStop() => _lanStop();

  int lanSelectDevice(String deviceId) {
    final s = deviceId.toNativeUtf8();
    try {
      return _lanSelectDevice(s);
    } finally {
      calloc.free(s);
    }
  }

  int lanSetAccount(int userId) => _lanSetAccount(userId);
  int lanSetPlayerState(int musicId, bool playing) =>
      _lanSetPlayerState(musicId, playing ? 1 : 0);
  int lanPoll() => _lanPoll();

  int recentLoad() => _recentLoad();
  int recordRecent(NekoCoreMusic music) {
    final ptr = calloc<_NativeNekoCoreMusic>();
    try {
      music.toNative(ptr);
      return _recordRecent(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  int downloadsLoad() => _downloadsLoad();

  int recordDownload(NekoCoreMusic music, String filePath) {
    final ptr = calloc<_NativeNekoCoreMusic>();
    final f = filePath.toNativeUtf8();
    try {
      music.toNative(ptr);
      return _recordDownload(ptr, f);
    } finally {
      calloc.free(ptr);
      calloc.free(f);
    }
  }

  // ── 本地歌单 ──

  int createPlaylist(String name, {String description = ''}) {
    final n = name.toNativeUtf8();
    final d = description.toNativeUtf8();
    try {
      return _createPlaylist(n, d);
    } finally {
      calloc.free(n);
      calloc.free(d);
    }
  }

  int deletePlaylist(int localId) => _deletePlaylist(localId);

  int updatePlaylist(int localId, String name, {String description = ''}) {
    final n = name.toNativeUtf8();
    final d = description.toNativeUtf8();
    try {
      return _updatePlaylist(localId, n, d);
    } finally {
      calloc.free(n);
      calloc.free(d);
    }
  }

  int loadPlaylists() => _loadPlaylists();
  int playlistDetail(int localId) => _playlistDetail(localId);

  int addMusicToPlaylist(int localId, NekoCoreMusic music) {
    final ptr = calloc<_NativeNekoCoreMusic>();
    try {
      music.toNative(ptr);
      return _playlistAddMusic(localId, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  int removeMusicFromPlaylist(int localId, int musicId) =>
      _playlistRemoveMusic(localId, musicId);

  // ── 云端歌单 / 歌手 / 导入 ──

  int fetchPlaylists(String query) {
    final q = query.toNativeUtf8();
    try {
      return _fetchPlaylists(q);
    } finally {
      calloc.free(q);
    }
  }

  int searchArtists(String query) {
    final q = query.toNativeUtf8();
    try {
      return _searchArtists(q);
    } finally {
      calloc.free(q);
    }
  }

  int fetchUserPlaylists() => _fetchUserPlaylists();
  int fetchFavoritePlaylists() => _fetchFavoritePlaylists();
  int fetchPlaylistMusic(int playlistId) => _fetchPlaylistMusic(playlistId);
  int favoritePlaylist(int playlistId) => _favoritePlaylist(playlistId);
  int unfavoritePlaylist(int playlistId) => _unfavoritePlaylist(playlistId);

  int cloudCreatePlaylist(String name, {String description = ''}) {
    final n = name.toNativeUtf8();
    final d = description.toNativeUtf8();
    try {
      return _cloudCreatePlaylist(n, d);
    } finally {
      calloc.free(n);
      calloc.free(d);
    }
  }

  int cloudDeletePlaylist(int playlistId) => _cloudDeletePlaylist(playlistId);

  int fetchNeteasePlaylist(String playlistId) {
    final s = playlistId.toNativeUtf8();
    try {
      return _fetchNeteasePlaylist(s);
    } finally {
      calloc.free(s);
    }
  }

  int fetchQqPlaylist(String disstid) {
    final s = disstid.toNativeUtf8();
    try {
      return _fetchQqPlaylist(s);
    } finally {
      calloc.free(s);
    }
  }

  int batchSearchMusic(String itemsJson) {
    final s = itemsJson.toNativeUtf8();
    try {
      return _batchSearchMusic(s);
    } finally {
      calloc.free(s);
    }
  }

  int batchAddMusicToPlaylist(int playlistId, String idsJson) {
    final s = idsJson.toNativeUtf8();
    try {
      return _batchAddMusicToPlaylist(playlistId, s);
    } finally {
      calloc.free(s);
    }
  }

  bool get isLoggedIn => _getLoginState() == 1;

  /// 登录用户信息 JSON；未登录返回空串
  String get loginInfo {
    final buf = calloc<Uint8>(4096);
    try {
      final rc = _getLoginInfo(buf.cast(), 4096);
      return rc == 0 ? '' : _readPtrCStr(buf.cast(), 4096);
    } finally {
      calloc.free(buf);
    }
  }

  /// 流媒体请求头；未登录返回空
  String get audioHeaders {
    final buf = calloc<Uint8>(4096);
    try {
      final rc = _audioHeaders(buf.cast(), 4096);
      return rc == 0 ? '' : _readPtrCStr(buf.cast(), 4096);
    } finally {
      calloc.free(buf);
    }
  }

  /// 取出并消费一条命令结果；返回 null 表示队列为空。
  NekoCoreResult? poll() {
    final r = calloc<_NativeNekoCoreResult>();
    try {
      final rc = _poll(r);
      if (rc == 0) return null;
      final rows = <NekoCoreMusic>[];
      for (var i = 0; i < r.ref.nrows; i++) {
        final m = r.ref.rows[i];
        rows.add(NekoCoreMusic(
          id: m.id,
          title: _readCStr(m.title, _kMaxTitle),
          artist: _readCStr(m.artist, _kMaxArtist),
          album: _readCStr(m.album, _kMaxAlbum),
          duration: m.duration,
          coverUrl: _readCStr(m.coverUrl, _kMaxCover),
          localPath: _readCStr(m.localPath, _kMaxPath),
          playCount: m.playCount,
          uploadedAtMs: m.uploadedAtMs,
          lrc: m.lrc != 0,
          progressReceived: m.progressReceived,
          progressTotal: m.progressTotal,
        ));
      }
      final playlists = <NekoCorePlaylist>[];
      for (var i = 0; i < r.ref.nplaylists; i++) {
        final p = r.ref.playlists[i];
        playlists.add(NekoCorePlaylist(
          localId: p.localId,
          name: _readCStr(p.name, _kMaxPlaylistName),
          description: _readCStr(p.description, _kMaxPlaylistDesc),
          coverMusicId: p.coverMusicId,
          musicCount: p.musicCount,
          createdAt: _readCStr(p.createdAt, _kMaxTimeStr),
          updatedAt: _readCStr(p.updatedAt, _kMaxTimeStr),
        ));
      }
      return NekoCoreResult(
        seq: r.ref.seq,
        ok: r.ref.ok != 0,
        rows: rows,
        currentIndex: r.ref.currentIndex,
        playMode: _readCStr(r.ref.playMode, _kMaxPlayMode),
        playlists: playlists,
        message: _readCStr(r.ref.message, _kMaxMessage),
        token: _readCStr(r.ref.token, _kMaxToken),
        str: _readCStr(r.ref.str, _kMaxStr),
        i64: r.ref.i64,
        progressReceived: r.ref.progressReceived,
        progressTotal: r.ref.progressTotal,
      );
    } finally {
      calloc.free(r);
    }
  }

  static DynamicLibrary _loadLibrary() {
    final candidates = <String>[
      Platform.environment['NEKO_CORE_PATH'] ?? '',
      // Windows bundle：DLL 随包分发在 exe 旁
      'neko_core.dll',
      'libneko_core.so',
      '../engine/build/libneko_core.so',
      '../engine/build/neko_core.dll',
      '../engine/build/libneko_core.dylib',
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
        'libneko_core not found. Build engine/ first, or set NEKO_CORE_PATH.');
  }
}
