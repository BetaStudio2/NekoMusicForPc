import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../ffi/neko_core.dart' show NekoCoreMusic;

/// LAN 设备同步面板（毛玻璃右缘滑入）。
/// 展示局域网内同账号发现的设备，点击订阅其队列；可一键接管远端列表播放。
class LanPanel extends StatelessWidget {
  const LanPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: core,
        builder: (context, _) {
          final devices = core.lanDevices;
          final rq = core.lanRemoteQueue;
          final rqItems = (rq?['items'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          return Container(
            decoration: BoxDecoration(
              color: kBgSurface.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 6, 4),
                  child: Row(
                    children: [
                      Icon(Icons.devices_other, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      const Text('设备同步',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (!core.isLoggedIn)
                        Text('需登录',
                            style: TextStyle(
                                fontSize: 11, color: kTextMuted)),
                      const Spacer(),
                      IconButton(
                        tooltip: '刷新',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: core.lanPollTick,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: kDivider),
                Expanded(
                  child: devices.isEmpty
                      ? Center(
                          child: Text(
                            core.isLoggedIn ? '局域网内暂无其他设备' : '登录后自动发现同账号设备',
                            style: TextStyle(color: kTextMuted, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: devices.length + (rqItems.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (rqItems.isNotEmpty && i == devices.length) {
                              return _remoteQueueTile(
                                  context, core, rq, rqItems);
                            }
                            final d = devices[i];
                            final selected =
                                d['deviceId'] == core.lanSelectedDeviceId;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor:
                                  kPrimary.withValues(alpha: 0.10),
                              leading: Icon(
                                d['platform'] == 'android'
                                    ? Icons.smartphone
                                    : Icons.computer,
                                size: 20,
                                color: selected
                                    ? kPrimary
                                    : kTextSecondary,
                              ),
                              title: Text(
                                d['deviceName']?.toString() ?? '?',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: selected
                                        ? kPrimary
                                        : kTextPrimary),
                              ),
                              subtitle: Text(
                                '${d['queueCount'] ?? 0} 首 · ${_curTitle(d)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Icon(
                                selected
                                    ? Icons.link
                                    : Icons.link_off,
                                size: 16,
                                color: selected ? kPrimary : kTextMuted,
                              ),
                              onTap: () => core.lanSelectDevice(
                                  selected
                                      ? ''
                                      : (d['deviceId']?.toString() ?? '')),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _remoteQueueTile(
      BuildContext context,
      CoreController core,
      Map<String, dynamic>? rq,
      List<Map<String, dynamic>> items) {
    final currentMusicId = (rq?['currentMusicId'] as num?)?.toInt() ?? 0;
    final playing = rq?['isPlaying'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBgMid.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync, size: 15,
                  color: playing ? kPrimary : kTextMuted),
              const SizedBox(width: 6),
              Text(
                playing ? '远端播放中' : '远端队列',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('${items.length} 首',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _curRemote(items, currentMusicId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary.withValues(alpha: 0.15),
                    foregroundColor: kPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _takeOver(core, items),
                  child: const Text('接管并播放', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 接管：把远端队列写入本地并起播（对齐点击歌单“播放全部”）
  void _takeOver(CoreController core, List<Map<String, dynamic>> items) {
    final songs = <NekoCoreMusic>[];
    for (final it in items) {
      final id = (it['id'] as num?)?.toInt() ?? 0;
      songs.add(NekoCoreMusic(
        id: id,
        title: (it['title'] as String?) ?? '',
        artist: (it['artist'] as String?) ?? '',
        album: (it['album'] as String?) ?? '',
        duration: (it['duration'] as num?)?.toInt() ?? 0,
        coverUrl: (it['coverPath'] as String?) ?? '',
        localPath: '',
        playCount: 0,
        uploadedAtMs: 0,
        lrc: false,
      ));
    }
    if (songs.isNotEmpty) core.playAll(songs);
  }

  String _curTitle(Map<String, dynamic> d) {
    final id = (d['currentMusicId'] as num?)?.toInt() ?? 0;
    if (id == 0) return '未在播放';
    return '正在播放 #$id';
  }

  String _curRemote(List<Map<String, dynamic>> items, int currentId) {
    for (final it in items) {
      if (((it['id'] as num?)?.toInt() ?? 0) == currentId) {
        return '${it['title']} - ${it['artist']}';
      }
    }
    return items.isEmpty ? '空' : '${items.first['title']} …';
  }
}
