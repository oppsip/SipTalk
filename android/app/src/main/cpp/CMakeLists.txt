cmake_minimum_required(VERSION 3.22)

project(siptalk_android LANGUAGES CXX)

include(${CMAKE_CURRENT_SOURCE_DIR}/pjsip_import.cmake)

add_subdirectory(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native/sip_core
    ${CMAKE_CURRENT_BINARY_DIR}/sip_core
)

target_link_libraries(siptalk_core
    PUBLIC
        siptalk_pjsip
)
target_compile_definitions(siptalk_core PRIVATE SIPTALK_HAS_PJSIP=1)
target_compile_options(siptalk_core PRIVATE -fexceptions -frtti)

add_library(siptalk_jni SHARED
    sip_native_jni.cpp
)

target_link_libraries(siptalk_jni
    PRIVATE
        siptalk_core
        siptalk_pjsip
        log
)

target_compile_features(siptalk_jni PRIVATE cxx_std_17)
target_compile_options(siptalk_jni PRIVATE -fexceptions -frtti)
