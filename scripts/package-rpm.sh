#!/usr/bin/env bash
# 生成 Fedora/openSUSE .rpm（需要 rpmbuild；在 RPM 系发行版执行）
# 产物: flutter/build/dist/nekomusic-<版本>-1.x86_64.rpm
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT_DIR/flutter/build/linux/x64/release/bundle"

[[ -x "$BUNDLE/neko_music" ]] || {
  echo "错误: 未找到 release bundle，请先执行 ./scripts/build.sh release" >&2
  exit 1
}
command -v rpmbuild >/dev/null || { echo "错误: 缺少 rpmbuild（dnf install rpm-build）" >&2; exit 1; }

VERSION="$(grep -E '^version:' "$ROOT_DIR/flutter/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
TOPDIR="$(mktemp -d)/rpmbuild"
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
# 源码包：bundle 打 tar 放入 SOURCES（rpmbuild 从 Source0 解包）
tar -czf "$TOPDIR/SOURCES/nekomusic-$VERSION-bundle.tar.gz" -C "$BUNDLE" .

cat > "$TOPDIR/SPECS/nekomusic.spec" <<SPEC
Name:           nekomusic
Version:        $VERSION
Release:        1%{?dist}
Summary:        Neko歌姬计划 高品质无损云音乐播放器（Flutter 版）
License:        GPL-3.0-or-later
Source0:        nekomusic-%{version}-bundle.tar.gz
BuildArch:      x86_64
Requires:       qt6-qtbase, mpv-libs
AutoReqProv:    no

%description
Neko歌姬计划 高品质无损云音乐播放器（Flutter 版）。

%prep
%setup -c

%install
mkdir -p %{buildroot}/opt/nekomusic %{buildroot}%{_datadir}/applications %{buildroot}%{_datadir}/icons/hicolor/512x512/apps
cp -r %{_builddir}/nekomusic-$VERSION-bundle/. %{buildroot}/opt/nekomusic/
install -m 644 %{_sourcedir}/../../%{_topdir}/SOURCES/nekomusic.desktop %{buildroot}%{_datadir}/applications/com.nekomusic.neko_music.desktop 2>/dev/null || true

%files
/opt/nekomusic
%{_datadir}/applications/com.nekomusic.neko_music.desktop
%{_datadir}/icons/hicolor/512x512/apps/nekomusic.png
SPEC

# 桌面入口与图标直接塞进 SOURCES 供 %files 使用
cp "$ROOT_DIR/packaging/com.nekomusic.neko_music.desktop" "$TOPDIR/SOURCES/nekomusic.desktop"
install -m 644 "$ROOT_DIR/packaging/icons/hicolor/512x512/apps/nekomusic.png" \
  "$TOPDIR/SOURCES/nekomusic.png"

rpmbuild -bb --define "_topdir $TOPDIR" \
  --define "_datadir /usr/share" \
  "$TOPDIR/SPECS/nekomusic.spec" >/dev/null

mkdir -p "$ROOT_DIR/flutter/build/dist"
RPM=$(ls "$TOPDIR"/RPMS/x86_64/nekomusic-*.rpm | head -1)
cp "$RPM" "$ROOT_DIR/flutter/build/dist/"
echo "== .rpm 打包完成: $ROOT_DIR/flutter/build/dist/$(basename "$RPM")"
du -sh "$ROOT_DIR/flutter/build/dist/$(basename "$RPM")"
