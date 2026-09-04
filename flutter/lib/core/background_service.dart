// 后台常驻：系统托盘 + 关窗最小化到托盘（播放继续）。
//
// 参考 ArchoeraMusic tray_integration / 原 Qt 版 SystemTray 行为：
//  - 窗口关闭 → 隐藏到托盘，引擎继续播放
//  - 托盘菜单：显示主界面 / 播放暂停 / 上一首 / 下一首 / 退出
//  - 托盘图标左键点击 → 显示主界面
//  - 托盘环境不可用（如无 appindicator）→ 降级为正常关闭退出
//
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../ffi/neko_engine.dart' show NekoPlayState;
import '../main.dart';

class BackgroundService with WindowListener, TrayListener {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  bool _ready = false;
  Timer? _winRefreshTimer;
  String? _iconFile;

  /// 托盘图标：Flutter 资产路径对原生插件不可见，先落盘为临时文件
  Future<String> _ensureIconFile() async {
    if (_iconFile != null) return _iconFile!;
    final data = await rootBundle.load('assets/logo/neko_tray.ico');
    final f = File('${Directory.systemTemp.path}/neko_tray_icon.ico');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    _iconFile = f.path;
    return _iconFile!;
  }

  /// Windows 托盘极易被 Explorer 通知区回收：图标消失/右键菜单丢失。
  /// 用低频周期重设图标与菜单恢复（仅 Windows）。
  Future<void> _refreshWindowsTray() async {
    if (!_ready || !Platform.isWindows) return;
    try {
      await trayManager.setIcon(await _ensureIconFile());
      await trayManager.setContextMenu(_buildMenu());
    } catch (_) {}
  }

  /// 在主界面就绪后调用；失败自动降级（不 preventClose）
  Future<void> init() async {
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(await _ensureIconFile());
      try {
        await trayManager.setToolTip('Neko歌姬计划');
      } catch (_) {}
      await trayManager.setContextMenu(_buildMenu());

      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      _ready = true;

      if (Platform.isWindows) {
        // 首帧后重挂一次（图标注册竞态），之后低频续命防 Explorer 回收
        Timer(const Duration(seconds: 3), _refreshWindowsTray);
        _winRefreshTimer = Timer.periodic(
            const Duration(seconds: 30), (_) => _refreshWindowsTray());
      }
    } catch (e) {
      debugPrint('[tray] init failed, falling back to normal close: $e');
      _ready = false;
      _winRefreshTimer?.cancel();
      try {
        await trayManager.destroy();
      } catch (_) {}
    }
  }

  Menu _buildMenu() {
    return Menu(items: [
      MenuItem(key: 'show', label: ThemeController.instance.t('显示主界面','Show main window'), onClick: (_) => _showWindow()),
      MenuItem.separator(),
      MenuItem(
          key: 'toggle',
          label: ThemeController.instance.t('播放 / 暂停','Play / Pause'),
          onClick: (_) {
            final (_, engine) = appControllers;
            if (engine.state != NekoPlayState.stopped) {
              engine.togglePlayPause();
            }
          }),
      MenuItem(
          key: 'prev',
          label: ThemeController.instance.t('上一首','Previous'),
          onClick: (_) {
            final (core, engine) = appControllers;
            final m = core.previous();
            if (m != null) engine.playUrl(m.playUrl());
          }),
      MenuItem(
          key: 'next',
          label: ThemeController.instance.t('下一首','Next'),
          onClick: (_) {
            final (core, engine) = appControllers;
            final m = core.next();
            if (m != null) engine.playUrl(m.playUrl());
          }),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: ThemeController.instance.t('退出','Quit'), onClick: (_) => quit()),
    ]);
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  // ── 窗口关闭：后台常驻（隐藏窗口，播放继续） ──
  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
    // 隐藏后补一次刷新（防止切到托盘瞬间图标丢失）
    _refreshWindowsTray();
  }

  // ── 托盘事件 ──
  @override
  void onTrayIconMouseDown() => _showWindow();
  @override
  void onTrayIconRightMouseDown() {}

  /// 真正退出：清理托盘并关闭窗口（结束进程）
  Future<void> quit() async {
    _winRefreshTimer?.cancel();
    if (_ready) {
      try {
        await trayManager.destroy();
      } catch (_) {}
    }
    await windowManager.destroy();
  }
}
