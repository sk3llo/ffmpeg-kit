# Building canonical `https` FFmpegKit for Windows (MSYS2 / MinGW-w64)

This documents how to build a **true `https`** FFmpegKit for Windows x86_64 — one
that `Packages::getPackageName()` classifies as `https` — using the **integrated
build system** (`windows.sh` → `scripts/main-windows.sh` → `scripts/windows/*.sh`),
the same path used by the `min`, `min-gpl` and `full-gpl` builds.

It produces the release artifact the Flutter plugin downloads:
`ffmpeg-kit-windows-x86_64-https-8.0.0.zip`.

## What `https` is

`https` is bare FFmpeg + TLS — the **`gmp` + `gnutls`** pair, and nothing else
(no GPL). It is the `min` set plus the gnutls TLS stack, enabling `https://` and
other TLS network protocols.

| FFmpegKit lib | build script | FFmpeg flag | role |
|---|---|---|---|
| gmp | `gmp.sh` | `--enable-gmp` | bignum (gnutls dep) |
| nettle | `nettle.sh` | *(none)* | crypto (gnutls dep, auto-enabled) |
| gnutls | `gnutls.sh` | `--enable-gnutls` | TLS backend |

### Why exactly this set

`windows/src/Packages.cpp` derives the variant from the enabled-library set
scanned out of `FFMPEG_CONFIGURATION`:

1. `speex`, `fribidi`, `xvid` all absent → not full/audio/video/*-gpl.
2. `gnutls` present (and `xvid` absent) → `https` branch.
3. `https` then requires `gmp && gnutls` → returns `https`.

`nettle` is a build dependency of gnutls; it carries no FFmpeg `--enable-*` flag
and does not affect classification. The framework auto-enables `nettle` (and
`gmp`) whenever `gnutls` is enabled (`scripts/function.sh` `set_library`), so
even `--enable-gnutls` alone yields the full {gmp, nettle, gnutls} build; the
wrapper passes `--enable-gmp` explicitly to match the documented set.

## Prerequisites

MSYS2 MINGW64 toolchain. gnutls's `./bootstrap` pulls gnulib and needs
gettext (autopoint) + perl + git on top of the base toolchain:

```bash
pacman -S --needed git make diffutils perl gettext-devel autoconf automake libtool pkgconf \
  mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm
```

## Build

```bash
cd /c/Users/<you>/StudioProjects/ffmpeg-kit
./build-windows-https.sh
```

It runs the integrated build with the https set, verifies the produced
`FFMPEG_CONFIGURATION`, and packages the zip. Equivalent manual invocation:

```bash
./windows.sh --enable-gmp --enable-gnutls
```

Full output is appended to `build.log`.

Outputs:
- Per-library installs: `prebuilt/windows-x86_64/{gmp,nettle,gnutls}/`
- FFmpeg install: `prebuilt/windows-x86_64/ffmpeg/` (reconfigured each run)
- Wrapper install: `prebuilt/windows-x86_64/ffmpeg-kit/`
- Bundle: `prebuilt/bundle-windows-x86_64/ffmpeg-kit/{bin,include,lib,pkgconfig}`
- **Release zip:** `prebuilt/ffmpeg-kit-windows-x86_64-https-8.0.0.zip`
  (the bundle's `bin/` + `include/`)

Unlike the codec variants (x264/x265/… linked statically into the av* DLLs), the
gnutls stack resolves as **shared** imports, so the bundle's `bin/` additionally
carries the gnutls runtime closure (`libgnutls-30`, `libgmp-10`,
`libnettle/hogweed`, `libtasn1`, `libidn2`, `libp11-kit`, `libunistring`,
`libffi`, `libbrotli*`, `libzstd`, `libiconv-2`, `libintl-8`, …). The bundle step
resolves this closure automatically with objdump.

> ⚠️ The bundle directory `prebuilt/bundle-windows-x86_64/` and the FFmpeg
> install `prebuilt/windows-x86_64/ffmpeg/` are **shared** across variants.
> Running this overwrites whatever variant was built there last. The already-zipped
> artifacts in `prebuilt/*.zip` are not touched.

## Verify it is genuinely `https`

```bash
grep FFMPEG_CONFIGURATION prebuilt/windows-x86_64/ffmpeg/include/config.h
# MUST contain:     enable-gmp enable-gnutls
# MUST NOT contain: enable-gpl, enable-libx264/x265/xvid/vidstab,
#                   enable-libspeex, enable-libfribidi
```

(`build-windows-https.sh` performs these assertions and fails the build otherwise.)

The example app's startup log must read `Loaded ffmpeg-kit-https-x86_64-...`, and a
TLS command (e.g. probing an `https://` URL) must succeed.

## Publishing to GitHub releases

Same convention as the other variants: the Windows zip is an **additional asset
on the existing per-variant release** (`8.0.0-https`), alongside the iOS/macOS zips.

```
FFMPEGKIT_RELEASE_TAG = <version>-<package>            -> 8.0.0-https   (already exists)
FFMPEGKIT_ZIP_NAME    = ffmpeg-kit-windows-x86_64-<package>-<version>.zip
download URL          = .../releases/download/8.0.0-https/ffmpeg-kit-windows-x86_64-https-8.0.0.zip
```

```bash
gh release upload 8.0.0-https \
  prebuilt/ffmpeg-kit-windows-x86_64-https-8.0.0.zip \
  --repo sk3llo/ffmpeg_kit_flutter --clobber
```

## Wiring it into the Flutter plugin (https branch)

`windows/CMakeLists.txt` on the `https` branch sets:

```cmake
set(FFMPEGKIT_PACKAGE "https" CACHE STRING "FFmpegKit variant")
set(FFMPEGKIT_VERSION "8.0.0" CACHE STRING "FFmpegKit release version")
```

Consume a local build with `-DFFMPEGKIT_LOCAL_DIR=.../bundle-windows-x86_64/ffmpeg-kit`,
or leave it empty to download from the release above.

## Status & caveats

- **arch:** x86_64 only.
- **Licensing:** `https` contains no GPL components — it stays under FFmpegKit's
  default LGPL 3.0.
