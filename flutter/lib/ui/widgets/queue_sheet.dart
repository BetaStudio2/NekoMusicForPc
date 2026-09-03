import 'package:flutter/material.dart';

import '../../main.dart';
import 'queue_panel_body.dart';

/// 播放条队列 BottomSheet：与播放详情页共用同一 QueuePanelBody，
/// 面板内「设备同步」作为子菜单映射（onLan 非空时展示）。
class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key, required this.onLan});

  final VoidCallback onLan;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: QueuePanelBody(
        onClose: () => Navigator.of(context).pop(),
        onLan: onLan,
      ),
    );
  }
}
