import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../core/engine_controller.dart';
import '../ffi/neko_engine.dart';
import '../l10n/generated/app_localizations.dart';
import 'list_pages.dart';
import 'login_dialog.dart';
import 'player_bar.dart';
import 'lan_panel.dart';
import 'daily_music_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'sidebar.dart';
import 'vip_page.dart';
import 'widgets/playlist_card.dart';
import 'widgets/song_tile.dart';

/// 主窗口骨架：侧边栏 + 顶栏 + 页面内容区 + 播放栏。
/// 页面切换对齐原版：侧边栏仅 首页/我喜欢的/最近播放/下载管理；
/// 搜索与设置由标题栏入口进入（-1=搜索，4=设置）。
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.core, required this.engine});

  final CoreController core;
  final EngineController engine;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  // 核心控制器为应用级单例（main() 创建）：歌词窗开关重建本树时不重建
  EngineController get _engine => widget.engine;
  CoreController get _core => widget.core;
  // 页面路由状态外置：重建后停留在原页面
  int _page = AppUiState.instance.page;
  String? get _searchInitial => AppUiState.instance.searchInitial;

  @override
  void initState() {
    super.initState();
    // 歌曲播放请求 → 交给引擎（PipeWire 优先，失败自动回退）+ 记录最近播放
    _core.onPlayRequest = (music) {
      _playUrl(music.playUrl());
      _core.recordRecent(music);
    };
    _core.onPlayUrl = (url) => _playUrl(url);
    // 曲目自然播完 → 自动连播下一首（对齐原版 PlayerPage 行为）
    _engine.onTrackEnded = () {
      final m = _core.next();
      if (m != null) _playUrl(m.playUrl());
    };
    // 在线流断流 → 断点续播（对齐原版 handleRemoteStreamFailure）
    _engine.onStreamFailure = _handleStreamFailure;
    // （桌面歌词 attach 已提升至 main()，避免重建时重复添加监听）
    // LAN 同步：周期推送本机播放镜像 + 轮询远端设备/队列
    _lanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final music = _core.current;
      _core.lanSyncPlayer(music?.id ?? 0,
          _engine.state == NekoPlayState.playing);
      _core.lanPollTick();
    });
  }

  /// 当前播放的在线 URL（断流重试用）与播放序号（用于丢弃过期的重试 Timer）
  Timer? _lanTimer;
  bool _lanVisible = false;
  late final AnimationController _lanAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<Offset> _lanSlide = Tween<Offset>(
    begin: const Offset(1.15, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _lanAnim, curve: Curves.easeOutCubic));
  late final Animation<double> _lanBarrier =
      Tween<double>(begin: 0, end: 0.35).animate(_lanAnim);

  void _openLan() {
    if (_lanVisible) return;
    setState(() => _lanVisible = true);
    _lanAnim.forward();
  }

  void _closeLan() {
    if (!_lanVisible) return;
    setState(() => _lanVisible = false);
    _lanAnim.reverse();
  }

  String? _currentUrl;
  int _streamSeq = 0;
  int _streamFailCount = 0;
  bool _resumingLocal = false;

  /// 统一播放入口：每次切换曲目都会重置断流重试计数，并作废旧的重试任务。
  void _playUrl(String url) {
    _streamSeq++;
    _streamFailCount = 0;
    _resumingLocal = false;
    _currentUrl = url;
    _engine.playUrl(url);
  }

  /// Qt 原版 handleRemoteStreamFailure 的移植：
  /// 断流 → 优先本地已下载文件从断点续播（playUrlResuming）；
  /// 否则 350ms 后重试远程流（最多 3 次，从头起播，对齐 kStreamRetryDelayMs）；
  /// 仍失败则切下一首。
  void _handleStreamFailure(double position) {
    final seq = _streamSeq;
    final music = _core.current;
    if (!_resumingLocal && music != null) {
      final local = _core.localFileFor(music);
      if (local != null) {
        _resumingLocal = true;
        _streamFailCount = 0;
        _engine.playUrlResuming(local, position);
        return;
      }
    }
    _resumingLocal = false;
    if (_streamFailCount < 3) {
      _streamFailCount++;
      Timer(const Duration(milliseconds: 350), () {
        if (seq != _streamSeq) return; // 期间已切歌
        final url = _currentUrl;
        if (url != null) _engine.playUrl(url);
      });
    } else {
      final m = _core.next();
      if (m != null) _playUrl(m.playUrl());
    }
  }

  @override
  void dispose() {
    _lanAnim.dispose();
    _lanTimer?.cancel();
    // 核心控制器为应用级单例，不随本树卸载
    super.dispose();
  }

  void _selectPage(int i) {
    setState(() {
      _page = i;
      AppUiState.instance
        ..page = i
        ..searchInitial = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CoreScope(
      controller: _core,
      child: EngineScope(
        controller: _engine,
        child: Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.keyP, control: true):
                _PlayPauseIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowRight,
                control: true, alt: true): _NextIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft,
                control: true, alt: true): _PrevIntent(),
          },
          child: Actions(
            actions: {
              _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
                  onInvoke: (_) {
                    if (_engine.state != NekoPlayState.stopped) {
                      _engine.togglePlayPause();
                    }
                    return null;
                  }),
              _NextIntent: CallbackAction<_NextIntent>(onInvoke: (_) {
                final m = _core.next();
                if (m != null) _playUrl(m.playUrl());
                return null;
              }),
              _PrevIntent: CallbackAction<_PrevIntent>(onInvoke: (_) {
                final m = _core.previous();
                if (m != null) _playUrl(m.playUrl());
                return null;
              }),
            },
            child: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  ..._buildBackdrop(),
                  Column(
                children: [
                  if (_engine.lastError != null)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFF5252).withValues(alpha: 0.14),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFFF8A80), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${l10n.engineErrorPrefix}${_engine.lastError}',
                              style: const TextStyle(
                                  color: Color(0xFFFF8A80), fontSize: 12),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TitleBar(
                    onSearch: (q) => setState(() {
                      AppUiState.instance.searchInitial = q;
                      _page = -1;
                      AppUiState.instance.page = -1;
                    }),
                    onSettings: () => setState(() {
                      _page = 4;
                      AppUiState.instance
                        ..page = 4
                        ..searchInitial = null;
                    }),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Sidebar(
                            selected: _page >= 0 && _page <= 3 ? _page : -1,
                            onSelect: _selectPage,
                            onLan: _openLan),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: _buildPage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PlayerBar(), // 非 const：主题切换时随 NekoApp 重建刷新配色
                ],
              ),
              // LAN 设备面板遮罩（变暗 + 点击关闭，关闭态不拦截）
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_lanVisible,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeLan,
                    child: FadeTransition(
                      opacity: _lanBarrier,
                      child: const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
              ),
              // LAN 设备面板：右缘滑入动效（常驻 + SlideTransition）
              Positioned(
                right: 12,
                top: 12,
                bottom: 12,
                width: 384,
                child: SlideTransition(
                  position: _lanSlide,
                  child: LanPanel(onClose: _closeLan),
                ),
              ),
            ],
          ),
            ),
          ),
      ),
      ),
    );
  }

  /// 背景个性化层（共享实现见 main.dart appBackdropLayers）
  List<Widget> _buildBackdrop() => appBackdropLayers();

  Widget _buildPage() {
    if (_page == -1) {
      return SearchPage(initialQuery: _searchInitial);
    }
    switch (_page) {
      case 0:
        return const _HomePage();
      case 1:
        return const FavoritesPage();
      case 2:
        return const RecentsPage();
      case 3:
        return const DownloadsPage();
      case 4:
        return const SettingsPage();
      default:
        return const _HomePage();
    }
  }
}

