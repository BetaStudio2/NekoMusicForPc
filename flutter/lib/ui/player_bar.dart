import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../core/engine_controller.dart';
import '../ffi/neko_core.dart';
import '../ffi/neko_engine.dart';
import 'player_detail_page.dart';
import '../l10n/generated/app_localizations.dart';

/// 底部播放栏（对齐原版 PlayerBar 的信息结构，布局约定对齐
/// ArchoeraMusic player_bar）：
///   Column
///    ├─ 进度行（22px，非悬停细条 / 悬停完整 Slider，触摸友好）
///    └─ 主行（60px）：左信息（弹性）｜ 三键（居中要素）｜ 右时间音量（弹性）
/// 左右两侧均为等宽弹性栏 → 播放控件严格居中；播放模式按钮在居中要素之外。
class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key});

  /// 播放条总高（对齐 Qt kPlayerBarBodyH=80 + 进度行余量）
  static const double barHeight = 82;

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  bool _volOpen = false;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite || s <= 0) return '00:00';
    final m = s ~/ 60;
    final sec = (s % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _openPlayerPage(CoreController core, EngineController engine) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => CoreScope(
          controller: core,
          child: EngineScope(
            controller: engine,
            child: const PlayerDetailPage(),
          ),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final engine = EngineScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([core, engine, ThemeController.instance]),
      builder: (context, _) {
        final music = core.current;
        final playing = engine.state == NekoPlayState.playing;
        final favorited = music != null &&
            music.id > 0 &&
            core.favoriteIds.contains(music.id);
        // 套用 Qt 原版几何（kPlayerBarSliderOverhang=8）：进度滑块上探出条外。
        // Stack(Clip.none) 允许滑块命中盒（48px）上探——轨道中心钉在条顶
        // y≈6，视觉细条与悬停拇指均贴顶；主行顶部留 22px 槽位且垂直居中。
        // 封面相对尺寸：Qt kPbCoverSize(64)/kPlayerBarBodyH(80) = 0.8，
        // 上下留白 = 条高×0.1 = 8 = 滑块上探量（kPlayerBarSliderOverhang），
        // 封面顶部恰好让出进度条区域
        final coverSize = PlayerBar.barHeight * 0.8;
        return Container(
          height: PlayerBar.barHeight,
          decoration: BoxDecoration(
            color: kCardBg, // 半透明：跟随主题 + 透出自定义底色（与侧栏一致）
            border: Border(top: BorderSide(color: kDivider)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 主行：占满全条高，内容垂直居中（对齐 Qt：封面居中于条体）
              // 左栏（弹性）｜三键（居中要素）｜右栏（弹性）
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          _cover(core, engine, music, size: coverSize),
                          const SizedBox(width: 12),
                          Expanded(child: _info(music, favorited, core)),
                          // 播放模式按钮：居中要素之外
                          _modeButton(core),
                        ],
                      ),
                    ),
                    _transportControls(core, engine, playing),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _timeText(engine),
                          const SizedBox(width: 8),
                          // 音量：点击图标展开内联水平滑条（Flutter 规范做法，
                          // 避免悬浮弹出层超出组件边界导致事件无法命中）
                          if (_volOpen) ...[
                            SizedBox(
                              width: 96,
                              child: Slider(
                                value: engine.volume,
                                activeColor: kPrimary,
                                onChanged: engine.setVolume,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          _volumeToggle(),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 进度滑块宿主：16px，top=-8（对齐 Qt kPbSliderHostH=16 /
              // kPlayerBarSliderOverhang=8）→ 轨道中心 = 条顶边 y=0，
              // 与主行封面（y≈21 起）零重叠；Clip.none 允许上探绘制
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                height: 16,
                child: _ProgressSlider(
                  value: engine.duration > 0
                      ? engine.position.clamp(0.0, engine.duration)
                      : 0,
                  max: engine.duration,
                  onChanged: (v) => engine.position = v,
                  onChangeEnd: (v) {
                    engine.seekTo(v);
                    engine.endSeek();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 左侧：封面 + 曲目信息 ────────────────────────────────────────

  Widget _cover(CoreController core, EngineController engine,
      NekoCoreMusic? music, {required double size}) {
    return GestureDetector(
      onTap: () => _openPlayerPage(core, engine),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: music != null && music.coverUrl.isNotEmpty
              ? Image.network(
                  music.fullCoverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder(),
                )
              : _coverPlaceholder(),
        ),
      ),
    );
  }

  Widget _info(NekoCoreMusic? music, bool favorited, CoreController core) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                music?.title ?? _l10n.playerIdleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => core.toggleFavorite(music?.id ?? 0),
              child: Icon(
                favorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 20,
                color: favorited ? kPrimary : kTextMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          music == null || music.artist.isEmpty ? ' ' : music.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: kTextSecondary, fontSize: 12),
        ),
      ],
    );
  }

  // ── 中部：播放模式按钮（居中要素之外）+ 三键（居中要素）─────────────

  /// 播放模式（顺序/循环/单曲/随机）按钮：位于左弹性栏末尾，不参与居中
  Widget _modeButton(CoreController core) {
    return PopupMenuButton<String>(
      tooltip: _l10n.playModeTooltip,
      initialValue: core.playMode,
      icon: Icon(_modeIcon(core.playMode), size: 20, color: kTextSecondary),
      onSelected: core.setPlayMode,
      itemBuilder: (context) => [
        PopupMenuItem(value: 'list', child: Text(_l10n.playModeList)),
        PopupMenuItem(value: 'loop', child: Text(_l10n.playModeLoop)),
        PopupMenuItem(value: 'single', child: Text(_l10n.playModeSingle)),
        PopupMenuItem(value: 'random', child: Text(_l10n.playModeRandom)),
      ],
    );
  }

  /// 居中要素：上一首 / 播放暂停 / 下一首
  Widget _transportControls(
      CoreController core, EngineController engine, bool playing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _l10n.prevTrack,
          iconSize: 20,
          icon: const Icon(Icons.skip_previous_rounded),
          color: kTextSecondary,
          onPressed: () {
            final m = core.previous();
            if (m != null) engine.playUrl(m.playUrl());
          },
        ),
        IconButton.filled(
          iconSize: 26,
          style: IconButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white),
          icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: () {
            if (engine.state == NekoPlayState.stopped) return;
            engine.togglePlayPause();
          },
        ),
        IconButton(
          tooltip: _l10n.nextTrack,
          iconSize: 20,
          icon: const Icon(Icons.skip_next_rounded),
          color: kTextSecondary,
          onPressed: () {
            final m = core.next();
            if (m != null) engine.playUrl(m.playUrl());
          },
        ),
      ],
    );
  }

  // ── 右侧：时间 + 音量 ────────────────────────────────────────────

  Widget _timeText(EngineController engine) {
    return Text(
      '${_fmt(engine.position)} / ${_fmt(engine.duration)}',
      style: TextStyle(color: kTextSecondary, fontSize: 12),
    );
  }

  Widget _volumeToggle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _volOpen = !_volOpen),
      child: Icon(
        Icons.volume_up_rounded,
        size: 20,
        color: kTextSecondary,
      ),
    );
  }

  IconData _modeIcon(String mode) => switch (mode) {
        'single' => Icons.repeat_one_rounded,
        'random' => Icons.shuffle_rounded,
        'loop' => Icons.repeat_rounded,
        _ => Icons.playlist_play_rounded,
      };

  Widget _coverPlaceholder() => Container(
        color: kBgSurface,
        child: Icon(Icons.music_note,
            size: 26, color: kPrimary.withValues(alpha: 0.5)),
      );
}

