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
WEB="$ROOT_DIR/src/resources/icons-web"
FLUTTER="$ROOT_DIR/flutter"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src"
python3 - "$SRC" "$WEB" "$WORK/src" <<'PYEOF'
import os, re, shutil, sys
dirs, dst = sys.argv[1:-1], sys.argv[-1]
inc = exc = 0
for src in dirs:
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

rm -rf "$WORK/node_modules"
mkdir -p "$WORK/out"
(cd "$WORK" && npm i --no-audit --no-fund --silent fantasticon)
(cd "$WORK" && npx fantasticon)

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
    lines.append(f"  static const IconData {const(k)} = IconData(0x{m[k]:04X}, fontFamily: 'neko_icons');")
lines.append("}")
open(sys.argv[2], 'w').write('\n'.join(lines) + '\n')
print(f"dart regenerated: {len(m)} icons")
PYEOF

# 完整性守卫：码点唯一 + json 与 dart 常量一一对应，防静默丢字形
python3 - "$WORK/out/neko_icons.json" "$FLUTTER/lib/ui/neko_icons.dart" <<'PYEOF'
import json, re, sys
m = json.load(open(sys.argv[1]))
src = open(sys.argv[2], encoding='utf-8').read()
consts = dict(re.findall(r'IconData (\w+) = IconData\((0x[0-9A-Fa-f]+),', src))
by_cp = {}
for k, cp in m.items():
    if cp in by_cp:
        raise SystemExit(f'dup codepoint {cp:#x}: {by_cp[cp]} / {k}')
    by_cp[cp] = k
if len(consts) != len(m):
    raise SystemExit(f'mismatch dart={len(consts)} json={len(m)}')
# 每个 json 名对应一个 dart 常量（kebab -> Pascal）
expect = {''.join(p[:1].upper() + p[1:] for p in k.split('-')) for k in m}
diff = set(consts) ^ expect
if diff:
    raise SystemExit(f'name mismatch: {sorted(diff)[:10]}')
print(f'guard ok: {len(m)} unique glyphs == dart consts')
PYEOF

echo "== done: $FLUTTER/assets/fonts/neko_icons.ttf (+ $FLUTTER/lib/ui/neko_icons.dart)"
