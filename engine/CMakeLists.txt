cmake_minimum_required(VERSION 3.20)
project(neko_engine LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# 导出符号仅限 NEKO_API
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

if(NOT WIN32)
    find_package(PkgConfig REQUIRED)
endif()

if(WIN32)
    # Windows：从 MPV_DIR 或系统路径查找 libmpv
    find_path(MPV_INCLUDE_DIR mpv/client.h
              HINTS "$ENV{MPV_DIR}/include" "$ENV{MPV_DIR}")
    # 优先 .lib 导入库；mpv 官方 Windows 包常仅含 dll（libmpv-2.dll /
    # mpv-2.dll）——MSVC 可直接链接 dll（自动生成导入库），故一并兜底
    find_library(MPV_LIBRARY NAMES mpv mpv-2 libmpv-2
                 HINTS "$ENV{MPV_DIR}/lib" "$ENV{MPV_DIR}")
    if(NOT MPV_INCLUDE_DIR)
        message(FATAL_ERROR "libmpv headers not found. Set MPV_DIR to the mpv dev package root.")
    endif()
    if(NOT MPV_LIBRARY)
        find_file(MPV_DLL NAMES mpv-2.dll libmpv-2.dll mpv.dll
                  HINTS "$ENV{MPV_DIR}/bin" "$ENV{MPV_DIR}")
        if(MPV_DLL)
            add_library(mpv_shared SHARED IMPORTED GLOBAL)
            # MSVC 直接链 dll：IMPORTED_LOCATION 与 IMPORTED_IMPLIB 同指 dll，
            # 链接时自动生成导入库
            set_target_properties(mpv_shared PROPERTIES
                IMPORTED_LOCATION "${MPV_DLL}"
                IMPORTED_IMPLIB "${MPV_DLL}")
            set(MPV_TARGET mpv_shared)
        else()
            message(FATAL_ERROR "libmpv library not found. Set MPV_DIR to the mpv dev package root.")
        endif()
    else()
        set(MPV_TARGET "${MPV_LIBRARY}")
    endif()
    add_library(neko_engine SHARED src/neko_engine.c)
    target_include_directories(neko_engine PUBLIC
            ${CMAKE_CURRENT_SOURCE_DIR}/include
            ${MPV_INCLUDE_DIR})
    if(TARGET mpv_shared)
        target_link_libraries(neko_engine PRIVATE mpv_shared)
    else()
        target_link_libraries(neko_engine PRIVATE ${MPV_LIBRARY})
    endif()
else()
    pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
    add_library(neko_engine SHARED src/neko_engine.c)
    target_include_directories(neko_engine PUBLIC
            ${CMAKE_CURRENT_SOURCE_DIR}/include)
    target_link_libraries(neko_engine PRIVATE PkgConfig::MPV)
    if(APPLE)
        target_link_libraries(neko_engine PRIVATE "-framework CoreFoundation")
    endif()
endif()

target_compile_definitions(neko_engine PRIVATE NEKO_ENGINE_BUILD)
set_target_properties(neko_engine PROPERTIES
        OUTPUT_NAME neko_engine
        C_VISIBILITY_PRESET hidden)

# ---- Qt 核心桥（neko_core）----
# 复刻原 Qt 程序的核心子集：ApiClient / UserManager / PlaylistDatabase / PlaylistManager
# 仅依赖 Qt Core/Network/Sql（不链 Multimedia/Gui，绕开 FFmpeg 符号冲突）
find_package(Qt6 REQUIRED COMPONENTS Core Network Sql)

add_library(neko_core SHARED
        core/neko_core.cpp
        ../flutter/lib/core/native/core/apiclient.cpp
        ../flutter/lib/core/native/core/usermanager.cpp
        ../flutter/lib/core/native/core/playlistdb.cpp
        ../flutter/lib/core/native/core/playlistmanager.cpp
        ../flutter/lib/core/native/core/landevicemanager.cpp)
target_include_directories(neko_core PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/core
        ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(neko_core PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../flutter/lib/core/native)
target_link_libraries(neko_core PRIVATE Qt6::Core Qt6::Network Qt6::Sql)
target_compile_definitions(neko_core PRIVATE NEKO_CORE_BUILD)
set_target_properties(neko_core PROPERTIES
        OUTPUT_NAME neko_core
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
        AUTOMOC ON)

# ---- CLI 自检程序 ----
add_executable(neko_engine_test src/test_engine.c)
target_link_libraries(neko_engine_test PRIVATE neko_engine)

add_executable(neko_core_test src/test_core.c)
target_link_libraries(neko_core_test PRIVATE neko_core)

enable_testing()
add_test(NAME engine_pipewire
         COMMAND neko_engine_test --check)
