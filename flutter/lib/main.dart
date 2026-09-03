import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'core/core_controller.dart';
import 'core/background_service.dart';
import 'core/engine_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/main_shell.dart';

/// 主题调色板：深/浅两套背景 + 主色
class NekoPalette {
  final Color primary;
  final Color bgDeep;
  final Color bgMid;
  final Color bgSurface;

  const NekoPalette({
    required this.primary,
    required this.bgDeep,
    required this.bgMid,
    required this.bgSurface,
  });

  static const dark = NekoPalette(
    primary: Color(0xFFF05E7A),
    bgDeep: Color(0xFF14161B),
    bgMid: Color(0xFF1B1E24),
    bgSurface: Color(0xFF23262E),
  );

  static const light = NekoPalette(
    primary: Color(0xFFE0507A),
    bgDeep: Color(0xFFF6F6F9),
    bgMid: Color(0xFFEDEDF2),
    bgSurface: Color(0xFFFFFFFF),
  );
}

/// 主题控制器：深/浅切换 + 背景个性化 + 本地持久化（~/.nekomusic/settings.json）
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  bool _dark = true;
  bool get isDark => _dark;

  // 界面语言：zh（简体中文）| en（English），由设置页切换
  String _language = 'zh';
  String get language => _language;

  /// 双语直取（用于无 BuildContext 的核心层/托盘文案）
  String t(String zh, String en) => _language == 'en' ? en : zh;

  // 背景个性化：default（跟随主题）| solid（纯色）| image（自定义图片）
  String _backdropKind = 'default';
  String get backdropKind => _backdropKind;
  Color _backdropColor = NekoPalette.dark.bgDeep;
  Color get backdropColor => _backdropColor;
  String _backdropImagePath = '';
  String get backdropImagePath => _backdropImagePath;

  File get _file =>
      File('${Platform.environment['HOME'] ?? '.'}/.nekomusic/settings.json');

  Future<void> load() async {
    try {
      if (await _file.exists()) {
        final j =
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        _dark = (j['dark'] as bool?) ?? true;
        _language = (j['language'] as String?) ?? 'zh';
        _backdropKind = (j['backdropKind'] as String?) ?? 'default';
        final colorHex = j['backdropColor'] as String?;
        if (colorHex != null && colorHex.length == 7) {
          try {
            _backdropColor = Color(int.parse('FF${colorHex.substring(1)}',
                radix: 16));
          } catch (_) {}
        }
        _backdropImagePath = (j['backdropImagePath'] as String?) ?? '';
      }
    } catch (_) {
      // 配置损坏时保持默认深色
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(jsonEncode({
        'dark': _dark,
        'language': _language,
        'backdropKind': _backdropKind,
        'backdropColor':
            '#${(_backdropColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'backdropImagePath': _backdropImagePath,
      }));
    } catch (_) {
      // 持久化失败不影响本次切换
    }
  }

  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    await _save();
  }

  Future<void> setDark(bool value) async {
    if (_dark == value) return;
    _dark = value;
    notifyListeners();
    await _save();
  }

  Future<void> setBackdropKind(String kind) async {
    if (_backdropKind == kind) return;
    _backdropKind = kind;
    notifyListeners();
    await _save();
  }

  Future<void> setBackdropColor(Color color) async {
    _backdropColor = color;
    notifyListeners();
    await _save();
  }

  Future<void> setBackdropImagePath(String path) async {
    _backdropImagePath = path;
    notifyListeners();
    await _save();
  }

}

NekoPalette get themePalette =>
    ThemeController.instance.isDark ? NekoPalette.dark : NekoPalette.light;

// ── 背景 / 主色（动态，跟随主题切换） ──
Color get kPrimary => themePalette.primary;
Color get kBgDeep => themePalette.bgDeep;
Color get kBgMid => themePalette.bgMid;
Color get kBgSurface => themePalette.bgSurface;

/// 内容卡片背景：半透明——自定义底色（图片/纯色）时可透出背景
Color get kCardBg => themePalette.bgSurface.withValues(alpha: 0.72);

