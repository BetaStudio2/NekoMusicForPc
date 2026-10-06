#!/usr/bin/env bash
# =============================================================================
# build-ffmpeg-minimal.sh — 为本机原生无缝播放引擎构建「最小、仅音频、纯 LGPL」
#                           的 FFmpeg 共享库（含 TLS，供 https 流式播放）。
#
# 背景：主工程默认不再复用 Qt / 系统的完整 FFmpeg，而是自建一份只含
#       「解码 + 重采样 + file/pipe/http(s)」的最小 FFmpeg，随包内嵌，
#       与系统 FFmpeg 版本完全解耦（RUNPATH=$ORIGIN / @loader_path）。
#       纯 LGPL（--disable-gpl --disable-nonfree），满足 AGPL 聚合的分发义务。
#
# 产物：third_party/ffmpeg-minimal/<target>/{include,lib,bin}
#   - include/   FFmpeg 头文件
#   - lib/       共享库（Linux: libav*.so*；macOS: libav*.dylib；Windows: 导入库 + bin/*.dll）
#   - bin/       Windows 运行时 DLL（其它平台为空）
#
# 用法：
#   bash third_party/archoera-audio-engine/tools/build-ffmpeg-minimal.sh
#   FFMPEG_VERSION=7.1.1 JOBS=8 bash .../build-ffmpeg-minimal.sh
#
# 常用环境变量：
#   FFMPEG_VERSION   源版本，默认 7.1.1（对齐 Qt 6.10.x 自带 FFmpeg 大版本）
#   JOBS             并行度，默认 nproc/sysctl
#   FFMPEG_TARGET    输出子目录名，默认自动探测 (<os>-<arch>)
#   FFMPEG_UNIVERSAL macOS 专用：=1 时构建 arm64+x86_64 通用库（默认 native 单架构）
#   CC/CXX/AR/RANLIB/STRIP/NM  交叉编译工具链覆盖（Windows/MinGW CI 使用）
#   FFMPEG_TARGET_OS / FFMPEG_TARGET_ARCH   交叉编译时显式指定
#   下载镜像可用 FFMPEG_SRC_URL 覆盖（默认 https://ffmpeg.org/releases）
#
# 输出根目录可用 FFMPEG_OUT_ROOT 覆盖（默认 <repo>/third_party/ffmpeg-minimal）。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# tools/ -> archoera-audio-engine/ -> third_party/ -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.1}"
FFMPEG_SRC_URL="${FFMPEG_SRC_URL:-https://ffmpeg.org/releases}"
OUT_ROOT="${FFMPEG_OUT_ROOT:-$REPO_ROOT/third_party/ffmpeg-minimal}"
SRC_ROOT="$OUT_ROOT/.src"
BUILD_ROOT="$OUT_ROOT/.build"

if [ -z "${JOBS:-}" ]; then
    if command -v nproc >/dev/null 2>&1; then JOBS="$(nproc)"
    elif command -v sysctl >/dev/null 2>&1; then JOBS="$(sysctl -n hw.ncpu)"
    else JOBS=4; fi
fi

# make 名称：Windows/Git Bash 下常只有 mingw32-make。
if [ -z "${MAKE:-}" ]; then
    if command -v make >/dev/null 2>&1; then MAKE=make
    elif command -v mingw32-make >/dev/null 2>&1; then MAKE=mingw32-make
    elif command -v gmake >/dev/null 2>&1; then MAKE=gmake
    else MAKE=make; fi
fi

# ── 平台探测 ────────────────────────────────────────────────────────────
UNAME_S="$(uname -s)"
case "$UNAME_S" in
    Linux*)   HOST_OS="linux" ;;
    Darwin*)  HOST_OS="macos" ;;
    MINGW*|MSYS*|CYGWIN*) HOST_OS="windows" ;;
    *) echo "不支持的主机系统: $UNAME_S" >&2; exit 1 ;;
esac
HOST_ARCH="$(uname -m)"

TARGET_OS="${FFMPEG_TARGET_OS:-$HOST_OS}"
TARGET_ARCH="${FFMPEG_TARGET_ARCH:-$HOST_ARCH}"
if [ "$TARGET_OS" = "macos" ] && [ "${FFMPEG_UNIVERSAL:-0}" = "1" ]; then
    FFMPEG_TARGET="${FFMPEG_TARGET:-macos-universal}"
else
    FFMPEG_TARGET="${FFMPEG_TARGET:-${TARGET_OS}-${TARGET_ARCH}}"
