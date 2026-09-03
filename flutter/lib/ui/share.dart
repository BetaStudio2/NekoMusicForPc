import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../ffi/neko_core.dart';

/// 分享歌曲：组装分享文案并写入剪贴板（对齐 Qt PlayerBar::shareClicked 行为）
Future<void> shareMusic(BuildContext context, NekoCoreMusic? music) async {
  if (music == null || music.id <= 0) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ThemeController.instance.t(
            '当前没有可分享的歌曲', 'Nothing to share right now')),
        duration: const Duration(seconds: 2),
      ));
    return;
  }
  final t = ThemeController.instance;
  final track = music.title;
  final artist = music.artist.isNotEmpty ? music.artist : '';
  final head = t.t('【NekoMusic】好歌分享', '【NekoMusic】Song share');
  final online = t.t('歌曲：%1 ｜ 歌手：%2',
      'Song: %1 | Artist: %2').replaceFirst('%1', track).replaceFirst('%2', artist);
  final link = music.playUrl();
  await Clipboard.setData(ClipboardData(text: '$head\n$online\n$link'));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(t.t('已复制分享内容', 'Share text copied')),
        duration: const Duration(seconds: 2),
      ));
  }
}
