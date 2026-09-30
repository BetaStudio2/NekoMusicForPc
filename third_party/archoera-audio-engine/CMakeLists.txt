# NekoMusicForPc — vendored ArchoeraMusic native audio engine (FFmpeg-only)
#
# 从 ArchoeraMusic 移植的无缝播放引擎（PC/桌面 FFI 库 libarchoera_mediaengine
# 的静态化版本），用于实现：
#   - 音质无缝切换（prepare_source / commit_source，样本级对齐）
#   - 曲间无缝续播（EOF 排空后 commit 新源）
#
# 与上游 CMakeLists 的差异（按移植决策刻意收敛）：
#   1. **不构建 Zig 内核**：不定义 HAS_ARCHOERA_KERNEL，native_decoder.c /
#      equalizer.c 编译期回退纯 FFmpeg（engine_mode 恒走 Stable）。
#   2. **不链接 Rust tempo**：不定义 HAS_TEMPO，tempo.c 走旁通 stub。
#   3. 只产出静态库 archoera_engine（供主程序直接链接），不构建 CLI / fft
#      共享库 / 测试。
#
# 上游来源：ArchoeraMusic @ 0b2556a（app/core/audio-engine），
# 许可证 AGPL-3.0-or-later，见本目录 LICENSE 与 THIRD-PARTY-LICENSES.md。

cmake_minimum_required(VERSION 3.20)

# 顶层工程只声明了 LANGUAGES CXX；作为子目录加入时须显式启用 C 语言，
# 否则 .c 源文件不会被编译（目标只剩 AUTOMOC 空对象，链接期全部未定义）。
enable_language(C)

# ── 依赖：FFmpeg 开发库（libavformat/avcodec/avutil/swresample）──────────
#
# 策略：**复用 Qt 运行期所用的同一套 FFmpeg**——同进程内只有一份 FFmpeg，
# 避免两份实例的符号/堆冲突。落地方式按平台：
#   - Linux：系统 FFmpeg（Qt 的 ffmpeg 插件也用它）→ pkg-config 直接命中；
#   - macOS：Homebrew/系统 FFmpeg（构建期），运行期随 bundle 的同一套 dylib；
#   - Windows/MinGW：**不查宿主 pkg-config**（跨编会误用宿主 Linux 库），
#     改用 NEKO_FFMPEG_ROOT（含 include/ 与 lib/ 的 FFmpeg 开发树，版本须与
#     Qt 套件自带 FFmpeg DLL 一致）。
#
# 可用 -DNEKO_DISABLE_AUDIO_ENGINE=ON 强制关闭原生引擎（播放回退 QMediaPlayer）。
option(NEKO_DISABLE_AUDIO_ENGINE "禁用原生无缝播放引擎（回退 QMediaPlayer）" OFF)
if(NEKO_DISABLE_AUDIO_ENGINE)
    message(STATUS "archoera-audio-engine: 已被 NEKO_DISABLE_AUDIO_ENGINE 显式禁用")
    set(ARCHOERRA_ENGINE_AVAILABLE FALSE PARENT_SCOPE)
    return()
endif()

set(ARCHOERRA_FFMPEG_FOUND FALSE)
set(ARCHOERRA_FFMPEG_INCLUDE_DIRS "")
set(ARCHOERRA_FFMPEG_LIBRARIES "")
set(ARCHOERRA_FFMPEG_LIBRARY_DIRS "")
set(ARCHOERRA_FFMPEG_CFLAGS_OTHER "")

# 1) 非 Windows：优先 pkg-config（Linux 系统 / macOS Homebrew）。
if(NOT WIN32)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(ARCHOERRA_FFMPEG_PC QUIET
            libavformat libavcodec libavutil libswresample)
        if(ARCHOERRA_FFMPEG_PC_FOUND)
            set(ARCHOERRA_FFMPEG_FOUND TRUE)
            set(ARCHOERRA_FFMPEG_VERSION ${ARCHOERRA_FFMPEG_PC_VERSION})
            set(ARCHOERRA_FFMPEG_INCLUDE_DIRS ${ARCHOERRA_FFMPEG_PC_INCLUDE_DIRS})
            set(ARCHOERRA_FFMPEG_LIBRARIES ${ARCHOERRA_FFMPEG_PC_LIBRARIES})
            set(ARCHOERRA_FFMPEG_LIBRARY_DIRS ${ARCHOERRA_FFMPEG_PC_LIBRARY_DIRS})
            set(ARCHOERRA_FFMPEG_CFLAGS_OTHER ${ARCHOERRA_FFMPEG_PC_CFLAGS_OTHER})
        endif()
    endif()