fi

case "$TARGET_OS" in
    linux)   FF_CONFIGURE_TARGET="--target-os=linux" ;;
    macos)   FF_CONFIGURE_TARGET="--target-os=darwin" ;;
    windows) FF_CONFIGURE_TARGET="--target-os=mingw32" ;;
    *) echo "不支持的 TARGET_OS: $TARGET_OS" >&2; exit 1 ;;
esac

PREFIX="$OUT_ROOT/$FFMPEG_TARGET"
mkdir -p "$SRC_ROOT" "$BUILD_ROOT"

echo "========================================="
echo "  最小 FFmpeg 构建（仅音频 · 纯 LGPL · TLS）"
echo "========================================="
echo "FFmpeg 版本 : $FFMPEG_VERSION"
echo "目标        : $FFMPEG_TARGET ($TARGET_OS/$TARGET_ARCH)"
echo "输出        : $PREFIX"
echo "并行度      : $JOBS"
echo ""

# ── 组件清单 ────────────────────────────────────────────────────────────
# 解码器：覆盖音乐平台常见（及内核移植表涉及）音频格式，仅音频、无视频。
FF_DECODERS="aac,aac_fixed,ac3,eac3,alac,als,amrnb,amrwb,ape,atrac1,atrac3,atrac3al,atrac3p,atrac9,\
cook,dca,dsd_lsbf,dsd_lsbf_planar,dsd_msbf,dsd_msbf_planar,dst,flac,g723_1,g729,gsm,gsm_ms,\
mace3,mace6,mlp,mp1,mp1float,mp2,mp2float,mp3,mp3float,mpc7,mpc8,nellymoser,on2avc,opus,qdm2,\
ra_144,shorten,sipr,speex,tak,truehd,tta,twinvq,vorbis,wavpack,wmav1,wmav2,wmalossless,wmapro,\
wmavoice,pcm_alaw,pcm_mulaw,pcm_s8,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s24be,pcm_s32le,pcm_s32be,\
pcm_u8,pcm_f32le,pcm_f32be,pcm_f64le,pcm_f64be,pcm_s24daud"

# 解复用器：容器/封装格式。
FF_DEMUXERS="aac,ac3,aiff,amr,ape,asf,au,caf,dff,dsf,dts,eac3,flac,loas,matroska,mlp,mov,mp3,mpc,mpc8,\
ogg,oma,speex,tak,truehd,tta,w64,wav,wv"

# 解析器：码流探测所需（avformat_find_stream_info / 首帧产出）。
FF_PARSERS="aac,aac_latm,ac3,cook,dca,dsd,eac3,flac,g723_1,g729,gsm,mlp,mpegaudio,opus,qdm2,sipr,tak,vorbis"

# 协议：本地 file/pipe + 网络 http/https。https 需要 TLS 后端（按平台注入）。
FF_PROTOCOLS="file,pipe,http,https,tcp,tls"

# TLS 后端：优先使用平台自带，避免额外第三方运行库随包分发。
case "$TARGET_OS" in
    linux)   TLS_FLAGS=(--enable-openssl) ;;          # 系统 OpenSSL（DEB 声明依赖）
    macos)   TLS_FLAGS=(--enable-securetransport) ;;  # Security.framework（系统自带）
    windows) TLS_FLAGS=(--enable-schannel) ;;         # Windows SChannel（系统自带）
esac

# macOS 通用架构：clang 可一次编译多 -arch。禁用 x86asm（nasm 不支持通用对象）。
# macOS 通用架构：clang 可一次编译多 -arch。但 FFmpeg 的 #if ARCH_* 由 configure 的
# 单一宿主架构决定，跨架构 intrinsics 会误编 → 通用构建统一 --disable-asm（仅 C 路径，
# 音频解码性能损失可接受，换取一次成型、无需双架构 lipo）。
UNIVERSAL_CFLAGS=()
UNIVERSAL_LDFLAGS=()
EXTRA_CONFIGURE=()
if [ "$TARGET_OS" = "macos" ] && [ "${FFMPEG_UNIVERSAL:-0}" = "1" ]; then
    UNIVERSAL_CFLAGS=(-arch arm64 -arch x86_64)
    UNIVERSAL_LDFLAGS=(-arch arm64 -arch x86_64)
    EXTRA_CONFIGURE+=(--disable-asm)
