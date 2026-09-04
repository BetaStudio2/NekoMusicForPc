import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neko_music/ffi/neko_core.dart';

/// neko_core FFI 冒烟测试：验证 Struct 布局、字符串读写、命令队列。
/// 运行前需先构建 engine（engine/build/libneko_core.so）。
void main() {
  test('neko_core FFI smoke', () {
    final core = NekoCore();
    core.start(verbose: false);
    expect(core.isLoggedIn, false);

    // 音频头：未登录应为空
    expect(core.audioHeaders, isEmpty);

    // 热门榜
    final seq = core.fetchRanking();
    expect(seq, isNot(0));
    NekoCoreResult? r;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      final ev = core.poll();
      if (ev != null && ev.seq == seq) {
        r = ev;
        break;
      }
      sleep(const Duration(milliseconds: 50));
    }
    expect(r, isNotNull, reason: 'ranking result not received');
    expect(r!.ok, true);
    expect(r.rows.length, greaterThan(0));
    final first = r.rows.first;
    expect(first.id, greaterThan(0));
    expect(first.title, isNotEmpty);
    expect(first.playUrl(), contains('/api/music/file/'));
    expect(first.fullCoverUrl, startsWith('http'));

    // 最新
    final seq2 = core.fetchLatest(3);
    NekoCoreResult? r2;
    final deadline2 = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline2)) {
      final ev = core.poll();
      if (ev != null && ev.seq == seq2) {
        r2 = ev;
        break;
      }
      sleep(const Duration(milliseconds: 50));
    }
    expect(r2, isNotNull);
    expect(r2!.ok, true);

    core.stop();
  });
}
