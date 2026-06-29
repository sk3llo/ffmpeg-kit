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
# Variant-aware enable list. The enabled external-library set determines the
# variant FFmpegKit's Packages::getPackageName() reports (windows/src/Packages.cpp).
# Select with FFMPEGKIT_VARIANT (min|min-gpl|https|https-gpl|audio|video|full|
# full-gpl); if unset it is derived from --full / --enable-gpl (back-compat:
# nothing=min, --full=full, --full --enable-gpl=full-gpl). All libs below are
# MSYS2 packages (see PUBLISHING-WINDOWS.md). NOTE: FFmpeg rejects --enable-gnutls
# together with --enable-schannel, so gnutls-bearing variants (https*, full*) use
# gnutls as the TLS backend and the others use native SChannel.
# ---------------------------------------------------------------------------
FF_ENABLES=" --enable-zlib --enable-bzlib --enable-iconv --enable-mediafoundation --enable-d3d11va --enable-dxva2"

# Reusable groups (the canonical per-variant signatures).
# --enable-version3 is required by gmp (TLS) and opencore-amr/vo-amrwbenc (audio):
# those are (L)GPLv3 and FFmpeg refuses them under plain --enable-version2. It is
# harmless where unused and does not affect the variant classification.
_GPL=" --enable-gpl --enable-version3 --enable-libx264 --enable-libx265 --enable-libxvid --enable-libvidstab --enable-librubberband"
_TLS=" --enable-version3 --enable-gmp --enable-gnutls"
_AUDIO=" --enable-version3 --enable-libmp3lame --enable-libilbc --enable-libvorbis --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libvo-amrwbenc --enable-libopus --enable-libshine --enable-libsoxr --enable-libspeex --enable-libtwolame"
_VIDEO=" --enable-libdav1d --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libkvazaar --enable-libass --enable-libtheora --enable-libvpx --enable-libwebp --enable-libsnappy --enable-libzimg"
_FULLEXTRA=" --enable-libxml2 --enable-libaom --enable-libopenh264 --enable-libopenjpeg --enable-libsrt --enable-sdl2 --enable-chromaprint --enable-libtesseract --enable-libharfbuzz"
_SCHANNEL=" --enable-schannel"

VARIANT="${FFMPEGKIT_VARIANT:-}"
if [ -z "${VARIANT}" ]; then
  if [ -n "${BUILD_FULL}" ] && [ "${GPL_ENABLED}" == "yes" ]; then VARIANT="full-gpl"
  elif [ -n "${BUILD_FULL}" ]; then VARIANT="full"
  else VARIANT="min"; fi
fi
echo "FFmpegKit variant: ${VARIANT}"

case "${VARIANT}" in
  min)        FF_ENABLES+="${_SCHANNEL}" ;;
  min-gpl)    FF_ENABLES+="${_SCHANNEL}${_GPL}" ;;
  https)      FF_ENABLES+="${_TLS}" ;;
  https-gpl)  FF_ENABLES+="${_TLS}${_GPL}" ;;
  audio)      FF_ENABLES+="${_SCHANNEL}${_AUDIO}" ;;
  video)      FF_ENABLES+="${_SCHANNEL}${_VIDEO}" ;;
  full)       FF_ENABLES+="${_TLS}${_AUDIO}${_VIDEO}${_FULLEXTRA}" ;;
  full-gpl)   FF_ENABLES+="${_TLS}${_AUDIO}${_VIDEO}${_FULLEXTRA}${_GPL}" ;;
  *) echo "ERROR: unknown FFMPEGKIT_VARIANT '${VARIANT}'." >&2; exit 1 ;;
esac

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

# Build the FFmpegKit wrapper (libffmpegkit) against the FFmpeg install just
# produced, unless explicitly skipped. It is installed alongside FFmpeg in
# ${FFMPEG_PREFIX} so create_windows_bundle picks it up.
if [ "${SKIP_FFMPEGKIT_WRAPPER:-0}" != "1" ] && [ -d "${BASEDIR}/windows/src" ]; then
  export ARCH CROSS_PREFIX BUILD_DIR FFMPEG_PREFIX BASEDIR
  if ! bash "${BASEDIR}/scripts/windows-ffmpeg-kit.sh"; then
    echo "ERROR: FFmpegKit wrapper build failed for ${FULL_ARCH:-$ARCH}." >&2
    exit 1
  fi
else
  echo "NOTE: skipping FFmpegKit wrapper (SKIP_FFMPEGKIT_WRAPPER=1 or windows/src missing)."
fi
