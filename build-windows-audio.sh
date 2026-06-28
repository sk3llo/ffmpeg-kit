#!/bin/bash
#
# Build the canonical `audio` FFmpegKit for Windows x86_64 and package the
# release zip. Thin wrapper around the integrated build system.
#
# `audio` is the audio-codec set (no GPL): lame, libilbc, libvorbis (pulls
# libogg), opencore-amr, opus, shine, soxr, speex, twolame. Packages::
# getPackageName() classifies this as `audio` (see windows/src/Packages.cpp):
# speex present and fribidi absent -> audio branch, which requires mp3lame &&
# libilbc && libvorbis && opencore-amr && opus && shine && soxr && speex &&
# twolame. (vo-amrwbenc is not required and is unsupported on Windows.)
#
# Run from an MSYS2 MINGW64 shell.  Usage: ./build-windows-audio.sh
#
set -u
export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-8.0.0}"
PACKAGE="audio"
ARCH="x86_64"
ZIP_NAME="ffmpeg-kit-windows-${ARCH}-${PACKAGE}-${FFMPEGKIT_VERSION}.zip"
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"

echo "=== Building FFmpegKit ${PACKAGE} for Windows ${ARCH} ==="
"${BASEDIR}/windows.sh" \
  --enable-lame --enable-libilbc --enable-libvorbis --enable-opencore-amr \
  --enable-opus --enable-shine --enable-soxr --enable-speex --enable-twolame
RC=$?
if [ ${RC} -ne 0 ]; then echo "ERROR: windows.sh failed (rc=${RC}). See build.log."; exit 1; fi

CONFIG_H="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg/include/config.h"
CONF="$(grep -Eo 'FFMPEG_CONFIGURATION "[^"]*"' "${CONFIG_H}" 2>/dev/null)"
echo "FFMPEG_CONFIGURATION: ${CONF}"
for need in enable-libmp3lame enable-libilbc enable-libvorbis enable-libopencore-amr enable-libopus enable-libshine enable-libsoxr enable-libspeex enable-libtwolame; do
  grep -q "${need}" <<<"${CONF}" || { echo "ERROR: expected ${need} missing."; exit 1; }
done
# fribidi present would make it full; gpl/xvid/gnutls would change it too.
for forbidden in enable-gpl enable-libfribidi enable-gnutls enable-libx264; do
  grep -q "${forbidden}" <<<"${CONF}" && { echo "ERROR: unexpected ${forbidden} present."; exit 1; }
done
echo "Config verified as audio."

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
