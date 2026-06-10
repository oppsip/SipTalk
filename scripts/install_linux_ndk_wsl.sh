#!/usr/bin/env bash
set -euo pipefail

NDK_VERSION="28.2.13676358"
NDK_ARCHIVE="android-ndk-r28c-linux.zip"
NDK_URL="https://dl.google.com/android/repository/${NDK_ARCHIVE}"
NDK_SHA1="a7b54a5de87fecd125a17d54f73c446199e72a64"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
DOWNLOAD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/siptalk"

mkdir -p "$ANDROID_SDK_ROOT/ndk" "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

if [[ ! -f "$NDK_ARCHIVE" ]]; then
  curl -L --fail --retry 3 -o "$NDK_ARCHIVE" "$NDK_URL"
fi

actual_sha1="$(sha1sum "$NDK_ARCHIVE" | awk '{print $1}')"
if [[ "$actual_sha1" != "$NDK_SHA1" ]]; then
  echo "NDK checksum mismatch. Expected $NDK_SHA1, got $actual_sha1" >&2
  exit 1
fi

rm -rf "$ANDROID_SDK_ROOT/ndk/android-ndk-r28c" "$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"

python3 - "$NDK_ARCHIVE" "$ANDROID_SDK_ROOT/ndk" <<'PY'
import os
import stat
import sys
import zipfile
from pathlib import Path

src = Path(sys.argv[1]).resolve()
dst = Path(sys.argv[2]).resolve()

with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        mode = info.external_attr >> 16
        target = dst / info.filename
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            if mode:
                os.chmod(target, mode & 0o777)
            continue

        target.parent.mkdir(parents=True, exist_ok=True)
        if stat.S_ISLNK(mode):
            if target.exists() or target.is_symlink():
                target.unlink()
            os.symlink(z.read(info).decode("utf-8"), target)
            continue

        with z.open(info) as source, open(target, "wb") as out:
            out.write(source.read())
        if mode:
            os.chmod(target, mode & 0o777)
PY

mv "$ANDROID_SDK_ROOT/ndk/android-ndk-r28c" "$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"

clang_path="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
test -x "$clang_path"
"$clang_path" --version | head -n 1

echo "Linux Android NDK installed at $ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
