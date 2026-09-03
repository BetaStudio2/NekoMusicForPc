import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../core/engine_controller.dart';
import '../core/lrc_parser.dart';
import '../ffi/neko_core.dart';
import '../ffi/neko_engine.dart';

/// 播放详情页：按原版 Qt PlayerPage（src/ui/playerpage.cpp setupUi/setupPlayerControl）布局移植 ——
///   顶部 80px 菜单栏区域（Qt kPlayerMenuH）→ 中间左右 50:50 分栏
///   （左：自适应封面 + 曲目信息；右：歌词）→ 底部 80px 控制栏（Qt kPlayerControlH，
///   左工具 / 中央控制 / 右工具三等分）。
/// 关键尺寸与 Qt 常量一致：
///   kPlayerStyleRatio=50、kPlayerCoverRadius=32、kPpSideIcon=24、kPpTransportIcon=26、
///   kPpPlayIcon=28、kPpModeIcon=20、kPpProgressMaxW=480、kCoverScalePaused=0.9、
///   kCoverScalePlaying=1.0；封面 = clamp(200, min(左栏宽*0.70, 内容高*0.50), 480)，
///   歌词字号 = clamp(28, 46*内容高/1080, 52)。
class PlayerDetailPage extends StatefulWidget {
  const PlayerDetailPage({super.key});

