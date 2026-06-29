# Windows build (MSYS2 / MinGW) — FFmpeg 8.1.1

Windows isn't officially supported by ffmpeg-kit; this is a custom path. External
libraries come from **MSYS2 packages** (not built from source). `windows.sh`
builds **FFmpeg 8.1.1 shared DLLs** and then the **FFmpegKit wrapper**
(`libffmpegkit.dll` — the `FFmpegKitConfig`/session API the Flutter plugin calls)
via `scripts/windows-ffmpeg-kit.sh`. Set `SKIP_FFMPEGKIT_WRAPPER=1` to build only
FFmpeg.

## 1. Environment
Install **MSYS2** (https://www.msys2.org/) and open the **“MSYS2 MinGW x64”** shell
(not the plain MSYS shell). Then:

```bash
pacman -Syu                     # update, reopen shell if it asks
pacman -S --needed \
  git make pkgconf \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm
```

## 2. Dependency packages (for `--full` / `--full-gpl`)
```bash
pacman -S --needed \
  mingw-w64-x86_64-lame mingw-w64-x86_64-libvorbis mingw-w64-x86_64-opus \
  mingw-w64-x86_64-libvpx mingw-w64-x86_64-libwebp mingw-w64-x86_64-libtheora \
  mingw-w64-x86_64-libass mingw-w64-x86_64-freetype mingw-w64-x86_64-fribidi \
  mingw-w64-x86_64-fontconfig mingw-w64-x86_64-harfbuzz mingw-w64-x86_64-libxml2 \
  mingw-w64-x86_64-libsoxr mingw-w64-x86_64-speex mingw-w64-x86_64-snappy \
  mingw-w64-x86_64-dav1d mingw-w64-x86_64-aom mingw-w64-x86_64-openjpeg2 \
  mingw-w64-x86_64-zimg mingw-w64-x86_64-twolame mingw-w64-x86_64-opencore-amr \
  mingw-w64-x86_64-vo-amrwbenc mingw-w64-x86_64-openh264 mingw-w64-x86_64-srt \
  mingw-w64-x86_64-SDL2 mingw-w64-x86_64-chromaprint mingw-w64-x86_64-tesseract-ocr \
  mingw-w64-x86_64-gmp mingw-w64-x86_64-gnutls mingw-w64-x86_64-kvazaar \
  mingw-w64-x86_64-libilbc mingw-w64-x86_64-shine
# gmp/gnutls/kvazaar/libilbc/shine complete FFmpegKit's full-gpl signature so the
# runtime reports `full-gpl` (not `custom`). gnutls is the TLS backend for full*
# (it conflicts with --enable-schannel, which is used only for the min variant).
# GPL-only (for --enable-gpl):
pacman -S --needed \
  mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 mingw-w64-x86_64-xvidcore \
  mingw-w64-x86_64-vid.stab mingw-w64-x86_64-rubberband
```
If `configure` later complains a library is missing, `pacman -Ss <name>` to find
the package and install it (or drop the matching `--enable-` from the variant set
in `scripts/main-windows.sh`).

## 3. Build (x86_64 only)
Only x86_64 is wired (MSYS2 ships just the x86_64 mingw toolchain by default), so
`enable_default_windows_architectures` enables x86_64 only — no `--disable-*`
needed (and `--disable-x86` would error, since x86 isn't a supported windows arch):

```bash
cd /path/to/ffmpeg-kit-6.0.LTS
# min:
./windows.sh
# full:
./windows.sh --full
# full-gpl:
./windows.sh --full --enable-gpl
```

## 4. Output
- Per-arch FFmpeg install: `build/windows/x86_64/install/{bin,lib,include}`
  (`bin/*.dll` are the runtime DLLs; `lib/*.dll.a` are import libs).
- Bundled for shipping: `prebuilt/bundle-windows/x86_64/{bin,lib,include}`.

Verify it compiled:
```bash
ls build/windows/x86_64/install/bin/*.dll
build/windows/x86_64/install/bin/avcodec-*.dll  # version in the name (8.1.1 -> avcodec-62)
```

The av* DLLs and `libffmpegkit.dll` link **shared** against the MSYS2 codec DLLs
(libx264-165.dll, libx265-216.dll, libdav1d-7.dll, xvidcore.dll, …) plus the MinGW
runtime. `create_windows_bundle` gathers that full dependency closure (objdump
walk) into `prebuilt/bundle-windows/x86_64/bin/`, so the bundle is **self-contained**
(runs without `/mingw64/bin` on `PATH`).

## Notes
- TLS uses native **SChannel** (no openssl/gnutls dependency on Windows).
- The **FFmpegKit wrapper** (`libffmpegkit.dll`) is built from `windows/src/`
  against the FFmpeg install (internal headers from `src/ffmpeg`, generated
  `config.h` from the out-of-tree FFmpeg build dir). The vendored `fftools_*` were
  ported to the FFmpeg 8.x APIs (frame/stream flag accessors, packet-side-data
  model, removed `ticks_per_frame`/`pkt_size`/`pkt_pos`), the non-local exit uses
  `__builtin_setjmp`/`__builtin_longjmp` (C `longjmp` SEH-unwinds and faults on
  Win64), and `prepare_app_arguments()` is a no-op (it must not replace the
  session's argv with the host process command line).
- x86 / arm64 would need their own mingw cross-toolchains; only x86_64 is wired.
