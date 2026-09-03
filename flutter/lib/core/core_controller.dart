import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../ffi/neko_core.dart';
import '../main.dart';

/// Qt 核心桥控制器：封装 neko_core FFI + 结果推送，向 UI 暴露响应式状态。
///
/// 线程模型：命令经 FFI 投递到 C 侧 Qt 工作线程执行，结果写回队列后触发
/// [NativeCallable.listener] 回调（投递到主隔离区执行），本控制器随即一次性
/// 取空队列——全程无 Timer 轮询，UI 线程不因取结果而阻塞。
class CoreController extends ChangeNotifier {
  CoreController({NekoCore? core}) : _core = core ?? NekoCore() {
    _core.start(verbose: kDebugMode);
    // listener：可从 Qt worker 线程调用，回调投递到本隔离区执行
    _evCb = NativeCallable<Void Function(Pointer<Void>)>.listener(
        _onNativeEvent);
    _core.setEventCallback(_evCb!.nativeFunction.cast());
    // 兜底：拉取注册回调前可能已入队的结果
    _drain();
    _boot();
  }

  final NekoCore _core;
  NativeCallable<Void Function(Pointer<Void>)>? _evCb;
  bool _draining = false;

  // ── 数据状态 ──
  List<NekoCoreMusic> ranking = [];
  List<NekoCoreMusic> latest = [];
  List<NekoCoreMusic> daily = [];
  List<NekoCoreMusic> favorites = [];
  Set<int> favoriteIds = {};
  List<NekoCoreMusic> queue = [];
  int currentIndex = -1;
  String playMode = 'list';
  List<NekoCoreMusic> recents = [];
  List<NekoCoreMusic> downloads = [];
  List<NekoCorePlaylist> playlists = [];
  List<NekoCorePlaylist> homePlaylists = [];
  List<NekoCorePlaylist> myPlaylists = [];
  List<NekoCorePlaylist> favPlaylists = [];
  Set<int> favPlaylistIds = {};
  Map<String, dynamic>? userInfo;

  /// 下载队列状态（进行中 + 排队；进度字段实时更新）
  List<NekoCoreMusic> downloadsActive = [];
  final _downloadProgressCtrl = StreamController<NekoCoreMusic>.broadcast();
  Stream<NekoCoreMusic> get downloadProgress => _downloadProgressCtrl.stream;

  /// 当前播放歌曲（点击播放/切换时更新；URL 直播时为 null）
  NekoCoreMusic? current;
  String lyrics = '';
  bool loadingLyrics = false;
  bool loading = false;
  String? error;

  // ── LAN 设备同步 ──
  List<Map<String, dynamic>> lanDevices = [];
  Map<String, dynamic>? lanRemoteQueue;
  bool lanConnected = false;
  String lanSelectedDeviceId = '';

  bool get isLoggedIn => userInfo != null;
  int _seq = 0;

  final Map<int, void Function(NekoCoreResult)> _pending = {};

  /// 启动初始化：恢复登录态 + 拉取初始数据
  Future<void> _boot() async {
    // 同步读取登录态（worker 空闲时阻塞极短）
    final infoJson = _core.loginInfo;
    if (infoJson.isNotEmpty) {
      try {
        userInfo = jsonDecode(infoJson) as Map<String, dynamic>;
        lanInit();
      } catch (_) {
        userInfo = null;
      }
    }
    notifyListeners();
    _requestQueue();
    _requestFavorites();
    _requestRanking();
    _requestLatest();
    _requestPlaylists();
    _requestHomePlaylists();
    _requestCloudPlaylists();
    _requestDownloads();
    _requestDownloadsStatus();
  }

  /// 当前歌曲对应的本地已下载文件（用于在线断流时改播本地续播）；
  /// 无匹配或文件不存在返回 null。
  String? localFileFor(NekoCoreMusic music) {
    if (music.id <= 0) return null;
    for (final d in downloads) {
      if (d.id == music.id &&
          d.localPath.isNotEmpty &&
          File(d.localPath).existsSync()) {
        return d.localPath;
      }
    }
    return null;
  }

  // ── 通用请求 ──

  int _post(int Function() fn, void Function(NekoCoreResult) onDone) {
    final seq = fn();
    if (seq != 0) _pending[seq] = onDone;
    return seq;
  }

  void _requestRanking() {
    _post(_core.fetchRanking, (r) {
      if (r.ok) {
        ranking = r.rows;
      } else {
        error = r.message;
      }
      notifyListeners();
    });
  }

