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

find_package(PkgConfig REQUIRED)

if(WIN32)
    # Windows：从 MPV_DIR 或系统路径查找 libmpv（mingw/msvc 均可用）
    find_path(MPV_INCLUDE_DIR mpv/client.h
              HINTS "$ENV{MPV_DIR}/include" "$ENV{MPV_DIR}")
    find_library(MPV_LIBRARY mpv
                 HINTS "$ENV{MPV_DIR}/lib" "$ENV{MPV_DIR}")
    if(NOT MPV_INCLUDE_DIR OR NOT MPV_LIBRARY)
        message(FATAL_ERROR "libmpv not found. Set MPV_DIR to the mpv dev package root.")
    endif()
    add_library(neko_engine SHARED src/neko_engine.c)
    target_include_directories(neko_engine PUBLIC
            ${CMAKE_CURRENT_SOURCE_DIR}/include
            ${MPV_INCLUDE_DIR})
    target_link_libraries(neko_engine PRIVATE ${MPV_LIBRARY})
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
# 仅依赖 Qt Core/Network/Sql/Gui（不链 Multimedia，绕开 FFmpeg 符号冲突）
# Gui 仅因 theme.h 引用 QColor
find_package(Qt6 REQUIRED COMPONENTS Core Network Sql Gui)

add_library(neko_core SHARED
        core/neko_core.cpp
        ../flutter/lib/core/native/core/apiclient.cpp
        ../flutter/lib/core/native/core/usermanager.cpp
        ../flutter/lib/core/native/core/playlistdb.cpp
        ../flutter/lib/core/native/core/playlistmanager.cpp)
target_include_directories(neko_core PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/core
        ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(neko_core PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../flutter/lib/core/native)
target_link_libraries(neko_core PRIVATE Qt6::Core Qt6::Network Qt6::Sql Qt6::Gui)
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
