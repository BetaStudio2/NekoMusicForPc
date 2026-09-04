#!/usr/bin/env bash
# Linux 分发行打包聚合入口：按可用工具分别生成 .deb / .rpm / Arch 包
# （各发行版独立产物，不再整合单个 zip）
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rc=0
if command -v dpkg-deb >/dev/null 2>&1; then
    "$DIR/package-deb.sh" || rc=1
else
    echo "跳过 .deb（缺少 dpkg-deb，非 Debian/Ubuntu 系）"
fi
if command -v rpmbuild >/dev/null 2>&1; then
    "$DIR/package-rpm.sh" || rc=1
else
    echo "跳过 .rpm（缺少 rpmbuild，非 RPM 系）"
fi
if command -v makepkg >/dev/null 2>&1; then
    "$DIR/package-arch.sh" || rc=1
else
    echo "跳过 Arch 包（缺少 makepkg，非 Arch 系）"
fi
exit $rc
