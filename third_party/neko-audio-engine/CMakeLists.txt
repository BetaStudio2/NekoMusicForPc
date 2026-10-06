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
# 推荐：**自建最小 FFmpeg**（tools/build-ffmpeg-minimal.sh，仅音频 · 纯 LGPL ·
# 含 TLS：Linux openssl / macOS securetransport / Windows schannel），以
# NEKO_FFMPEG_ROOT 指向其产物、NEKO_FFMPEG_BUNDLE=ON 随包内嵌，与系统 FFmpeg 解耦
# （Linux RUNPATH=$ORIGIN/lib、macOS @loader_path、Windows 拷 bin/*.dll）。
# 回退（未给 NEKO_FFMPEG_ROOT）按平台解析：
#   - Linux：系统 FFmpeg（Qt 的 ffmpeg 插件也用它）→ pkg-config 直接命中；
#   - macOS：Homebrew/系统 FFmpeg（构建期），运行期随 bundle 的同一套 dylib；
#   - Windows/MinGW：**不查宿主 pkg-config**（跨编会误用宿主 Linux 库），
#     必须显式 -DNEKO_FFMPEG_ROOT（含 include/ 与 lib/，或 lib/<triple>/）。
#
# 可用 -DNEKO_DISABLE_AUDIO_ENGINE=ON 强制关闭原生引擎（播放回退 QMediaPlayer）。
option(NEKO_DISABLE_AUDIO_ENGINE "禁用原生无缝播放引擎（回退 QMediaPlayer）" OFF)

# NEKO_FFMPEG_BUNDLE=ON：NEKO_FFMPEG_ROOT 指向自建最小 FFmpeg 时，把其共享库
# 随包内嵌（Linux 装到 <prefix>/lib 并设 RUNPATH=$ORIGIN/lib；macOS 交 macdeployqt；
# Windows 由 CI 把 bin/*.dll 拷到安装目录）。默认 OFF = 复用系统/Qt 的 FFmpeg。
option(NEKO_FFMPEG_BUNDLE "随包内嵌 NEKO_FFMPEG_ROOT 下的最小 FFmpeg 共享库" OFF)
if(NEKO_DISABLE_AUDIO_ENGINE)
    message(STATUS "neko-audio-engine: 已被 NEKO_DISABLE_AUDIO_ENGINE 显式禁用")
    set(ARCHOERRA_ENGINE_AVAILABLE FALSE PARENT_SCOPE)
    return()
endif()

set(ARCHOERRA_FFMPEG_FOUND FALSE)
set(ARCHOERRA_FFMPEG_INCLUDE_DIRS "")
set(ARCHOERRA_FFMPEG_LIBRARIES "")
set(ARCHOERRA_FFMPEG_LIBRARY_DIRS "")
set(ARCHOERRA_FFMPEG_CFLAGS_OTHER "")

# 1) 非 Windows 且未显式指定 NEKO_FFMPEG_ROOT：优先 pkg-config（Linux 系统 / macOS Homebrew）。
#    显式指定 NEKO_FFMPEG_ROOT 时优先手工定位（用于精确对齐 Qt 自带 FFmpeg 版本）。
if(NOT WIN32 AND NOT NEKO_FFMPEG_ROOT)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(ARCHOERRA_FFMPEG_PC QUIET
            libavformat libavcodec libavutil libswresample)
        if(ARCHOERRA_FFMPEG_PC_FOUND)
            set(ARCHOERRA_FFMPEG_FOUND TRUE)
            set(ARCHOERRA_FFMPEG_VERSION ${ARCHOERRA_FFMPEG_PC_VERSION})
            set(ARCHOERRA_FFMPEG_INCLUDE_DIRS ${ARCHOERRA_FFMPEG_PC_INCLUDE_DIRS})
            set(ARCHOERRA_FFMPEG_INCLUDE_DIRS ${ARCHOERRA_FFMPEG_PC_INCLUDE_DIRS} PARENT_SCOPE)
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
        set(ARCHOERRA_FFMPEG_INCLUDE_DIRS "${ARCHOERRA_FFMPEG_INC}" PARENT_SCOPE)
        set(ARCHOERRA_FFMPEG_LIBRARIES
            "${ARCHOERRA_FFMPEG_avformat}"
            "${ARCHOERRA_FFMPEG_avcodec}"
            "${ARCHOERRA_FFMPEG_avutil}"
            "${ARCHOERRA_FFMPEG_swresample}")
        # 供顶层打包随包内嵌（NEKO_FFMPEG_BUNDLE）
        set(ARCHOERRA_FFMPEG_ROOT "${_ff_root}" PARENT_SCOPE)
        set(ARCHOERRA_FFMPEG_LIBRARY_DIRS "${_ff_libdirs}" PARENT_SCOPE)
        message(STATUS "neko-audio-engine: 使用 NEKO_FFMPEG_ROOT=${_ff_root}")
    else()
        message(WARNING
            "neko-audio-engine: NEKO_FFMPEG_ROOT=${_ff_root} 下未找齐 FFmpeg "
            "开发文件（需 include/libavformat/avformat.h 与 lib 下 avformat/avcodec/"
            "avutil/swresample 导入库）")
    endif()
