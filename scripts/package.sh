#!/usr/bin/env bash
# Neko歌姬计划（Flutter 版）打包脚本：生成可直接分发的 tar.gz
#
# 产物结构:
#   nekomusic-<版本>-linux-x64/
#     ├─ neko_music/            # flutter build linux --release 的 bundle
#     ├─ com.nekomusic.neko_music.desktop
#     ├─ icons/hicolor/...      # 应用图标
#     └─ install-linux.sh       # 桌面集成安装器（图标 + desktop 入口）
#
# 用法:
#   ./scripts/build.sh release && ./scripts/package.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter"
BUNDLE="$FLUTTER_DIR/build/linux/x64/release/bundle"

[[ -x "$BUNDLE/neko_music" ]] || {
  echo "错误: 未找到 release 产物，请先执行 ./scripts/build.sh release" >&2
  exit 1
}

VERSION="$(grep -E '^version:' "$FLUTTER_DIR/pubspec.yaml" | awk '{print $2}')"
NAME="nekomusic-${VERSION}-linux-x64"
STAGING="$FLUTTER_DIR/build/dist/$NAME"

rm -rf "$STAGING"
mkdir -p "$STAGING"

# 1. 应用 bundle
cp -r "$BUNDLE" "$STAGING/neko_music"
chmod +x "$STAGING/neko_music/neko_music"

# 2. 桌面集成物料
cp "$ROOT_DIR/packaging/com.nekomusic.neko_music.desktop" "$STAGING/"
cp "$ROOT_DIR/packaging/install-linux.sh" "$STAGING/"
chmod +x "$STAGING/install-linux.sh"
cp -r "$ROOT_DIR/packaging/icons" "$STAGING/icons"

# 3. 压缩
mkdir -p "$(dirname "$STAGING")"
TARBALL="$FLUTTER_DIR/build/dist/$NAME.tar.gz"
tar -czf "$TARBALL" -C "$(dirname "$STAGING")" "$NAME"

echo "== 打包完成: $TARBALL"
echo "   安装方式: 解压后执行 ./install-linux.sh --bundle neko_music --dest ~/.local/opt/nekomusic"
du -sh "$TARBALL"
