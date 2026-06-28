#!/bin/bash
#
# Build the canonical `video` FFmpegKit for Windows x86_64 and package the
# release zip. Thin wrapper around the integrated build system.
#
# `video` is the video-codec set (no GPL): dav1d, fontconfig, freetype, fribidi,
# kvazaar, libass, iconv, libtheora, libvpx, libwebp, snappy. Enabling libass
# cascades freetype+fribidi+fontconfig+harfbuzz+iconv; libtheora cascades
# libogg+libvorbis; fontconfig cascades expat; freetype cascades libpng.
# Packages::getPackageName() classifies this as `video` (see Packages.cpp):
# fribidi present and speex absent -> video branch, which requires dav1d &&
# fontconfig && freetype && fribidi && kvazaar && libass && iconv && libtheora &&
# libvpx && libwebp && snappy.
#
# Run from an MSYS2 MINGW64 shell.  Usage: ./build-windows-video.sh
#
set -u
export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-8.0.0}"
PACKAGE="video"
ARCH="x86_64"
ZIP_NAME="ffmpeg-kit-windows-${ARCH}-${PACKAGE}-${FFMPEGKIT_VERSION}.zip"
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"

echo "=== Building FFmpegKit ${PACKAGE} for Windows ${ARCH} ==="
"${BASEDIR}/windows.sh" \
  --enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi \
  --enable-kvazaar --enable-libass --enable-libiconv --enable-libtheora \
  --enable-libvpx --enable-libwebp --enable-snappy
RC=$?
if [ ${RC} -ne 0 ]; then echo "ERROR: windows.sh failed (rc=${RC}). See build.log."; exit 1; fi

CONFIG_H="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg/include/config.h"
CONF="$(grep -Eo 'FFMPEG_CONFIGURATION "[^"]*"' "${CONFIG_H}" 2>/dev/null)"
echo "FFMPEG_CONFIGURATION: ${CONF}"
for need in enable-libdav1d enable-libfontconfig enable-libfreetype enable-libfribidi enable-libkvazaar enable-libass enable-iconv enable-libtheora enable-libvpx enable-libwebp enable-libsnappy; do
  grep -q "${need}" <<<"${CONF}" || { echo "ERROR: expected ${need} missing."; exit 1; }
done
# speex present would make it full; gpl/gnutls/xvid would change it too.
for forbidden in enable-gpl enable-libspeex enable-gnutls enable-libx264; do
  grep -q "${forbidden}" <<<"${CONF}" && { echo "ERROR: unexpected ${forbidden} present."; exit 1; }
done
echo "Config verified as video."

[ -d "${BUNDLE_DIR}/bin" ] || { echo "ERROR: bundle bin/ not found."; exit 1; }
rm -f "${ZIP_PATH}"
if command -v zip >/dev/null 2>&1; then ( cd "${BUNDLE_DIR}" && zip -r -q "${ZIP_PATH}" bin include )
else ( cd "${BUNDLE_DIR}" && cmake -E tar cf "${ZIP_PATH}" --format=zip bin include ); fi
[ $? -eq 0 ] && [ -f "${ZIP_PATH}" ] || { echo "ERROR: zip creation failed."; exit 1; }

echo ""
echo "=== Done ==="
echo "Artifact : ${ZIP_PATH}"
echo "Upload as: ${ZIP_NAME}  -> release tag ${FFMPEGKIT_VERSION}-${PACKAGE}"
echo "  gh release upload ${FFMPEGKIT_VERSION}-${PACKAGE} \"${ZIP_PATH}\" --repo sk3llo/ffmpeg_kit_flutter --clobber"
