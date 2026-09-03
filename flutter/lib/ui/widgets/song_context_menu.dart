import 'package:flutter/material.dart';

import '../../main.dart';
import '../../core/core_controller.dart';
import '../../l10n/generated/app_localizations.dart';
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
  final l10n = AppLocalizations.of(context);
  final isFav = music.id > 0 && core.favoriteIds.contains(music.id);
  final entries = <SongMenuEntry>[
    (
      icon: Icons.play_arrow_rounded,
      label: l10n.play,
      action: () => core.play(music),
    ),
    if (music.id > 0)
      (
        icon: isFav ? Icons.favorite : Icons.favorite_border,
        label: isFav ? l10n.removeFavorite : l10n.favorite,
        action: () => core.toggleFavorite(music.id),
      ),
    (
      icon: Icons.playlist_add_rounded,
      label: l10n.addToPlaylist,
      action: () => _addToPlaylist(context, core, music),
    ),
    if (music.id > 0)
      (
        icon: Icons.download_outlined,
        label: l10n.download,
        action: () => core.download(music),
      ),
    if (music.artist.isNotEmpty)
      (
        icon: Icons.person_outline_rounded,
        label: l10n.viewArtist,
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
  final l10n = AppLocalizations.of(context);
  if (music.id < 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.localToCloudUnsupported),
      duration: Duration(seconds: 2),
    ));
    return;
  }
  if (!core.isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.needLoginAdd),
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
  final l10n = AppLocalizations.of(context);
  core.searchArtists(artistName, onDone: (artist) {
    if (!context.mounted) return;
    if (artist == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.artistNotFound),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ArtistDetailPage(core: core, artist: artist),
    ));
  });
}
