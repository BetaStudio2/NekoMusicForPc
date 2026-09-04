import 'package:flutter/material.dart';

import '../../core/core_controller.dart';
import '../../core/engine_controller.dart';
import '../../ffi/neko_core.dart';
import '../../ffi/neko_engine.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../main.dart';
import '../neko_icons.dart';

/// 统一「播放队列」面板组件（播放页与播放条共用）。
/// 头部含设备选择器（本机 + LAN 设备，对齐 Qt PlaylistPanel QComboBox）：
///   - 选「本机」→ 显示本地播放队列
///   - 选远端设备 → 同一列表切换为该设备远端队列，底部提供「接管播放」
class QueuePanelBody extends StatelessWidget {
  const QueuePanelBody({super.key, required this.onClose});

  final VoidCallback onClose;

  NekoCoreMusic _musicFromRemote(Map<String, dynamic> it) {
    return NekoCoreMusic(
      id: (it['id'] as num?)?.toInt() ?? 0,
      title: (it['title'] as String?) ?? '',
      artist: (it['artist'] as String?) ?? '',
      album: (it['album'] as String?) ?? '',
      duration: (it['duration'] as num?)?.toInt() ?? 0,
      coverUrl: (it['coverPath'] as String?) ?? '',
      localPath: '',
      playCount: 0,
      uploadedAtMs: 0,
      lrc: false,
    );
  }

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
        _ => NekoIcons.FormatList,
      };

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final engine = EngineScope.of(context);
    final l10n = AppLocalizations.of(context);
    final t = ThemeController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([core, engine, ThemeController.instance]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final playing = engine.state == NekoPlayState.playing;
        final sel = core.lanSelectedDeviceId;
        final remote = sel.isNotEmpty;
        final rq = core.lanRemoteQueue;
        final remoteItems =
            (rq?['items'] as List? ?? const <dynamic>[]).cast<Map<String, dynamic>>();
        final localQueue = core.queue;
        final curRemoteId =
            (rq?['currentMusicId'] as num?)?.toInt() ?? 0;
        final deviceName = remote
            ? (() {
                for (final d in core.lanDevices) {
                  if ((d['id'] ?? d['deviceId'])?.toString() == sel) {
                    return d['deviceName']?.toString() ?? sel;
                  }
                }
                return sel;
              })()
            : t.t('本机', 'This device');
        final count = remote ? remoteItems.length : localQueue.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 4),
              child: Row(
                children: [
                  Icon(remote ? NekoIcons.DevicesOther : NekoIcons.PlayList,
                      size: 19, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(remote
                      ? t.t('远端队列', 'Remote queue')
                      : l10n.queueTitle,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (count > 0)
                    Text('$count',
                        style:
                            TextStyle(fontSize: 12, color: kTextMuted)),
                  const SizedBox(width: 8),
                  // ── 设备选择器（本机 + LAN 设备，对齐 Qt deviceCombo）──
                  PopupMenuButton<String>(
                    onSelected: (v) => core.lanSelectDevice(v),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: '',
                        height: 38,
                        child: Row(
                          children: [
                            Icon(NekoIcons.PlayList,
                                size: 16,
                                color: !remote ? kPrimary : kTextSecondary),
                            const SizedBox(width: 8),
                            Text(t.t('本机', 'This device'),
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      for (final d in core.lanDevices)
                        PopupMenuItem(
                          value:
                              (d['id'] ?? d['deviceId'])?.toString() ?? '',
                          height: 38,
                          child: Row(
                            children: [
                              Icon(NekoIcons.DevicesOther,
                                  size: 16,
                                  color: remote &&
                                          (d['id'] ?? d['deviceId'])
                                                  ?.toString() ==
                                      sel
                                      ? kPrimary
                                      : kTextSecondary),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  d['deviceName']?.toString() ?? '?',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: remote
                            ? kPrimary.withValues(alpha: 0.15)
                            : kBgMid,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(NekoIcons.DevicesOther,
                              size: 14,
                              color: remote ? kPrimary : kTextSecondary),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 120),
                            child: Text(
                              deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: remote
                                      ? kPrimary
                                      : kTextPrimary),
                            ),
                          ),
                          Icon(NekoIcons.Down,
                              size: 14, color: kTextMuted),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: t.t('播放模式', 'Play mode'),
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
                    onPressed:
                        localQueue.isEmpty || remote ? null : core.clearQueue,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(NekoIcons.DeleteSweep, size: 18),
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
              child: remote
                  ? (remoteItems.isEmpty
                      ? Center(
                          child: Text(t.t('该设备暂无播放内容', 'Nothing playing'),
                              style: TextStyle(
                                  fontSize: 12, color: kTextMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: remoteItems.length,
                          itemBuilder: (context, i) {
                            final m = remoteItems[i];
                            final active =
                                (m['id'] as num?)?.toInt() == curRemoteId;
                            return ListTile(
                              dense: true,
                              onTap: () {
                                core.play(_musicFromRemote(m));
                                core.lanSelectDevice('');
                              },
                              leading: SizedBox(
                                width: 36,
                                child: Center(
                                  child: active
                                      ? Icon(playing
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
                              title: Text(
                                m['title']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: active
                                        ? kPrimary
                                        : kTextPrimary),
                              ),
                              subtitle: m['artist']?.toString().isNotEmpty ==
                                      true
                                  ? Text(
                                      m['artist'].toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: kTextMuted))
                                  : null,
                            );
                          },
                        ))
                  : (localQueue.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(NekoIcons.PlaylistPlay,
                                  size: 44,
                                  color:
                                      kTextMuted.withValues(alpha: 0.35)),
                              const SizedBox(height: 10),
                              Text(l10n.queueEmpty,
                                  style: TextStyle(
                                      color: kTextMuted, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(l10n.queueEmptyHint,
                                  style: TextStyle(
                                      color: kTextMuted
                                          .withValues(alpha: 0.6),
                                      fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: localQueue.length,
                          itemBuilder: (context, i) {
                            final m = localQueue[i];
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
                                    borderRadius:
                                        BorderRadius.circular(6),
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
                                                child: Icon(
                                                    NekoIcons.Music,
                                                    size: 16,
                                                    color: kTextMuted),
                                              ),
                                            )
                                          : Container(
                                              color: kBgSurface,
                                              child: Icon(
                                                  NekoIcons.Music,
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
                                            overflow:
                                                TextOverflow.ellipsis,
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
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: kTextMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      _fmt(m.duration.toDouble()),
                                      style: TextStyle(
                                          fontSize: 11, color: kTextMuted)),
                                  IconButton(
                                    tooltip: t.t('移除', 'Remove'),
                                    icon: const Icon(NekoIcons.Close,
                                        size: 14),
                                    constraints:
                                        const BoxConstraints.tightFor(
                                            width: 26, height: 26),
                                    visualDensity:
                                        VisualDensity.compact,
                                    color: kTextMuted,
                                    onPressed: () =>
                                        core.removeFromQueue(i),
                                  ),
                                ],
                              ),
                            );
                          },
                        )),
            ),
            if (remote && remoteItems.isNotEmpty)
              Divider(height: 1, color: kDivider),
            if (!remote &&
                !localQueue.isEmpty &&
                core.currentIndex >= 0 &&
                localQueue.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: t.t('定位当前播放', 'Scroll to current'),
                    icon: const Icon(NekoIcons.Location, size: 16),
                    constraints: const BoxConstraints.tightFor(
                        width: 30, height: 30),
                    visualDensity: VisualDensity.compact,
                    color: kTextSecondary,
                    onPressed: () {
                      // 滚动到当前曲（近似按行高 56）
                      Scrollable.ensureVisible(
                        context,
                        alignment: 0.0,
                        duration: const Duration(milliseconds: 200),
                        alignmentPolicy: ScrollPositionAlignmentPolicy
                            .explicit,
                      );
                    },
                  ),
                ),
              ),
            if (remote && remoteItems.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextSecondary,
                          side: BorderSide(color: kDivider),
                        ),
                        onPressed: () {
                          final songs =
                              remoteItems.map(_musicFromRemote).toList();
                          if (songs.isNotEmpty) {
                            core.replaceQueue(songs);
                            core.lanSelectDevice('');
                          }
                        },
                        icon: const Icon(NekoIcons.AddList, size: 16),
                        label: Text(t.t('替换本机列表', 'Replace local'),
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white),
                        onPressed: () {
                          final songs =
                              remoteItems.map(_musicFromRemote).toList();
                          if (songs.isNotEmpty) {
                            core.playAll(songs);
                            core.lanSelectDevice('');
                          }
                        },
                        icon: const Icon(NekoIcons.Play, size: 16),
                        label: Text(t.t('播放全部', 'Play all'),
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
