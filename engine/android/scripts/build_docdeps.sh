#!/bin/bash
# Builds the document-pipeline dependencies for one Android ABI:
# libiconv (poppler-cpp needs it; the NDK has no iconv), FreeType, libzip
# and finally poppler itself.
set -e
source "$(dirname "$0")/env.sh"
abi_setup "$1"

BASE=$ANDROID_ROOT/build/$ABI
CFLAGS_COMMON="-Os -fPIC"

# --- libiconv -------------------------------------------------------------
B=$BASE/iconv; rm -rf "$B"; mkdir -p "$B"; cd "$B"
"$SRC"/libiconv-1.17/configure \
  --host="$TARGET" --prefix="$PREFIX" \
  --enable-static --disable-shared --with-pic \
  CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS_COMMON" \
  >configure.log 2>&1
make -j"$(nproc)" >build.log 2>&1
make install >>build.log 2>&1
echo "  iconv $ABI ok"

# --- FreeType (poppler requires it) ---------------------------------------
B=$BASE/freetype; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cmake "$SRC"/freetype-2.13.3 -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON \
  -DFT_DISABLE_PNG=ON \
  >cmake.log 2>&1
ninja >build.log 2>&1
ninja install >>build.log 2>&1
echo "  freetype $ABI ok"

# --- libzip (OOXML reading) ----------------------------------------------
B=$BASE/libzip; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cmake "$SRC"/libzip-1.11.2 -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF \
  -DENABLE_OPENSSL=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF \
  -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF \
  >cmake.log 2>&1
ninja >build.log 2>&1
ninja install >>build.log 2>&1
echo "  libzip $ABI ok"

# --- poppler + poppler-cpp (PDF read and render) --------------------------
B=$BASE/poppler; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cmake "$SRC"/poppler-24.08.0 -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DENABLE_CPP=ON -DENABLE_GLIB=OFF -DENABLE_QT5=OFF -DENABLE_QT6=OFF \
  -DENABLE_UTILS=OFF -DBUILD_GTK_TESTS=OFF -DBUILD_CPP_TESTS=OFF \
  -DBUILD_MANUAL_TESTS=OFF \
  -DENABLE_FONTCONFIG=OFF -DENABLE_LIBCURL=OFF -DENABLE_NSS3=OFF \
  -DENABLE_GPGME=OFF -DENABLE_LIBOPENJPEG=none -DENABLE_LCMS=OFF \
  -DENABLE_DCTDECODER=unmaintained -DENABLE_LIBTIFF=OFF -DENABLE_LIBPNG=OFF -DENABLE_LIBCURL=OFF \
  -DENABLE_LIBJPEG=OFF -DENABLE_ZLIB_UNCOMPRESS=OFF -DENABLE_BOOST=OFF \
  -DRUN_GPERF_IF_PRESENT=OFF \
  -DIconv_LIBRARY="$PREFIX/lib/libiconv.a" \
  -DIconv_INCLUDE_DIR="$PREFIX/include" \
  -DFREETYPE_LIBRARY="$PREFIX/lib/libfreetype.a" \
  -DFREETYPE_INCLUDE_DIRS="$PREFIX/include/freetype2" \
  >cmake.log 2>&1
ninja >build.log 2>&1
ninja install >>build.log 2>&1
echo "  poppler $ABI ok"
