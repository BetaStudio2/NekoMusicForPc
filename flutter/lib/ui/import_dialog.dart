import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';

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
        _fetchError = '请输入歌单 ID';
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
      setState(() => _status = '歌单里没有可导入的曲目');
      return;
    }
    if (_target == _kTargetNewPlaylist) {
      final name = _newNameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() => _status = '请输入新建歌单名称');
        return;
      }
    }
    setState(() {
      _importing = true;
      _status = '正在批量搜索匹配歌曲…';
    });

    // 1) 批量搜索匹配
    widget.core.batchSearchMusic(tracks,
        onDone: (result, error) {
      if (!mounted) return;
      if (error != null || result == null) {
        setState(() {
          _importing = false;
          _status = '批量搜索失败：$error';
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
          _status = '没有匹配到可导入的歌曲';
        });
        return;
      }
      _addMatched(ids, (result['successCount'] as num?)?.toInt() ?? 0);
    });
  }

  void _addMatched(List<int> ids, int successCount) {
    // 目标解析：新建歌单 → 先创建再添加
    if (_target == _kTargetNewPlaylist) {
      setState(() => _status = '正在创建歌单…');
      widget.core.createCloudPlaylist(_newNameCtrl.text.trim(),
          onDone: (id) {
        if (!mounted) return;
        if (id == null) {
          setState(() {
            _importing = false;
            _status = '新建歌单失败';
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
          ? '正在加入收藏（${ids.length} 首）…'
          : '正在加入歌单（${ids.length} 首）…';
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
        _resultText = '已收藏 $done 首（匹配 $successCount 首）';
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
          _resultText = '添加失败：$error';
        } else {
          _resultText = '成功添加 $added 首（匹配 $successCount 首）';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBgSurface,
      title: const Text('导入歌单'),
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
                    segments: const [
                      ButtonSegment(value: true, label: Text('网易云')),
                      ButtonSegment(value: false, label: Text('QQ 音乐')),
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
                        labelText: _netease ? '网易云歌单 ID' : 'QQ 歌单 disstid',
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
                        : const Text('获取'),
                  ),
                ],
              ),
              if (_fetchError != null) ...[
                const SizedBox(height: 10),
                Text(_fetchError!,
                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text('歌单：${_info!['name'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('共 ${((_info!['tracks'] as List?) ?? const []).length} 首（最多导入前 60 首）',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
                const SizedBox(height: 12),
                // 目标选择
                Row(
                  children: [
                    const Text('导入到：',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _target,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                            value: _kTargetFavorites, child: Text('我的收藏')),
                        for (final p in widget.core.myPlaylists)
                          DropdownMenuItem(
                              value: p.localId.toInt(),
                              child: Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(
                            value: _kTargetNewPlaylist, child: Text('新建歌单')),
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
                    decoration: const InputDecoration(
                        labelText: '新建歌单名称', isDense: true),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _importing ? null : _startImport,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(_importing ? _status : '开始导入'),
                  ),
                ),
                if (_importing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
