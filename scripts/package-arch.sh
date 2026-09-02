#!/usr/bin/env bash
# 生成 Arch Linux 包（需要 makepkg；在 Arch 系执行）
# 产物: flutter/build/dist/nekomusic-<版本>-1-x86_64.pkg.tar.zst
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT_DIR/flutter/build/linux/x64/release/bundle"

[[ -x "$BUNDLE/neko_music" ]] || {
  echo "错误: 未找到 release bundle，请先执行 ./scripts/build.sh release" >&2
  exit 1
}

VERSION="$(grep -E '^version:' "$ROOT_DIR/flutter/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
PKGDIR="$ROOT_DIR/flutter/build/dist/archpkg"
rm -rf "$PKGDIR"
mkdir -p "$PKGDIR/pkg/nekomusic/opt/nekomusic" \
         "$PKGDIR/pkg/nekomusic/usr/share/applications" \
         "$PKGDIR/pkg/nekomusic/usr/share/icons/hicolor/512x512/apps"

# 直接装配包内容（跳过 makepkg 构建，仅用其打包/压缩能力）
cp -r "$BUNDLE"/. "$PKGDIR/pkg/nekomusic/opt/nekomusic/"
install -m 644 "$ROOT_DIR/packaging/com.nekomusic.neko_music.desktop" \
  "$PKGDIR/pkg/nekomusic/usr/share/applications/"
sed -i "s|^Exec=.*|Exec=/opt/nekomusic/neko_music %F|" \
  "$PKGDIR/pkg/nekomusic/usr/share/applications/com.nekomusic.neko_music.desktop"
install -m 644 "$ROOT_DIR/packaging/icons/hicolor/512x512/apps/nekomusic.png" \
  "$PKGDIR/pkg/nekomusic/usr/share/icons/hicolor/512x512/apps/nekomusic.png"

cat > "$PKGDIR/pkg/nekomusic/.PKGINFO" <<CTL
pkgname = nekomusic
pkgver = $VERSION-1
pkgdesc = Neko歌姬计划 高品质无损云音乐播放器（Flutter 版）
url = https://github.com/BetaStudio2/NekoMusicForPc
arch = x86_64
depend = qt6-base
depend = mpv
CTL

mkdir -p "$ROOT_DIR/flutter/build/dist"
cd "$PKGDIR/pkg/nekomusic"
PKG="$ROOT_DIR/flutter/build/dist/nekomusic-$VERSION-1-x86_64.pkg.tar.zst"
tar --zstd -cf "$PKG" .PKGINFO opt usr
echo "== Arch 包完成: $PKG"
du -sh "$PKG"
