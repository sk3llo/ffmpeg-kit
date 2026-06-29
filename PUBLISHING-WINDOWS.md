# Windows build (MSYS2 / MinGW) — FFmpeg 8.1.1

Windows isn't officially supported by ffmpeg-kit; this is a custom path. External
libraries come from **MSYS2 packages** (not built from source). This iteration
builds **FFmpeg 8.1.1 shared DLLs**; the FFmpegKit wrapper (`libffmpegkit`) is a
later step once FFmpeg compiles cleanly on your machine.

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
  mingw-w64-x86_64-SDL2 mingw-w64-x86_64-chromaprint mingw-w64-x86_64-tesseract-ocr
# GPL-only (for --enable-gpl):
pacman -S --needed \
  mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 mingw-w64-x86_64-xvidcore \
  mingw-w64-x86_64-libvidstab mingw-w64-x86_64-rubberband
```
If `configure` later complains a library is missing, `pacman -Ss <name>` to find
the package and install it (or drop the matching `--enable-` from the variant set
in `scripts/main-windows.sh`).

## 3. Build (x86_64 only)
The default enables x86 + x86_64 + arm64, but MSYS2 ships only the x86_64
mingw toolchain by default, so scope to x86_64:

```bash
cd /path/to/ffmpeg-kit-6.0.LTS
# min:
./windows.sh --disable-x86 --disable-arm64
# full:
./windows.sh --full --disable-x86 --disable-arm64
# full-gpl:
./windows.sh --full --enable-gpl --disable-x86 --disable-arm64
```

## 4. Output
- Per-arch FFmpeg install: `build/windows/windows-x86_64/install/{bin,lib,include}`
  (`bin/*.dll` are the runtime DLLs; `lib/*.dll.a` are import libs).
- Bundled for shipping: `prebuilt/bundle-windows/windows-x86_64/{bin,lib,include}`.

Verify it compiled:
```bash
ls build/windows/windows-x86_64/install/bin/*.dll
build/windows/windows-x86_64/install/bin/avcodec-*.dll  # version in the name
```

## What to report back
- Whether `configure` succeeds (and any “ERROR: <lib> not found” lines).
- Whether `make` finishes and the `*.dll` files appear.
Paste the tail of `build.log` on failure. Next iteration adds the FFmpegKit
wrapper once FFmpeg itself builds.

## Notes / known gaps
- TLS uses native **SChannel** (no openssl/gnutls dependency on Windows).
- The **FFmpegKit wrapper** (`libffmpegkit`, the `FFmpegKitConfig`/session API the
  Flutter plugin calls) is **not built yet** — this milestone is FFmpeg itself.
- x86 / arm64 would need their own mingw cross-toolchains; only x86_64 is wired.
