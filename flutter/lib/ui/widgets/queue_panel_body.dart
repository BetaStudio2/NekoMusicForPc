import 'package:flutter/material.dart';

import '../../core/core_controller.dart';
import '../../core/engine_controller.dart';
import '../../ffi/neko_core.dart';
import '../../ffi/neko_engine.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../main.dart';
import '../neko_icons.dart';

/// 统一「播放队列」面板组件：播放详情页内嵌面板与播放条队列
/// BottomSheet 共用同一份视图（对齐 Qt PlaylistPanel）。
class QueuePanelBody extends StatelessWidget {
  const QueuePanelBody({super.key, required this.onClose, this.onLan});

  final VoidCallback onClose;
  final VoidCallback? onLan;

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite || s <= 0) return '00:00';
    final m = s ~/ 60;
    final sec = (s % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  IconData _modeIcon(String mode) => switch (mode) {
        'single' => NekoIcons.RepeatOne,
        'random' => NekoIcons.Shuffle,
        'loop' => NekoIcons.Repeat,
        _ => NekoIcons.PlaylistPlay,
      };

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final engine = EngineScope.of(context);
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([core, engine, ThemeController.instance]),
      builder: (context, _) {
        final queue = core.queue;
        final scheme = Theme.of(context).colorScheme;
        final playing = engine.state == NekoPlayState.playing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 4),
              child: Row(
                children: [
                  Icon(NekoIcons.QueueMusic, size: 19, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.queueTitle,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (queue.isNotEmpty)
                    Text(l10n.playlistCountSongs(queue.length),
                        style:
                            TextStyle(fontSize: 12, color: kTextMuted)),
                  const Spacer(),
                  IconButton(
                    tooltip: ThemeController.instance.t('播放模式', 'Play mode'),
                    onPressed: () => core.setPlayMode(switch (core.playMode) {
                      'list' => 'loop',
                      'loop' => 'single',
                      'single' => 'random',
                      _ => 'list',
                    }),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(_modeIcon(core.playMode),
                        size: 19,
                        color: core.playMode == 'list'
                            ? kTextSecondary
                            : scheme.primary),
                  ),
                  IconButton(
                    tooltip: l10n.clearQueue,
                    onPressed: queue.isEmpty ? null : core.clearQueue,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(NekoIcons.DeleteSweep, size: 18),
                  ),
                  if (onLan != null)
                    PopupMenuButton<String>(
                      icon: Icon(NekoIcons.More,
                          size: 18, color: kTextSecondary),
                      onSelected: (v) {
                        if (v == 'lan') {
                          onLan!();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'lan',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(NekoIcons.DevicesOther,
                                  size: 18, color: kTextSecondary),
                              const SizedBox(width: 10),
                              Text(
                                  ThemeController.instance.t(
                                      '设备同步', 'Device sync'),
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(NekoIcons.Close, size: 18),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: kDivider),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(NekoIcons.PlaylistPlay,
                              size: 44,
                              color: kTextMuted.withValues(alpha: 0.35)),
                          const SizedBox(height: 10),
                          Text(l10n.queueEmpty,
                              style: TextStyle(
                                  color: kTextMuted, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(l10n.queueEmptyHint,
                              style: TextStyle(
                                  color:
                                      kTextMuted.withValues(alpha: 0.6),
                                  fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final m = queue[i];
                        final active = i == core.currentIndex;
                        return ListTile(
                          dense: true,
                          onTap: () {
                            core.playAt(i);
                            engine.playUrl(m.playUrl());
                          },
                          leading: SizedBox(
                            width: 36,
                            child: Center(
                              child: active
                                  ? Icon(
                                      playing
                                          ? NekoIcons.Eq
                                          : NekoIcons.Play,
                                      size: 18,
                                      color: kPrimary)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: kTextMuted)),
                            ),
                          ),
                          title: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: m.coverUrl.isNotEmpty
                                      ? Image.network(
                                          m.fullCoverUrl,
                                          fit: BoxFit.cover,
                                          cacheWidth: 60,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: kBgSurface,
                                            child: Icon(NekoIcons.Music,
                                                size: 16,
                                                color: kTextMuted),
                                          ),
                                        )
                                      : Container(
                                          color: kBgSurface,
                                          child: Icon(NekoIcons.Music,
                                              size: 16,
                                              color: kTextMuted),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(m.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: active
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: active
                                                ? kPrimary
                                                : kTextPrimary)),
                                    if (m.artist.isNotEmpty)
                                      Text(m.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: kTextMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(_fmt(m.duration.toDouble()),
                              style: TextStyle(
                                  fontSize: 11, color: kTextMuted)),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
