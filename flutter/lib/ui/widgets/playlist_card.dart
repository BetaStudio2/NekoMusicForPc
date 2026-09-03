import 'package:flutter/material.dart';

import '../../main.dart';
import '../../core/core_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ffi/neko_core.dart';
import '../cloud_playlist_detail_page.dart';

/// 云端歌单卡片（封面 + 名称 + 歌曲数），点击进入云端歌单详情。
/// 首页推荐流 / 搜索歌单结果 / 我的与收藏歌单共用。
class CloudPlaylistCard extends StatelessWidget {
  const CloudPlaylistCard({
    super.key,
    required this.core,
    required this.playlist,
    this.actions,
  });

  final CoreController core;
  final NekoCorePlaylist playlist;

  /// 右上角附加操作（如收藏状态 / 更多菜单）
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              CloudPlaylistDetailPage(core: core, playlist: playlist),
        ));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              width: double.infinity,
              child: playlist.coverMusicId > 0
                  ? Image.network(
                      'https://music.cnmsb.xin/api/music/cover/${playlist.coverMusicId}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
                    )
                  : const _CoverPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.playlistCountSongs(playlist.musicCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: kTextMuted),
                        ),
                      ],
                    ),
                  ),
                  if (actions != null) actions!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBgMid,
      child: Center(
        child: Icon(Icons.queue_music_rounded, size: 40, color: kTextFaint),
      ),
    );
  }
}
