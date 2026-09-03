#!/usr/bin/env bash
# 由原作者自制 SVG（src/resources/icons）重建 NekoIcons 图标字体。
#
# 用法: ./scripts/build-icon-font.sh
# 前置: Node + npm（fantasticon 走 npx 临时安装）
#
# 过滤规则：剔除非单色字形（stroke 轮廓 / 渐变 / url(#) 引用），
# 它们无法作为 fill 型字体字形，Flutter 侧保留 Material 同义图标。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/src/resources/icons"
FLUTTER="$ROOT_DIR/flutter"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src"
python3 - "$SRC" "$WORK/src" <<'PYEOF'
import os, re, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
inc = exc = 0
for f in sorted(os.listdir(src)):
    if not f.endswith('.svg'):
        continue
    c = open(os.path.join(src, f)).read()
    if re.search(r'stroke=|gradient|<stop|url\(#', c):
        exc += 1
        continue
    base = f[:-4]
    kebab = re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '-', base).lower()
    shutil.copy(os.path.join(src, f), os.path.join(dst, kebab + '.svg'))
    inc += 1
print(f"include={inc} exclude={exc}")
PYEOF

cat > "$WORK/.fantasticonrc.json" <<'EOF'
{
  "name": "neko_icons",
  "inputDir": "src",
  "outputDir": "out",
  "fontTypes": ["ttf"],
  "assetTypes": ["json"],
  "normalize": true,
  "fontHeight": 1000,
  "descent": 0,
  "round": 1e10
}
EOF

mkdir -p "$WORK/node_modules"
(cd "$WORK" && npm i --no-audit --no-fund --silent fantasticon >/dev/null 2>&1)
(cd "$WORK" && npx fantasticon >/dev/null)

mkdir -p "$FLUTTER/assets/fonts"
cp "$WORK/out/neko_icons.ttf" "$FLUTTER/assets/fonts/neko_icons.ttf"

python3 - "$WORK/out/neko_icons.json" "$FLUTTER/lib/ui/neko_icons.dart" <<'PYEOF'
import json, sys
m = json.load(open(sys.argv[1]))
def const(n):
    return ''.join(p[:1].upper() + p[1:] for p in n.split('-'))
lines = [
    "// 由 src/resources/icons 经 scripts/build-icon-font.sh 生成，勿手改。",
    "import 'package:flutter/widgets.dart';",
    "",
    "/// 原作者自制图标字体（neko_icons.ttf）——单色字形，颜色由 IconTheme 决定，深浅主题自适应。",
    "abstract final class NekoIcons {",
]
for k in sorted(m):
    lines.append(f"  static const IconData {const(k)} = IconData(0x{m[k]:04X}, fontFamily: 'NekoIcons');")
lines.append("}")
open(sys.argv[2], 'w').write('\n'.join(lines) + '\n')
print(f"dart regenerated: {len(m)} icons")
PYEOF

echo "== done: $FLUTTER/assets/fonts/neko_icons.ttf (+ $FLUTTER/lib/ui/neko_icons.dart)"
