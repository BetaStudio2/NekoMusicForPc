/// 一行 LRC 歌词。time < 0 表示无时间戳的纯文本行；
/// translation 为同时间戳的 `=` 前缀翻译行（可空，对齐 Qt parseLyrics）。
class LrcLine {
  const LrcLine(this.time, this.text, [this.translation = '']);

  final double time;
  final String text;
  final String translation;
}

/// 解析 LRC 文本：[mm:ss.xx] 标签；纯文本行 time = -1；
/// `[mm:ss]=翻译` 合并为同一时间戳主行的 translation（对齐 Qt DesktopLrc::parseLyrics）。
List<LrcLine> parseLrc(String lrc) {
  final lines = <LrcLine>[];
  final re = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  for (final raw in lrc.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final matches = re.allMatches(line).toList();
    if (matches.isEmpty) {
      lines.add(LrcLine(-1, line));
      continue;
    }
    final text = line.substring(matches.last.end).trim();
    final isTranslation = text.startsWith('=');
    final content = isTranslation ? text.substring(1).trim() : text;
    if (isTranslation && content.isEmpty) continue;
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      var ms = 0.0;
      final frac = m.group(3);
      if (frac != null) {
        ms = int.parse(frac) /
            (frac.length == 2
                ? 100
                : frac.length == 3
                    ? 1000
                    : 10);
      }
      final time = min * 60 + sec + ms;
      if (isTranslation) {
        // 翻译行：合并到同时间主行（从后往前找）
        for (var i = lines.length - 1; i >= 0; i--) {
          if (lines[i].time == time) {
            lines[i] = LrcLine(time, lines[i].text, content);
            break;
          }
        }
      } else {
        lines.add(LrcLine(time, content.isEmpty ? '♪' : content));
      }
    }
  }
  lines.sort((a, b) {
    // 无时间戳行排在最后，避免时间排序混乱
    if (a.time < 0) return 1;
    if (b.time < 0) return -1;
    return a.time.compareTo(b.time);
  });
  return lines;
}
