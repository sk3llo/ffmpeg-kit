#!/bin/bash
#
# Build the canonical `min` FFmpegKit for Windows x86_64 and package the release
# zip that the Flutter plugin downloads.
#
# Thin, reproducible wrapper around the integrated build system
# (windows.sh -> scripts/main-windows.sh -> scripts/windows/*.sh), the same path
# used by build-windows-min-gpl.sh / build-windows-full-gpl.sh.
#
# `min` is the smallest variant: a bare FFmpeg with NO external libraries and no
# --enable-gpl. With an empty external-library set Packages::getPackageName()
# falls through to `return "min"` (see windows/src/Packages.cpp): speex, fribidi,
# xvid and gnutls are all absent, so none of the full/audio/video/https*/min-gpl
# branches match. It is exactly the min-gpl set minus the four GPL libraries.
#
# Run from an MSYS2 MINGW64 shell (C:\msys64\mingw64.exe).
#
# Usage:
#   ./build-windows-min.sh
#   FFMPEGKIT_VERSION=8.0.0 ./build-windows-min.sh
#
set -u

export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Release version used only for artifact / release-tag naming. Must match the
# Flutter plugin's FFMPEGKIT_VERSION default (windows/CMakeLists.txt).
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-8.0.0}"
PACKAGE="min"
ARCH="x86_64"

ZIP_NAME="ffmpeg-kit-windows-${ARCH}-${PACKAGE}-${FFMPEGKIT_VERSION}.zip"
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"

echo "=== Building FFmpegKit ${PACKAGE} for Windows ${ARCH} ==="

# No --enable-* and no --enable-gpl: a bare FFmpeg. The variant name is an
# emergent property of the (empty) external-library set (see Packages.cpp).
"${BASEDIR}/windows.sh"
RC=$?
if [ ${RC} -ne 0 ]; then
  echo "ERROR: windows.sh failed (rc=${RC}). See build.log."
  exit 1
fi

# --- Verify the produced config really is min (no classifying libs, no gpl) ---
CONFIG_H="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg/include/config.h"
CONF="$(grep -Eo 'FFMPEG_CONFIGURATION "[^"]*"' "${CONFIG_H}" 2>/dev/null)"
echo "FFMPEG_CONFIGURATION: ${CONF}"
# None of the variant-classifying flags may be present, or it is not `min`.
for forbidden in enable-gpl enable-libx264 enable-libx265 enable-libxvid \
                 enable-libvidstab enable-gnutls enable-libfribidi enable-libspeex; do
  if grep -q "${forbidden}" <<<"${CONF}"; then
    echo "ERROR: unexpected ${forbidden} present; this is not a bare min set."
    exit 1
  fi
done
echo "Config verified as min."

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

RELEASE_TAG="${FFMPEGKIT_VERSION}-${PACKAGE}"   # e.g. 8.0.0-min (shared per-variant release)
echo ""
echo "=== Done ==="
echo "Artifact : ${ZIP_PATH}"
echo "Upload as: ${ZIP_NAME}"
echo "To existing release tag: ${RELEASE_TAG}"
echo ""
echo "Publish (add the Windows zip as an asset on the existing per-variant release,"
echo "alongside the iOS/macOS zips — same convention as 8.0.0-full / 8.0.0-min-gpl):"
echo "  gh release upload ${RELEASE_TAG} \\"
echo "    \"${ZIP_PATH}\" \\"
echo "    --repo sk3llo/ffmpeg_kit_flutter --clobber"