  void _requestLatest() {
    _post(() => _core.fetchLatest(20), (r) {
      if (r.ok) latest = r.rows;
      notifyListeners();
    });
  }

  /// 拉取每日推荐（需登录）
  void fetchDaily() {
    _post(_core.fetchDaily, (r) {
      if (r.ok) {
        daily = r.rows;
      } else {
        error = r.message;
      }
      notifyListeners();
    });
  }

  void _requestQueue() {
    _post(_core.queueLoad, (r) {
      queue = r.rows;
      currentIndex = r.currentIndex;
      playMode = r.playMode;
      notifyListeners();
    });
  }

  void _requestFavorites() {
    _post(_core.fetchFavorites, (r) {
      favorites = r.rows;
      favoriteIds = r.rows.map((m) => m.id).toSet();
      notifyListeners();
    });
  }

  void _requestRecents() {
    _post(_core.recentLoad, (r) {
      recents = r.rows;
      notifyListeners();
    });
  }

  void _requestDownloads() {
    _post(_core.downloadsLoad, (r) {
      downloads = r.rows;
      notifyListeners();
    });
  }

  // ── 本地歌单 ──

  void _requestPlaylists() {
    _post(_core.loadPlaylists, (r) {
      playlists = r.playlists;
      notifyListeners();
    });
  }

  /// 新建歌单；成功后刷新列表
  void createPlaylist(String name, {String description = ''}) {
    _post(() => _core.createPlaylist(name, description: description), (r) {
      if (r.ok) _requestPlaylists();
      notifyListeners();
    });
  }

  /// 删除歌单；成功后刷新列表
  void deletePlaylist(int localId) {
    _post(() => _core.deletePlaylist(localId), (r) {
      if (r.ok) _requestPlaylists();
      notifyListeners();
    });
  }

  /// 重命名歌单；成功后刷新列表
  void renamePlaylist(int localId, String name, {String description = ''}) {
    _post(() => _core.updatePlaylist(localId, name, description: description),
        (r) {
      if (r.ok) _requestPlaylists();
      notifyListeners();
    });
  }

  /// 拉取歌单内歌曲列表（详情页用）
  void loadPlaylistDetail(int localId,
      {void Function(List<NekoCoreMusic> songs)? onDone}) {
    _post(() => _core.playlistDetail(localId), (r) {
      onDone?.call(r.ok ? r.rows : const []);
    });
  }

  /// 向歌单添加歌曲；成功后可选回调
  void addToPlaylist(int localId, NekoCoreMusic music,
      {void Function(bool ok)? onDone}) {
    _post(() => _core.addMusicToPlaylist(localId, music), (r) {
      onDone?.call(r.ok);
      if (r.ok) _requestPlaylists();
    });
  }

  /// 从歌单移除歌曲；成功后可选回调
  void removeFromPlaylist(int localId, NekoCoreMusic music,
      {void Function(bool ok)? onDone}) {
    _post(() => _core.removeMusicFromPlaylist(localId, music.id), (r) {
      onDone?.call(r.ok);
      if (r.ok) _requestPlaylists();
    });
  }

  // ── 云端歌单 / 推荐歌单 ──

  /// 首页推荐歌单（query 为空串 = 推荐列表）
  void _requestHomePlaylists() {
    _post(() => _core.fetchPlaylists(''), (r) {
      if (r.ok) homePlaylists = r.playlists;
      notifyListeners();
    });
  }

  /// 我的 + 收藏的云端歌单（需登录；未登录清空）
  void _requestCloudPlaylists() {
    if (!isLoggedIn) {
      myPlaylists = [];
      favPlaylists = [];
      favPlaylistIds = {};
      notifyListeners();
      return;
    }
    _post(_core.fetchUserPlaylists, (r) {
      if (r.ok) myPlaylists = r.playlists;
      notifyListeners();
    });
    _post(_core.fetchFavoritePlaylists, (r) {
      if (r.ok) {
        favPlaylists = r.playlists;
        favPlaylistIds = r.playlists.map((p) => p.localId).toSet();
      }
      notifyListeners();
    });
  }

  /// 搜索歌单（query 为空串 = 推荐）
  void searchPlaylists(String query,
      {void Function(List<NekoCorePlaylist> results)? onDone}) {
    _post(() => _core.fetchPlaylists(query), (r) {
      onDone?.call(r.ok ? r.playlists : const []);
    });
  }

