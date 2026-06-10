# Native Dependencies

SipTalk pins native dependencies and builds them reproducibly. Android uses PJSIP 2.17 as the SIP/media engine baseline.

## Pinned Versions

See `native/third_party/versions.json`.

Current Android baseline:

```text
PJSIP: 2.17
NDK: 28.2.13676358
CMake: 3.22.1
ABI: arm64-v8a first
API level: 28 first
```

## Fetch PJSIP

```powershell
.\scripts\fetch_pjsip.ps1
```

This checks out `pjproject` tag `2.17` and verifies the expected commit.

## Build PJSIP For Android

Minimal audio-first build:

```powershell
.\scripts\build_pjsip_android.ps1
```

Build the Android APK for the same ABI:

```powershell
.\scripts\build_android_debug_arm64.ps1
```

PJSIP is currently linked only for `arm64-v8a`. A generic `flutter build apk --debug` may still package Flutter engine binaries for other ABIs, but `libsiptalk_jni.so` is available only for `arm64-v8a` until the other PJSIP ABI builds are added.

Production TLS build should pass OpenSSL and require it:

```powershell
.\scripts\build_pjsip_android.ps1 `
  -Abi arm64-v8a `
  -ApiLevel 28 `
  -OpenSslDir C:\path\to\openssl-android\arm64-v8a `
  -RequireSsl
```

If using Oboe:

```powershell
.\scripts\build_pjsip_android.ps1 `
  -Abi arm64-v8a `
  -ApiLevel 28 `
  -OpenSslDir C:\path\to\openssl-android\arm64-v8a `
  -OboeDir C:\path\to\oboe `
  -RequireSsl `
  -RequireOboe
```

## Why WSL

PJSIP's Android build uses GNU/autoconf style scripts such as `configure-android` and `make`. On this Windows workstation, the reproducible path is to call those scripts through WSL with a Linux-host Android NDK installed inside WSL.

Important: the Windows Android NDK cannot be used from WSL because it contains `windows-x86_64` host tools. PJSIP's WSL build requires the Linux NDK host tools at:

```text
<ndk>/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++
```

Install or extract the Linux Android NDK inside WSL, then call:

```powershell
.\scripts\install_linux_ndk_wsl.ps1
.\scripts\build_pjsip_android.ps1 -AndroidNdkRoot /home/<user>/Android/Sdk/ndk/28.2.13676358
```

The install script preserves Linux symlinks and executable bits. Do not extract the NDK with Python's standard `zipfile.extractall()` or a Windows unzipper into WSL, because NDK compiler symlinks such as `clang++ -> clang` may become plain text files.

## Line Endings

When `pjproject` is checked out on Windows and built through WSL, shell scripts and autoconf templates can have CRLF endings. The build script normalizes build inputs before `configure-android`; without this, `config.status` may leave generated headers such as `os_auto.h` full of `#undef` values.

## Rules

- Build OpenSSL for the same ABI and API level as PJSIP.
- Keep production builds on `arm64-v8a` first.
- Use NDK r27 or newer compatible flags for Android 15 16 KB page sizes.
- Keep generated third-party sources and build outputs out of git.
- Do not disable TLS certificate verification in production.
