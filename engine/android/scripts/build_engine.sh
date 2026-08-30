#!/bin/bash
# Builds libconvertor.so for one Android ABI and installs it into the Flutter
# app's jniLibs, where the APK packaging picks it up automatically.
set -e
source "$(dirname "$0")/env.sh"
abi_setup "$1"

ENGINE_ROOT=/home/snowowl/convertor/engine
JNI_DIR=/home/snowowl/convertor/offlineconvertor/android/app/src/main/jniLibs/$ABI
BUILD=$ANDROID_ROOT/build/$ABI/engine

rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"

cmake "$ENGINE_ROOT" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" \
  -DANDROID_STL=c++_static \
  -DCMAKE_BUILD_TYPE=Release \
  -DCONVERTOR_DEPS_PREFIX="$PREFIX" \
  >cmake.log 2>&1

ninja convertor_shared >build.log 2>&1

mkdir -p "$JNI_DIR"
cp libconvertor.so "$JNI_DIR/libconvertor.so"
"$STRIP" --strip-unneeded "$JNI_DIR/libconvertor.so"
echo "engine $ABI OK -> $JNI_DIR/libconvertor.so ($(du -h "$JNI_DIR/libconvertor.so" | cut -f1))"
