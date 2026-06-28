# Building canonical `full-gpl` FFmpegKit for Windows (MSYS2 / MinGW-w64)

This documents how to build a **true `full-gpl`** FFmpegKit for Windows x86_64 —
one that `Packages::getPackageName()` classifies as `full-gpl` (all 27 external
libraries, GPL components enabled) — using the **integrated build system**
(`windows.sh` → `scripts/main-windows.sh` → `scripts/windows/*.sh`), the same
structure used for android/apple/linux.

> The standalone `build-windows-full-gpl.sh` (a one-off MSYS2/pacman scaffold)
> is **superseded** by this integrated path and kept only for reference.

## Why this exists

The previously published Windows artifacts (`8.0.0-full`, `8.0.0-full-gpl`) were a
**reduced custom configuration**:

```
--enable-gpl --enable-version3 --enable-libx264 --enable-libaom --enable-libdav1d
--enable-libopenh264 --enable-libkvazaar --enable-libilbc --enable-libzimg
--enable-openssl --enable-libsrt
```

That set is missing most of the libraries the detector requires, so even the
`full-gpl`-labelled zip self-reports as **`min`** at runtime (see
`windows/src/Packages.cpp` → falls through to `return "min";`). Building the
complete set below makes the package genuinely `full-gpl`.

## The canonical `full-gpl` library set (27)

Each is built from source by a `scripts/windows/<lib>.sh` script and enabled in
FFmpeg by `scripts/windows/ffmpeg.sh`. `Packages.cpp` detects each by scanning
`FFMPEG_CONFIGURATION` for `enable-<lib>` / `enable-lib<lib>`.

| FFmpegKit lib | build script | FFmpeg flag | GPL |
|---|---|---|---|
| x264 | `x264.sh` | `--enable-libx264` | ✅ |
| x265 | `x265.sh` | `--enable-libx265` | ✅ |
| xvid | `xvidcore.sh` | `--enable-libxvid` | ✅ |
| libvidstab | `libvidstab.sh` | `--enable-libvidstab` | ✅ |
| dav1d | `dav1d.sh` | `--enable-libdav1d` | |
| kvazaar | `kvazaar.sh` | `--enable-libkvazaar` | |
| libvpx | `libvpx.sh` | `--enable-libvpx` | |
| libwebp | `libwebp.sh` | `--enable-libwebp` | |
| libtheora | `libtheora.sh` | `--enable-libtheora` | |
| fontconfig | `fontconfig.sh` | `--enable-libfontconfig` | |
| freetype | `freetype.sh` | `--enable-libfreetype` | |
| fribidi | `fribidi.sh` | `--enable-libfribidi` | |
| libass | `libass.sh` | `--enable-libass` | |
| libxml2 | `libxml2.sh` | `--enable-libxml2` | |
| gmp | `gmp.sh` | `--enable-gmp` | |
| gnutls | `gnutls.sh` | `--enable-gnutls` | |
| iconv | `libiconv.sh` | `--enable-iconv` | |
| mp3lame | `lame.sh` | `--enable-libmp3lame` | |
| opus | `opus.sh` | `--enable-libopus` | |
| libvorbis | `libvorbis.sh` | `--enable-libvorbis` | |
| speex | `speex.sh` | `--enable-libspeex` | |
| twolame | `twolame.sh` | `--enable-libtwolame` | |
| shine | `shine.sh` | `--enable-libshine` | |
| snappy | `snappy.sh` | `--enable-libsnappy` | |
| soxr | `soxr.sh` | `--enable-libsoxr` | |
| opencore-amr | `opencore-amr.sh` | `--enable-libopencore-amrnb --enable-libopencore-amrwb` | |
| libilbc | `libilbc.sh` | `--enable-libilbc` | |

`libaom` is also built/enabled (`libaom.sh`, AV1 encode) as a useful extra; extras
do not affect the `full-gpl` classification.

### Dependency-only libraries (not FFmpeg-enabled directly)

These are built because the libraries above need them; they get **no** FFmpeg
`--enable-*` flag. `scripts/main-windows.sh` gates build order so dependencies
finish first:

| dep | build script | required by |
|---|---|---|
| libogg | `libogg.sh` | libvorbis, libtheora |
| libpng | `libpng.sh` | freetype |
| harfbuzz | `harfbuzz.sh` (meson) | libass (via freetype/text shaping) |
| expat | `expat.sh` | fontconfig |
| nettle | `nettle.sh` | gnutls |

Build-order chain enforced in `main-windows.sh`:
`gmp → nettle → gnutls`, `libpng → freetype → harfbuzz`,
`{freetype, expat, libiconv} → fontconfig`,
`{freetype, fribidi, harfbuzz, fontconfig} → libass`,
`libogg → libvorbis → libtheora`, `libiconv → libxml2`.

## Prerequisites

