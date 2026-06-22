#!/usr/bin/env bash
#
# build-tdjson-android.sh
#
# Cross-compiles TDLib's `tdjson` shared library for Android and installs the
# per-ABI .so files into android/app/src/main/jniLibs/, where the Android Gradle
# plugin bundles them automatically. The Dart FFI layer then resolves the
# symbols at runtime via DynamicLibrary.open('libtdjson.so').
#
# Requirements:
#   - Android NDK (set ANDROID_NDK_HOME, or it is auto-detected under
#     $ANDROID_HOME/ndk/<version>)
#   - cmake, git, gperf, and a host OpenSSL+zlib cross-build (the official TDLib
#     Android guide builds these; see https://tdlib.github.io/td/build.html)
#
# Usage:
#   ./scripts/build-tdjson-android.sh [abi ...]
#   (default ABIs: arm64-v8a armeabi-v7a x86_64)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/.tdlib-build"
JNI_DIR="$REPO_ROOT/android/app/src/main/jniLibs"
ABIS=("${@:-arm64-v8a armeabi-v7a x86_64}")

: "${ANDROID_NDK_HOME:=}"
if [[ -z "$ANDROID_NDK_HOME" ]]; then
  SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [[ -d "$SDK/ndk" ]]; then
    ANDROID_NDK_HOME="$SDK/ndk/$(ls "$SDK/ndk" | sort -V | tail -1)"
  fi
fi
if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
  echo "✗ Android NDK not found. Install it and set ANDROID_NDK_HOME." >&2
  exit 1
fi
echo "→ NDK: $ANDROID_NDK_HOME"

# ABI → CMake Android ABI mapping is 1:1 for the NDK toolchain file.
mkdir -p "$BUILD_DIR"
if [[ ! -d "$BUILD_DIR/td" ]]; then
  echo "→ Cloning TDLib…"
  git clone https://github.com/tdlib/td.git "$BUILD_DIR/td"
fi

for ABI in $ABIS; do
  echo "→ Building tdjson for $ABI…"
  OUT="$BUILD_DIR/build-android-$ABI"
  cmake -S "$BUILD_DIR/td" -B "$OUT" \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_BUILD_TYPE=Release \
    -DTD_ENABLE_LTO=ON \
    -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR:-$BUILD_DIR/openssl/$ABI}"
  cmake --build "$OUT" --target tdjson -j"$(getconf _NPROCESSORS_ONLN)"

  mkdir -p "$JNI_DIR/$ABI"
  cp "$OUT/libtdjson.so" "$JNI_DIR/$ABI/libtdjson.so"
  echo "  ✓ $JNI_DIR/$ABI/libtdjson.so"
done

echo "✓ Done. Run: flutter run"
