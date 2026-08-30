#!/bin/bash
# Builds libx264 as a static library for one Android ABI.
set -e
source "$(dirname "$0")/env.sh"
abi_setup "$1"

BUILD=$ANDROID_ROOT/build/$ABI/x264
rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"

"$SRC"/x264-stable/configure \
  --prefix="$PREFIX" \
  --host="$TARGET" \
  --cross-prefix="$TOOLCHAIN/bin/llvm-" \
  --sysroot="$SYSROOT" \
  --enable-static --disable-cli --enable-pic \
  --disable-opencl --disable-asm \
  --extra-cflags="-Os -fPIC" \
  >configure.log 2>&1

make -j"$(nproc)" >build.log 2>&1
make install >>build.log 2>&1
echo "x264 $ABI OK -> $PREFIX/lib/libx264.a"