1. **MSYS2** installed (this machine: `C:\msys64`).
2. Run from an **MSYS2 MINGW64** shell (`C:\msys64\mingw64.exe`), not cmd/PowerShell.
   In MINGW64 the build is effectively *native* (the produced x86_64 binaries run
   during the build, e.g. fontconfig's `fc-cache`).
3. First-time only: `pacman -Syu` (then reopen the shell), then install the
   toolchain + build tools the source builds need:

```bash
pacman -S --needed \
  git make diffutils perl gettext-devel autoconf automake libtool pkgconf \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-meson \
  mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm mingw-w64-x86_64-gperf
```

Why these matter for specific libs:
- **meson + ninja** — `dav1d`, `harfbuzz`
- **nasm** — `x264`, `x265`, `openh264`, `libvpx` (MSYS2's yasm 1.3.0 cannot
  assemble AVX-512, so libvpx uses nasm)
- **gperf** — `fontconfig` (`fcobjshash.h` generation)
- **gettext (autopoint) + perl + git** — `gnutls` `./bootstrap`

## Build

```bash
cd /c/Users/<you>/StudioProjects/ffmpeg-kit
./windows.sh --full --enable-gpl
```

- `--full` enables every external library; `--enable-gpl` is required to include
  the GPL components (x264, x265, xvid, vid.stab). Without `--enable-gpl` the same
  command yields a (non-GPL) `full` build instead.
- To build a single variant instead, pass an explicit subset, e.g.
  `--enable-gnutls --enable-gmp` (https) or `--enable-x264 --enable-x265
  --enable-xvidcore --enable-libvidstab --enable-gpl` (min-gpl). The variant name
  is an emergent property of the enabled library set — see `Packages.cpp`. When
  building a subset, remember to also enable each library's dependencies from the
  table above (`--full` does this automatically).

Full output is appended to `build.log`.

Outputs:
- Per-library installs: `prebuilt/windows-x86_64/<lib>/`
- FFmpeg install: `prebuilt/windows-x86_64/ffmpeg/`
- Wrapper install: `prebuilt/windows-x86_64/ffmpeg-kit/`
- Bundle: `prebuilt/bundle-windows-x86_64/ffmpeg-kit/{bin,include,lib,pkgconfig}`
  (the bundle's `bin/` also gets the MinGW runtime DLLs: `libgcc_s_seh-1.dll`,
  `libwinpthread-1.dll`, `libstdc++-6.dll`, `zlib1.dll`)

External codecs are linked **statically** (`--pkg-config-flags=--static`) into the
`av*` DLLs, so the bundle keeps the same shape as the released one (no per-codec
sidecar DLLs).

## Verify it is genuinely `full-gpl`

```bash
grep FFMPEG_CONFIGURATION prebuilt/windows-x86_64/ffmpeg/include/config.h
# must contain enable-gpl, enable-libx264, enable-libx265, enable-libxvid,
# enable-libvidstab, enable-libass, enable-gnutls, enable-libvorbis, ... (all 27)
```

Then point the Flutter plugin at the bundle and run the example — the startup log
must read `Loaded ffmpeg-kit-full-gpl-x86_64-...` (not `-min-`), and a GPL codec
command such as `-c:v libx265` must succeed.

## Wiring it into the Flutter plugin

The plugin's `ffmpeg_kit_flutter/windows/CMakeLists.txt` is already variant-aware:

- **Consume the local build directly** (no upload):
  ```
  flutter build windows \
    --dart-define= ... \
    -- -DFFMPEGKIT_LOCAL_DIR=/c/Users/<you>/StudioProjects/ffmpeg-kit/prebuilt/bundle-windows-x86_64/ffmpeg-kit
  ```
  (or set `FFMPEGKIT_LOCAL_DIR` in the CMake cache). It copies `bin/` (+ `include/`)
  and records a marker so changing the variant triggers a clean re-fetch.
- **Or download from a release**: leave `FFMPEGKIT_LOCAL_DIR` empty and set
  `FFMPEGKIT_PACKAGE=full-gpl` / `FFMPEGKIT_VERSION=8.0.0` (the defaults). Upload the
  zip as `ffmpeg-kit-windows-x86_64-full-gpl-<version>.zip` to the matching release
  tag `<version>-full-gpl`.

The plugin patches the MinGW DLLs (ASLR off + compact rebase) at consume time, so
that step does not need to happen in this repo.

## Status & caveats

- **Not yet run end-to-end here.** A full build is long (27 libs + FFmpeg + LTO).
  Highest-risk scripts on a first run:
  - **gnutls** — `./bootstrap` pulls gnulib and needs gettext/perl/git; it links
    the locally-built nettle+gmp. If configure fails on gmp/nettle, check the
    `NETTLE_*`/`HOGWEED_*`/`GMP_*` and `CPPFLAGS`/`LDFLAGS` exports in `gnutls.sh`.
  - **fontconfig** — needs `gperf`; built with autotools to match the other
    platforms at the pinned 2.17.1. If the source tag turns out to be **meson-only**
    (no `configure`), convert `fontconfig.sh` to meson the same way `harfbuzz.sh`
    was.
  - **libvpx** — uses nasm and the native `x86_64-win64-gcc` target.
  - **freetype ↔ harfbuzz ↔ libass** ordering — handled by the gating in
    `main-windows.sh`; freetype is built `--without-harfbuzz` (single pass) to avoid
    the dependency cycle.
- **Partial-variant builds** must include each enabled library's dependencies, or
  the dependency-gated `while` loop in `main-windows.sh` cannot make progress
  (same constraint as the existing `srt` → `openssl` gate). `--full` enables
  everything, so it is unaffected.
- **arch:** x86_64 only. x86/arm64 would follow the same pattern with the matching
  MinGW environment and target triples.
- **Licensing:** `full-gpl` bundles GPLv2/GPLv3 components (x264, x265, xvid,
  vid.stab). Distributing it makes the whole application **GPL**. Ensure that is
  intended and documented for downstream consumers.
