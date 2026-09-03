import 'package:flutter/material.dart';

/// 居中弹出式对话框（风格参考 ArchoeraMusic 设置弹窗）：
/// 圆角卡片 + 深色遮罩 + 淡入缩放，内容为整页型 Widget。
Future<void> showCenterDialog(
  BuildContext context, {
  required Widget page,
  double widthRatio = 0.9,
  double heightRatio = 0.86,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim, sec) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(ctx).size.width * widthRatio,
          maxHeight: MediaQuery.of(ctx).size.height * heightRatio,
        ),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: page,
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, sec, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
        child: child,
      ),
    ),
  );
}
