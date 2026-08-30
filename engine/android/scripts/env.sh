# Shared Android cross-compilation settings.
export NDK=/home/snowowl/Android/Sdk/ndk/28.2.13676358
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export API=24
export ANDROID_ROOT=/home/snowowl/convertor/engine/android
export SRC=$ANDROID_ROOT/src
# Locally built nasm: needed for x86_64 assembly in libvpx and FFmpeg.
export PATH=$ANDROID_ROOT/hosttools/bin:$PATH

# abi_setup <abi>  ->  TARGET, CC/CXX/AR/..., PREFIX, CMAKE_ABI
abi_setup() {
  export ABI="$1"
  case "$ABI" in
    arm64-v8a) export TARGET=aarch64-linux-android; export FF_ARCH=aarch64;  export FF_CPU_FLAGS="" ;;
    # FFmpeg's x86 assembly - including the inline asm in libavcodec, which
    # --disable-x86asm leaves in place - emits non-PIC relocations that the
    # linker rejects when everything is folded into one shared library. arm64
    # keeps its NEON assembly; only the emulator ABI gives all of it up.
    x86_64)    export TARGET=x86_64-linux-android;  export FF_ARCH=x86_64;   export FF_CPU_FLAGS="--disable-asm" ;;
    *) echo "unknown abi $ABI" >&2; return 1 ;;
  esac
  export PREFIX=$ANDROID_ROOT/prefix/$ABI
  export CC=$TOOLCHAIN/bin/${TARGET}${API}-clang
  export CXX=$TOOLCHAIN/bin/${TARGET}${API}-clang++
  export AR=$TOOLCHAIN/bin/llvm-ar
  export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
  export STRIP=$TOOLCHAIN/bin/llvm-strip
  export NM=$TOOLCHAIN/bin/llvm-nm
  export LD=$TOOLCHAIN/bin/ld
  export SYSROOT=$TOOLCHAIN/sysroot
  export PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig
  export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
  mkdir -p "$PREFIX"
}
