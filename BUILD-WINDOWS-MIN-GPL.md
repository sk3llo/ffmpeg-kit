# Building canonical `min-gpl` FFmpegKit for Windows (MSYS2 / MinGW-w64)

This documents how to build a **true `min-gpl`** FFmpegKit for Windows x86_64 —
one that `Packages::getPackageName()` classifies as `min-gpl` — using the
**integrated build system** (`windows.sh` → `scripts/main-windows.sh` →
`scripts/windows/*.sh`), the same path used by android/apple/linux and by the
`full-gpl` build (see `BUILD-WINDOWS-FULL-GPL.md`).

It produces the release artifact the Flutter plugin downloads:
`ffmpeg-kit-windows-x86_64-min-gpl-8.0.0.zip`.

## What `min-gpl` is

`min-gpl` is the smallest GPL variant: the **four GPL video libraries** on top of
a bare FFmpeg, with `--enable-gpl`, and **nothing else**.

| FFmpegKit lib | build script | FFmpeg flag | GPL |
|---|---|---|---|
| x264 | `x264.sh` | `--enable-libx264` | ✅ |
| x265 | `x265.sh` | `--enable-libx265` | ✅ |
| xvid | `xvidcore.sh` | `--enable-libxvid` | ✅ |
| vid.stab | `libvidstab.sh` | `--enable-libvidstab` | ✅ |

### Why exactly this set

`windows/src/Packages.cpp` derives the variant name from the enabled-library set
scanned out of `FFMPEG_CONFIGURATION`:

1. `speex && fribidi` absent, `speex` absent, `fribidi` absent → not full/audio/video.
2. `xvid` present **and** `gnutls` **absent** → `minGpl` branch.
3. `minGpl` then requires `libvidstab && x264 && x265 && xvid` → returns `min-gpl`.

So the variant is an **emergent property of the library set** — adding `gnutls`
would make it `https-gpl`, adding `speex`+`fribidi` would make it `full-gpl`, and
dropping any of the four GPL libs makes it `custom`. None of the four pull
external dependencies, so (unlike a partial `full` subset) no extra `--enable-*`
dependency libs are needed.

## Prerequisites

Identical to `BUILD-WINDOWS-FULL-GPL.md`. Run from an **MSYS2 MINGW64** shell
(`C:\msys64\mingw64.exe`). The only source builds here are x264, x265, xvid and
vid.stab; the relevant tools are the toolchain + **nasm** (x264/x265 assembly):

```bash
pacman -S --needed \
  git make diffutils perl pkgconf \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm
```

(cmake/ninja are used by x265; meson is not needed for the min-gpl set.)

## Build

One command, via the convenience wrapper:

```bash
cd /c/Users/<you>/StudioProjects/ffmpeg-kit
./build-windows-min-gpl.sh
```

It runs the integrated build with exactly the min-gpl set, verifies the produced
`FFMPEG_CONFIGURATION`, and packages the zip. Equivalent manual invocation:

```bash
./windows.sh --enable-x264 --enable-x265 --enable-xvidcore --enable-libvidstab --enable-gpl
```

Full output is appended to `build.log`.

Outputs:
- Per-library installs: `prebuilt/windows-x86_64/{x264,x265,xvidcore,libvidstab}/`
- FFmpeg install: `prebuilt/windows-x86_64/ffmpeg/` (reconfigured each run)
- Wrapper install: `prebuilt/windows-x86_64/ffmpeg-kit/`
- Bundle: `prebuilt/bundle-windows-x86_64/ffmpeg-kit/{bin,include,lib,pkgconfig}`
  (the bundle's `bin/` also gets the MinGW runtime DLLs:
  `libgcc_s_seh-1.dll`, `libwinpthread-1.dll`, `libstdc++-6.dll`, `zlib1.dll`)