/// 播放进度滑块（套用 ArchoeraMusic playback_slider）：
/// 非悬停 = 4px 细条（仍可点击/拖动 seek，触摸友好）；
/// 悬停/拖动 = 完整 Material Slider（48px 命中区，原生手势）。
/// 外层 SizedBox(height: 48) 略超出 22px 槽位属有意为之：扩大命中区。
class _ProgressSlider extends StatefulWidget {
  const _ProgressSlider({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        // 高度 16px = Qt kPbSliderHostH（条顶上探 8px）：未悬停细条与
        // 悬停 Slider 同宽同轨；悬停拇指/overlay 均在此范围内
        height: 16,
        child: LayoutBuilder(
          builder: (context, c) => (_hovered || _dragging)
              ? _buildSlider(Theme.of(context).colorScheme)
              : _buildBar(Theme.of(context).colorScheme),
        ),
      ),
    );
  }

  /// 轨道矩形：水平按拇指 overlay 内缩，垂直居中（对齐 SliderTheme 几何）
  Rect _trackRect(BuildContext context, double width, double height) {
    final st = SliderTheme.of(context);
    final overlayW = st.overlayShape?.getPreferredSize(true, false).width ??
        (st.thumbShape?.getPreferredSize(true, false).width ?? 24.0);
    const trackH = 4.0;
    final trackW = (width - overlayW).clamp(0.0, double.infinity);
    return Rect.fromLTWH(
      (overlayW - trackH) / 2,
      (height - trackH) / 2,
      trackW,
      trackH,
    );
  }

  /// 悬停/拖动态：完整 Material Slider（原生手势，触摸友好）
  Widget _buildSlider(ColorScheme scheme) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: widget.value.clamp(0.0, widget.max <= 0 ? 1.0 : widget.max),
        max: widget.max <= 0 ? 1.0 : widget.max,
        onChangeStart: (_) => setState(() => _dragging = true),
        onChanged: widget.onChanged,
        onChangeEnd: (v) {
          setState(() => _dragging = false);
          widget.onChangeEnd(v);
        },
      ),
    );
  }

  /// 未悬停态：细条（灰底轨道 + 主色进度），仍可点击/拖动 seek
  Widget _buildBar(ColorScheme scheme) {
    final max = widget.max <= 0 ? 1.0 : widget.max;
    final ratio = (widget.value / max).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        final w = context.size?.width ?? 1;
        widget.onChanged((d.localPosition.dx / w).clamp(0.0, 1.0) * max);
        widget.onChangeEnd(widget.value);
      },
      onHorizontalDragStart: (d) {
        final w = context.size?.width ?? 1;
        widget.onChanged((d.localPosition.dx / w).clamp(0.0, 1.0) * max);
      },
      onHorizontalDragUpdate: (d) {
        final w = context.size?.width ?? 1;
        widget.onChanged((d.localPosition.dx / w).clamp(0.0, 1.0) * max);
      },
      onHorizontalDragEnd: (_) => widget.onChangeEnd(widget.value),
      child: LayoutBuilder(
        builder: (context, c) {
          final rect = _trackRect(context, c.maxWidth, c.maxHeight);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fromRect(
                rect: rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child:
                      ColoredBox(color: scheme.onSurface.withValues(alpha: 0.12)),
                ),
              ),
              Positioned.fromRect(
                rect: Rect.fromLTWH(
                    rect.left, rect.top, rect.width * ratio, rect.height),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(color: kPrimary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
