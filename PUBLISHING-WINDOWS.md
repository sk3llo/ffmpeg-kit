# Windows build (MSYS2 / MinGW) — FFmpeg 8.1.1 + FFmpegKit wrapper

Windows isn't officially supported by ffmpeg-kit; this is a custom path. External
libraries come from **MSYS2 packages** (not built from source). The build produces
**FFmpeg 8.1.1 shared DLLs AND `libffmpegkit.dll`** (the FFmpegKit wrapper the
Flutter plugin loads at runtime via `LoadLibraryA` + `GetProcAddress` of the
`ffmpegkit_*` C API).

Wrapper sources live in `windows/src/`: the Windows-adapted C++ API + `ffmpegkit_c_api`
(originally ported in the plugin repo's `windows/src`) combined with the FFmpeg
**8.x-correct** `fftools_*` copies shared with `linux/src` (the plugin repo's fftools
were stale pre-7.x sources using removed APIs — do not resync from there).
`windows/Makefile` builds the DLL; `scripts/main-windows.sh` invokes it right after
the FFmpeg install, so `./windows.sh` yields a complete bundle.

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
- Per-arch install: `build/windows/windows-x86_64/install/{bin,lib,include}` —
  `bin/` holds the av* runtime DLLs **and `libffmpegkit.dll`**; `lib/` the import
  libs; `include/ffmpegkit/` the wrapper headers.
- Bundled for shipping: `prebuilt/bundle-windows/windows-x86_64/{bin,lib,include}`.

Verify it compiled:
```bash
ls build/windows/windows-x86_64/install/bin/*.dll        # av* + libffmpegkit.dll
build/windows/windows-x86_64/install/bin/avcodec-*.dll   # version in the name
```

## 5. Package for the plugin
The Flutter plugin's `windows/CMakeLists.txt` downloads
`ffmpeg-kit-windows-x86_64-<variant>-8.1.1.zip` from the `8.1.1-<variant>` release
and expects **`bin/` at the zip root** (it checks `bin/libffmpegkit.dll`). Zip from
inside the bundle dir:
```bash
cd prebuilt/bundle-windows/windows-x86_64
zip -r ../../../ffmpeg-kit-windows-x86_64-full-gpl-8.1.1.zip bin include
gh release upload 8.1.1-full-gpl ../../../ffmpeg-kit-windows-x86_64-full-gpl-8.1.1.zip \
  --repo sk3llo/ffmpeg_kit_flutter --clobber
```

## What to report back
- Whether FFmpeg `configure`/`make` succeed (any “ERROR: <lib> not found” lines).
- Whether the wrapper compiles and `bin/libffmpegkit.dll` appears — compile/link
  errors from `windows/src` are expected on the first Windows run (this port was
  assembled and symbol-checked on macOS but cannot be compiled there); paste them
  and they'll be fixed quickly.

## Notes
- TLS uses native **SChannel** (no openssl/gnutls dependency on Windows).
- x86 / arm64 would need their own mingw cross-toolchains; only x86_64 is wired.
- The wrapper links the FFmpeg import libs from this build and keeps libgcc/libstdc++
  static so no extra MinGW runtime DLLs are required beyond what FFmpeg needs.
