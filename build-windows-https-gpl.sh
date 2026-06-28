#!/bin/bash
#
# Build the canonical `https-gpl` FFmpegKit for Windows x86_64 and package the
# release zip. Thin wrapper around the integrated build system, same pattern as
# build-windows-https.sh / build-windows-min-gpl.sh.
#
# `https-gpl` = https + the four GPL video libraries: gmp + gnutls (TLS) plus
# x264, x265, xvid, vid.stab, with --enable-gpl. Packages::getPackageName()
# classifies this as `https-gpl` (see windows/src/Packages.cpp): xvid present and
# gnutls present -> httpsGpl branch, which requires gmp && gnutls && libvidstab &&
# x264 && x265 && xvid.
#
# Run from an MSYS2 MINGW64 shell.  Usage: ./build-windows-https-gpl.sh
#
set -u
export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-8.0.0}"
PACKAGE="https-gpl"
ARCH="x86_64"
ZIP_NAME="ffmpeg-kit-windows-${ARCH}-${PACKAGE}-${FFMPEGKIT_VERSION}.zip"
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"

echo "=== Building FFmpegKit ${PACKAGE} for Windows ${ARCH} ==="
"${BASEDIR}/windows.sh" \
  --enable-gmp --enable-gnutls \
  --enable-x264 --enable-x265 --enable-xvidcore --enable-libvidstab \
  --enable-gpl
RC=$?
if [ ${RC} -ne 0 ]; then echo "ERROR: windows.sh failed (rc=${RC}). See build.log."; exit 1; fi

CONFIG_H="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg/include/config.h"
CONF="$(grep -Eo 'FFMPEG_CONFIGURATION "[^"]*"' "${CONFIG_H}" 2>/dev/null)"
echo "FFMPEG_CONFIGURATION: ${CONF}"
for need in enable-gpl enable-gmp enable-gnutls enable-libx264 enable-libx265 enable-libxvid enable-libvidstab; do
  grep -q "${need}" <<<"${CONF}" || { echo "ERROR: expected ${need} missing."; exit 1; }
done
for forbidden in enable-libspeex enable-libfribidi; do
  grep -q "${forbidden}" <<<"${CONF}" && { echo "ERROR: unexpected ${forbidden} present."; exit 1; }
done
echo "Config verified as https-gpl."

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
