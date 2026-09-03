import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
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
  AppLocalizations get _l10n => AppLocalizations.of(context);
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
          ? _l10n.addFailed(error)
          : added > 0
              ? _l10n.addedToN(name)
              : _l10n.addFailedDupe;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
    });
  }

  Future<void> _createAndAdd() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_l10n.enterPlaylistName),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    widget.core.createCloudPlaylist(name, onDone: (id) {
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_l10n.createPlaylistFailed),
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
      title: Text(_l10n.addToPlaylist),
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
                      decoration: InputDecoration(
                          labelText: _l10n.newPlaylistName, isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _createAndAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(_l10n.createAndAdd),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.core.myPlaylists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(_l10n.noPlaylistsCreateHint,
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
          child: Text(_l10n.cancel),
        ),
      ],
    );
  }
}
