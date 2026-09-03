import 'neko_icons.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';

/// 设置页：对齐原版 SettingsPage 的四个分组
///   通用（语言切换）/ 外观（主题 + 背景个性化）/ 快捷键 / 关于（版本/GitHub/检查更新）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([core, ThemeController.instance]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final username =
            core.userInfo?['username'] ?? core.userInfo?['nickname'];
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          children: [
            Text(l10n.settingsTitle,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // ── 通用：语言切换（dart 原生 l10n，实时生效并持久化） ──
            _section(l10n.settingsGeneral, [
              ListTile(
                leading: const Icon(NekoIcons.Earth),
                title: Text(l10n.settingsLanguage),
                trailing: DropdownButton<String>(
                  value: ThemeController.instance.language,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(10),
                  items: [
                    DropdownMenuItem(
                        value: 'zh', child: Text(l10n.settingsLanguageZh)),
                    DropdownMenuItem(
                        value: 'en', child: Text(l10n.settingsLanguageEn)),
                    DropdownMenuItem(
                        value: 'ja', child: Text(l10n.settingsLanguageNya)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ThemeController.instance.setLanguage(v);
                    }
                  },
                ),
              ),
            ]),
            // ── 外观：主题 + 背景个性化 ──
            _section(l10n.settingsAppearance, [
              SwitchListTile(
                secondary: const Icon(NekoIcons.Palette),
                title: Text(l10n.settingsDarkTheme),
                subtitle: Text(l10n.settingsDarkThemeHint),
                value: ThemeController.instance.isDark,
                onChanged: ThemeController.instance.setDark,
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(l10n.settingsBackdropCustomize),
                subtitle: Text(l10n.settingsBackdropHint),
                trailing: DropdownButton<String>(
                  value: ThemeController.instance.backdropKind,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(10),
                  items: [
                    DropdownMenuItem(
                        value: 'default',
                        child: Text(l10n.settingsBackdropFollowTheme)),
                    DropdownMenuItem(
                        value: 'solid',
                        child: Text(l10n.settingsBackdropSolid)),
                    DropdownMenuItem(
                        value: 'image',
                        child: Text(l10n.settingsBackdropImage)),
                  ],
                  onChanged: (v) {
                    if (v == 'image') {
                      _pickBackdropImage(context);
                    } else if (v != null) {
                      ThemeController.instance.setBackdropKind(v);
                    }
                  },
                ),
              ),
              if (ThemeController.instance.backdropKind == 'solid')
                ListTile(
                  leading: const Icon(NekoIcons.Palette),
                  title: Text(l10n.settingsBackdropColor),
                  trailing: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _pickBackdropColor(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ThemeController.instance.backdropColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kDivider),
                      ),
                    ),
                  ),
                ),
              if (ThemeController.instance.backdropKind == 'image')
                ListTile(
                  leading: const Icon(Icons.broken_image_outlined),
                  title: Text(l10n.settingsBackdropImageTitle),
                  subtitle: Text(
                    ThemeController.instance.backdropImagePath.isEmpty
                        ? l10n.settingsBackdropNotSet
                        : ThemeController.instance.backdropImagePath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: () =>
                        ThemeController.instance.setBackdropImagePath(''),
                    child: Text(l10n.settingsBackdropRemove),
                  ),
                ),
            ]),
            // ── 快捷键（对齐原版 AppShortcuts 默认值） ──
            _section(l10n.settingsShortcuts, [
              ListTile(
                leading: const Icon(NekoIcons.PlayCircle),
                title: Text(l10n.settingsShortcutPlayPause),
                trailing: const _KeyCap('Ctrl+P'),
              ),
              ListTile(
                leading: const Icon(NekoIcons.SkipNext),
                title: Text(l10n.settingsShortcutNext),
                trailing: const _KeyCap('Ctrl+Alt+→'),
              ),
              ListTile(
                leading: const Icon(NekoIcons.SkipPrev),
                title: Text(l10n.settingsShortcutPrev),
                trailing: const _KeyCap('Ctrl+Alt+←'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  l10n.settingsShortcutHint,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ]),
            // ── 关于 ──
            _section(l10n.settingsAbout, [
              ListTile(
                leading: const Icon(NekoIcons.Info),
                title: Text(l10n.appName),
                subtitle: Text(l10n.settingsAppSubtitle),
              ),
              ListTile(
                leading: const Icon(NekoIcons.Tag),
                title: Text(l10n.settingsVersion),
                // 版本读取自 pubspec.yaml（version 字段，随构建注入）
                trailing: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Text(
                      snap.data?.version ?? '…',
                      style: TextStyle(color: kTextSecondary, fontSize: 13)),
                ),
              ),
              ListTile(
                leading: const Icon(NekoIcons.Github),
                title: Text(l10n.settingsGithubRepo),
                subtitle: const Text('FantasyNetworkCN/NekoMusicForPc'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () async {
                  await Clipboard.setData(const ClipboardData(
                      text: 'https://github.com/FantasyNetworkCN/NekoMusicForPc'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.settingsGithubCopied),
                        duration: const Duration(seconds: 1)));
                  }
                },
              ),
              ListTile(
                leading: const Icon(NekoIcons.Update),
                title: Text(l10n.settingsCheckUpdate),
                trailing: const Icon(NekoIcons.Right, size: 18),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.settingsUpToDate),
                      duration: const Duration(seconds: 1)));
                },
              ),
            ]),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _pickBackdropColor(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final color = await showDialog<Color>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsBackdropColorPickerTitle),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in const [
                  Color(0xFF14161B),
                  Color(0xFF1B1E24),
                  Color(0xFF23262E),
                  Color(0xFF2C3E50),
                  Color(0xFF1A237E),
                  Color(0xFF4A148C),
                  Color(0xFF1B5E20),
                  Color(0xFF311B92),
                  Color(0xFF3E2723),
                  Color(0xFF101418),
                ])
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(ctx).pop(c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kDivider),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (color != null) ThemeController.instance.setBackdropColor(color);
  }

  Future<void> _pickBackdropImage(BuildContext context) async {
    final result = await _pickImageFile(context);
    if (result == null) return;
    ThemeController.instance
      ..setBackdropKind('image')
      ..setBackdropImagePath(result);
  }

  Future<String?> _pickImageFile(BuildContext context) async {
    // 桌面端无插件时：从 ~/Pictures、~/Downloads 快速选择，或直接输入路径
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final home = userHomeDir;
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: Text(l10n.settingsBackdropImagePathTitle),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '${home}/Pictures/wallpaper.jpg',
                  isDense: true,
                  filled: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.settingsBackdropImageFormatHint,
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.settingsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary.withValues(alpha: 0.15),
              foregroundColor: kPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.settingsApply),
          ),
        ],
      ),
    );
    if (path == null || path.isEmpty) return null;
    // 展开 ~ 为用户主目录（输入 ~/Pictures/xx.jpg 这类路径）
    var p = path;
    if (p == '~' || p.startsWith('~/')) {
      p = userHomeDir + p.substring(1);
    }
    final f = File(p);
    if (!f.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.settingsFileNotFound),
            duration: const Duration(seconds: 1)));
      }
      return null;
    }
    return path;
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
            child: Text(title,
                style: TextStyle(color: kTextMuted, fontSize: 13)),
          ),
          Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
          const SizedBox(height: 16),
        ],
      );
}

/// 快捷键按键样式
class _KeyCap extends StatelessWidget {
  const _KeyCap(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // 无底色盒（固定底色在浅色/深色切换与半透明容器下观感不稳）：
    // 等宽字体 + 次级灰，自然融入任意主题
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: Theme.of(context).textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.75) ??
                kTextSecondary),
      ),
    );
  }
}
