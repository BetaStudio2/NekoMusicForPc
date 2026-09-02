#!/usr/bin/env bash
# 桌面集成安装（图标 + 应用入口）：转调 packaging/install-linux.sh
# 用法:
#   ./scripts/install.sh                                # 仅注册图标与入口
#   ./scripts/install.sh --bundle <release包目录>/neko_music
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/packaging/install-linux.sh" "$@"
