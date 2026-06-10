set(PJSIP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/pjproject")
set(PJSIP_TARGET_NAME "aarch64-unknown-linux-android")
set(PJSIP_LIB_SUFFIX "${PJSIP_TARGET_NAME}.a")

if(NOT CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
    message(FATAL_ERROR "PJSIP is currently built only for arm64-v8a, got ${CMAKE_ANDROID_ARCH_ABI}")
endif()

function(add_pjsip_static_library target_name library_path)
    add_library(${target_name} STATIC IMPORTED GLOBAL)
    set_target_properties(${target_name}
        PROPERTIES
            IMPORTED_LOCATION "${PJSIP_ROOT}/${library_path}"
    )
endfunction()

add_pjsip_static_library(pjsua2 "pjsip/lib/libpjsua2-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjsua "pjsip/lib/libpjsua-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjsip_ua "pjsip/lib/libpjsip-ua-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjsip_simple "pjsip/lib/libpjsip-simple-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjsip_core "pjsip/lib/libpjsip-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjmedia_codec "pjmedia/lib/libpjmedia-codec-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjmedia_videodev "pjmedia/lib/libpjmedia-videodev-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjmedia "pjmedia/lib/libpjmedia-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjmedia_audiodev "pjmedia/lib/libpjmedia-audiodev-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjnath "pjnath/lib/libpjnath-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pjlib_util "pjlib-util/lib/libpjlib-util-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(pj "pjlib/lib/libpj-${PJSIP_LIB_SUFFIX}")

add_pjsip_static_library(g7221codec "third_party/lib/libg7221codec-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(gsmcodec "third_party/lib/libgsmcodec-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(ilbccodec "third_party/lib/libilbccodec-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(resample "third_party/lib/libresample-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(speex "third_party/lib/libspeex-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(srtp "third_party/lib/libsrtp-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(webrtc "third_party/lib/libwebrtc-${PJSIP_LIB_SUFFIX}")
add_pjsip_static_library(yuv "third_party/lib/libyuv-${PJSIP_LIB_SUFFIX}")

add_library(siptalk_pjsip INTERFACE)
target_include_directories(siptalk_pjsip
    INTERFACE
        "${PJSIP_ROOT}/pjlib/include"
        "${PJSIP_ROOT}/pjlib-util/include"
        "${PJSIP_ROOT}/pjnath/include"
        "${PJSIP_ROOT}/pjmedia/include"
        "${PJSIP_ROOT}/pjsip/include"
)

target_compile_definitions(siptalk_pjsip
    INTERFACE
        PJ_AUTOCONF=1
        PJ_IS_BIG_ENDIAN=0
        PJ_IS_LITTLE_ENDIAN=1
)

target_link_libraries(siptalk_pjsip
    INTERFACE
        pjsua2
        pjsua
        pjsip_ua
        pjsip_simple
        pjsip_core
        pjmedia_codec
        pjmedia_videodev
        pjmedia
        pjmedia_audiodev
        pjnath
        pjlib_util
        g7221codec
        gsmcodec
        ilbccodec
        resample
        speex
        srtp
        webrtc
        yuv
        pj
        mediandk
        OpenSLES
        log
        GLESv2
        EGL
        android
        atomic
        m
)
