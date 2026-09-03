import 'neko_icons.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../ffi/neko_core.dart';
import 'widgets/song_tile.dart';

/// 歌手详情页（对齐原版 ArtistDetailPage）：
/// 歌手信息头部 + 歌曲列表，歌手名/歌曲来自搜索接口返回的 artist map。
class ArtistDetailPage extends StatefulWidget {
  const ArtistDetailPage({super.key, required this.core, required this.artist});

  final CoreController core;
  final Map<String, dynamic> artist;

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  AppLocalizations get _l10n => AppLocalizations.of(context);
  late List<NekoCoreMusic> _songs;

  @override
  void initState() {
    super.initState();
    _songs = _tracksFromArtist(widget.artist);
  }

  /// 解析 artist map 的 musicList（id/title/artist/album/duration）
  static List<NekoCoreMusic> _tracksFromArtist(Map<String, dynamic> artist) {
    final list = artist['musicList'];
    if (list is! List) return const [];
    final songs = <NekoCoreMusic>[];
    for (final v in list) {
      if (v is! Map) continue;
      final m = Map<String, dynamic>.from(v);
      final id = (m['id'] as num?)?.toInt() ?? 0;
      songs.add(NekoCoreMusic(
        id: id,
        title: '${m['title'] ?? ''}',
        artist: '${m['artist'] ?? ''}',
        album: '${m['album'] ?? ''}',
        duration: (m['duration'] as num?)?.toInt() ?? 0,
        coverUrl: 'https://music.cnmsb.xin/api/music/cover/$id',
        localPath: '',
        playCount: 0,
        uploadedAtMs: 0,
        lrc: false,
      ));
    }
    return songs;
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.artist['name'] ?? _l10n.unknownArtist}';
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // 歌手信息
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: kBgMid,
                    child: Icon(NekoIcons.Person,
                        size: 44, color: kTextFaint),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_l10n.songsCountFull(_songs.length),
                            style: TextStyle(
                                fontSize: 13, color: kTextSecondary)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _songs.isEmpty ? null : () => widget.core.playAll(_songs),
                    icon: const Icon(NekoIcons.Play, size: 18),
                    label: Text(_l10n.playAll),
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: kDivider),
            Expanded(
              child: _songs.isEmpty
                  ? Center(
                      child: Text(_l10n.artistNoSongs,
                          style: TextStyle(color: kTextMuted)))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
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
                                  core: widget.core,
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
