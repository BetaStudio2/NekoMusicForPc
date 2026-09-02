#!/usr/bin/env bash
# Neko歌姬计划（Flutter 版）Linux 桌面集成安装：
#   1. 安装 hicolor 全尺寸应用图标
#   2. 安装与 runner APPLICATION_ID 匹配的 desktop 文件
#      （Wayland/KDE 任务栏图标靠 app_id ↔ desktop 文件名匹配）
#   3. 可选：把 flutter build linux 产出的 bundle 拷贝到目标目录
#
# 用法：
#   ./install-linux.sh                      # 仅安装图标 + desktop（Exec=neko_music）
#   ./install-linux.sh --exec /path/to/neko_music
#   ./install-linux.sh --bundle /path/to/bundle_dir [--dest ~/NekoMusic]
#   sudo ./install-linux.sh --system ...    # 装到 /usr/share（需 root）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID="com.nekomusic.neko_music"

SYSTEM=0
EXEC_PATH="neko_music"
BUNDLE_DIR=""
DEST_DIR="$HOME/NekoMusic"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --system) SYSTEM=1; shift ;;
    --exec) EXEC_PATH="$2"; shift 2 ;;
    --bundle) BUNDLE_DIR="$2"; shift 2 ;;
    --dest) DEST_DIR="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

if [[ $SYSTEM -eq 1 ]]; then
  DATA_DIR="/usr/share"
  [[ $(id -u) -eq 0 ]] || { echo "--system 需要 root（sudo）" >&2; exit 1; }
else
  DATA_DIR="$HOME/.local/share"
fi
APP_DIR="$DATA_DIR/applications"
ICON_DIR="$DATA_DIR/icons/hicolor"

# 1. 图标
for png in "$SCRIPT_DIR"/icons/hicolor/*/apps/nekomusic.png; do
  size="$(basename "$(dirname "$(dirname "$png")")")"
  target="$ICON_DIR/${size}/apps"
  mkdir -p "$target"
  install -m 644 "$png" "$target/nekomusic.png"
  echo "图标: $target/nekomusic.png"
done

# 2. bundle（可选）
if [[ -n "$BUNDLE_DIR" ]]; then
  mkdir -p "$DEST_DIR"
  cp -r "$BUNDLE_DIR"/. "$DEST_DIR"/
  EXEC_PATH="$DEST_DIR/neko_music"
  chmod +x "$EXEC_PATH"
  echo "程序: $DEST_DIR"
fi

# 3. desktop 文件（写入后重写 Exec 为实际路径）
mkdir -p "$APP_DIR"
sed "s|^Exec=.*|Exec=${EXEC_PATH} %F|" \
  "$SCRIPT_DIR/${APP_ID}.desktop" > "$APP_DIR/${APP_ID}.desktop"
chmod 644 "$APP_DIR/${APP_ID}.desktop"
echo "desktop: $APP_DIR/${APP_ID}.desktop (Exec=${EXEC_PATH})"

# 4. 刷新缓存
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APP_DIR" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -qtf "$ICON_DIR" 2>/dev/null || true

echo "完成。KDE/任务栏图标依赖 app_id=${APP_ID} 匹配，重新登录或重启 plasmashell 后生效。"
