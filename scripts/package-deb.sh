#!/usr/bin/env bash
# 生成 Debian/Ubuntu .deb（需要 dpkg-deb；在 Debian/Ubuntu 系执行）
# 产物: flutter/build/dist/nekomusic_<版本>_amd64.deb
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT_DIR/flutter/build/linux/x64/release/bundle"

[[ -x "$BUNDLE/neko_music" ]] || {
  echo "错误: 未找到 release bundle，请先执行 ./scripts/build.sh release" >&2
  exit 1
}
command -v dpkg-deb >/dev/null || { echo "错误: 缺少 dpkg-deb" >&2; exit 1; }

VERSION="$(grep -E '^version:' "$ROOT_DIR/flutter/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
STAGING="$(mktemp -d)/nekomusic"
mkdir -p "$STAGING/opt/nekomusic" \
         "$STAGING/usr/share/applications" \
         "$STAGING/usr/share/icons/hicolor/512x512/apps" \
         "$STAGING/DEBIAN"

# 应用 bundle → /opt/nekomusic
cp -r "$BUNDLE"/. "$STAGING/opt/nekomusic/"

# 控制信息（Qt 与 mpv 走系统依赖，不重复打包）
cat > "$STAGING/DEBIAN/control" <<CTL
Package: nekomusic
Version: $VERSION
Section: sound
Priority: optional
Architecture: amd64
Maintainer: BetaStudio2 <BetaStudio2@users.noreply.github.com>
Depends: libqt6core6t64 | libqt6core6, libqt6network6 | libqt6network, libqt6sql6 | libqt6sql, libqt6gui6 | libqt6gui, libmpv2 | libmpv1, libayatana-appindicator3-1
Description: Neko歌姬计划 高品质无损云音乐播放器（Flutter 版）
CTL

# 桌面入口 + 图标（Exec 指向 /opt 安装路径）
install -m 644 "$ROOT_DIR/packaging/com.nekomusic.neko_music.desktop" \
  "$STAGING/usr/share/applications/"
sed -i "s|^Exec=.*|Exec=/opt/nekomusic/neko_music %F|" \
  "$STAGING/usr/share/applications/com.nekomusic.neko_music.desktop"
install -m 644 "$ROOT_DIR/packaging/icons/hicolor/512x512/apps/nekomusic.png" \
  "$STAGING/usr/share/icons/hicolor/512x512/apps/nekomusic.png"

mkdir -p "$ROOT_DIR/flutter/build/dist"
DEB="$ROOT_DIR/flutter/build/dist/nekomusic_${VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group "$STAGING" "$DEB" >/dev/null
echo "== .deb 打包完成: $DEB"
du -sh "$DEB"