  /// 搜索歌手；artist 为 null 表示无匹配
  void searchArtists(String query,
      {void Function(Map<String, dynamic>? artist)? onDone}) {
    _post(() => _core.searchArtists(query), (r) {
      if (!r.ok || r.str.isEmpty) {
        onDone?.call(null);
        return;
      }
      try {
        onDone?.call(jsonDecode(r.str) as Map<String, dynamic>);
      } catch (_) {
        onDone?.call(null);
      }
    });
  }

  /// 拉取云端歌单内歌曲（详情页用）
  void loadCloudPlaylistMusic(int playlistId,
      {void Function(List<NekoCoreMusic> songs)? onDone}) {
    _post(() => _core.fetchPlaylistMusic(playlistId), (r) {
      onDone?.call(r.ok ? r.rows : const []);
    });
  }

  /// 收藏 / 取消收藏云端歌单
  void toggleFavoritePlaylist(int playlistId) {
    final fav = favPlaylistIds.contains(playlistId);
    _post(
        () => fav
            ? _core.unfavoritePlaylist(playlistId)
            : _core.favoritePlaylist(playlistId), (r) {
      if (r.ok) _requestCloudPlaylists();
      notifyListeners();
    });
  }

  /// 新建云端歌单；成功回调 id
  void createCloudPlaylist(String name,
      {String description = '', void Function(int? id)? onDone}) {
    _post(() => _core.cloudCreatePlaylist(name, description: description),
        (r) {
      onDone?.call(r.ok ? r.i64.toInt() : null);
      if (r.ok) _requestCloudPlaylists();
    });
  }

  /// 删除云端歌单
  void deleteCloudPlaylist(int playlistId) {
    _post(() => _core.cloudDeletePlaylist(playlistId), (r) {
      if (r.ok) _requestCloudPlaylists();
      notifyListeners();
    });
  }

  // ── 歌单导入（网易云 / QQ） ──

  /// 拉取网易云歌单；info 为 {"name","tracks":[{name,artist}]}，error 非空表示失败
  void fetchNeteasePlaylist(String playlistId,
      {void Function(Map<String, dynamic>? info, String? error)? onDone}) {
    _post(() => _core.fetchNeteasePlaylist(playlistId), (r) {
      if (!r.ok) {
        onDone?.call(null, r.message.isEmpty ? ThemeController.instance.t('拉取失败','Fetch failed') : r.message);
        return;
      }
      try {
        onDone?.call(jsonDecode(r.str) as Map<String, dynamic>, null);
      } catch (_) {
        onDone?.call(null, ThemeController.instance.t('数据解析失败','Failed to parse data'));
      }
    });
  }

  /// 拉取 QQ 音乐歌单
  void fetchQqPlaylist(String disstid,
      {void Function(Map<String, dynamic>? info, String? error)? onDone}) {
    _post(() => _core.fetchQqPlaylist(disstid), (r) {
      if (!r.ok) {
        onDone?.call(null, r.message.isEmpty ? ThemeController.instance.t('拉取失败','Fetch failed') : r.message);
        return;
      }
      try {
        onDone?.call(jsonDecode(r.str) as Map<String, dynamic>, null);
      } catch (_) {
        onDone?.call(null, ThemeController.instance.t('数据解析失败','Failed to parse data'));
      }
    });
  }

  /// 批量搜索匹配歌曲；result 为 {"matchedMusicIds":[...],"successCount","failCount"}
  void batchSearchMusic(List<Map<String, String>> items,
      {void Function(Map<String, dynamic>? result, String? error)? onDone}) {
    _post(() => _core.batchSearchMusic(jsonEncode(items)), (r) {
      if (!r.ok) {
        onDone?.call(null, r.message.isEmpty ? ThemeController.instance.t('搜索失败','Search failed') : r.message);
        return;
      }
      try {
        onDone?.call(jsonDecode(r.str) as Map<String, dynamic>, null);
      } catch (_) {
        onDone?.call(null, ThemeController.instance.t('数据解析失败','Failed to parse data'));
      }
    });
  }

