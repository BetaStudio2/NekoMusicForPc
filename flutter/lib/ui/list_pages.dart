import 'neko_icons.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../ffi/neko_core.dart';
import 'widgets/song_tile.dart';

/// 收藏页（我喜欢的，对齐原版 FavoritesPage）
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.myFavorites,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (core.favorites.isNotEmpty)
              Text(l10n.playlistCountSongs(core.favorites.length),
                  style: TextStyle(color: kTextMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              if (!core.isLoggedIn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l10n.loginHintFavorites,
                      style: TextStyle(color: kTextMuted, fontSize: 12)),
                ),
              SongList(core: core, songs: core.favorites, emptyText: l10n.emptyFavorites),
            ],
          ),
        ),
      ],
    );
  }
}

/// 最近播放页（对齐原版 RecentPage）
class RecentsPage extends StatelessWidget {
  const RecentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.navRecents,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (core.recents.isNotEmpty)
              Text(l10n.playlistCountSongs(core.recents.length),
                  style: TextStyle(color: kTextMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              SongList(core: core, songs: core.recents, emptyText: l10n.emptyRecents),
            ],
          ),
        ),
      ],
    );
  }
}

/// 下载页（对齐原版 DownloadPage）：正在下载 / 已完成 双 Tab。
/// 进行中列表来自 downloadsStatus() 队列快照 + seq=-1 进度事件实时刷新。
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  AppLocalizations get _l10n => AppLocalizations.of(context);
  int _tab = 0; // 0 = 正在下载, 1 = 已完成

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CoreScope.of(context).requestDownloadsStatus();
    });
  }

  String _fmtBytes(int v) {
    if (v <= 0) return '--';
    if (v < 1024) return '$v B';
    if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
    return '${(v / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_l10n.download,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: core.requestDownloadsStatus,
              icon: const Icon(NekoIcons.Refresh, size: 16),
              label: Text(_l10n.actionRefresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment<int>(
                    value: 0,
                    label: Text(_l10n.downloadsActiveN(core.downloadsActive.length))),
                ButtonSegment<int>(
                    value: 1, label: Text(_l10n.downloadsDoneN(core.downloads.length))),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const Spacer(),
            if (_tab == 0 && core.downloadsActive.isNotEmpty)
              TextButton(
                onPressed: () {
                  for (final m in List.of(core.downloadsActive)) {
                    core.cancelDownload(m.id);
                  }
                },
                child: Text(_l10n.cancelAllDownloads,
                    style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              )
            else if (_tab == 1 && core.downloads.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  core.playAll(core.downloads);
                  if (core.downloads.isNotEmpty) core.play(core.downloads.first);
                },
                icon: const Icon(NekoIcons.Play, size: 16),
                label: Text(_l10n.playAll, style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListenableBuilder(
            listenable: core,
            builder: (context, _) {
              if (_tab == 0) return _buildActive(core);
              return _buildDone(core);
            },
          ),
        ),
      ],
    );
  }

  // ── 正在下载：队列 + 进度 ──

  Widget _buildActive(CoreController core) {
    final list = core.downloadsActive;
    if (list.isEmpty) {
      return Center(
        child: Text(_l10n.noActiveDownloads,
            style: TextStyle(color: kTextMuted, fontSize: 13)),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: kDivider),
      itemBuilder: (context, i) {
        final m = list[i];
        final total = m.progressTotal;
        final received = m.progressReceived;
        final pct = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        final downloading = i == 0 && total > 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _cover(m),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(m.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 12, color: kTextMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: downloading ? pct : null,
                              minHeight: 5,
                              backgroundColor: kBgMid,
                              color: kPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 76,
                          child: Text(
                            total > 0
                                ? '${(pct * 100).toStringAsFixed(0)}%  ${_fmtBytes(received)}/${_fmtBytes(total)}'
                                : _l10n.queuing,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11, color: kTextMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _l10n.cancelDownload,
                iconSize: 18,
                icon: const Icon(NekoIcons.Close),
                color: kTextSecondary,
                onPressed: () => core.cancelDownload(m.id),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 已完成：本地文件列表（含打开文件夹） ──

  Widget _buildDone(CoreController core) {
    final list = core.downloads;
    if (list.isEmpty) {
      return Center(
        child: Text(_l10n.emptyDownloads,
            style: TextStyle(color: kTextMuted, fontSize: 13)),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: kDivider),
      itemBuilder: (context, i) {
        final m = list[i];
        return InkWell(
          onTap: () => core.play(m),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _cover(m),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        '${m.artist} · ${m.localPath.split('/').last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 12, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _l10n.play,
                  iconSize: 20,
                  icon: const Icon(NekoIcons.PlayCircle),
                  color: kTextSecondary,
                  onPressed: () => core.play(m),
                ),
                IconButton(
                  tooltip: _l10n.openContainingFolder,
                  iconSize: 18,
                  icon: const Icon(Icons.folder_open),
                  color: kTextSecondary,
                  onPressed: () {
                    final idx = m.localPath.lastIndexOf('/');
                    final dir = idx > 0 ? m.localPath.substring(0, idx) : null;
                    if (dir != null) {
                      Process.start('xdg-open', [dir]);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cover(NekoCoreMusic m) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: m.coverUrl.isNotEmpty
            ? Image.network(m.fullCoverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _coverFallback())
            : _coverFallback(),
      ),
    );
  }

  Widget _coverFallback() => Container(
        color: kBgMid,
        child: Icon(NekoIcons.Music, color: kTextFaint, size: 20),
      );
}
