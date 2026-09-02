import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../ffi/neko_core.dart';
import 'artist_detail_page.dart';
import 'widgets/playlist_card.dart';
import 'widgets/song_tile.dart';

/// 搜索页：单曲 / 歌单 / 歌手 三类结果（对齐原版 SearchPage）。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  /// 标题栏搜索框提交时带入的初始关键字
  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

enum _SearchTab { songs, playlists, artists }

class _SearchPageState extends State<SearchPage> {
  String? _lastQuery; // 已执行搜索的关键字（随标题栏全局搜索更新）

  // 单曲
  List<NekoCoreMusic> _results = [];
  int _total = 0;
  bool _searching = false;

  // 歌单
  List<NekoCorePlaylist> _playlistResults = [];
  bool _searchingPlaylists = false;

  // 歌手
  Map<String, dynamic>? _artist;
  bool _searchingArtists = false;

  _SearchTab _tab = _SearchTab.songs;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastQuery != q) {
          _lastQuery = q;
          _search(q);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 标题栏全局搜索再次提交 → 直接跟随新关键字重新搜索
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty && q != _lastQuery) {
      _lastQuery = q;
      _search(q);
    }
  }

  void _search(String raw) {
    final core = CoreScope.of(context);
    final q = raw.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searched = true;
      _searching = true;
      _results = [];
      _total = 0;
      _searchingPlaylists = true;
      _playlistResults = [];
      _searchingArtists = true;
      _artist = null;
    });
    // 单曲
    core.search(q, page: 1, pageSize: 30, onDone: (rows, total) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = rows;
        _total = total;
      });
    });
    // 歌单
    core.searchPlaylists(q, onDone: (list) {
      if (!mounted) return;
      setState(() {
        _searchingPlaylists = false;
        _playlistResults = list;
      });
    });
    // 歌手
    core.searchArtists(q, onDone: (artist) {
      if (!mounted) return;
      setState(() {
        _searchingArtists = false;
        _artist = artist;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('搜索',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_tab == _SearchTab.songs && _total > 0)
              Text('找到 $_total 首',
                  style: TextStyle(color: kTextMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        // 类型 Tab（关键字由顶部全局搜索框输入）
        if (_searched)
          Row(
            children: [
              _tabBtn('单曲', _SearchTab.songs),
              _tabBtn('歌单', _SearchTab.playlists),
              _tabBtn('歌手', _SearchTab.artists),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody(core)),
      ],
    );
  }

  Widget _tabBtn(String label, _SearchTab tab) {
    final active = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? kPrimary : kBgSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CoreController core) {
    if (!_searched) {
      return Center(
        child: Text('输入关键字开始搜索', style: TextStyle(color: kTextMuted)),
      );
    }
    return switch (_tab) {
      _SearchTab.songs => _searching
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              children: [
                SongList(core: core,
                    songs: _results, emptyText: '未找到相关歌曲'),
              ],
            ),
      _SearchTab.playlists => _searchingPlaylists
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _playlistResults.isEmpty
              ? Center(
                  child: Text('未找到相关歌单',
                      style: TextStyle(color: kTextMuted)))
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _playlistResults.length,
                  itemBuilder: (context, i) => CloudPlaylistCard(
                    core: core,
                    playlist: _playlistResults[i],
                  ),
                ),
      _SearchTab.artists => _searchingArtists
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _artist == null
              ? Center(
                  child: Text('未找到相关歌手',
                      style: TextStyle(color: kTextMuted)))
              : Align(
                  alignment: Alignment.topLeft,
                  child: _ArtistCard(
                    artist: _artist!,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ArtistDetailPage(
                            core: core, artist: _artist!),
                      ));
                    },
                  ),
                ),
    };
  }
}

/// 歌手搜索结果卡片（点击进入歌手详情页）
class _ArtistCard extends StatelessWidget {
  const _ArtistCard({required this.artist, required this.onTap});

  final Map<String, dynamic> artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = '${artist['name'] ?? '未知歌手'}';
    final tracks = artist['musicList'];
    final count = tracks is List ? tracks.length : 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kBgSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: kBgMid,
              child: Icon(Icons.person_rounded,
                  size: 48, color: kTextFaint),
            ),
            const SizedBox(height: 12),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$count 首歌',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kPrimary),
                onPressed: onTap,
                icon: const Icon(Icons.person_rounded, size: 16),
                label: const Text('查看歌手'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