  /// 批量把匹配到的歌曲加入云端歌单；result 为 {"addedCount"}
  void batchAddMusicToPlaylist(int playlistId, List<int> musicIds,
      {void Function(Map<String, dynamic>? result, String? error)? onDone}) {
    _post(() => _core.batchAddMusicToPlaylist(playlistId, jsonEncode(musicIds)),
        (r) {
      if (!r.ok) {
        onDone?.call(null, r.message.isEmpty ? ThemeController.instance.t('添加失败','Add failed') : r.message);
        return;
      }
      try {
        onDone?.call(jsonDecode(r.str) as Map<String, dynamic>, null);
      } catch (_) {
        onDone?.call(null, ThemeController.instance.t('数据解析失败','Failed to parse data'));
      }
    });
  }

  // ── 登录增强：改密 / 滑块验证 / 邮箱验证码 / 找回密码 ──

  /// 修改密码；onDone(ok, message)
  void changePassword(String oldPassword, String newPassword,
      {void Function(bool ok, String message)? onDone}) {
    _post(() => _core.changePassword(oldPassword, newPassword), (r) {
      onDone?.call(r.ok, r.message);
    });
  }

  /// 注册前发送邮箱验证码（需先滑块通过取得 captchaPassToken）
  void sendVerification(String email, String username, String captchaPassToken,
      {void Function(bool ok, String message)? onDone}) {
    _post(() => _core.sendVerification(email, username, captchaPassToken), (r) {
      onDone?.call(r.ok, r.message);
    });
  }

  /// 公开 API 基址（滑块验证码为公开接口，直接 HTTP 获取；
  /// 不走 Qt 桥——其结果缓冲 str[4096] 装不下含 base64 图片的响应）
  static const String _apiBase = 'https://music.cnmsb.xin';

  /// 获取滑块验证码 challenge；data 为
  /// {captchaToken,bgImage,sliderImage,bgWidth,bgHeight,puzzleY,sliderWidth,sliderHeight}
  Future<void> sliderChallenge(
      {void Function(bool ok, Map<String, dynamic>? data, String message)?
          onDone}) async {
    try {
      final resp = await HttpClient()
          .getUrl(Uri.parse('$_apiBase/api/captcha/slider'))
          .then((req) => req.close())
          .timeout(const Duration(seconds: 8));
      final body = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      final d = jsonDecode(body) as Map<String, dynamic>;
      final ok = d['success'] == true;
      final data = d['data'];
      onDone?.call(
          ok,
          data is Map<String, dynamic> ? data : null,
          (d['message'] as String?) ??
              (ok ? '' : ThemeController.instance.t('验证码加载失败','Failed to load captcha')));
    } catch (e) {
      onDone?.call(false, null, '验证码加载失败：$e');
    }
  }

