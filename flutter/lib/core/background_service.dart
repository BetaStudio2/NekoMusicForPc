// 后台常驻：系统托盘 + 关窗最小化到托盘（播放继续）。
//
// 参考 ArchoeraMusic tray_integration / 原 Qt 版 SystemTray 行为：
//  - 窗口关闭 → 隐藏到托盘，引擎继续播放
//  - 托盘菜单：显示主界面 / 播放暂停 / 上一首 / 下一首 / 退出
//  - 托盘图标左键点击 → 显示主界面
//  - 托盘环境不可用（如无 appindicator）→ 降级为正常关闭退出
//
// ignore_for_file: avoid_print
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../ffi/neko_engine.dart' show NekoPlayState;
import '../main.dart';

class BackgroundService with WindowListener, TrayListener {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  bool _ready = false;

  /// 在主界面就绪后调用；失败自动降级（不 preventClose）
  Future<void> init() async {
    try {
      trayManager.addListener(this);
      await trayManager.setIcon('assets/logo/nekomusic.png');
      try {
        await trayManager.setToolTip('Neko歌姬计划');
      } catch (_) {}
      await trayManager.setContextMenu(_buildMenu());

      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      _ready = true;
    } catch (e) {
      debugPrint('[tray] 初始化失败，降级为正常关闭: $e');
      _ready = false;
      try {
        await trayManager.destroy();
      } catch (_) {}
    }
  }

  Menu _buildMenu() {
    return Menu(items: [
      MenuItem(key: 'show', label: '显示主界面', onClick: (_) => _showWindow()),
      MenuItem.separator(),
      MenuItem(
          key: 'toggle',
          label: '播放 / 暂停',
          onClick: (_) {
            final (_, engine) = appControllers;
            if (engine.state != NekoPlayState.stopped) {
              engine.togglePlayPause();
            }
          }),
      MenuItem(
          key: 'prev',
          label: '上一首',
          onClick: (_) {
            final (core, engine) = appControllers;
            final m = core.previous();
            if (m != null) engine.playUrl(m.playUrl());
          }),
      MenuItem(
          key: 'next',
          label: '下一首',
          onClick: (_) {
            final (core, engine) = appControllers;
            final m = core.next();
            if (m != null) engine.playUrl(m.playUrl());
          }),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出', onClick: (_) => quit()),
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
  }

  // ── 托盘事件 ──
  @override
  void onTrayIconMouseDown() => _showWindow();
  @override
  void onTrayIconRightMouseDown() {}

  /// 真正退出：清理托盘并关闭窗口（结束进程）
  Future<void> quit() async {
    if (_ready) {
      try {
        await trayManager.destroy();
      } catch (_) {}
    }
    await windowManager.destroy();
  }
}