/// 顶部工具栏：中央搜索框 + 右侧（VIP/账号/设置）。
/// 窗口装饰（拖动/最小化/最大化/关闭）由系统标题栏提供。
class TitleBar extends StatefulWidget {
  const TitleBar({super.key, required this.onSearch, required this.onSettings});

  final ValueChanged<String> onSearch;
  final VoidCallback onSettings;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: kCardBg, // 半透明：跟随主题 + 透出自定义底色（与侧栏一致）
        border: Border(bottom: BorderSide(color: kDivider)),
      ),
      child: Row(
        children: [
          const Spacer(flex: 3),
          // 中央搜索框（对齐原版标题栏搜索）
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                  filled: true,
                  fillColor: kBgSurface,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: kTextMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (q) {
                  if (q.trim().isNotEmpty) widget.onSearch(q.trim());
                },
              ),
            ),
          ),
          const Spacer(flex: 1),
          // 右侧：VIP / 账号 / 设置（窗口控制由系统标题栏提供）
          if (core.isLoggedIn)
            _vipPill(core),
          const UserMenu(),
          const SizedBox(width: 4),
          _iconBtn(Icons.settings_outlined, l10n.settingsTooltip,
              widget.onSettings),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: kTextSecondary),
        ),
      ),
    );
  }

  Widget _vipPill(CoreController core) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const VipPage()));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7B733), Color(0xFFFC4A1A)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text('VIP',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页：每日推荐入口 + 推荐歌单网格 + 热门榜 + 最新音乐（对齐原版 HomePage）
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        return ListView(
          children: [
            Row(
              children: [
                const Text('首页',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: core.refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('刷新'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 每日推荐入口（原版首页顶部入口卡片）
            _DailyEntry(core: core),
            const SizedBox(height: 24),
            _sectionHeader('推荐歌单', core.homePlaylists.length),
            const SizedBox(height: 8),
            if (core.homePlaylists.isEmpty)
              _emptyBlock('暂无推荐歌单')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: core.homePlaylists.length,
                itemBuilder: (context, i) => CloudPlaylistCard(
                  core: core,
                  playlist: core.homePlaylists[i],
                ),
              ),
            const SizedBox(height: 28),
            _sectionHeader('热门音乐', core.ranking.length),
            const SizedBox(height: 8),
            SongList(core: core, songs: core.ranking),
            const SizedBox(height: 28),
            _sectionHeader('最新音乐', core.latest.length),
            const SizedBox(height: 8),
            SongList(core: core, songs: core.latest),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('$count 首',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }

  Widget _emptyBlock(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(color: kTextMuted)),
      );
}

/// 每日推荐入口卡片：封面 + 「每日推荐」+ 描述，点击进入每日推荐列表页
class _DailyEntry extends StatelessWidget {
  const _DailyEntry({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final coverMusicId = core.daily.isNotEmpty ? core.daily.first.id : 0;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CoreScope(
            controller: core,
            child: const DailyMusicPage(),
          ),
        ));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: kCardBg, // 半透明：透出自定义底色（与其他内容卡片一致）
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 70,
                height: 70,
                child: coverMusicId > 0
                    ? Image.network(
                        'https://music.cnmsb.xin/api/music/cover/$coverMusicId',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _entryCoverPlaceholder(),
                      )
                    : _entryCoverPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: kPrimary),
                      const SizedBox(width: 6),
                      const Text('每日推荐',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('根据你的音乐口味 · 每日更新',
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: kTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _entryCoverPlaceholder() => Container(
        color: kBgMid,
        child: Icon(Icons.music_note, color: kTextFaint, size: 28),
      );
}

// ── 应用内快捷键（对应设置页「快捷键」分组） ─────────────────────────

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}
