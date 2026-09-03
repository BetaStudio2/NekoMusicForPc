#!/usr/bin/env bash
# Linux AppImage：整份 release bundle 入 AppDir，linuxdeploy 装配 + 出镜像。
# 说明：GTK3/Qt6/mpv 取系统动态库；linuxdeploy 生成 AppRun 启动 exe
#（exe 相对路径自带 data/ 与 lib/，引擎库经 $ORIGIN/lib RUNPATH 解析）。
# 需先构建 release bundle；CI 提供 linuxdeploy/appimagetool 环境变量。
# 产物: flutter/build/dist/nekomusic-<版本>-x86_64.AppImage
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT_DIR/flutter/build/linux/x64/release/bundle"
LINUXDEPLOY="${LINUXDEPLOY:-}"
APPIMAGETOOL="${APPIMAGETOOL:-}"

[[ -x "$BUNDLE/neko_music" ]] || { echo "错误: 缺 release bundle（先 ./scripts/build.sh release）" >&2; exit 1; }
VERSION="$(grep -E '^version:' "$ROOT_DIR/flutter/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"

APPDIR="$ROOT_DIR/flutter/build/dist/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/512x512/apps"

# 应用本体：整份 bundle 放 usr/bin（exe 相对 data/lib 解析不变；
# Exec=neko_music 可解析，linuxdeploy 根部署/AppRun 链接正常）
mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE"/. "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/neko_music"

# desktop + 图标（Exec 指向 usr/bin 内的 neko_music）
sed "s|^Exec=.*|Exec=neko_music %F|" \
  "$ROOT_DIR/packaging/com.nekomusic.neko_music.desktop" \
  > "$APPDIR/usr/share/applications/nekomusic.desktop"
cp "$ROOT_DIR/packaging/icons/hicolor/512x512/apps/nekomusic.png" \
   "$APPDIR/usr/share/icons/hicolor/512x512/apps/nekomusic.png"

# linuxdeploy 装配：若提供 qt/gtk 插件则随镜像打包 Qt6/GTK 依赖
#（含 Qt 平台插件，保证目标机无 Qt/GTK 也能运行）
PLUGIN_ARGS=""
if ls "${LINUXDEPLOY_PLUGIN_PATH:-}"/*plugin-qt* >/dev/null 2>&1; then
  PLUGIN_ARGS="$PLUGIN_ARGS --plugin qt"
fi
if ls "${LINUXDEPLOY_PLUGIN_PATH:-}"/*plugin-gtk* >/dev/null 2>&1; then
  PLUGIN_ARGS="$PLUGIN_ARGS --plugin gtk"
fi
# Qt/引擎库在 libneko_core.so 等（flutter exe 仅动态依赖），
# 显式以 --library 引入以便收集 Qt 模块与 mpv/appindicator 依赖
"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/neko_music" \
  --library "$APPDIR/usr/bin/lib/libneko_core.so" \
  --library "$APPDIR/usr/bin/lib/libneko_engine.so" \
  --desktop-file "$APPDIR/usr/share/applications/nekomusic.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/512x512/apps/nekomusic.png" \
  $PLUGIN_ARGS

if command -v appimagetool >/dev/null 2>&1; then
  APPIMAGETOOL="$(command -v appimagetool)"
fi
if [[ -n "$APPIMAGETOOL" ]]; then
  "$APPIMAGETOOL" "$APPDIR" \
    "$ROOT_DIR/flutter/build/dist/nekomusic-${VERSION}-x86_64.AppImage"
else
  echo "警告: 未提供 appimagetool，AppDir 已就绪于 $APPDIR" >&2
fi