endif()

# 2) NEKO_FFMPEG_ROOT 兜底/覆盖（Windows/MinGW 必用；其它平台亦可指定精确版本）。
if(NOT ARCHOERRA_FFMPEG_FOUND AND NEKO_FFMPEG_ROOT)
    set(_ff_root "${NEKO_FFMPEG_ROOT}")
    # Windows 交叉编译时库可能位于 lib/ 或 lib/<triple>/。
    set(_ff_libdirs "${_ff_root}/lib")
    file(GLOB _ff_sub "${_ff_root}/lib/*")
    foreach(_d ${_ff_sub})
        if(IS_DIRECTORY "${_d}")
            list(APPEND _ff_libdirs "${_d}")
        endif()
    endforeach()

    find_path(ARCHOERRA_FFMPEG_INC libavformat/avformat.h
        PATHS "${_ff_root}/include" NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
    find_library(ARCHOERRA_FFMPEG_avformat NAMES avformat libavformat
        PATHS ${_ff_libdirs} NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
    find_library(ARCHOERRA_FFMPEG_avcodec NAMES avcodec libavcodec
        PATHS ${_ff_libdirs} NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
    find_library(ARCHOERRA_FFMPEG_avutil NAMES avutil libavutil
        PATHS ${_ff_libdirs} NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
    find_library(ARCHOERRA_FFMPEG_swresample NAMES swresample libswresample
        PATHS ${_ff_libdirs} NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)

    if(ARCHOERRA_FFMPEG_INC
       AND ARCHOERRA_FFMPEG_avformat AND ARCHOERRA_FFMPEG_avcodec
       AND ARCHOERRA_FFMPEG_avutil AND ARCHOERRA_FFMPEG_swresample)
        set(ARCHOERRA_FFMPEG_FOUND TRUE)
        set(ARCHOERRA_FFMPEG_INCLUDE_DIRS "${ARCHOERRA_FFMPEG_INC}")
        set(ARCHOERRA_FFMPEG_LIBRARIES
            "${ARCHOERRA_FFMPEG_avformat}"
            "${ARCHOERRA_FFMPEG_avcodec}"
            "${ARCHOERRA_FFMPEG_avutil}"
            "${ARCHOERRA_FFMPEG_swresample}")
        message(STATUS "archoera-audio-engine: 使用 NEKO_FFMPEG_ROOT=${_ff_root}")
    else()
        message(WARNING
            "archoera-audio-engine: NEKO_FFMPEG_ROOT=${_ff_root} 下未找齐 FFmpeg "
            "开发文件（需 include/libavformat/avformat.h 与 lib 下 avformat/avcodec/"
            "avutil/swresample 导入库）")
    endif()
endif()

if(NOT ARCHOERRA_FFMPEG_FOUND)
    message(STATUS
        "archoera-audio-engine: 未找到 FFmpeg 开发库，跳过原生引擎（播放回退 QMediaPlayer）。"
        "Windows/MinGW 请以 -DNEKO_FFMPEG_ROOT=<FFmpeg开发树> 指定（版本须与 Qt 套件 "
        "自带 FFmpeg DLL 一致）。")
    set(ARCHOERRA_ENGINE_AVAILABLE FALSE PARENT_SCOPE)
    return()
endif()

# macOS 通用架构保护：pkg-config/Homebrew 的 FFmpeg 通常仅单一架构，与
# arm64;x86_64 通用链接会失败（CI 出包即挂）。通用构建要求显式
# -DNEKO_FFMPEG_ROOT=<通用 FFmpeg 开发树>，否则跳过引擎（回退 QMediaPlayer）。
if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    list(LENGTH CMAKE_OSX_ARCHITECTURES _neko_narch)
    if(_neko_narch GREATER 1 AND NOT NEKO_FFMPEG_ROOT)
        message(STATUS
            "archoera-audio-engine: macOS 通用架构（${CMAKE_OSX_ARCHITECTURES}）需显式 "
            "-DNEKO_FFMPEG_ROOT=<通用 FFmpeg 开发树>；跳过原生引擎（回退 QMediaPlayer）")
        set(ARCHOERRA_ENGINE_AVAILABLE FALSE PARENT_SCOPE)
        return()
    endif()
endif()

set(ARCHOERRA_ENGINE_AVAILABLE TRUE PARENT_SCOPE)
message(STATUS "archoera-audio-engine: FFmpeg ${ARCHOERRA_FFMPEG_VERSION} — 构建无 Zig 内核的无缝播放引擎")

# ── 源文件（对齐上游 AUDIO_ENGINE_SOURCES + tempo.c + mediaengine_lib.c）──
set(ARCHOERRA_ENGINE_SOURCES
    src/decoder.c
    src/native_decoder.c
    src/resampler.c
    src/encoder.c
    src/equalizer.c
    src/loudness.c
    src/limiter.c
    src/fft.c
    src/era_log.c
    src/parametric_eq.c
    src/lowfreq.c
    src/pipeline.c
    src/pcm_uds.c
    src/player.c
    src/audio_output.c
    src/audio_output_platform.c
    src/segstore.c
    src/tempo.c
    src/mediaengine_lib.c
)

# 输出设备枚举平台后端（编译期单选）
if(WIN32)
    list(APPEND ARCHOERRA_ENGINE_SOURCES src/audio_output_windows.c)
elseif(APPLE)
    list(APPEND ARCHOERRA_ENGINE_SOURCES src/audio_output_macos.c)
elseif(UNIX)
    list(APPEND ARCHOERRA_ENGINE_SOURCES src/audio_output_linux.c)
else()
    list(APPEND ARCHOERRA_ENGINE_SOURCES src/audio_output_stub.c)
endif()

set(ARCHOERRA_ENGINE_INCLUDES
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# ── 静态库 ────────────────────────────────────────────────────────────
add_library(archoera_engine STATIC ${ARCHOERRA_ENGINE_SOURCES})
set_target_properties(archoera_engine PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_include_directories(archoera_engine
    PUBLIC ${ARCHOERRA_ENGINE_INCLUDES}
    PRIVATE ${ARCHOERRA_FFMPEG_INCLUDE_DIRS}
)
target_link_libraries(archoera_engine PUBLIC ${ARCHOERRA_FFMPEG_LIBRARIES})
target_link_directories(archoera_engine PUBLIC ${ARCHOERRA_FFMPEG_LIBRARY_DIRS})
target_compile_options(archoera_engine PUBLIC ${ARCHOERRA_FFMPEG_CFLAGS_OTHER})

# 上游全局 -fvisibility=hidden + C11；这里保持 C11。
set_target_properties(archoera_engine PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    C_EXTENSIONS OFF
)
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(archoera_engine PRIVATE
        -Wall -Wextra -Wno-unused-parameter -O2)
endif()

# ── 系统库：pthread / dl / libm ──────────────────────────────────────
find_package(Threads REQUIRED)
target_link_libraries(archoera_engine PUBLIC Threads::Threads)
if(CMAKE_DL_LIBS)
    target_link_libraries(archoera_engine PUBLIC ${CMAKE_DL_LIBS})
endif()
find_library(ARCHOERRA_MATH_LIBRARY m)
if(ARCHOERRA_MATH_LIBRARY)
    target_link_libraries(archoera_engine PUBLIC ${ARCHOERRA_MATH_LIBRARY})
endif()

# macOS：CoreAudio / CoreFoundation（audio_output_macos.c 原生设备枚举）
if(APPLE)
    target_link_libraries(archoera_engine PUBLIC
        "-framework CoreAudio" "-framework CoreFoundation")
endif()