- **Release zip:** `prebuilt/ffmpeg-kit-windows-x86_64-min-gpl-8.0.0.zip`
  (the bundle's `bin/` + `include/`, the layout the plugin consumes)

The GPL codecs are linked **statically** into the `av*` DLLs
(`--pkg-config-flags=--static`), so the min-gpl bundle's `bin/` is just the
`av*`/`swscale`/`swresample`/`libffmpegkit` DLLs plus the MinGW runtime closure —
**no gnutls/gmp/nettle stack** (those aren't linked in min-gpl), so it is much
smaller than the full-gpl bundle.

> ⚠️ The bundle directory `prebuilt/bundle-windows-x86_64/` and the FFmpeg
> install `prebuilt/windows-x86_64/ffmpeg/` are **shared** across variants. Running
> this build overwrites whatever full/full-gpl bundle/ffmpeg was there last. The
> already-zipped artifacts in `prebuilt/*.zip` are not touched. Re-run the matching
> build to regenerate another variant.

## Verify it is genuinely `min-gpl`

```bash
grep FFMPEG_CONFIGURATION prebuilt/windows-x86_64/ffmpeg/include/config.h
# MUST contain:  enable-gpl enable-libx264 enable-libx265 enable-libxvid enable-libvidstab
# MUST NOT contain: enable-gnutls, enable-libfribidi, enable-libspeex
```

(`build-windows-min-gpl.sh` performs exactly these assertions and fails the build
if they don't hold.)

Then point the Flutter plugin at the bundle and run the example — the startup log
must read `Loaded ffmpeg-kit-min-gpl-x86_64-...`, and a GPL codec command such as
`-c:v libx265` must succeed.

## Publishing to GitHub releases

The artifact name and release tag follow the convention baked into the plugin's
`ffmpeg_kit_flutter/windows/CMakeLists.txt` (the `full`-branch convention: the
Windows zip is an **additional asset on the existing per-variant release**,
alongside the iOS/macOS zips — NOT a separate `-windows` tag):

```
FFMPEGKIT_RELEASE_TAG = <version>-<package>            -> 8.0.0-min-gpl   (already exists)
FFMPEGKIT_ZIP_NAME    = ffmpeg-kit-windows-x86_64-<package>-<version>.zip
download URL          = .../releases/download/8.0.0-min-gpl/ffmpeg-kit-windows-x86_64-min-gpl-8.0.0.zip
```

The `8.0.0-min-gpl` release already exists (it carries
`ffmpeg-kit-ios-min-gpl-8.0.0.zip` and `ffmpeg-kit-macos-min-gpl-8.0.0.zip`), so
**upload** the Windows zip to it rather than creating a new release — exactly as
`8.0.0-full` already carries `ffmpeg-kit-windows-x86_64-full-8.0.0.zip`:

```bash
gh release upload 8.0.0-min-gpl \
  prebuilt/ffmpeg-kit-windows-x86_64-min-gpl-8.0.0.zip \
  --repo sk3llo/ffmpeg_kit_flutter --clobber
```

## Wiring it into the Flutter plugin (min-gpl branch)

The plugin's `windows/CMakeLists.txt` is already variant-aware. On the `min-gpl`
branch set the default package to `min-gpl`:

```cmake
set(FFMPEGKIT_PACKAGE "min-gpl" CACHE STRING "FFmpegKit variant")
set(FFMPEGKIT_VERSION "8.0.0"  CACHE STRING "FFmpegKit release version")
```

- **Consume the local build directly** (no upload), e.g.:
  ```
  flutter build windows \
    -- -DFFMPEGKIT_LOCAL_DIR=/c/Users/<you>/StudioProjects/ffmpeg-kit/prebuilt/bundle-windows-x86_64/ffmpeg-kit
  ```
- **Or download from the release** above (leave `FFMPEGKIT_LOCAL_DIR` empty).

The plugin patches the MinGW DLLs (ASLR off + compact rebase) at consume time, so
that step does not need to happen in this repo.

## Status & caveats

- **arch:** x86_64 only (same as full-gpl).
- **Licensing:** `min-gpl` bundles GPLv2/GPLv3 components (x264, x265, xvid,
  vid.stab). Distributing it makes the whole application **GPL**.
