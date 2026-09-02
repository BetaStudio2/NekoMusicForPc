import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../ffi/neko_core.dart';

/// 「添加到歌单」对话框（对齐原版 AddToPlaylistDialog）：
/// 把歌曲加入云端歌单（我的歌单列表），或新建歌单后加入。
class AddToPlaylistDialog extends StatefulWidget {
  const AddToPlaylistDialog({super.key, required this.core, required this.music});

  final CoreController core;
  final NekoCoreMusic music;

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final TextEditingController _newNameCtrl = TextEditingController();

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  void _add(int playlistId, String name) {
    widget.core.batchAddMusicToPlaylist(playlistId, [widget.music.id],
        onDone: (result, error) {
      if (!mounted) return;
      final added = (result?['addedCount'] as num?)?.toInt() ?? 0;
      final msg = error != null
          ? '添加失败：$error'
          : added > 0
              ? '已添加到「$name」'
              : '添加失败（歌曲可能已在歌单中）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
    });
  }

  Future<void> _createAndAdd() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请输入歌单名称'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    widget.core.createCloudPlaylist(name, onDone: (id) {
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('创建歌单失败'),
          duration: Duration(seconds: 2),
        ));
        return;
      }
      _add(id, name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBgSurface,
      title: const Text('添加到歌单'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 新建歌单
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newNameCtrl,
                      decoration: const InputDecoration(
                          labelText: '新建歌单名称', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _createAndAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新建并添加'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.core.myPlaylists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('暂无歌单，可先新建',
                      style: TextStyle(color: kTextMuted)),
                )
              else
                for (final p in widget.core.myPlaylists)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.queue_music_rounded,
                        size: 20, color: kTextSecondary),
                    title: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${p.musicCount}',
                        style: TextStyle(fontSize: 12, color: kTextMuted)),
                    onTap: () {
                      Navigator.pop(context);
                      _add(p.localId.toInt(), p.name);
                    },
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
