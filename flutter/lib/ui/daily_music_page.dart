import 'neko_icons.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'widgets/song_tile.dart';

/// 每日推荐列表页（由首页入口卡片 push 进入，对齐原版 Daily 音乐列表页）。
class DailyMusicPage extends StatelessWidget {
  const DailyMusicPage({super.key, this.onBack});

  /// 页内嵌入时由宿主返回上一页（null=路由模式自行 pop）
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: kBgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 自定义底色/图片背景（与主壳一致；默认模式为空 → 页面底色）
          ...appBackdropLayers(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.back,
                        icon: const Icon(NekoIcons.ArrowBack),
                        onPressed: () {
                          if (onBack != null) {
                            onBack!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(l10n.homeDailyTitle,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: core.fetchDaily,
                        icon: const Icon(NekoIcons.Refresh, size: 16),
                        label: Text(l10n.shuffleAgain),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(l10n.homeDailySubtitle,
                      style: TextStyle(fontSize: 12, color: kTextMuted)),
                ),
                Divider(height: 1, color: kDivider),
                Expanded(
                  child: ListenableBuilder(
                    listenable: core,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SongList(
                            core: core,
                            songs: core.daily,
                            emptyText: l10n.dailyShuffleHint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
