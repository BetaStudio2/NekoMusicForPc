import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neko_music/ui/neko_icons.dart';

Future<int> countInk(WidgetTester tester, IconData icon) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: RepaintBoundary(key: key, child: Icon(icon, size: 128, color: const Color(0xFF000000))),
  ));
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
  final bytes = data!.buffer.asUint8List();
  var inked = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i + 3] > 0) inked++;
  }
  return inked;
}

const _cases = <(String, IconData)>[
  ('home', NekoIcons.Home),
  ('earth', NekoIcons.Earth),
  ('update', NekoIcons.Update),
  ('tag', NekoIcons.Tag),
  ('github', NekoIcons.Github),
  ('download', NekoIcons.Download),
  ('favorite', NekoIcons.Favorite),
  ('history', NekoIcons.History),
  ('music', NekoIcons.Music),
  ('play', NekoIcons.Play),
];

void main() {
  for (final c in _cases) {
    testWidgets('ink ${c.$1}', (tester) async {
      final ink = await countInk(tester, c.$2);
      // ignore: avoid_print
      print('${c.$1}: inked=$ink');
      expect(ink, greaterThan(200), reason: '${c.$1} 无像素');
    });
  }
}
