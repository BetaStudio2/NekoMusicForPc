#!/usr/bin/env bash
# =====================================================================
#  NekoMusicForPc — 原生无缝播放引擎「三平台编译自检」
#
#  仅做编译（-c），不做链接：链接需要各目标平台的 FFmpeg 运行库/导入库，
#  由各平台打包流程负责（见 docs/seamless-playback-port.md §6）。本脚本用于
#  在 Linux 开发机上快速验证引擎源码对 MSVC / macOS clang 的兼容性。
#
#  支持的交叉工具链（按需自动探测，可用环境变量覆盖）：
#    - MSVC(wine)：  NEKO_MSVC_CL（默认 /opt/msvc/bin/x64/cl）
#    - macOS SDK ：  NEKO_MACOS_SDK（默认 ~/.local/share/macos-sdk/MacOSX*.sdk）
#    - FFmpeg 头 ：  NEKO_FFMPEG_INCLUDE（默认 ~/.local/ffmpeg-minimal/include）
#
#  用法：tools/compile-check.sh [host|win|mac|all]（默认 all）
# =====================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-all}"

FFINC="${NEKO_FFMPEG_INCLUDE:-$HOME/.local/ffmpeg-minimal/include}"
if [ ! -f "$FFINC/libavformat/avformat.h" ] && command -v pkg-config >/dev/null 2>&1; then
    FFINC="$(pkg-config --cflags-only-I libavformat 2>/dev/null | sed 's/-I//g;s/ //g')"
fi

# 与 CMake 的 AUDIO_ENGINE_SOURCES 保持一致（平台后端单列）。
COMMON_SRCS="mediaengine_lib tempo decoder resampler encoder equalizer parametric_eq \
lowfreq loudness limiter native_decoder pipeline pcm_uds player fft era_log \
audio_output audio_output_platform segstore"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
FAILED=0
TOTAL=0

banner() { echo ""; echo "=== $* ==="; }
result() { # name count failcount
    TOTAL=$((TOTAL + $2))
    FAILED=$((FAILED + $3))
    if [ "$3" -eq 0 ]; then echo "  [OK]   $1: $2/$2 源文件通过";
    else echo "  [FAIL] $1: $(( $2 - $3 ))/$2 通过（$3 失败）"; fi
}

# ── 1) 本机（Linux/宿主 cc）───────────────────────────────────────────
check_host() {
    banner "宿主 cc（Linux）"
    local n=0 f=0
    for s in $COMMON_SRCS audio_output_linux; do
        n=$((n + 1))
        if ! cc -c -O2 -I"$ROOT/include" -I"$ROOT/src" -I"$ROOT/include/compat" \
                -I"$FFINC" "$ROOT/src/$s.c" -o "$OUT/host/$s.o" 2>"$OUT/host-$s.err"; then
            echo "    FAIL $s"; sed 's/^/      /' "$OUT/host-$s.err" | head -6; f=$((f + 1))
        fi
    done
    result "host/cc" "$n" "$f"
}

# ── 2) Windows / MSVC（wine）──────────────────────────────────────────
check_win() {
    local CL="${NEKO_MSVC_CL:-/opt/msvc/bin/x64/cl}"
    banner "Windows / MSVC (wine): $CL"
    if [ ! -x "$CL" ]; then
        echo "  跳过（未找到 MSVC-wine；可设 NEKO_MSVC_CL）"
        return
    fi
    local n=0 f=0 oldpwd="$PWD"
    cd "$ROOT" || return
    for s in $COMMON_SRCS audio_output_windows; do
        n=$((n + 1))
        if ! "$CL" -nologo /utf-8 /O2 /MD /std:c11 -c \
                -Iinclude -Isrc -Iinclude/compat -I"$FFINC" \
                "src/$s.c" -Fo"$OUT/win/$s.obj" >"$OUT/win-$s.log" 2>&1; then
            echo "    FAIL $s"; grep -iE "error" "$OUT/win-$s.log" | head -6 | sed 's/^/      /'; f=$((f + 1))
        fi
    done
    cd "$oldpwd" || true
    result "win/msvc" "$n" "$f"
}

# ── 3) macOS / clang（SDK 交叉）───────────────────────────────────────
check_mac() {
    local SDK="${NEKO_MACOS_SDK:-}"
    if [ -z "$SDK" ]; then
        SDK="$(ls -d "$HOME"/.local/share/macos-sdk/MacOSX*.sdk 2>/dev/null | tail -1)"
    fi
    banner "macOS / clang: ${SDK:-<未找到 SDK>}"
    if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
        echo "  跳过（未找到 macOS SDK；可设 NEKO_MACOS_SDK）"
        return
    fi
    local n=0 f=0 arch
    for arch in x86_64 arm64; do
        for s in $COMMON_SRCS audio_output_macos; do
            n=$((n + 1))
            if ! clang -target "$arch-apple-darwin" -isysroot "$SDK" -mmacosx-version-min=14.0 \
                    -c -O2 -I"$ROOT/include" -I"$ROOT/src" -I"$ROOT/include/compat" -I"$FFINC" \
                    "$ROOT/src/$s.c" -o "$OUT/mac/$arch-$s.o" 2>"$OUT/mac-$arch-$s.err"; then
                echo "    FAIL $arch/$s"; grep -iE "error" "$OUT/mac-$arch-$s.err" | head -6 | sed 's/^/      /'; f=$((f + 1))
            fi
        done
    done
    result "mac/clang(x86_64+arm64)" "$n" "$f"
}

mkdir -p "$OUT/host" "$OUT/win" "$OUT/mac"
case "$MODE" in
    host) check_host ;;
    win)  check_win ;;
    mac)  check_mac ;;
    all)  check_host; check_win; check_mac ;;
    *) echo "用法: $0 [host|win|mac|all]"; exit 2 ;;
esac

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "全部通过（共 $TOTAL 个编译单元）。"
else
    echo "存在失败：$FAILED/$TOTAL。"
    exit 1
fi
