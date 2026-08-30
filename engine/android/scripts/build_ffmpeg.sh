#!/bin/bash
# Builds FFmpeg as static libraries for one Android ABI, with the external
# encoders the conversion matrix depends on (x264, LAME, Vorbis, Opus, VP8/9).
set -e
source "$(dirname "$0")/env.sh"
abi_setup "$1"

BUILD=$ANDROID_ROOT/build/$ABI/ffmpeg
rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"

"$SRC"/ffmpeg-7.1/configure \
  --prefix="$PREFIX" \
  --target-os=android \
  --arch="$FF_ARCH" \
  --enable-cross-compile \
  --cross-prefix="$TOOLCHAIN/bin/llvm-" \
  --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --nm="$NM" --strip="$STRIP" \
  --sysroot="$SYSROOT" \
  --pkg-config=pkg-config --pkg-config-flags=--static \
  --enable-static --disable-shared --enable-pic \
  --disable-programs --disable-doc --disable-avdevice --disable-postproc \
  --enable-gpl --enable-version3 \
  --enable-libx264 --enable-libmp3lame --enable-libvorbis --enable-libopus --enable-libvpx \
  --enable-libwebp \
  --extra-cflags="-Os -fPIC -I$PREFIX/include" \
  --extra-ldflags="-L$PREFIX/lib" \
  $FF_CPU_FLAGS \
  >configure.log 2>&1

make -j"$(nproc)" >build.log 2>&1
make install >>build.log 2>&1
echo "ffmpeg $ABI OK"
