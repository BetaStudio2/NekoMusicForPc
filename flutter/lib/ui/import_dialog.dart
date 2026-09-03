import 'neko_icons.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';

/// 歌单导入对话框：网易云 / QQ 音乐歌单 → 批量搜索匹配 → 加入目标歌单或收藏。
/// 流程对齐原版 NeteaseImportDialog / QqImportDialog。
class ImportPlaylistDialog extends StatefulWidget {
  const ImportPlaylistDialog({super.key, required this.core});

  final CoreController core;

  @override
  State<ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

/// 导入目标特殊值：-1 收藏，-2 新建歌单
const _kTargetFavorites = -1;
const _kTargetNewPlaylist = -2;

class _ImportPlaylistDialogState extends State<ImportPlaylistDialog> {
  AppLocalizations get _l10n => AppLocalizations.of(context);
  bool _netease = true;
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _newNameCtrl = TextEditingController();

  Map<String, dynamic>? _info; // {"name","tracks":[{name,artist}]}
  String? _fetchError;
  bool _fetching = false;

  int _target = _kTargetFavorites;
  String _status = '';
  bool _importing = false;
  String? _resultText;

  @override
  void dispose() {
    _idCtrl.dispose();
    _newNameCtrl.dispose();
    super.dispose();
  }

  void _fetch() {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      setState(() {
        _fetchError = _l10n.enterPlaylistId;
        _info = null;
      });
      return;
    }
    setState(() {
      _fetching = true;
      _fetchError = null;
      _info = null;
      _resultText = null;
    });
    final onDone = (Map<String, dynamic>? info, String? error) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _info = info;
        _fetchError = error;
      });
    };
    if (_netease) {
      widget.core.fetchNeteasePlaylist(id, onDone: onDone);
    } else {
      widget.core.fetchQqPlaylist(id, onDone: onDone);
    }
  }

  Future<void> _startImport() async {
    final info = _info;
    if (info == null) return;
    final tracks = ((info['tracks'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => {'title': '${m['name'] ?? ''}', 'artist': '${m['artist'] ?? ''}'})
        .toList();
    if (tracks.isEmpty) {
      setState(() => _status = _l10n.noImportableTracks);
      return;
    }
    if (_target == _kTargetNewPlaylist) {
      final name = _newNameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _status = _l10n.enterNewPlaylistName);
        return;
      }
    }
    setState(() {
      _importing = true;
      _status = _l10n.importSearching;
    });

    // 1) 批量搜索匹配
    widget.core.batchSearchMusic(tracks,
        onDone: (result, error) {
      if (!mounted) return;
      if (error != null || result == null) {
        setState(() {
          _importing = false;
          _status = _l10n.importSearchFailed(error ?? '');
        });
        return;
      }
      final ids = ((result['matchedMusicIds'] as List?) ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList();
      if (ids.isEmpty) {
        setState(() {
          _importing = false;
          _status = _l10n.noMatchSongs;
        });
        return;
      }
      _addMatched(ids, (result['successCount'] as num?)?.toInt() ?? 0);
    });
  }

  void _addMatched(List<int> ids, int successCount) {
    // 目标解析：新建歌单 → 先创建再添加
    if (_target == _kTargetNewPlaylist) {
      setState(() => _status = _l10n.creatingPlaylist);
      widget.core.createCloudPlaylist(_newNameCtrl.text.trim(),
          onDone: (id) {
        if (!mounted) return;
        if (id == null) {
          setState(() {
            _importing = false;
            _status = _l10n.createPlaylistFailed;
          });
          return;
        }
        _addToPlaylist(id, ids, successCount);
      });
      return;
    }
    _addToPlaylist(_target, ids, successCount);
  }

  void _addToPlaylist(int playlistId, List<int> ids, int successCount) {
    final toFavorites = playlistId == _kTargetFavorites;
    setState(() {
      _status = toFavorites
          ? _l10n.importingToFavoritesN(ids.length)
          : _l10n.importingToPlaylistN(ids.length);
    });
    if (toFavorites) {
      // 收藏走批量收藏接口不可用时的兜底：逐个收藏
      var done = 0;
      for (final id in ids) {
        widget.core.toggleFavorite(id);
        done++;
      }
      setState(() {
        _importing = false;
        _resultText = _l10n.favoritedDoneN(done, successCount);
      });
      return;
    }
    widget.core.batchAddMusicToPlaylist(playlistId, ids,
        onDone: (result, error) {
      if (!mounted) return;
      final added = (result?['addedCount'] as num?)?.toInt() ?? 0;
      setState(() {
        _importing = false;
        if (error != null) {
          _resultText = _l10n.addFailed(error);
        } else {
          _resultText = _l10n.addedDoneN(added, successCount);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBgSurface,
      title: Text(_l10n.importPlaylist),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 平台 + ID
              Row(
                children: [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(_l10n.neteaseName)),
                      ButtonSegment(value: false, label: Text(_l10n.qqName)),
                    ],
                    selected: {_netease},
                    onSelectionChanged: (s) {
                      setState(() {
                        _netease = s.first;
                        _info = null;
                        _fetchError = null;
                        _resultText = null;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _idCtrl,
                      decoration: InputDecoration(
                        labelText: _netease ? _l10n.neteasePlaylistId : _l10n.qqDisstid,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fetch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _fetching ? null : _fetch,
                    child: _fetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_l10n.fetch),
                  ),
                ],
              ),
              if (_fetchError != null) ...[
                const SizedBox(height: 10),
                Text(_fetchError!,
                    style: TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_l10n.playlistPrefix(_info!['name'] ?? ''),
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_l10n.importCountN((( _info!['tracks'] as List?) ?? const []).length),
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
                const SizedBox(height: 12),
                // 目标选择
                Row(
                  children: [
                    Text(_l10n.importTo,
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _target,
                      isDense: true,
                      items: [
                        DropdownMenuItem(
                            value: _kTargetFavorites, child: Text(_l10n.myFavorites)),
                        for (final p in widget.core.myPlaylists)
                          DropdownMenuItem(
                              value: p.localId.toInt(),
                              child: Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: _kTargetNewPlaylist, child: Text(_l10n.newPlaylist)),
                      ],
                      onChanged: _importing
                          ? null
                          : (v) => setState(() => _target = v ?? _kTargetFavorites),
                    ),
                  ],
                ),
                if (_target == _kTargetNewPlaylist) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newNameCtrl,
                    enabled: !_importing,
                    decoration: InputDecoration(
                        labelText: _l10n.newPlaylistName, isDense: true),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _importing ? null : _startImport,
                    icon: Icon(NekoIcons.Download, size: 18),
                    label: Text(_importing ? _status : _l10n.startImport),
                  ),
                ),
                if (_importing)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(_status,
                        style: TextStyle(fontSize: 12, color: kTextSecondary)),
                  ),
                if (_resultText != null) ...[
                  const SizedBox(height: 8),
                  Text(_resultText!,
                      style: TextStyle(
                          fontSize: 13,
                          color: kPrimary,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_l10n.close),
        ),
      ],
    );
  }
}
