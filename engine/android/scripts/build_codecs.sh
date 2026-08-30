#!/bin/bash
# Builds the codec libraries FFmpeg needs but does not implement natively:
# LAME (MP3 encode), Ogg/Vorbis, Opus and libvpx (VP8/VP9 for WebM).
set -e
source "$(dirname "$0")/env.sh"
abi_setup "$1"

BASE=$ANDROID_ROOT/build/$ABI
COMMON_CFLAGS="-Os -fPIC"

autotools_build() {
  local name="$1"; shift
  local dir="$1"; shift
  local build="$BASE/$name"
  rm -rf "$build"; mkdir -p "$build"; cd "$build"
  "$SRC/$dir/configure" \
    --host="$TARGET" --prefix="$PREFIX" \
    --enable-static --disable-shared --with-pic \
    CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
    CFLAGS="$COMMON_CFLAGS" CXXFLAGS="$COMMON_CFLAGS" \
    "$@" >configure.log 2>&1
  make -j"$(nproc)" >build.log 2>&1
  make install >>build.log 2>&1
  echo "  $name $ABI ok"
}

# LAME's configure ships a broken check that pulls in a glibc-only header.
autotools_build lame lame-3.100 --disable-frontend --disable-decoder --disable-analyzer-hooks
autotools_build ogg libogg-1.3.5
autotools_build vorbis libvorbis-1.3.7 --disable-oggtest
autotools_build opus opus-1.5.2 --disable-doc --disable-extra-programs

# libwebp: FFmpeg has no native WebP encoder, so .webp output needs it.
autotools_build webp libwebp-1.4.0 --disable-libwebpmux --disable-libwebpdemux \
  --disable-libwebpdecoder --disable-sdl --disable-gl --disable-png --disable-jpeg \
  --disable-tiff --disable-gif

# libvpx has its own configure conventions.
VPX_BUILD=$BASE/vpx
rm -rf "$VPX_BUILD"; mkdir -p "$VPX_BUILD"; cd "$VPX_BUILD"
case "$ABI" in
  arm64-v8a) VPX_TARGET=arm64-android-gcc ;;
  x86_64)    VPX_TARGET=x86_64-android-gcc ;;
esac
CROSS="$TOOLCHAIN/bin/llvm-" \
CC="$CC" CXX="$CXX" AR="$AR" LD="$CXX" RANLIB="$RANLIB" STRIP="$STRIP" \
"$SRC"/libvpx-1.14.1/configure \
  --target="$VPX_TARGET" --prefix="$PREFIX" \
  --disable-examples --disable-tools --disable-docs --disable-unit-tests \
  --enable-pic --enable-static --disable-shared \
  --enable-vp8 --enable-vp9 --enable-vp9-encoder --enable-vp8-encoder \
  --extra-cflags="$COMMON_CFLAGS" \
  >configure.log 2>&1
make -j"$(nproc)" >build.log 2>&1
make install >>build.log 2>&1
echo "  vpx $ABI ok"
