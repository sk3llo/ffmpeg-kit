#!/bin/bash
#
# main-windows.sh — per-architecture FFmpeg build for Windows (MSYS2/MinGW).
#
# Invoked by windows.sh ONCE PER ENABLED ARCH via:  . scripts/main-windows.sh "${ENABLED_LIBRARIES[@]}"
# windows.sh has already exported, for the current arch:
#   ARCH        x86 | x86_64 | arm64
#   FULL_ARCH   windows-x86 | windows-x86_64 | windows-arm64
#   HOST        i686-w64-mingw32 | x86_64-w64-mingw32 | aarch64-w64-mingw32
#   CROSS_PREFIX "${HOST}-"
#   BUILD_DIR   build/windows/${FULL_ARCH}
# and the build-wide flags GPL_ENABLED (yes/no) and BUILD_FULL (1 when --full).
#
# DEPENDENCY MODEL: external libraries come from MSYS2 packages (pacman), NOT from
# source. pkg-config (PKG_CONFIG_PATH=/mingw64/lib/pkgconfig, set by windows.sh)
# resolves them. Install the deps once with the pacman list in PUBLISHING-WINDOWS.md.
#
# This script builds FFmpeg 8.1.1 shared DLLs only. The FFmpegKit wrapper
# (libffmpegkit) is built in a later step once FFmpeg compiles cleanly.

set -e

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# windows.sh sources us in its own shell, so ARCH/HOST/BUILD_DIR are inherited.
# Guard against being run standalone.
if [ -z "${ARCH}" ] || [ -z "${HOST}" ] || [ -z "${BUILD_DIR}" ]; then
  echo "ERROR: main-windows.sh must be invoked from windows.sh (ARCH/HOST/BUILD_DIR unset)."
  exit 1
fi

FFMPEG_SRC="${BASEDIR}/src/ffmpeg"
FFMPEG_PREFIX="${BUILD_DIR}/install"
[ -d "${FFMPEG_SRC}" ] || { echo "ERROR: FFmpeg source not found at ${FFMPEG_SRC} (run the download step)."; exit 1; }

echo "Building FFmpeg for ${FULL_ARCH:-$ARCH} (host=${HOST})..."

# ---------------------------------------------------------------------------
# Variant-aware enable list. Windows only ships min / full / full-gpl, selected
# by BUILD_FULL + GPL_ENABLED. External libs below must exist as MSYS2 packages
# (mingw-w64-${MINGW_PKG_ARCH}-<name>); FFmpeg's configure will name any missing
# one so you can `pacman -S` it. TLS uses native SChannel (no openssl/gnutls dep).
# ---------------------------------------------------------------------------
FF_ENABLES=""

# Always-on, dependency-free (system / native Windows) features.
FF_ENABLES+=" --enable-zlib --enable-bzlib --enable-iconv --enable-schannel"
FF_ENABLES+=" --enable-mediafoundation --enable-d3d11va --enable-dxva2"

if [ -n "${BUILD_FULL}" ]; then
  # 'full' external set — all available from MSYS2 mingw-w64 packages.
  FF_ENABLES+=" --enable-libmp3lame --enable-libvorbis --enable-libopus"
  FF_ENABLES+=" --enable-libvpx --enable-libwebp --enable-libtheora"
  FF_ENABLES+=" --enable-libass --enable-libfreetype --enable-libfribidi --enable-libfontconfig --enable-libharfbuzz"
  FF_ENABLES+=" --enable-libxml2 --enable-libsoxr --enable-libspeex --enable-libsnappy"
  FF_ENABLES+=" --enable-libdav1d --enable-libaom --enable-libopenjpeg --enable-libzimg"
  FF_ENABLES+=" --enable-libtwolame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc"
  FF_ENABLES+=" --enable-libopenh264 --enable-libsrt --enable-sdl2 --enable-chromaprint --enable-libtesseract"
fi

if [ "${GPL_ENABLED}" == "yes" ]; then
  # GPL-only libraries (require --enable-gpl).
  FF_ENABLES+=" --enable-gpl --enable-version3"
  FF_ENABLES+=" --enable-libx264 --enable-libx265 --enable-libxvid --enable-libvidstab --enable-librubberband"
fi

# ---------------------------------------------------------------------------
# Configure + build. Out-of-tree build so each arch is isolated.
# ---------------------------------------------------------------------------
mkdir -p "${BUILD_DIR}/ffmpeg-build"
cd "${BUILD_DIR}/ffmpeg-build"

"${FFMPEG_SRC}/configure" \
  --prefix="${FFMPEG_PREFIX}" \
  --arch="${ARCH}" \
  --target-os=mingw32 \
  --cc="${CROSS_PREFIX}gcc" \
  --cxx="${CROSS_PREFIX}g++" \
  --ar=ar \
  --nm=nm \
  --ranlib=ranlib \
  --strip=strip \
  --windres=windres \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --enable-cross-compile \
  --disable-static \
  --enable-shared \
  --enable-pic \
  --enable-w32threads \
  --enable-small \
  --disable-debug \
  --disable-programs \
  --disable-doc \
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  ${FF_ENABLES}

make -j"$(nproc)"
make install

cd - > /dev/null

echo "FFmpeg for ${FULL_ARCH:-$ARCH} installed to ${FFMPEG_PREFIX}"
echo "NOTE: FFmpegKit wrapper (libffmpegkit) build is a separate step — see PUBLISHING-WINDOWS.md."
