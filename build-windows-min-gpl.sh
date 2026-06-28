#!/bin/bash
#
# Build the canonical `min-gpl` FFmpegKit for Windows x86_64 and package the
# release zip that the Flutter plugin downloads.
#
# This is a thin, reproducible wrapper around the integrated build system
# (windows.sh -> scripts/main-windows.sh -> scripts/windows/*.sh), exactly the
# same path documented for full-gpl in BUILD-WINDOWS-FULL-GPL.md.
#
# `min-gpl` is the smallest GPL variant: the four GPL video libraries
#   x264, x265, xvid (xvidcore), vid.stab (libvidstab)
# plus --enable-gpl, and NOTHING else. With this exact set
# Packages::getPackageName() classifies the build as `min-gpl`
# (see windows/src/Packages.cpp): it needs xvid present and gnutls absent
# (=> minGpl branch) and then requires libvidstab + x264 + x265 + xvid.
#
# None of the four libraries pull external dependencies, so unlike a partial
# `full` subset no extra --enable-* deps are required.
#
# Run from an MSYS2 MINGW64 shell (C:\msys64\mingw64.exe). Prereqs are the same
# as BUILD-WINDOWS-FULL-GPL.md (toolchain + nasm; x264/x265 use nasm).
#
# Usage:
#   ./build-windows-min-gpl.sh            # build + package
#   FFMPEGKIT_VERSION=8.0.0 ./build-windows-min-gpl.sh
#
set -u

export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Release version used only for the artifact / release-tag naming. Must match the
# Flutter plugin's FFMPEGKIT_VERSION default (windows/CMakeLists.txt) so the
# generated download URL resolves. This is the FFmpeg major version line (8.0),
# not get_ffmpeg_kit_version().
FFMPEGKIT_VERSION="${FFMPEGKIT_VERSION:-8.0.0}"
PACKAGE="min-gpl"
ARCH="x86_64"

ZIP_NAME="ffmpeg-kit-windows-${ARCH}-${PACKAGE}-${FFMPEGKIT_VERSION}.zip"
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"

echo "=== Building FFmpegKit ${PACKAGE} for Windows ${ARCH} ==="

# The min-gpl library set. The variant name is an emergent property of this set
# (see Packages.cpp); do not add unrelated libraries or it stops being min-gpl.
"${BASEDIR}/windows.sh" \
  --enable-x264 \
  --enable-x265 \
  --enable-xvidcore \
  --enable-libvidstab \
  --enable-gpl
RC=$?
if [ ${RC} -ne 0 ]; then
  echo "ERROR: windows.sh failed (rc=${RC}). See build.log."
  exit 1
fi

# --- Verify the produced config really is min-gpl ---
CONFIG_H="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg/include/config.h"
CONF="$(grep -Eo 'FFMPEG_CONFIGURATION "[^"]*"' "${CONFIG_H}" 2>/dev/null)"
echo "FFMPEG_CONFIGURATION: ${CONF}"
for need in enable-gpl enable-libx264 enable-libx265 enable-libxvid enable-libvidstab; do
  if ! grep -q "${need}" <<<"${CONF}"; then
    echo "ERROR: expected ${need} missing from FFmpeg configuration."
    exit 1
  fi
done
# gnutls / fribidi / speex must be ABSENT or the detector reports another variant.
for forbidden in enable-gnutls enable-libfribidi enable-libspeex; do
  if grep -q "${forbidden}" <<<"${CONF}"; then
    echo "ERROR: unexpected ${forbidden} present; this is not a min-gpl set."
    exit 1
  fi
done
echo "Config verified as min-gpl."

# --- Package the release zip: bin/ (runtime DLL closure) + include/ headers ---
# Matches the layout of the published full-gpl zip and what the Flutter plugin's
# windows/CMakeLists.txt consumes (a dir containing bin/ [+ include/]).
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

RELEASE_TAG="${FFMPEGKIT_VERSION}-${PACKAGE}"   # e.g. 8.0.0-min-gpl (shared per-variant release)
echo ""
echo "=== Done ==="
echo "Artifact : ${ZIP_PATH}"
echo "Upload as: ${ZIP_NAME}"
echo "To existing release tag: ${RELEASE_TAG}"
echo ""
echo "Publish (add the Windows zip as an asset on the existing per-variant release,"
echo "alongside the iOS/macOS zips — same convention as 8.0.0-full):"
echo "  gh release upload ${RELEASE_TAG} \\"
echo "    \"${ZIP_PATH}\" \\"
echo "    --repo sk3llo/ffmpeg_kit_flutter --clobber"
