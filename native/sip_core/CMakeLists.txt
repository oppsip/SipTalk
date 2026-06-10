cmake_minimum_required(VERSION 3.22)

project(siptalk_core LANGUAGES CXX)

add_library(siptalk_core STATIC
    SipCommandQueue.cpp
    SipCore.cpp
)

target_include_directories(siptalk_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_features(siptalk_core PUBLIC cxx_std_17)

if(MSVC)
    target_compile_options(siptalk_core PRIVATE /W4)
else()
    target_compile_options(siptalk_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

# PJSIP integration will be added here after the pinned native dependency build
# exists. Keep this target as the stable app-facing boundary.