fi
# Windows/MinGW：显式指定架构；x86asm 需要 nasm，跨平台 CI 下默认关闭以确保可编。
if [ "$TARGET_OS" = "windows" ]; then
    EXTRA_CONFIGURE+=(--arch="$TARGET_ARCH" --disable-x86asm)
fi
# 额外 configure 参数（空格分隔），供 CI 覆盖特殊情况。
if [ -n "${FFMPEG_CONFIGURE_EXTRA:-}" ]; then
    # shellcheck disable=SC2206
    EXTRA_CONFIGURE+=(${FFMPEG_CONFIGURE_EXTRA})
fi

# ── 下载并解压源码 ──────────────────────────────────────────────────────
SRC_DIR="$SRC_ROOT/ffmpeg-$FFMPEG_VERSION"
if [ ! -f "$SRC_DIR/configure" ]; then
    TARBALL="$SRC_ROOT/ffmpeg-$FFMPEG_VERSION.tar.xz"
    echo "下载 FFmpeg $FFMPEG_VERSION 源码..."
    if [ ! -f "$TARBALL" ]; then
        curl -fL --retry 3 -o "$TARBALL" "$FFMPEG_SRC_URL/ffmpeg-$FFMPEG_VERSION.tar.xz"
    fi
    echo "解压..."
    rm -rf "$SRC_DIR.tmp"
    mkdir -p "$SRC_DIR.tmp"
    tar -xf "$TARBALL" -C "$SRC_DIR.tmp" --strip-components=1
    mv "$SRC_DIR.tmp" "$SRC_DIR"
fi

# ── 配置 ────────────────────────────────────────────────────────────────
BUILD_DIR="$BUILD_ROOT/$FFMPEG_TARGET-$FFMPEG_VERSION"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CONFIGURE_ARGS=(
    --prefix="$PREFIX"
    $FF_CONFIGURE_TARGET
    --enable-shared
    --disable-static
    --enable-pic
    --disable-doc
    --disable-programs
    --disable-autodetect
    --disable-gpl
    --disable-nonfree
    --disable-everything
    --disable-encoders
    --disable-muxers
    --disable-devices
    --disable-filters
    --disable-bsfs
    --disable-hwaccels
    --disable-avdevice
    --disable-postproc
    --disable-swscale
    --disable-avfilter
    --enable-avformat
    --enable-avcodec
    --enable-avutil
    --enable-swresample
    --enable-network
    --disable-debug
    --enable-decoder="$FF_DECODERS"
    --enable-demuxer="$FF_DEMUXERS"
    --enable-parser="$FF_PARSERS"
    --enable-protocol="$FF_PROTOCOLS"
    "${TLS_FLAGS[@]}"
    "${EXTRA_CONFIGURE[@]}"
    --extra-cflags="${UNIVERSAL_CFLAGS[*]}"
    --extra-ldflags="${UNIVERSAL_LDFLAGS[*]}"
)

echo "configure ${CONFIGURE_ARGS[*]}"
"$SRC_DIR/configure" "${CONFIGURE_ARGS[@]}"

# ── 构建并安装 ──────────────────────────────────────────────────────────
echo ""
echo "编译 ($MAKE · $JOBS 并行)..."
"$MAKE" -j"$JOBS"

echo ""
echo "安装到 $PREFIX ..."
rm -rf "$PREFIX"
"$MAKE" install

# Windows：DLL 默认装到 bin/ 之外的 lib/？确保 bin/ 下也有运行时 DLL。
if [ "$TARGET_OS" = "windows" ]; then
    mkdir -p "$PREFIX/bin" "$PREFIX/lib"
    # MinGW 共享构建把 .dll 放在 prefix/bin，导入库在 prefix/lib；此处仅确认布局。
    ls -1 "$PREFIX/bin" 2>/dev/null || true
fi

echo ""
echo "========================================="
echo "  完成：$PREFIX"
echo "========================================="
echo "共享库："
ls -1 "$PREFIX"/lib/libavformat* "$PREFIX"/lib/libavcodec* \
      "$PREFIX"/lib/libavutil* "$PREFIX"/lib/libswresample* 2>/dev/null || \
ls -1 "$PREFIX"/lib/*.dylib "$PREFIX"/lib/*.dll 2>/dev/null || true
echo ""
echo "下一步："
echo "  cmake -S \"$REPO_ROOT\" -B build-linux -DNEKO_FFMPEG_ROOT=\"$PREFIX\" -DNEKO_FFMPEG_BUNDLE=ON"
