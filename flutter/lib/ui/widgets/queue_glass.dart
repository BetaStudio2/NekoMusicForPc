import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../main.dart';
import 'queue_panel_body.dart';

/// 播放队列抽屉「毛玻璃面板」——播放页与播放条共用同一方案：
/// 玻璃层 + 圆角 + 白描边 + 阴影，内部统一为 [QueuePanelBody]。
class QueueGlass extends StatelessWidget {
  const QueueGlass({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kBgSurface.withValues(alpha: 0.72),
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
          child: QueuePanelBody(onClose: onClose),
        ),
      ),
    );
  }
}
