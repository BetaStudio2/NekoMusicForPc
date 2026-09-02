import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../ffi/neko_core.dart';
import 'cloud_playlist_detail_page.dart';
import 'import_dialog.dart';
import 'local_playlist_detail_page.dart';

/// 侧边栏（240px）：对齐原版 Sidebar ——
///   Logo + 4 个主导航（首页/我喜欢的/最近播放/下载管理）
///   + 「我的歌单」列表（云端，点击进详情）+ 创建歌单/导入网易云/导入QQ
///   + 「收藏的歌单」列表。
/// 搜索/设置/VIP 入口在标题栏，不占用导航项。
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.selected, required this.onSelect});

  /// 0=首页 1=我喜欢的 2=最近播放 3=下载管理
  final int selected;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, '首页'),
    (Icons.favorite_outline, '我喜欢的'),
    (Icons.history_outlined, '最近播放'),
    (Icons.download_outlined, '下载管理'),
  ];

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    // 半透明底色：跟随主题切换，自定义底色（图片/纯色）时透出背景
    return Container(
      width: 240,
      color: kCardBg,
      child: ListenableBuilder(
        listenable: core,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/logo/nekomusic.png',
                        width: 30, height: 30, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Text('Neko歌姬',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary)),
                ],
              ),
            ),
            Divider(height: 1, color: kDivider),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              _SidebarItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                selected: selected == i,
                onTap: () => onSelect(i),
              ),
            const SizedBox(height: 8),
            Divider(height: 1, color: kDivider),
            // 歌单区（可滚动）
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                children: [
                  _listHeader('本地歌单'),
                  if (core.playlists.isEmpty) _emptyHint('暂无本地歌单'),
                  for (final p in core.playlists)
                    _PlaylistListItem(
                      playlist: p,
                      onTap: () => _openLocalDetail(context, core, p),
                      onSecondaryTapDown: (gpos) =>
                          _localPlaylistMenu(context, core, p, gpos),
                    ),
                  _actionButton(Icons.add_rounded, '新建本地歌单', () {
                    _createLocalPlaylistDialog(context, core);
                  }),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: kDivider),
                  const SizedBox(height: 6),
                  _listHeader('我的歌单'),
                  if (core.isLoggedIn && core.myPlaylists.isEmpty)
                    _emptyHint('暂无歌单，点下方创建'),
                  for (final p in core.myPlaylists)
                    _PlaylistListItem(
                      playlist: p,
                      onTap: () => _openDetail(context, core, p),
                    ),
                  _actionButton(Icons.add_rounded, '创建歌单', () {
                    _createPlaylistDialog(context, core);
                  }),
                  _actionButton(Icons.input_rounded, '导入网易云歌单', () {
                    _importDialog(context, core, true);
                  }),
                  _actionButton(Icons.input_rounded, '导入 QQ 歌单', () {
                    _importDialog(context, core, false);
                  }),
                  if (core.isLoggedIn) ...[
                    const SizedBox(height: 6),
                    Divider(height: 1, color: kDivider),
                    const SizedBox(height: 6),
                    _listHeader('收藏的歌单'),
                    if (core.favPlaylists.isEmpty)
                      _emptyHint('暂无收藏的歌单'),
                    for (final p in core.favPlaylists)
                      _PlaylistListItem(
                        playlist: p,
                        onTap: () => _openDetail(context, core, p),
                      ),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Neko歌姬计划',
                  style: TextStyle(color: kTextFaint, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Text(title,
            style: TextStyle(color: kTextMuted, fontSize: 12)),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
        child: Text(text,
            style: TextStyle(color: kTextFaint, fontSize: 11)),
      );

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: kTextSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: kTextSecondary)),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, CoreController core, NekoCorePlaylist p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CloudPlaylistDetailPage(core: core, playlist: p),
    ));
  }

  void _openLocalDetail(
      BuildContext context, CoreController core, NekoCorePlaylist p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LocalPlaylistDetailPage(core: core, playlist: p),
    ));
  }

  /// 本地歌单右键菜单：重命名 / 删除
  void _localPlaylistMenu(
      BuildContext context, CoreController core, NekoCorePlaylist p, Offset at) async {
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      color: kBgSurface,
      items: [
        PopupMenuItem<VoidCallback>(
          value: () => _renameLocalPlaylist(context, core, p),
          height: 40,
          child: const Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('重命名', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<VoidCallback>(
          value: () => core.deletePlaylist(p.localId),
          height: 40,
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 10),
              Text('删除歌单', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
    action?.call();
  }

  Future<void> _renameLocalPlaylist(
      BuildContext context, CoreController core, NekoCorePlaylist p) async {
    final ctrl = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgSurface,
        title: const Text('重命名歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != p.name) {
      core.renamePlaylist(p.localId, name);
    }
  }

  Future<void> _createLocalPlaylistDialog(
      BuildContext context, CoreController core) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgSurface,
        title: const Text('新建本地歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) core.createPlaylist(name);
  }

  void _importDialog(BuildContext context, CoreController core, bool netease) {
    if (!core.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('导入歌单需要先登录'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => ImportPlaylistDialog(core: core),
    );
  }

  Future<void> _createPlaylistDialog(
      BuildContext context, CoreController core) async {
    if (!core.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('创建云端歌单需要先登录'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgSurface,
        title: const Text('创建歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) core.createCloudPlaylist(name);
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kPrimary : kTextSecondary;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// 歌单列表行：小封面 + 名称 + 数量
class _PlaylistListItem extends StatelessWidget {
  const _PlaylistListItem({
    required this.playlist,
    required this.onTap,
    this.onSecondaryTapDown,
  });

  final NekoCorePlaylist playlist;
  final VoidCallback onTap;
  final void Function(Offset at)? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: onSecondaryTapDown == null
          ? null
          : (d) => onSecondaryTapDown!(d.globalPosition),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: playlist.coverMusicId > 0
                      ? Image.network(
                          'https://music.cnmsb.xin/api/music/cover/${playlist.coverMusicId}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${playlist.musicCount} 首',
                      style: TextStyle(fontSize: 11, color: kTextFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        color: kBgMid,
        child: Icon(Icons.queue_music_rounded, size: 18, color: kTextFaint),
      );
}
