#!/usr/bin/env bash
# Linux 纯二进制便携包（zip）：把 release bundle 打成一个可运行 zip。
# 说明：仍是动态依赖 gtk3/Qt6/mpv（发行版普遍自带），不依赖 .desktop 注册——
# 运行时窗口图标由二进制内嵌提供（X11/XWayland）。
# 产物: flutter/build/dist/nekomusic-<版本>-linux-x64.zip
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT_DIR/flutter/build/linux/x64/release/bundle"

[[ -x "$BUNDLE/neko_music" ]] || {
  echo "错误: 未找到 release bundle，请先执行 ./scripts/build.sh release" >&2
  exit 1
}

VERSION="$(grep -E '^version:' "$ROOT_DIR/flutter/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
OUT="$ROOT_DIR/flutter/build/dist"
mkdir -p "$OUT"
ZIP="$OUT/nekomusic-${VERSION}-linux-x64.zip"
STAGE="$OUT/portable-linux"
rm -rf "$STAGE"
mkdir -p "$STAGE/nekomusic"
cp -r "$BUNDLE"/. "$STAGE/nekomusic/"
# 附带运行说明与桌面集成（可选，安装器类）
cat > "$STAGE/nekomusic/README.txt" <<EOF
Neko歌姬计划 ${VERSION}（Linux 便携版）
运行: ./neko_music
系统依赖: GTK3、Qt6(Core/Network/Sql/Gui)、libmpv（各发行版均自带）
任务栏图标: 若未显示，请按发行版安装 .deb/.rpm/Arch 包或参考 packaging/install-linux.sh
EOF

rm -f "$ZIP"
(cd "$STAGE" && zip -qr "$ZIP" nekomusic)
rm -rf "$STAGE"
echo "== Linux 便携 zip: $ZIP"
du -sh "$ZIP"
