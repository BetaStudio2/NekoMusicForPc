import 'package:flutter/material.dart';

import '../../main.dart';
import '../../core/core_controller.dart';
import '../../ffi/neko_core.dart';
import '../add_to_playlist_dialog.dart';
import '../artist_detail_page.dart';

/// 右键菜单条目（图标 + 文案 + 动作），对齐原版 SongContextMenuPopup::Entry
typedef SongMenuEntry = ({IconData icon, String label, VoidCallback action});

/// 构建歌曲菜单条目（更多按钮 / 右键菜单共用）：
/// 播放 / 收藏 / 添加到歌单 / 下载 / 查看歌手 + 调用方追加项（如"从歌单移除"）
List<PopupMenuEntry<VoidCallback>> buildSongMenuEntries(
  BuildContext context, {
  required CoreController core,
  required NekoCoreMusic music,
  List<SongMenuEntry> extra = const [],
}) {
  final isFav = music.id > 0 && core.favoriteIds.contains(music.id);
  final entries = <SongMenuEntry>[
    (
      icon: Icons.play_arrow_rounded,
      label: '播放',
      action: () => core.play(music),
    ),
    if (music.id > 0)
      (
        icon: isFav ? Icons.favorite : Icons.favorite_border,
        label: isFav ? '取消收藏' : '收藏',
        action: () => core.toggleFavorite(music.id),
      ),
    (
      icon: Icons.playlist_add_rounded,
      label: '添加到歌单',
      action: () => _addToPlaylist(context, core, music),
    ),
    if (music.id > 0)
      (
        icon: Icons.download_outlined,
        label: '下载',
        action: () => core.download(music),
      ),
    if (music.artist.isNotEmpty)
      (
        icon: Icons.person_outline_rounded,
        label: '查看歌手',
        action: () => _viewArtist(context, core, music.artist),
      ),
    ...extra,
  ];
  return [
    for (final e in entries)
      PopupMenuItem<VoidCallback>(
        value: e.action,
        height: 40,
        child: Row(
          children: [
            Icon(e.icon, size: 18, color: kTextSecondary),
            const SizedBox(width: 10),
            Text(e.label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
  ];
}

/// 在全局坐标弹出右键菜单（对齐原版 SongContextMenuPopup::showAt）。
/// [extra] 供调用方追加上下文相关动作。
Future<void> showSongContextMenu(
  BuildContext context, {
  required CoreController core,
  required NekoCoreMusic music,
  required Offset at,
  List<SongMenuEntry> extra = const [],
}) async {
  final action = await showMenu<VoidCallback>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    color: kBgSurface,
    items: buildSongMenuEntries(context, core: core, music: music, extra: extra),
  );
  action?.call();
}

/// 添加到云端歌单（对齐原版 AddToPlaylistDialog；本地音乐 id<0 时跳过）
void _addToPlaylist(
    BuildContext context, CoreController core, NekoCoreMusic music) {
  if (music.id < 0) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('本地音乐暂不支持添加到云端歌单'),
      duration: Duration(seconds: 2),
    ));
    return;
  }
  if (!core.isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('添加到歌单需要先登录'),
      duration: Duration(seconds: 2),
    ));
    return;
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AddToPlaylistDialog(core: core, music: music),
  );
}

/// 按歌手名搜索并跳转歌手详情页
void _viewArtist(BuildContext context, CoreController core, String artistName) {
  core.searchArtists(artistName, onDone: (artist) {
    if (!context.mounted) return;
    if (artist == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('未找到该歌手'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ArtistDetailPage(core: core, artist: artist),
    ));
  });
}
