import 'neko_icons.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../ffi/neko_core.dart';
import 'widgets/song_context_menu.dart';
import 'widgets/song_tile.dart';

/// 本地歌单详情页（对齐原版 PlaylistDetailPage 本地部分）：
/// 歌曲列表 + 播放全部 + 重命名 / 删除歌单 + 逐首移除。
/// 经 Navigator.push 打开（不在 CoreScope 子树内），core 由构造传入。
class LocalPlaylistDetailPage extends StatefulWidget {
  const LocalPlaylistDetailPage({
    super.key,
    required this.core,
    required this.playlist,
  });

  final CoreController core;
  final NekoCorePlaylist playlist;

  @override
  State<LocalPlaylistDetailPage> createState() =>
      _LocalPlaylistDetailPageState();
}

class _LocalPlaylistDetailPageState extends State<LocalPlaylistDetailPage> {
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
    widget.core.loadPlaylistDetail(widget.playlist.localId, onDone: (songs) {
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    });
  }

  /// 从歌单移除（对齐原版 removeSongFromPlaylist）
  void _removeSong(NekoCoreMusic music) {
    widget.core.removeFromPlaylist(widget.playlist.localId, music, onDone: (ok) {
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_l10n.removeFailed), duration: const Duration(seconds: 2)));
        return;
      }
      _load();
    });
  }

  /// 重命名（对齐原版 LineInputDialog 输入歌单名）
  Future<void> _rename() async {
    final ctrl = TextEditingController(text: widget.playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgSurface,
        title: Text(_l10n.renamePlaylistTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: _l10n.inputName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(_l10n.confirm),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != widget.playlist.name) {
      widget.core.renamePlaylist(widget.playlist.localId, name);
    }
  }

  /// 删除歌单（确认后回退上一页）
  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgSurface,
        title: Text(_l10n.deletePlaylist),
        content: Text(_l10n.deletePlaylistConfirm(widget.playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.deleteAction),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.core.deletePlaylist(widget.playlist.localId);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.core;
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶栏：返回 + 名称 + 重命名 / 删除
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _l10n.back,
                    icon: const Icon(NekoIcons.ArrowBack),
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
                  IconButton(
                    tooltip: _l10n.rename,
                    icon: const Icon(NekoIcons.Edit, size: 20),
                    color: kTextSecondary,
                    onPressed: _rename,
                  ),
                  IconButton(
                    tooltip: _l10n.deletePlaylist,
                    icon: const Icon(NekoIcons.Delete, size: 20),
                    color: kTextSecondary,
                    onPressed: _delete,
                  ),
                ],
              ),
            ),
            // 歌单信息 + 播放全部
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: _coverWidget(),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                                    menuExtra: [
                                      (
                                        icon: NekoIcons.RemoveCircleOutline,
                                        label: _l10n.removeFromPlaylist,
                                        action: () => _removeSong(_songs[i]),
                                      ),
                                    ],
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

  /// 封面：优先歌单 coverMusicId，否则第一首歌封面，否则占位
  Widget _coverWidget() {
    var coverId = widget.playlist.coverMusicId;
    if (coverId <= 0 && _songs.isNotEmpty) coverId = _songs.first.id;
    if (coverId <= 0) {
      return Container(
        color: kBgMid,
        child: Icon(NekoIcons.QueueMusic, size: 32, color: kTextFaint),
      );
    }
    return Image.network(
      'https://music.cnmsb.xin/api/music/cover/$coverId',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: kBgMid,
        child: Icon(NekoIcons.QueueMusic, size: 32, color: kTextFaint),
      ),
    );
  }
}
