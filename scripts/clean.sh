#!/usr/bin/env bash
# 清理所有构建产物
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$ROOT_DIR/flutter/build" "$ROOT_DIR/engine/build"
echo "已清理 flutter/build 与 engine/build"