  /// 校验滑块；成功返回 captchaPassToken
  Future<void> sliderVerify(String captchaToken, int offsetX,
      {void Function(bool ok, String passToken, String message)? onDone}) async {
    try {
      final req = await HttpClient()
          .postUrl(Uri.parse('$_apiBase/api/captcha/slider/verify'))
          .timeout(const Duration(seconds: 8));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(
          {'captchaToken': captchaToken, 'captchaOffsetX': offsetX})));
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await resp.transform(utf8.decoder).join();
      final d = jsonDecode(body) as Map<String, dynamic>;
      final ok = d['success'] == true;
      final data = d['data'];
      final pass = data is Map<String, dynamic>
          ? (data['captchaPassToken'] as String? ?? '')
          : '';
      onDone?.call(ok, pass, (d['message'] as String?) ?? '');
    } catch (e) {
      onDone?.call(false, '', '验证失败：$e');
    }
  }

  /// 忘记密码：发送重置验证码到邮箱
  void sendResetCode(String email,
      {void Function(bool ok, String message)? onDone}) {
    _post(() => _core.sendResetCode(email), (r) {
      onDone?.call(r.ok, r.message);
    });
  }

  /// 忘记密码：校验验证码并重置密码
  void resetPassword(String email, String code, String newPassword,
      {void Function(bool ok, String message)? onDone}) {
    _post(() => _core.resetPassword(email, code, newPassword), (r) {
      onDone?.call(r.ok, r.message);
    });
  }

  // ── 会员中心 ──

  /// 获取 VIP 套餐列表；items 为 [{id,name,price,...}]
  void vipPricing(
      {void Function(bool ok, List<Map<String, dynamic>> items, String message)?
          onDone}) {
    _post(_core.vipPricing, (r) {
      if (!r.ok) {
        onDone?.call(false, const [], r.message);
        return;
      }
      try {
        final arr = jsonDecode(r.str) as List<dynamic>;
        onDone?.call(true,
            arr.map((e) => e as Map<String, dynamic>).toList(), '');
      } catch (_) {
        onDone?.call(false, const [], ThemeController.instance.t('数据解析失败','Failed to parse data'));
      }
    });
  }

  /// 创建支付订单；order 为 {qrUrl,qrContent,orderId,...}
  void vipPayCreate(int pricingId,
      {String payType = 'alipay',
      void Function(bool ok, Map<String, dynamic>? order, String message)?
          onDone}) {
    _post(() => _core.vipPayCreate(pricingId, payType: payType), (r) {
      if (!r.ok || r.str.isEmpty) {
        onDone?.call(false, null, r.message);
        return;
      }
      try {
        onDone?.call(true, jsonDecode(r.str) as Map<String, dynamic>, '');
      } catch (_) {
        onDone?.call(false, null, ThemeController.instance.t('数据解析失败','Failed to parse data'));
      }
    });
  }

  /// 同步会话 VIP 状态；onDone(ok, isVip, vipExpiresAt)
  void vipSyncStatus(
      {void Function(bool ok, bool isVip, String vipExpiresAt)? onDone}) {
    _post(_core.vipSyncStatus, (r) {
      var isVip = false;
      var expires = '';
      if (r.ok && r.str.isNotEmpty) {
        try {
          final obj = jsonDecode(r.str) as Map<String, dynamic>;
          isVip = obj['isVip'] == true;
          expires = obj['vipExpiresAt']?.toString() ?? '';
        } catch (_) {}
      }
      onDone?.call(r.ok, isVip, expires);
    });
  }

  // ── 下载管理 ──

  /// 加入下载队列；完成/失败经 onDone(ok, musicId, message, filePath)
  void download(NekoCoreMusic music,
      {void Function(bool ok, int musicId, String message, String filePath)?
          onDone}) {
    _post(() => _core.downloadMusic(music), (r) {
      if (r.ok) {
        _requestDownloads();
        _requestDownloadsStatus();
      }
      onDone?.call(r.ok, r.i64.toInt(), r.message, r.str);
    });
  }

  /// 取消下载（进行中或排队）
  void cancelDownload(int musicId, {void Function(bool ok)? onDone}) {
    _post(() => _core.downloadCancel(musicId), (r) {
      onDone?.call(r.ok);
      _requestDownloadsStatus();
    });
  }

  /// 刷新下载队列状态（进行中 + 排队，含实时进度）
  void _requestDownloadsStatus() {
    _post(_core.downloadsStatus, (r) {
      if (r.ok) downloadsActive = r.rows;
      notifyListeners();
    });
  }

  void requestDownloadsStatus() => _requestDownloadsStatus();

  // ── 对外命令 ──

  void refresh() {
    _requestQueue();
    _requestFavorites();
    _requestRanking();
    _requestLatest();
    _requestHomePlaylists();
  }

  /// 登录；结果通过 [error] 或 userInfo 呈现
  /// LAN：按当前登录态（重）启动。userId<=0 停止。
  void lanInit() {
    final userId = userInfo?['id'] ?? userInfo?['userId'] ?? -1;
    final id = userId is num ? userId.toInt() : -1;
    _post(() => _core.lanSetAccount(id), (_) {
      _post(() => _core.lanStart(), (_) {});
    });
  }

  void lanStop() => _post(_core.lanStop, (_) {});

  void lanSelectDevice(String deviceId) {
    _post(() => _core.lanSelectDevice(deviceId), (_) {});
    lanSelectedDeviceId = deviceId;
    notifyListeners();
  }

  /// 上报本机播放镜像（曲目 id + 是否播放），供快照广播
  void lanSyncPlayer(int musicId, bool playing) {
    _post(() => _core.lanSetPlayerState(musicId, playing), (_) {});
  }

  /// 轮询一次：刷新设备列表/远端队列/连接状态
  void lanPollTick() {
    _post(_core.lanPoll, (r) {
      if (r.str.isEmpty) return;
      try {
        final j = jsonDecode(r.str) as Map<String, dynamic>;
        lanDevices = (j['devices'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        lanRemoteQueue = j['remoteQueue'] as Map<String, dynamic>?;
        lanConnected = j['connected'] == true;
        lanSelectedDeviceId =
            (j['selectedDeviceId'] as String?) ?? lanSelectedDeviceId;
        notifyListeners();
      } catch (_) {}
    });
  }

  void login(String username, String password, {void Function(bool ok)? onDone}) {
    _post(() => _core.login(username, password), (r) {
      if (r.ok) {
        userInfo = jsonDecode(r.str) as Map<String, dynamic>;
        _requestFavorites();
        _requestCloudPlaylists();
        lanInit();
      } else {
        error = r.message;
      }
      notifyListeners();
      onDone?.call(r.ok);
    });
  }

  /// 注册（需先完成滑块验证 + 邮箱验证码）；onDone(ok, message)
  void register(String username, String password, String email, String code,
      {void Function(bool ok, String message)? onDone}) {
    _post(() => _core.register(username, password, email, code), (r) {
      if (r.ok) {
        userInfo = jsonDecode(r.str) as Map<String, dynamic>;
        _requestFavorites();
        _requestCloudPlaylists();
        lanInit();
      } else {
        error = r.message;
      }
      notifyListeners();
      onDone?.call(r.ok, r.message);
    });
  }

  void logout() {
    lanStop();
    _post(_core.logout, (r) {
      userInfo = null;
      favoriteIds.clear();
      favorites = [];
      myPlaylists = [];
      favPlaylists = [];
      favPlaylistIds = {};
      lanDevices = [];
      lanRemoteQueue = null;
      lanConnected = false;
      notifyListeners();
    });
  }

  /// 切歌统一入口：写 current + 立即拉取歌词（对齐 Qt loadLyricsForTrack：
  /// 每次曲目变更同步取词，而非仅在打开播放页时）
  void _applyCurrent(NekoCoreMusic music) {
    current = music;
    fetchLyrics(music);
  }

  /// 播放歌曲：写入队列并交给引擎起播
  void play(NekoCoreMusic music, {void Function()? onError}) {
    _applyCurrent(music);
    _post(() => _core.queueAddAll([music]), (r) {
      _post(() => _core.queueSetIndex(0), (_) {
        _requestQueue();
        notifyListeners();
      });
    });
    // 播放流直接交给 libmpv（PipeWire 优先，失败自动回退）
    _onPlayRequest?.call(music);
    notifyListeners();
  }

  /// 把整批歌曲写入队列并从第一首开始播放（歌单详情「播放全部」）
  void playAll(List<NekoCoreMusic> songs) {
    if (songs.isEmpty) return;
    _applyCurrent(songs.first);
    _post(() => _core.queueAddAll(songs), (r) {
      _post(() => _core.queueSetIndex(0), (_) {
        _requestQueue();
        notifyListeners();
      });
    });
    _onPlayRequest?.call(songs.first);
    notifyListeners();
  }

  /// 把外部 URL/曲目交给引擎播放（不重写队列；供 PlayerBar 详情等使用）
  void playCurrent({String? url}) {
    final m = current;
    if (m == null && url == null) return;
    _onPlayRequest?.call(m ?? NekoCoreMusic(
      id: 0, title: url!, artist: '', album: '',
      duration: 0, coverUrl: '', localPath: '', playCount: 0,
      uploadedAtMs: 0, lrc: false,
    ));
    if (url != null) _onPlayUrl?.call(url);
  }

  void Function(String url)? _onPlayUrl;
  set onPlayUrl(void Function(String url)? v) => _onPlayUrl = v;

  /// 由外部（MainShell）注入：把歌曲交给引擎播放
  void Function(NekoCoreMusic music)? _onPlayRequest;
  set onPlayRequest(void Function(NekoCoreMusic music)? v) => _onPlayRequest = v;

  /// 搜索
  void search(String query, {int page = 1, int pageSize = 20, void Function(List<NekoCoreMusic> results, int total)? onDone}) {
    _post(() => _core.searchMusic(query, page: page, pageSize: pageSize), (r) {
      onDone?.call(r.rows, r.i64);
    });
  }

  /// 切换收藏
  void toggleFavorite(int musicId) {
    _post(() => _core.toggleFavorite(musicId), (r) {
      if (r.ok) _requestFavorites();
      notifyListeners();
    });
  }

  void recordRecent(NekoCoreMusic music) {
    _post(() => _core.recordRecent(music), (_) {});
  }

  void recordDownload(NekoCoreMusic music, String filePath) {
    _post(() => _core.recordDownload(music, filePath), (_) {});
  }

  /// 播放队列下一首（返回下一首曲目，供引擎播放）
  NekoCoreMusic? next() {
    if (queue.isEmpty) return null;
    final idx = switch (playMode) {
      'single' => currentIndex,
      'random' => _randomOther(currentIndex),
      _ => (currentIndex + 1) % queue.length,
    };
    if (idx < 0 || idx >= queue.length) return null;
    currentIndex = idx;
    _applyCurrent(queue[idx]);
    _post(() => _core.queueSetIndex(idx), (_) {});
    notifyListeners();
    return queue[idx];
  }

  NekoCoreMusic? previous() {
    if (queue.isEmpty) return null;
    final idx = (currentIndex - 1 + queue.length) % queue.length;
    if (idx < 0 || idx >= queue.length) return null;
    currentIndex = idx;
    _applyCurrent(queue[idx]);
    _post(() => _core.queueSetIndex(idx), (_) {});
    notifyListeners();
    return queue[idx];
  }

  /// 播放队列指定位置（供队列面板点击切歌）
  void playAt(int index) {
    if (index < 0 || index >= queue.length) return;
    currentIndex = index;
    _applyCurrent(queue[index]);
    _post(() => _core.queueSetIndex(index), (_) {});
    _onPlayRequest?.call(queue[index]);
    notifyListeners();
  }

  /// 清空播放队列
  void clearQueue() {
    _post(_core.queueClear, (r) {
      queue = [];
      currentIndex = -1;
      notifyListeners();
    });
  }

  /// 切换播放模式（list/loop/single/random）
  void setPlayMode(String mode) {
    playMode = mode;
    _post(() => _core.queueSetMode(mode), (_) {});
    notifyListeners();
  }

  /// 拉取当前歌曲歌词
  ///
  /// 用递增序号标记请求：快速切歌时旧结果直接丢弃（既不丢失新请求，
  /// 也不会让上一首的歌词覆盖当前曲）。
  void fetchLyrics([NekoCoreMusic? music]) {
    final m = music ?? current;
    if (m == null || m.id <= 0) {
      lyrics = '';
      notifyListeners();
      return;
    }
    final seq = ++_lyricsReqSeq;
    loadingLyrics = true;
    notifyListeners();
    _post(() => _core.fetchLyrics(m.id), (r) {
      if (seq != _lyricsReqSeq) return; // 过期结果：已切歌
      loadingLyrics = false;
      lyrics = r.str;
      notifyListeners();
    });
  }

  int _lyricsReqSeq = 0;

  int _randomOther(int exclude) {
    if (queue.length <= 1) return exclude;
    var idx = exclude;
    while (idx == exclude) idx = DateTime.now().microsecondsSinceEpoch % queue.length;
    return idx;
  }

  // ── 结果推送 ──

  /// worker 线程结果入队后触发（listener 回调，投递到主隔离区执行）
  void _onNativeEvent(Pointer<Void> _) => _drain();

  /// 一次性取空结果队列；回调可能连续触发，用 [_draining] 防重入
  void _drain() {
    if (_draining) return;
    _draining = true;
    try {
      while (true) {
        final r = _core.poll();
        if (r == null) break;
        if (r.seq == -1) {
          // 下载进度事件：更新进行中列表 + 推送流
          final musicId = r.i64.toInt();
          final idx =
              downloadsActive.indexWhere((m) => m.id == musicId);
          if (idx >= 0) {
            final updated = NekoCoreMusic(
              id: downloadsActive[idx].id,
              title: downloadsActive[idx].title,
              artist: downloadsActive[idx].artist,
              album: downloadsActive[idx].album,
              duration: downloadsActive[idx].duration,
              coverUrl: downloadsActive[idx].coverUrl,
              localPath: downloadsActive[idx].localPath,
              playCount: downloadsActive[idx].playCount,
              uploadedAtMs: downloadsActive[idx].uploadedAtMs,
              lrc: downloadsActive[idx].lrc,
              progressReceived: r.progressReceived,
              progressTotal: r.progressTotal,
            );
            downloadsActive[idx] = updated;
            notifyListeners();
            _downloadProgressCtrl.add(updated);
          }
          continue;
        }
        final cb = _pending.remove(r.seq);
        if (cb != null) cb(r);
      }
    } finally {
      _draining = false;
    }
  }

  @override
  void dispose() {
    _core.setEventCallback(nullptr);
    _core.stop();
    _evCb?.close();
    _downloadProgressCtrl.close();
    super.dispose();
  }
}
