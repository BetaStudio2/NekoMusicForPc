#!/usr/bin/env bash
# Neko歌姬计划（Flutter 版）一键构建脚本
#
# 用法:
#   ./scripts/build.sh              # Debug 构建（默认）
#   ./scripts/build.sh release      # Release 构建
#   NEKO_FLUTTER=/path/to/flutter ./scripts/build.sh release
#
# 流程: 解析 Flutter SDK → 预构建引擎 (libneko_engine + libneko_core)
#       → flutter build linux → 输出 bundle 路径
#
# SDK 解析顺序（任意官方 3.44+ 均可，无需补丁 SDK）:
#   1. $NEKO_FLUTTER 环境变量
#   2. 仓库同级 flutter-stable 副本
#   3. PATH 中的 flutter
#   4. /opt/flutter
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter"
MODE="${1:-debug}"
case "$MODE" in
  debug | release) ;;
  *) echo "用法: $0 [debug|release]" >&2; exit 1 ;;
esac

# ── Flutter SDK 解析 ──
find_flutter() {
  local candidates=(
    "${NEKO_FLUTTER:-}"
    "$ROOT_DIR/../flutter-stable/bin/flutter"
    "$(command -v flutter 2>/dev/null || true)"
    "/opt/flutter/bin/flutter"
  )
  for c in "${candidates[@]}"; do
    [[ -n "$c" && -x "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}
FLUTTER_BIN="$(find_flutter)" || {
  echo "错误: 未找到 Flutter SDK（3.44+）。可用 NEKO_FLUTTER=/path/to/flutter 指定。" >&2
  exit 1
}
echo "== Flutter SDK: $FLUTTER_BIN"
"$FLUTTER_BIN" --version 2>/dev/null | head -1 || true

# ── 平台检测 ──
OS="$(uname -s)"
case "$OS" in
  Linux) FLUTTER_TARGET_PLATFORM="linux" ;;
  Darwin) FLUTTER_TARGET_PLATFORM="macos" ;;
  *) echo "错误: 仅支持 Linux / macOS（Windows 用 scripts\\build.bat）" >&2; exit 1 ;;
esac

# ── 依赖检查 ──
for tool in cmake ninja; do
  command -v "$tool" >/dev/null || { echo "错误: 缺少 $tool" >&2; exit 1; }
done
pkg-config --exists mpv >/dev/null 2>&1 || {
  echo "错误: 缺少 libmpv 开发文件（pkg-config mpv）。Arch: pacman -S mpv; Debian: apt install libmpv-dev" >&2
  exit 1
}
# Qt6（核心桥 neko_core：Core/Network/Sql）
if command -v brew >/dev/null 2>&1; then
  brew --prefix qt >/dev/null 2>&1 || echo "警告: 未通过 Homebrew 安装 qt（brew install qt6 mpv）" >&2
fi

# ── 1. 预构建引擎（flutter 的 CMake 也会自动构建，这里显式执行以便提早暴露错误）──
echo "== 构建 C 引擎 (libneko_engine + libneko_core)..."
cmake -S "$ROOT_DIR/engine" -B "$ROOT_DIR/engine/build" \
  -DCMAKE_BUILD_TYPE="$([[ $MODE == release ]] && echo Release || echo Debug)" \
  >/dev/null
cmake --build "$ROOT_DIR/engine/build" --parallel \
  --target neko_engine neko_core >/dev/null
echo "== 引擎构建完成"

# ── 2. Flutter 应用构建 ──
echo "== Flutter 构建 ($FLUTTER_TARGET_PLATFORM, $MODE)..."
cd "$FLUTTER_DIR"
"$FLUTTER_BIN" build "$FLUTTER_TARGET_PLATFORM" --"$MODE"

if [[ $OS == Linux ]]; then
  BUNDLE="$FLUTTER_DIR/build/linux/x64/$MODE/bundle"
  echo ""
  echo "== 构建完成: $BUNDLE/neko_music"
  if [[ $MODE == debug ]]; then
    echo "   （运行需在 bundle 目录内执行：./neko_music）"
  fi
else
  # macOS：引擎 dylib 拷入 .app/Contents/Frameworks（dyld 裸名搜索路径）
  APP_DIR=$(ls -d "$FLUTTER_DIR"/build/macos/Build/Products/$MODE/*.app 2>/dev/null | head -1)
  [[ -z "$APP_DIR" ]] && { echo "错误: 未找到 .app 产物" >&2; exit 1; }
  mkdir -p "$APP_DIR/Contents/Frameworks"
  cp "$ROOT_DIR/engine/build/libneko_engine.dylib" \
     "$ROOT_DIR/engine/build/libneko_core.dylib" \
     "$APP_DIR/Contents/Frameworks/" 2>/dev/null || true
  BUNDLE="$APP_DIR"
  echo ""
  echo "== 构建完成: $APP_DIR"
fi
