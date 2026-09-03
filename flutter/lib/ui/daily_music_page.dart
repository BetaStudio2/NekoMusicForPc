import 'package:flutter/material.dart';

import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import 'neko_icons.dart';
import 'widgets/song_tile.dart';

/// 每日推荐（对齐原版 Daily 列表页）。
/// 默认作为独立页（带 Scaffold/背景层）；[embedded] 时作为主壳内容组件渲染，
/// 不再创建独立容器/背景（与设置页同方案）。
class DailyMusicPage extends StatelessWidget {
  const DailyMusicPage({super.key, this.onBack, this.embedded = false});

  /// 页内嵌入时由宿主返回上一页（null=路由模式自行 pop）
  final VoidCallback? onBack;

  /// 是否嵌入主内容区渲染（无独立 Scaffold/背景重绘）
  final bool embedded;

  Widget _content(BuildContext context, AppLocalizations l10n,
      CoreController core) {
    return SafeArea(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final l10n = AppLocalizations.of(context);
    if (embedded) {
      return _content(context, l10n, core);
    }
    return Scaffold(
      backgroundColor: kBgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 自定义底色/图片背景（与主壳一致；默认模式为空 → 页面底色）
          ...appBackdropLayers(),
          _content(context, l10n, core),
        ],
      ),
    );
  }
}