  @override
  State<PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends State<PlayerDetailPage>
    with SingleTickerProviderStateMixin {
  /// Qt kPlayerMenuH
  static const double _kMenuBarH = 80;
  /// Qt kPlayerControlH
  static const double _kControlBarH = 80;
  /// Qt kLyricPadLeft / kLyricPadRight
  static const double _kLyricPadLeft = 10;
  static const double _kLyricPadRight = 80;

  final ScrollController _lrcCtrl = ScrollController();
  List<LrcLine> _lrcLines = const [];
  List<GlobalKey> _lrcKeys = const [];
  int _lrcIndex = -1;
  String _lrcRaw = '';      // 已解析的歌词源（切歌时比对重解析）
  String _lrcLayoutSig = ''; // 视口尺寸签名（展开/缩放后重新定位）
  bool _showQueue = false;
  // 队列面板动效（对齐 ArchoeraMusic slide 模式：右缘滑入 300ms easeOutCubic）
  late final AnimationController _queueAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  // 起始偏移 1.2×宽：完全移出窗口（Offset(1,0) 仅移自身宽，
  // 面板右侧 12px 边距与投影仍会露出）
  late final Animation<Offset> _queueSlide = Tween<Offset>(
    begin: const Offset(1.2, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _queueAnim, curve: Curves.easeOutCubic));
  late final Animation<double> _queueBarrier =
      Tween<double>(begin: 0, end: 0.35).animate(_queueAnim);

  void _openQueue() {
    if (_showQueue) return;
    setState(() => _showQueue = true);
    _queueAnim.forward();
  }

  /// 关闭队列：反向滑出动画 + 立即解除交互（避免面板/遮罩残留导致的假卡死）
  void _closeQueue() {
    if (!_showQueue) return;
    setState(() => _showQueue = false);
    _queueAnim.reverse();
  }

  void _toggleQueue() => _showQueue ? _closeQueue() : _openQueue();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 进入页面时拉取当前歌曲歌词，并刷新歌单/收藏（保证「加入歌单」可用）
      CoreScope.of(context).fetchLyrics();
      CoreScope.of(context).refresh();
    });
  }

  @override
  void dispose() {
    _lrcCtrl.dispose();
    _queueAnim.dispose();
    super.dispose();
  }

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite || s <= 0) return '00:00';
    final m = s ~/ 60;
    final sec = (s % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final engine = EngineScope.of(context);
    return Scaffold(
      backgroundColor: kBgDeep,
      body: ListenableBuilder(
        listenable: Listenable.merge([core, engine]),
        builder: (context, _) {
          final music = core.current;
          final playing = engine.state == NekoPlayState.playing;
          final hasCover = music != null && music.coverUrl.isNotEmpty;
          return Stack(
            fit: StackFit.expand,
            children: [
              // 模糊背景：专辑封面铺满 + 高斯模糊
              //（对齐 Qt playerpage kBackdropBlurRadius=80 / softenBackdropImage
              //  低分辨率柔化思路：cacheWidth 小图解码 + 放大，性能友好）
              if (hasCover)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter:
                        ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Transform.scale(
                      scale: 1.35, // 抑制模糊导致的边缘透出
                      child: Image.network(
                        music.fullCoverUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 128,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              // 顶/底暗角（对齐 Qt paintChromeEdgeGradients：黑 alpha 72→0）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _kMenuBarH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 72 / 255),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: _kControlBarH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 72 / 255),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
              children: [
                // 顶部 80px 菜单栏区域（Qt kPlayerMenuH；悬停出现的 chrome 区域，Flutter 端留白）
                const SizedBox(height: _kMenuBarH),
                // 内容区：左封面/信息，右歌词（Qt kPlayerStyleRatio=50 → 50:50）
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: _leftPanel(core, music, engine, playing)),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                                child: _lyricsPanel(core, engine)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _controlBar(core, engine, playing, music),
              ],
              ),
            ),
              // 队列遮罩：变暗 + 点击关闭（关闭态 IgnorePointer 不拦截）
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showQueue,
                  child: GestureDetector(
                    onTap: _toggleQueue,
                    child: FadeTransition(
                      opacity: _queueBarrier,
                      child: const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
              ),
              // 队列面板：常驻 + 右缘滑入动效（对齐 ArchoeraMusic slide 模式）
              Positioned(
                right: 12,
                top: 12,
                bottom: 12,
                width: 384,
                child: SlideTransition(
                  position: _queueSlide,
                  child: _queuePanel(core, engine, playing, _closeQueue),
                ),
              ),
          ],
        );
      },
    ),
    );
  }

  // ── 左栏：自适应封面 + 曲目信息（Qt playerLeftPanel / leftInfoColumn） ──

  Widget _leftPanel(CoreController core, NekoCoreMusic? music,
      EngineController engine, bool playing) {
    return LayoutBuilder(builder: (context, c) {
      // Qt coverSideLength()：clamp(200, min(panelW*0.70, pageH*0.50), 480)
      final byPanel = c.maxWidth * 0.70;
      final byVh = c.maxHeight * 0.50;
      final cover = math.min(byPanel, byVh).clamp(200.0, 480.0).toDouble();
      final title = (music == null || music.title.isEmpty) ? '未在播放' : music.title;
      final artist = (music == null || music.artist.isEmpty) ? ' ' : music.artist;
      final album = (music == null || music.album.isEmpty) ? ' ' : music.album;
      return Center(
        child: SingleChildScrollView(
          // Qt leftOuter 内容边距 (0, 0, 24, 0)
          padding: const EdgeInsets.only(right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 封面：点击切换播放/暂停；播放态放大（Qt kCoverScalePlaying/Paused）
              GestureDetector(
                onTap: () {
                  if (engine.state == NekoPlayState.stopped) return;
                  engine.togglePlayPause();
                },
                child: AnimatedScale(
                  scale: playing ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: ClipRRect(
                    // Qt kPlayerCoverRadius
                    borderRadius: BorderRadius.circular(32),
                    child: SizedBox(
                      width: cover,
                      height: cover,
                      child: music != null && music.coverUrl.isNotEmpty
                          ? Image.network(
                              music.fullCoverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _coverPlaceholder(cover),
                            )
                          : _coverPlaceholder(cover),
                    ),
                  ),
                ),
              ),
              // Qt infoLay spacing 24（封面 ↔ 信息列）
              const SizedBox(height: 24),
              // 信息列：标题 26w700 / 歌手 16 / 专辑 16（Qt metaLay spacing 12，左对齐单行省略）
              SizedBox(
                width: cover,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: kTextSecondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: kTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── 右栏：歌词（LRC 时间轴滚动高亮；纯文本歌词原样显示） ──────────

  /// 当前行滚动到视口中心（Qt scrollLyricsToActiveLine）。
  /// [postDelayMs] 延迟校准：页面滑入转场（250ms）期间布局会变化，
  /// 首次进入时在转场结束后再校准一次，保证落点准确。
  void _scheduleLyricsCenter(int idx, List<LrcLine> lines,
      {int postDelayMs = 0}) {
    final key = idx >= 0 && idx < _lrcKeys.length ? _lrcKeys[idx] : null;
    if (key == null) return;
    void doCenter() {
      if (!mounted || !_lrcCtrl.hasClients) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else if (lines.isNotEmpty) {
        // 目标行尚未构建（跳转场景）：按行号比例近似定位
        final maxExt = _lrcCtrl.position.maxScrollExtent;
        _lrcCtrl.animateTo(
          (maxExt * idx / lines.length).clamp(0.0, maxExt),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => doCenter());
    if (postDelayMs > 0) {
      Future.delayed(Duration(milliseconds: postDelayMs), doCenter);
    }
  }

  Widget _lyricsPanel(CoreController core, EngineController engine) {
    if (core.loadingLyrics) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (core.lyrics.isEmpty) {
      return Center(
        child: Text('暂无歌词', style: TextStyle(color: kTextMuted)),
      );
    }
    // 歌词源变化（切歌）→ 重新解析并复位定位状态
    if (core.lyrics != _lrcRaw) {
      _lrcRaw = core.lyrics;
      _lrcLines = parseLrc(core.lyrics);
      _lrcKeys = List.generate(_lrcLines.length, (_) => GlobalKey());
      _lrcIndex = -1;
      _lrcLayoutSig = ''; // 触发当前行重新居中
    }
    final lines = _lrcLines;
    // 无时间戳 → 纯文本歌词，原样居中显示
    if (lines.isEmpty || lines.length == 1 && lines.first.time < 0) {
      return Container(
        padding: const EdgeInsets.fromLTRB(
            _kLyricPadLeft, 0, _kLyricPadRight, 26),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: SelectableText(
            core.lyrics,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.9, color: kTextSecondary),
          ),
        ),
      );
    }
    // 定位当前行：最后一个 time <= position 的行
    final pos = engine.position;
    var idx = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _lrcIndex) {
      final firstCenter = _lrcIndex < 0; // 进入页面/切歌后的首次定位
      _lrcIndex = idx;
      _scheduleLyricsCenter(idx, lines, postDelayMs: firstCenter ? 320 : 0);
    }
    return LayoutBuilder(builder: (context, c) {
      // Qt lyricMainFontPx()：clamp(28, 46*高/1080, 52)
      final fs = (c.maxHeight * 46 / 1080 + 0.5).clamp(28.0, 52.0).toDouble();
      // 视口尺寸变化（窗口缩放 / 面板展开）：当前行重新居中
      final sig = '${c.maxWidth.round()}x${c.maxHeight.round()}';
      if (sig != _lrcLayoutSig) {
        _lrcLayoutSig = sig;
        _scheduleLyricsCenter(idx, lines);
      }
      return Container(
        // Qt lyricsCol 边距 (kLyricPadLeft, 0, kLyricPadRight, 26)
        padding: const EdgeInsets.fromLTRB(
            _kLyricPadLeft, 0, _kLyricPadRight, 26),
        alignment: Alignment.center,
        // 全量构建（歌词行数量级小）：GlobalKey 的 context 恒可用，
        // 重开页面/跳转/缩放时 ensureVisible 均能精确定位当前行
        child: ListView(
          controller: _lrcCtrl,
          // 顶部/底部大留白（Qt kLyricTopPad=300 / 底部 max(视口,120)），首/末行也能居中
          padding: const EdgeInsets.only(top: 240, bottom: 160),
          children: [
            for (var i = 0; i < lines.length; i++)
              KeyedSubtree(
                key: _lrcKeys[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    lines[i].text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: i == _lrcIndex ? fs + 1 : fs,
                      fontWeight:
                          i == _lrcIndex ? FontWeight.w700 : FontWeight.w400,
                      color: i == _lrcIndex
                          ? kPrimary
                          : kTextSecondary.withValues(alpha: 0.6),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  // ── 播放队列面板（点击切歌 / 清空） ────────────────────────────────

  /// 播放队列面板（对齐 ArchoeraMusic queue_panel slide 模式）：
  /// 毛玻璃容器 + 头部（图标/标题/计数 + 模式循环/清空/关闭）+ 队列列表
  ///（当前曲高亮 + 均衡器动效图标 + 封面 + 副标题）。
  Widget _queuePanel(CoreController core, EngineController engine,
      bool playing, VoidCallback onClose) {
    final queue = core.queue;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kBgSurface.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 头部：图标 + 标题 + 计数 + 模式循环/清空/关闭 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 6, 4),
                  child: Row(
                    children: [
                      Icon(Icons.queue_music,
                          size: 19, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('播放队列',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (queue.isNotEmpty)
                        Text('${queue.length} 首',
                            style: TextStyle(
                                fontSize: 12, color: kTextMuted)),
                      const Spacer(),
                      IconButton(
                        tooltip: '播放模式：' + _playModeLabel(core.playMode),
                        onPressed: () => core.setPlayMode(switch (
                            core.playMode) {
                          'list' => 'loop',
                          'loop' => 'single',
                          'single' => 'random',
                          _ => 'list',
                        }),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(_modeIconOf(core.playMode),
                            size: 19,
                            color: core.playMode == 'list'
                                ? kTextSecondary
                                : scheme.primary),
                      ),
                      IconButton(
                        tooltip: '清空队列',
                        onPressed: queue.isEmpty ? null : core.clearQueue,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_sweep_outlined,
                            size: 18),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: onClose,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: kDivider),
                // ── 队列列表 ──
                Expanded(
                  child: queue.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.playlist_play,
                                  size: 44,
                                  color: kTextMuted.withValues(alpha: 0.35)),
                              const SizedBox(height: 10),
                              Text('队列为空',
                                  style: TextStyle(
                                      color: kTextMuted, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('从列表中添加歌曲开始播放',
                                  style: TextStyle(
                                      color: kTextMuted
                                          .withValues(alpha: 0.6),
                                      fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: queue.length,
                          itemBuilder: (context, i) {
                            final m = queue[i];
                            final active = i == core.currentIndex;
                            return ListTile(
                              dense: true,
                              onTap: () {
                                core.playAt(i);
                                engine.playUrl(m.playUrl());
                              },
                              leading: SizedBox(
                                width: 36,
                                child: Center(
                                  child: active
                                      ? Icon(
                                          playing
                                              ? Icons.graphic_eq
                                              : Icons.play_arrow,
                                          size: 18,
                                          color: kPrimary)
                                      : Text('${i + 1}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: kTextMuted)),
                                ),
                              ),
                              title: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: m.coverUrl.isNotEmpty
                                          ? Image.network(
                                              m.fullCoverUrl,
                                              fit: BoxFit.cover,
                                              cacheWidth: 60,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: kBgSurface,
                                                child: Icon(
                                                    Icons.music_note,
                                                    size: 16,
                                                    color: kTextMuted),
                                              ),
                                            )
                                          : Container(
                                              color: kBgSurface,
                                              child: Icon(Icons.music_note,
                                                  size: 16,
                                                  color: kTextMuted),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: active
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: active
                                                    ? kPrimary
                                                    : kTextPrimary)),
                                        if (m.artist.isNotEmpty)
                                          Text(m.artist,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: kTextMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(_fmt(m.duration.toDouble()),
                                  style: TextStyle(
                                      fontSize: 11, color: kTextMuted)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _playModeLabel(String mode) => switch (mode) {
        'loop' => '列表循环',
        'single' => '单曲循环',
        'random' => '随机播放',
        _ => '顺序播放',
      };

  IconData _modeIconOf(String mode) => switch (mode) {
        'single' => Icons.repeat_one,
        'random' => Icons.shuffle,
        'loop' => Icons.repeat,
        _ => Icons.queue_play_next,
      };

  // ── 底部控制栏：Qt kPlayerControlH=80；左工具/中央/右工具 1:1:1 ─────

  Widget _controlBar(CoreController core, EngineController engine,
      bool playing, NekoCoreMusic? music) {
    return LayoutBuilder(builder: (context, c) {
      // 窄窗退化为精简控制栏，避免溢出（对齐 Qt width<=700 常驻 chrome 的行为）
      if (c.maxWidth < 760) {
        return _compactControlBar(core, engine, playing, music);
      }
      return _fullControlBar(core, engine, playing, music);
    });
  }

  Widget _fullControlBar(CoreController core, EngineController engine,
      bool playing, NekoCoreMusic? music) {
    final favorited =
        music != null && music.id > 0 && core.favoriteIds.contains(music.id);
    final hasMusic = music != null && music.id > 0;
    final progress = engine.duration > 0
        ? (engine.position / engine.duration).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      height: _kControlBarH,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // 左工具（Qt m_ppLeftTools：返回 / 收藏 / 加入歌单）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  _toolBtn(Icons.keyboard_arrow_down_rounded, '返回',
                      () => Navigator.of(context).pop()),
                  _toolBtn(
                      favorited ? Icons.favorite : Icons.favorite_border,
                      '收藏',
                      () => core.toggleFavorite(music?.id ?? 0),
                      highlight: favorited),
                  _addToPlaylistBtn(core, music),
                ],
              ),
            ),
          ),
          // 中央控制（Qt m_playerControlCenter：按钮行 + 进度行）
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _modeBtn(core),
                      const SizedBox(width: 12),
                      _ctrlBtn(Icons.skip_previous_rounded, '上一首', hasMusic
                          ? () {
                              final m = core.previous();
                              if (m != null) engine.playUrl(m.playUrl());
                            }
                          : null),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        iconSize: 28,
                        // Qt kPpPlayBtn=44
                        constraints: const BoxConstraints.tightFor(
                            width: 44, height: 44),
                        style: IconButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white),
                        icon: Icon(playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        onPressed: engine.state == NekoPlayState.stopped
                            ? null
                            : engine.togglePlayPause,
                      ),
                      const SizedBox(width: 12),
                      _ctrlBtn(Icons.skip_next_rounded, '下一首', hasMusic
                          ? () {
                              final m = core.next();
                              if (m != null) engine.playUrl(m.playUrl());
                            }
                          : null),
                      const SizedBox(width: 12),
                      _ctrlBtn(Icons.download_outlined, '下载', hasMusic
                          ? () => _download(core, music!)
                          : null),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // 进度行（Qt sliderRow：时间 40w + 进度条 max480 + 时间 40w）
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        _fmt(engine.position),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: SliderTheme(
                          // 对齐 Qt sliderRow：进度条高 16（setFixedHeight(16)），
                          // 与按钮行(44)+spacing(4) 合计 64px，在 80px 控制栏内
                          // 居中并留出上下呼吸空间，避免控件组顶满容器
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: SizedBox(
                            height: 16,
                            child: Slider(
                              value: progress,
                              activeColor: kPrimary,
                              onChanged: (v) {
                                engine.beginSeek();
                                engine.position = v * engine.duration;
                              },
                              onChangeEnd: (v) {
                                engine.seekTo(v * engine.duration);
                                engine.endSeek();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        _fmt(engine.duration),
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右工具（Qt m_ppRightTools：音量 + 播放队列）
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.volume_up_rounded,
                      size: 24, color: kTextSecondary),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Slider(
                      value: engine.volume,
                      activeColor: kPrimary,
                      onChanged: engine.setVolume,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _toolBtn(
                      Icons.queue_music_rounded,
                      _showQueue ? '收起队列' : '播放队列',
                      _toggleQueue,
                      highlight: _showQueue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 窄窗精简控制栏：返回 / 收藏 / 播放控制 / 队列，避免溢出
  Widget _compactControlBar(CoreController core, EngineController engine,
      bool playing, NekoCoreMusic? music) {
    final favorited =
        music != null && music.id > 0 && core.favoriteIds.contains(music.id);
    final hasMusic = music != null && music.id > 0;
    return Container(
      height: _kControlBarH,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          _toolBtn(Icons.keyboard_arrow_down_rounded, '返回',
              () => Navigator.of(context).pop()),
          _toolBtn(
              favorited ? Icons.favorite : Icons.favorite_border,
              '收藏',
              () => core.toggleFavorite(music?.id ?? 0),
              highlight: favorited),
          const Spacer(),
          _ctrlBtn(Icons.skip_previous_rounded, '上一首', hasMusic
              ? () {
                  final m = core.previous();
                  if (m != null) engine.playUrl(m.playUrl());
                }
              : null),
          IconButton.filled(
            iconSize: 28,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            style: IconButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white),
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed:
                engine.state == NekoPlayState.stopped ? null : engine.togglePlayPause,
          ),
          _ctrlBtn(Icons.skip_next_rounded, '下一首', hasMusic
              ? () {
                  final m = core.next();
                  if (m != null) engine.playUrl(m.playUrl());
                }
              : null),
          const Spacer(),
          _toolBtn(
              Icons.queue_music_rounded,
              _showQueue ? '收起队列' : '播放队列',
              () => setState(() => _showQueue = !_showQueue),
              highlight: _showQueue),
        ],
      ),
    );
  }

  /// 普通工具按钮（Qt kPpMenuBtn=40 / kPpSideIcon=24）
  Widget _toolBtn(IconData icon, String tip, VoidCallback? onTap,
      {bool highlight = false}) {
    return IconButton(
      tooltip: tip,
      iconSize: 24,
      // 收紧交互区，避免 IconButton 默认 48px 高撑破 80px 控制栏
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: Icon(icon, color: highlight ? kPrimary : kTextSecondary),
      onPressed: onTap,
    );
  }

  /// 传输控制按钮（Qt kPpCtrlBtn=38 / kPpTransportIcon=26）
  Widget _ctrlBtn(IconData icon, String tip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tip,
      iconSize: 26,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      icon: Icon(icon, color: kTextSecondary),
      onPressed: onTap,
    );
  }

  /// 加入歌单：弹出本地歌单选择（Qt m_ppAddToPlaylistBtn）
  Widget _addToPlaylistBtn(CoreController core, NekoCoreMusic? music) {
    final hasMusic = music != null && music.id > 0;
    final list =
        core.myPlaylists.isNotEmpty ? core.myPlaylists : core.playlists;
    return PopupMenuButton<int>(
      tooltip: '加入歌单',
      iconSize: 24,
      icon: const Icon(Icons.playlist_add_rounded),
      enabled: hasMusic,
      onSelected: (localId) {
        core.addToPlaylist(localId, music!, onDone: (ok) {
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('加入歌单失败')));
          }
        });
      },
      itemBuilder: (context) {
        if (list.isEmpty) {
          return const [
            PopupMenuItem<int>(enabled: false, child: Text('暂无本地歌单'))
          ];
        }
        return [
          for (final p in list)
            PopupMenuItem(value: p.localId, child: Text(p.name)),
        ];
      },
    );
  }

  void _download(CoreController core, NekoCoreMusic music) {
    core.download(music, onDone: (ok, id, msg, path) {
      if (!ok && msg.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  Widget _modeBtn(CoreController core) {
    return PopupMenuButton<String>(
      tooltip: '播放模式',
      initialValue: core.playMode,
      // Qt kPpCtrlBtn=38
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      icon: Icon(_modeIcon(core.playMode), size: 20, color: kTextSecondary),
      onSelected: (v) => core.setPlayMode(v),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'list', child: Text('顺序播放')),
        PopupMenuItem(value: 'loop', child: Text('列表循环')),
        PopupMenuItem(value: 'single', child: Text('单曲循环')),
        PopupMenuItem(value: 'random', child: Text('随机播放')),
      ],
    );
  }

  IconData _modeIcon(String mode) => switch (mode) {
        'single' => Icons.repeat_one_rounded,
        'random' => Icons.shuffle_rounded,
        'loop' => Icons.repeat_rounded,
        _ => Icons.playlist_play_rounded,
      };

  Widget _coverPlaceholder(double size) => Container(
        width: size,
        height: size,
        color: kBgSurface,
        child: Icon(Icons.music_note,
            size: 96, color: kPrimary.withValues(alpha: 0.5)),
      );
}
