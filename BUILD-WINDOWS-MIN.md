# Building canonical `min` FFmpegKit for Windows (MSYS2 / MinGW-w64)

This documents how to build a **true `min`** FFmpegKit for Windows x86_64 — one
that `Packages::getPackageName()` classifies as `min` — using the **integrated
build system** (`windows.sh` → `scripts/main-windows.sh` → `scripts/windows/*.sh`),
the same path used by the `min-gpl` and `full-gpl` builds
(see `BUILD-WINDOWS-MIN-GPL.md`, `BUILD-WINDOWS-FULL-GPL.md`).

It produces the release artifact the Flutter plugin downloads:
`ffmpeg-kit-windows-x86_64-min-8.0.0.zip`.

## What `min` is

`min` is the smallest variant: a **bare FFmpeg** with **no external libraries**
and **no `--enable-gpl`**. It is exactly the `min-gpl` set minus the four GPL
video libraries (x264, x265, xvid, vid.stab).

### Why exactly nothing

`windows/src/Packages.cpp` derives the variant from the enabled-library set
scanned out of `FFMPEG_CONFIGURATION`. With an empty set:

1. `speex && fribidi` absent, `speex` absent, `fribidi` absent, `xvid` absent → not full/audio/video/*-gpl.
2. `gnutls` absent → not https.
3. Falls through to the final `return "min"`.

So the variant is an **emergent property of the (empty) library set** — adding
any classifying library changes it (e.g. x264+x265+xvid+vid.stab+gpl → min-gpl,
gmp+gnutls → https). To stay `min`, pass no `--enable-*` library flags.

## Prerequisites

Same MSYS2 MINGW64 toolchain as the other variants, but `min` builds **no source
libraries at all** — only FFmpeg itself — so only the base toolchain + nasm
(FFmpeg x86 asm) are needed:

```bash
pacman -S --needed git make diffutils perl pkgconf \
  mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm
```

## Build

```bash
cd /c/Users/<you>/StudioProjects/ffmpeg-kit
./build-windows-min.sh
```

It runs the integrated build with **no** library flags, verifies the produced
`FFMPEG_CONFIGURATION` carries none of the classifying flags, and packages the
zip. Equivalent manual invocation:

```bash
./windows.sh
```

Full output is appended to `build.log`.

Outputs:
- FFmpeg install: `prebuilt/windows-x86_64/ffmpeg/` (reconfigured each run)
- Wrapper install: `prebuilt/windows-x86_64/ffmpeg-kit/`
- Bundle: `prebuilt/bundle-windows-x86_64/ffmpeg-kit/{bin,include,lib,pkgconfig}`
  (the bundle's `bin/` also gets the MinGW runtime DLLs:
  `libgcc_s_seh-1.dll`, `libwinpthread-1.dll`, `libstdc++-6.dll`)
- **Release zip:** `prebuilt/ffmpeg-kit-windows-x86_64-min-8.0.0.zip`
  (the bundle's `bin/` + `include/`)

With no external codecs, the `min` bundle's `bin/` is just the `av*` /
`swscale` / `swresample` / `libffmpegkit` DLLs plus the MinGW runtime closure —
the smallest of all variants.

> ⚠️ The bundle directory `prebuilt/bundle-windows-x86_64/` and the FFmpeg
> install `prebuilt/windows-x86_64/ffmpeg/` are **shared** across variants.
> Running this overwrites whatever variant was built there last. The already-zipped
> artifacts in `prebuilt/*.zip` are not touched.

## Verify it is genuinely `min`

```bash
grep FFMPEG_CONFIGURATION prebuilt/windows-x86_64/ffmpeg/include/config.h
# MUST NOT contain: enable-gpl, enable-libx264/x265/xvid/vidstab,
#                   enable-gnutls, enable-libfribidi, enable-libspeex (or any enable-lib*)
```

(`build-windows-min.sh` performs these assertions and fails the build otherwise.)

The example app's startup log must read `Loaded ffmpeg-kit-min-x86_64-...`.

## Publishing to GitHub releases

Same convention as `full` / `min-gpl`: the Windows zip is an **additional asset
on the existing per-variant release** (`8.0.0-min`), alongside the iOS/macOS zips.

```
FFMPEGKIT_RELEASE_TAG = <version>-<package>            -> 8.0.0-min   (already exists)
FFMPEGKIT_ZIP_NAME    = ffmpeg-kit-windows-x86_64-<package>-<version>.zip
download URL          = .../releases/download/8.0.0-min/ffmpeg-kit-windows-x86_64-min-8.0.0.zip
```

```bash
gh release upload 8.0.0-min \
  prebuilt/ffmpeg-kit-windows-x86_64-min-8.0.0.zip \
  --repo sk3llo/ffmpeg_kit_flutter --clobber
```

## Wiring it into the Flutter plugin (min branch)

`windows/CMakeLists.txt` on the `min` branch sets:

```cmake
set(FFMPEGKIT_PACKAGE "min" CACHE STRING "FFmpegKit variant")
set(FFMPEGKIT_VERSION "8.0.0" CACHE STRING "FFmpegKit release version")
```

Consume a local build with `-DFFMPEGKIT_LOCAL_DIR=.../bundle-windows-x86_64/ffmpeg-kit`,
or leave it empty to download from the release above.

## Status & caveats

- **arch:** x86_64 only.
- **Licensing:** `min` contains no GPL components — it stays under FFmpegKit's
  default LGPL 3.0.
