import '../neko_icons.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../core/core_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ffi/neko_core.dart';
import 'song_context_menu.dart';

/// 歌曲行（封面 + 标题/歌手 + 时长 + 收藏），首页/搜索/收藏/最近等共用。
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.music,
    required this.core,
    this.index,
    this.onTap,
    this.trailing,
    this.menuExtra = const [],
  });

  final NekoCoreMusic music;
  final CoreController core;
  final int? index;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// 追加到右键/更多菜单的上下文动作（如"从歌单移除"）
  final List<SongMenuEntry> menuExtra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final durationText = music.duration > 0
        ? '${music.duration ~/ 60}:${(music.duration % 60).toString().padLeft(2, '0')}'
        : '';
    final isFav = music.id > 0 && core.favoriteIds.contains(music.id);

    return GestureDetector(
      // 右键菜单（对齐原版 SongContextMenu）
      onSecondaryTapDown: (d) => showSongContextMenu(context,
          core: core, music: music, at: d.globalPosition, extra: menuExtra),
      child: InkWell(
        onTap: onTap ?? () => core.play(music),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (index != null) ...[
              SizedBox(
                width: 24,
                child: Text('$index',
                    style: TextStyle(color: kTextMuted, fontSize: 13)),
              ),
              const SizedBox(width: 8),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                music.fullCoverUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: kBgMid,
                  child: Icon(NekoIcons.Music, color: kTextFaint),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(music.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    music.artist.isEmpty ? l10n.unknownArtist : music.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                ],
              ),
            ),
            Text(durationText,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.download,
                    icon: const Icon(NekoIcons.Download, size: 18),
                    color: kTextMuted,
                    onPressed: music.id > 0
                        ? () => core.download(music, onDone: (ok, id, msg, path) {
                              if (!ok && msg.isNotEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(msg == 'cancelled'
                                      ? l10n.downloadCancelled
                                      : l10n.downloadFailedN(msg)),
                                  duration: const Duration(seconds: 2),
                                ));
                              } else if (ok) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(path.isNotEmpty
                                      ? l10n.downloadSavedToN(path)
                                      : l10n.downloadQueued),
                                  duration: const Duration(seconds: 2),
                                ));
                              }
                            })
                        : null,
                  ),
                  IconButton(
                    tooltip: isFav ? l10n.removeFavorite : l10n.favorite,
                    icon: Icon(
                      isFav ? NekoIcons.Favorite : NekoIcons.FavoriteBorder,
                      size: 18,
                      color: isFav ? kPrimary : kTextMuted,
                    ),
                    onPressed:
                        music.id > 0 ? () => core.toggleFavorite(music.id) : null,
                  ),
                  PopupMenuButton<VoidCallback>(
                    tooltip: l10n.more,
                    icon: Icon(NekoIcons.More, size: 18, color: kTextMuted),
                    color: kBgMid,
                    onSelected: (action) => action(),
                    itemBuilder: (_) => buildSongMenuEntries(context,
                        core: core, music: music, extra: menuExtra),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 歌曲列表容器（圆角卡片 + 逐行渲染）
class SongList extends StatelessWidget {
  const SongList(
      {super.key,
      required this.core,
      required this.songs,
      this.emptyText});

  final CoreController core;
  final List<NekoCoreMusic> songs;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: Text(emptyText ?? l10n.emptyData,
            style: TextStyle(color: kTextMuted)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < songs.length; i++)
            SongTile(music: songs[i], core: core, index: i + 1),
        ],
      ),
    );
  }
}
