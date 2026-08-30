# Android build

The engine is one shared library, `libconvertor.so`, with every dependency
linked in statically. Android ships none of them, so FFmpeg, poppler and the
codec libraries are cross-compiled here with the NDK before the engine itself
is built.

Built for **arm64-v8a** (real devices) and **x86_64** (emulators). Anything
else is excluded from the APK — see `abiFilters` and the `jniLibs` exclusion in
`android/app/build.gradle.kts` — because a device we have no engine for would
otherwise fall back to placeholder output.

## Rebuilding

Run in order; each script takes one ABI:

```sh
./scripts/build_x264.sh    x86_64      # H.264 encoder (GPL)
./scripts/build_codecs.sh  x86_64      # LAME, Ogg/Vorbis, Opus, libwebp, libvpx
./scripts/build_docdeps.sh x86_64      # libiconv, FreeType, libzip, poppler
./scripts/build_ffmpeg.sh  x86_64      # FFmpeg, against the libraries above
./scripts/build_engine.sh  x86_64      # libconvertor.so -> app/src/main/jniLibs/
```

Repeat with `arm64-v8a`. `build_engine.sh` installs straight into the Flutter
app, so a rebuild is picked up by the next `flutter build apk`.

Sources are downloaded into `src/`, intermediate objects land in `build/`, and
the cross-compiled dependencies in `prefix/<abi>/`. All four are generated and
git-ignored.

## Things that are the way they are for a reason

- **libx264 makes this GPL.** FFmpeg has no H.264 encoder of its own, and
  without one MP4 output falls back to MPEG-4 Part 2. Dropping `--enable-gpl
  --enable-libx264` from `build_ffmpeg.sh` is what reverts that decision.
- **x86_64 is built with `--disable-asm`.** FFmpeg's x86 assembly — including
  the inline asm that `--disable-x86asm` leaves alone — emits relocations the
  linker rejects when everything is folded into one shared library. arm64 keeps
  its NEON assembly, so real devices lose nothing.
- **`-Wl,--exclude-libs,ALL`** makes symbols from the bundled archives local.
  Besides shrinking the library, it is what lets the linker resolve FFmpeg's
  aarch64 assembly: while those symbols stay globally visible they count as
  preemptible, and the PC-relative relocations the assembly emits are refused.
- **poppler is built without libpng/libjpeg.** Rendered pages come back as a
  pixel buffer and are encoded through FFmpeg, the same path every other image
  conversion uses, so poppler needs no image writers of its own.
- **libiconv is built even though the NDK has no iconv**, because poppler-cpp
  requires it.

## Verifying

`integration_test/` runs the engine on a device:

```sh
flutter test integration_test/android_conversion_test.dart -d <device>
flutter test integration_test/android_matrix_test.dart     -d <device>
```

The second one runs every conversion the UI offers for each bundled sample, so
a codec missing from the cross-compile fails there rather than in someone's
hands.
