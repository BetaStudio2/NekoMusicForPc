#!/usr/bin/env bash
# Snap 构建脚本：在具备 snap 运行环境的主机（本机 Ubuntu / 自托管 runner）上
# 用官方 snapcraft 产出 .snap。
#
# 前置：sudo snap install snapcraft --classic （或已安装）
# 用法:  scripts/build-snap.sh            # 自动装 snapcraft 并构建
#        SNAP_TOKEN=<Launchpad> scripts/build-snap.sh   # 预留远程构建
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v snap >/dev/null 2>&1 || ! snap version >/dev/null 2>&1; then
  echo "错误: 需要 snapd（snap 命令不可用）。" >&2
  echo "  GitHub 托管 runner 无 snapd；请在装有 snap 的 Ubuntu / 自托管 runner 上运行：" >&2
  echo "    sudo apt install snapd && sudo snap install snapcraft --classic" >&2
  exit 3
fi

if ! command -v snapcraft >/dev/null 2>&1; then
  echo "== 安装 snapcraft (classic)..."
  sudo snap install snapcraft --classic || { echo "snapcraft 安装失败" >&2; exit 1; }
fi

# bundle 来源：优先本地 release bundle；否则需 NEKO_PORTABLE_ZIP
BUNDLE="$ROOT_DIR/flutter/build/linux/x64/release/bundle"
if [[ ! -x "$BUNDLE/neko_music" && -n "${NEKO_PORTABLE_ZIP:-}" && -f "$NEKO_PORTABLE_ZIP" ]]; then
  echo "== 使用便携 zip 作为 bundle 源: $NEKO_PORTABLE_ZIP"
  rm -rf "$ROOT_DIR/snap/bundle"
  mkdir -p "$ROOT_DIR/snap/bundle"
  unzip -oq "$NEKO_PORTABLE_ZIP" -d /tmp/neko-portable
  cp -r /tmp/neko-portable/nekomusic/. "$ROOT_DIR/snap/bundle/"
  rm -f "$ROOT_DIR/snap/bundle/README.txt"
elif [[ -x "$BUNDLE/neko_music" ]]; then
  echo "== 使用本地 release bundle"
  rm -rf "$ROOT_DIR/snap/bundle"
  mkdir -p "$ROOT_DIR/snap/bundle"
  cp -r "$BUNDLE"/. "$ROOT_DIR/snap/bundle/"
else
  echo "错误: 未找到 bundle。请先 ./scripts/build.sh release，或设 NEKO_PORTABLE_ZIP" >&2
  exit 1
fi

cd "$ROOT_DIR/snap"
snapcraft snap --output "$ROOT_DIR/flutter/build/dist/nekomusic-1.0.1.snap"
echo "== Snap 产物: $ROOT_DIR/flutter/build/dist/nekomusic-1.0.1.snap"
