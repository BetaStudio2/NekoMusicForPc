import 'neko_icons.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../ffi/neko_core.dart';
import 'widgets/song_tile.dart';

/// 云端歌单详情页：歌曲列表 + 播放全部 + 收藏切换。
/// 经 Navigator.push 打开（不在 CoreScope 子树内），core 由构造传入。
class CloudPlaylistDetailPage extends StatefulWidget {
  const CloudPlaylistDetailPage({
    super.key,
    required this.core,
    required this.playlist,
  });

  final CoreController core;
  final NekoCorePlaylist playlist;

  @override
  State<CloudPlaylistDetailPage> createState() => _CloudPlaylistDetailPageState();
}

class _CloudPlaylistDetailPageState extends State<CloudPlaylistDetailPage> {
  AppLocalizations get _l10n => AppLocalizations.of(context);
  List<NekoCoreMusic> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _loading = true);
    widget.core.loadCloudPlaylistMusic(widget.playlist.localId, onDone: (songs) {
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.core;
    final favorited = core.favPlaylistIds.contains(widget.playlist.localId);
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶栏：返回 + 标题 + 收藏
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _l10n.back,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: core,
                    builder: (context, _) => IconButton(
                      tooltip: favorited ? _l10n.unfavoritePlaylist : _l10n.favoritePlaylist,
                      icon: Icon(
                        favorited ? NekoIcons.Favorite : NekoIcons.FavoriteBorder,
                        size: 20,
                        color: favorited ? kPrimary : kTextSecondary,
                      ),
                      onPressed: () =>
                          core.toggleFavoritePlaylist(widget.playlist.localId),
                    ),
                  ),
                ],
              ),
            ),
            // 歌单信息 + 播放全部
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _l10n.songsCountFull(_songs.length),
                          style: TextStyle(
                              fontSize: 13, color: kTextSecondary),
                        ),
                        if (widget.playlist.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.playlist.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: kTextMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _songs.isEmpty
                        ? null
                        : () => core.playAll(_songs),
                    icon: const Icon(NekoIcons.Play, size: 18),
                    label: Text(_l10n.playAll),
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: kDivider),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_songs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Text(_l10n.playlistEmpty,
                                  style: TextStyle(color: kTextMuted)),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: kBgSurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0; i < _songs.length; i++)
                                  SongTile(
                                    music: _songs[i],
                                    core: core,
                                    index: i + 1,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
