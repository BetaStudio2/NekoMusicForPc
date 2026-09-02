import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import 'widgets/song_tile.dart';

/// 每日推荐列表页（由首页入口卡片 push 进入，对齐原版 Daily 音乐列表页）。
class DailyMusicPage extends StatelessWidget {
  const DailyMusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
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
                        tooltip: '返回',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Text('每日推荐',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: core.fetchDaily,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('换一批'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text('根据你的音乐口味 · 每日更新',
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
                            emptyText: '点击「换一批」获取每日推荐'),
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
