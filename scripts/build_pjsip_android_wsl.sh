#!/usr/bin/env bash
set -euo pipefail

PJPROJECT_DIR="${1:?pjproject dir is required}"
ANDROID_NDK_ROOT_ARG="${2:?android ndk root is required}"
TARGET_ABI_ARG="${3:-arm64-v8a}"
APP_PLATFORM_ARG="${4:-28}"
OPENSSL_DIR_ARG="${5:-}"
OBOE_DIR_ARG="${6:-}"

cd "$PJPROJECT_DIR"

find . -type f \( \
  -name 'configure' -o \
  -name 'aconfigure' -o \
  -name 'configure-*' -o \
  -name 'config.sub' -o \
  -name 'config.guess' -o \
  -name '*.in' -o \
  -name '*.mak' -o \
  -name '*.sh' \
\) -exec sed -i 's/\r$//' {} +

cat > pjlib/include/pj/config_site.h <<'EOF'
#define PJ_CONFIG_ANDROID 1
#include <pj/config_site_sample.h>

/* SipTalk MVP is audio-first. Enable video later with an explicit test pass. */
#define PJMEDIA_HAS_VIDEO 0

/* Keep PJSUA2 object ownership inside the app's native core. */
#define PJ_HAS_EXCEPTION_NAMES 1
EOF

export ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT_ARG"
export APP_PLATFORM="$APP_PLATFORM_ARG"
export TARGET_ABI="$TARGET_ABI_ARG"

CONFIGURE_ARGS=(--use-ndk-cflags)

if [[ -n "$OPENSSL_DIR_ARG" ]]; then
  export OPENSSL_DIR="$OPENSSL_DIR_ARG"
  CONFIGURE_ARGS+=(--with-ssl="$OPENSSL_DIR")
fi

if [[ -n "$OBOE_DIR_ARG" ]]; then
  export OBOE_DIR="$OBOE_DIR_ARG"
  CONFIGURE_ARGS+=(--with-oboe="$OBOE_DIR")
fi

make distclean >/dev/null 2>&1 || true
CFLAGS="-D__BIONIC_NO_PAGE_SIZE_MACRO" \
LDFLAGS="-Wl,-z,max-page-size=16384" \
  ./configure-android "${CONFIGURE_ARGS[@]}"

make dep
make clean
make

echo "PJSIP Android build completed for $TARGET_ABI_ARG API $APP_PLATFORM_ARG"