endif()

if(NOT ARCHOERRA_FFMPEG_FOUND)
    message(STATUS
        "neko-audio-engine: 未找到 FFmpeg 开发库，跳过原生引擎（播放回退 QMediaPlayer）。"
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
            "neko-audio-engine: macOS 通用架构（${CMAKE_OSX_ARCHITECTURES}）需显式 "
            "-DNEKO_FFMPEG_ROOT=<通用 FFmpeg 开发树>；跳过原生引擎（回退 QMediaPlayer）")
        set(ARCHOERRA_ENGINE_AVAILABLE FALSE PARENT_SCOPE)
        return()
    endif()
endif()

set(ARCHOERRA_ENGINE_AVAILABLE TRUE PARENT_SCOPE)
message(STATUS "neko-audio-engine: FFmpeg ${ARCHOERRA_FFMPEG_VERSION} — 构建无 Zig 内核的无缝播放引擎")

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

# ── EraAudio Zig 解码内核（可选，默认开启；zig 不可用时回退 FFmpeg）──────
# 自研 Zig 解码内核（build.zig → libarchoera_kernel.a），逐格式接管音频解码；
# 不可用/未支持的格式由引擎内部自动回退 FFmpeg。定义 HAS_ARCHOERA_KERNEL 后，
# native_decoder.c / equalizer.c / limiter.c / ... 走内核实现（否则走 FFmpeg/stub）。
option(NEKO_ENABLE_ERAUDIO_KERNEL "构建并链接 EraAudio Zig 解码内核（libarchoera_kernel）" ON)
if(NEKO_ENABLE_ERAUDIO_KERNEL)
    find_program(NEKO_ZIG_EXECUTABLE zig)
    if(NEKO_ZIG_EXECUTABLE)
        set(_zk_out "${CMAKE_CURRENT_BINARY_DIR}/archoera_kernel-out")
        set(_zk_cache "${CMAKE_CURRENT_BINARY_DIR}/archoera_kernel-cache")
        set(_zk_lib_name "libarchoera_kernel.a")
        if(WIN32)
            # Zig 在 Windows（含 MinGW 目标）安装为 archoera_kernel.lib
            set(_zk_lib_name "archoera_kernel.lib")
        endif()
        set(_zk_lib "${_zk_out}/lib/${_zk_lib_name}")

        # CPU 基线（避免 Zig 生成 AVX-512/EVEX 在主流 CPU 上 SIGILL），仅 x86_64。
        set(_zk_cpu_arg "")
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64)$")
            set(_zk_cpu_arg "-Dcpu=baseline")
        endif()

        # 平台 target triple：Windows/MinGW 需显式 gnu ABI（否则默认 msvc 与 MinGW 不兼容）。
        set(_zk_target_arg "")
        if(WIN32 AND NOT MSVC)
            if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(_zk_target_arg "-Dtarget=x86_64-windows-gnu")
            else()
                set(_zk_target_arg "-Dtarget=x86-windows-gnu")
            endif()
        endif()

        set(_zk_cmds COMMAND "${NEKO_ZIG_EXECUTABLE}" build
                            --prefix "${_zk_out}"
                            --cache-dir "${_zk_cache}"
                            -Doptimize=ReleaseFast
                            ${_zk_cpu_arg} ${_zk_target_arg})

        # 内核源码变化时重新构建
        file(GLOB_RECURSE _zk_deps
            "${CMAKE_CURRENT_SOURCE_DIR}/kernel/*.zig"
            "${CMAKE_CURRENT_SOURCE_DIR}/kernel/c/*"
            "${CMAKE_CURRENT_SOURCE_DIR}/build.zig"
            "${CMAKE_CURRENT_SOURCE_DIR}/build.zig.zon")

        # macOS 通用架构：Zig 默认只出宿主架构，需逐架构构建后 lipo 合成 universal .a。
        if(APPLE AND CMAKE_OSX_ARCHITECTURES)
            list(LENGTH CMAKE_OSX_ARCHITECTURES _neko_zk_narch)
            set(_zk_thin "")
            set(_zk_cmds COMMAND "${CMAKE_COMMAND}" -E make_directory "${_zk_out}/lib")
            foreach(_a ${CMAKE_OSX_ARCHITECTURES})
                if(_a STREQUAL "arm64")
                    set(_zt "aarch64-macos")
                else()
                    set(_zt "${_a}-macos")
                endif()
                if(_neko_zk_narch GREATER 1)
                    set(_thout "${CMAKE_CURRENT_BINARY_DIR}/archoera_kernel-out-${_a}")
                    list(APPEND _zk_cmds
                        COMMAND "${NEKO_ZIG_EXECUTABLE}" build
                                --prefix "${_thout}"
                                --cache-dir "${_zk_cache}"
                                -Doptimize=ReleaseFast -Dtarget=${_zt}
                        # Zig 归档成员非 8 字节对齐，Apple ld 拒绝 lipo 后的通用 .a。
                        # 解包成 .o 后用 Apple libtool 从零重打包（会 8 字节对齐）再 lipo。
                        COMMAND sh -c "mkdir -p '${_thout}/objs' && cd '${_thout}/objs' && ar x '${_thout}/lib/${_zk_lib_name}' && rm -f '${_thout}/lib/${_zk_lib_name}' && libtool -static -o '${_thout}/lib/${_zk_lib_name}' *.o")
                    list(APPEND _zk_thin "${_thout}/lib/${_zk_lib_name}")
                else()
                    list(APPEND _zk_cmds
                        COMMAND "${NEKO_ZIG_EXECUTABLE}" build
                                --prefix "${_zk_out}"
                                --cache-dir "${_zk_cache}"
                                -Doptimize=ReleaseFast -Dtarget=${_zt})
                endif()
            endforeach()
            if(_neko_zk_narch GREATER 1)
                list(APPEND _zk_cmds COMMAND lipo -create ${_zk_thin} -output "${_zk_lib}")
            endif()
        endif()

        add_custom_command(
            OUTPUT "${_zk_lib}"
            ${_zk_cmds}
            DEPENDS ${_zk_deps}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "构建 EraAudio Zig 解码内核（archoera_kernel）"
            VERBATIM)
        add_custom_target(archoera_kernel_lib DEPENDS "${_zk_lib}")
        target_compile_definitions(archoera_engine PUBLIC HAS_ARCHOERA_KERNEL=1)
        add_dependencies(archoera_engine archoera_kernel_lib)
        # kernel 必须在 -lm 之前（--as-needed 下顺序敏感）
        target_link_libraries(archoera_engine PUBLIC "${_zk_lib}")
        message(STATUS "neko-audio-engine: EraAudio Zig 内核已启用（${NEKO_ZIG_EXECUTABLE}）")
    else()
        message(WARNING
            "NEKO_ENABLE_ERAUDIO_KERNEL=ON 但未找到 zig —— EraAudio 内核不启用，"
            "解码回退 FFmpeg（可 -DNEKO_ENABLE_ERAUDIO_KERNEL=OFF 消除本警告）")
    endif()
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

# Windows：miniaudio 的 WASAPI/WinMM 后端所需系统库（MinGW/MSVC 均自带）
# ntdll：EraAudio Zig 内核在 Windows 上直接引用 NtClose/RtlAllocateHeap 等。
if(WIN32)
    target_link_libraries(archoera_engine PUBLIC
        ole32 winmm avrt uuid bcrypt secur32 ws2_32 ntdll)
endif()