/// 应用背景层（自定义纯色/图片，按主题压暗）：铺在各页面 Stack 最底层。
/// backdropKind 为 default 时返回空列表（页面保持自身底色）。
/// 供主壳与 push 的独立页面（每日推荐等）复用。
List<Widget> appBackdropLayers() {
  final t = ThemeController.instance;
  switch (t.backdropKind) {
    case 'solid':
      return [Positioned.fill(child: ColoredBox(color: t.backdropColor))];
    case 'image':
      if (t.backdropImagePath.isNotEmpty) {
        return [
          Positioned.fill(
            child: Image.file(File(t.backdropImagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          Positioned.fill(
            child: ColoredBox(
                color:
                    Colors.black.withValues(alpha: t.isDark ? 0.45 : 0.20)),
          ),
        ];
      }
  }
  return const [];
}

// ── 语义色：深色主题为白色系，浅色主题为深灰系 ──
Color get kTextPrimary =>
    ThemeController.instance.isDark ? Colors.white : const Color(0xFF1A1D24);
Color get kTextSecondary =>
    ThemeController.instance.isDark ? Colors.white70 : const Color(0xFF5A6070);
Color get kTextMuted =>
    ThemeController.instance.isDark ? Colors.white38 : const Color(0xFF9AA0AC);
Color get kTextFaint =>
    ThemeController.instance.isDark ? Colors.white24 : const Color(0xFFB5BAC5);
Color get kDivider => ThemeController.instance.isDark
    ? Colors.white12
    : const Color(0x1F000000);
Color get kHoverBg => ThemeController.instance.isDark
    ? Colors.white10
    : const Color(0x12000000);

/// 应用级 UI 状态：MainShell 因歌词窗开关重建时保留页面路由
class AppUiState {
  AppUiState._();
  static final AppUiState instance = AppUiState._();

  int page = 0;
  String? searchInitial;
}

/// 应用级核心控制器：MainShell 重建（歌词窗开关）时不重建引擎/登录态
final (CoreController, EngineController) appControllers =
    (CoreController(), EngineController());

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  // 引擎与 Qt 核心桥：应用生命周期单例
  final (core, engine) = appControllers;
  engine.init();
  runApp(NekoApp(core: core, engine: engine));
  // 后台常驻：系统托盘 + 关窗隐藏（引擎继续播放）；失败自动降级
  await BackgroundService.instance.init();
}

class NekoApp extends StatelessWidget {
  const NekoApp({super.key, required this.core, required this.engine});

  final CoreController core;
  final EngineController engine;

  /// 统一主题：切换条（SegmentedButton）与开关（Switch）使用调色板配色，
  /// 修复默认 M3 配色与整体风格不符的问题
  ThemeData _buildTheme(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color surface = dark ? NekoPalette.dark.bgSurface : NekoPalette.light.bgSurface;
    final Color onSurface = dark ? Colors.white : const Color(0xFF1A1D24);
    final Color muted = dark ? Colors.white38 : const Color(0xFF9AA0AC);
    final Color divider = dark ? Colors.white12 : const Color(0x1F000000);
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: dark ? NekoPalette.dark.bgDeep : NekoPalette.light.bgDeep,
      colorScheme: (dark ? ColorScheme.dark : ColorScheme.light)(
        primary: kPrimary,
        surface: surface,
      ),
      splashFactory: NoSplash.splashFactory,
      fontFamily: 'NotoSansCJKsc',
      fontFamilyFallback: const ['Noto Sans CJK SC', 'PingFang SC'],
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? kPrimary.withValues(alpha: 0.85)
                  : surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : onSurface.withValues(alpha: 0.75)),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? kPrimary
                  : divider)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8))),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : muted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? kPrimary
                : divider),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        return MaterialApp(
          title: 'Neko歌姬计划',
          debugShowCheckedModeBanner: false,
          // dart 原生 l10n（gen_l10n）：语言随设置实时切换并持久化
          locale: Locale(ThemeController.instance.language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: MainShell(core: core, engine: engine),
        );
      },
    );
  }
}

/// 全局引擎控制器：MainShell 创建，供全树通过 EngineScope 访问
class EngineScope extends InheritedNotifier<EngineController> {
  const EngineScope({
    super.key,
    required EngineController controller,
    required super.child,
  }) : super(notifier: controller);

  static EngineController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EngineScope>();
    assert(scope != null, 'EngineScope not found in widget tree');
    return scope!.notifier!;
  }
}

/// 全局 Qt 核心桥控制器：MainShell 创建，供全树通过 CoreScope 访问
class CoreScope extends InheritedNotifier<CoreController> {
  const CoreScope({
    super.key,
    required CoreController controller,
    required super.child,
  }) : super(notifier: controller);

  static CoreController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<CoreScope>();
    assert(scope != null, 'CoreScope not found in widget tree');
    return scope!.notifier!;
  }
}
