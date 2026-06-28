#!/bin/bash
#
# Build the canonical `https` FFmpegKit for Windows x86_64 and package the
# release zip that the Flutter plugin downloads.
#
# Thin, reproducible wrapper around the integrated build system
# (windows.sh -> scripts/main-windows.sh -> scripts/windows/*.sh), the same path
# used by build-windows-min.sh / build-windows-min-gpl.sh / build-windows-full-gpl.sh.
#
# `https` is bare FFmpeg + TLS: gmp + gnutls (gnutls pulls nettle as a build
# dependency, and the framework auto-enables nettle+gmp when gnutls is enabled),
# and no --enable-gpl. With {gmp, gnutls} as the external set
# Packages::getPackageName() classifies the build as `https` (see
# windows/src/Packages.cpp): gnutls present and xvid absent -> https branch,
# which then requires gmp && gnutls.
#
# Run from an MSYS2 MINGW64 shell (C:\msys64\mingw64.exe). gnutls bootstrap needs
# gettext (autopoint) + perl + git in addition to the base toolchain.
#
# Usage:
#   ./build-windows-https.sh
#   FFMPEGKIT_VERSION=8.0.0 ./build-windows-https.sh
#
set -u

export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Release version used only for artifact / release-tag naming. Must match the
# Flutter plugin's FFMPEGKIT_VERSION default (windows/CMakeLists.txt).
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-8.0.0}"
PACKAGE="https"
ARCH="x86_64"

ZIP_NAME="ffmpeg-kit-windows-${ARCH}-${PACKAGE}-${FFMPEGKIT_VERSION}.zip"
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"

echo "=== Building FFmpegKit ${PACKAGE} for Windows ${ARCH} ==="

# gmp + gnutls. Enabling gnutls auto-cascades nettle + gmp (see
# scripts/function.sh set_library), but gmp is passed explicitly to match the
# documented https set. No --enable-gpl. The variant name is an emergent
# property of this set (see Packages.cpp).
"${BASEDIR}/windows.sh" \
  --enable-gmp \
  --enable-gnutls
RC=$?
if [ ${RC} -ne 0 ]; then
  echo "ERROR: windows.sh failed (rc=${RC}). See build.log."
  exit 1
fi

# --- Verify the produced config really is https ---
CONFIG_H="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg/include/config.h"
CONF="$(grep -Eo 'FFMPEG_CONFIGURATION "[^"]*"' "${CONFIG_H}" 2>/dev/null)"
echo "FFMPEG_CONFIGURATION: ${CONF}"
for need in enable-gmp enable-gnutls; do
  if ! grep -q "${need}" <<<"${CONF}"; then
    echo "ERROR: expected ${need} missing from FFmpeg configuration."
    exit 1
  fi
done
# Anything below would push it out of the plain `https` classification.
for forbidden in enable-gpl enable-libx264 enable-libx265 enable-libxvid \
                 enable-libvidstab enable-libspeex enable-libfribidi; do
  if grep -q "${forbidden}" <<<"${CONF}"; then
    echo "ERROR: unexpected ${forbidden} present; this is not a plain https set."
    exit 1
  fi
done
echo "Config verified as https."

# --- Package the release zip: bin/ (runtime DLL closure) + include/ headers ---
if [ ! -d "${BUNDLE_DIR}/bin" ]; then
  echo "ERROR: bundle bin/ not found at ${BUNDLE_DIR}."
  exit 1
fi

rm -f "${ZIP_PATH}"
if command -v zip >/dev/null 2>&1; then
  ( cd "${BUNDLE_DIR}" && zip -r -q "${ZIP_PATH}" bin include )
else
  # No `zip` in this MSYS2 env. CMake is always present (used by the build) and
  # produces a standard zip that the plugin's `cmake -E tar xf` extracts.
  ( cd "${BUNDLE_DIR}" && cmake -E tar cf "${ZIP_PATH}" --format=zip bin include )
fi
if [ $? -ne 0 ] || [ ! -f "${ZIP_PATH}" ]; then
  echo "ERROR: zip creation failed."
  exit 1
fi

RELEASE_TAG="${FFMPEGKIT_VERSION}-${PACKAGE}"   # e.g. 8.0.0-https (shared per-variant release)
echo ""
echo "=== Done ==="
echo "Artifact : ${ZIP_PATH}"
echo "Upload as: ${ZIP_NAME}"
echo "To existing release tag: ${RELEASE_TAG}"
echo ""
echo "Publish (add the Windows zip as an asset on the existing per-variant release,"
echo "alongside the iOS/macOS zips — same convention as 8.0.0-min / 8.0.0-min-gpl):"
echo "  gh release upload ${RELEASE_TAG} \\"
echo "    \"${ZIP_PATH}\" \\"
echo "    --repo sk3llo/ffmpeg_kit_flutter --clobber"
