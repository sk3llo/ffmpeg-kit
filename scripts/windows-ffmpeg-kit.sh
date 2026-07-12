#!/bin/bash
#
# windows-ffmpeg-kit.sh — build the FFmpegKit wrapper (libffmpegkit) for Windows
# against an already-built FFmpeg install. Run from windows.sh after FFmpeg is
# installed, ONCE PER ARCH. Inherits from windows.sh / main-windows.sh:
#   BASEDIR, ARCH, CROSS_PREFIX, BUILD_DIR, FFMPEG_PREFIX(=BUILD_DIR/install)
#
# Compiles windows/src/*.cpp + the vendored fftools_*.c into libffmpegkit.dll,
# linking against the FFmpeg shared DLLs (import libs in <install>/lib). FFmpeg
# *internal* headers come from src/ffmpeg (must match the built FFmpeg version).
#
# Direct gcc/g++ build (no cmake) — robust in a bare MSYS2 MINGW64 shell.
set -u

WRAP_BASE="${BASEDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ARCH="${ARCH:-x86_64}"
CC_BIN="${CROSS_PREFIX:-x86_64-w64-mingw32-}gcc"
CXX_BIN="${CROSS_PREFIX:-x86_64-w64-mingw32-}g++"
BUILD_DIR="${BUILD_DIR:-${WRAP_BASE}/build/windows/${ARCH}}"
INSTALL="${FFMPEG_PREFIX:-${BUILD_DIR}/install}"
SRC_FFMPEG="${WRAP_BASE}/src/ffmpeg"
FFMPEG_BUILD="${BUILD_DIR}/ffmpeg-build"   # out-of-tree dir holding generated config.h / config_components.h
WRAP_SRC="${WRAP_BASE}/windows/src"
OBJ_DIR="${BUILD_DIR}/ffmpeg-kit-build/obj"

[ -f "${INSTALL}/lib/libavcodec.dll.a" ] || { echo "ERROR: FFmpeg import libs not found in ${INSTALL}/lib (build FFmpeg first)."; exit 1; }
[ -d "${WRAP_SRC}" ] || { echo "ERROR: wrapper sources not found at ${WRAP_SRC}."; exit 1; }

echo "Building libffmpegkit wrapper for ${ARCH}..."
rm -rf "${OBJ_DIR}"; mkdir -p "${OBJ_DIR}"

# Include order: wrapper src; FFmpeg generated headers (config.h / config_components.h
# in the out-of-tree build dir); FFmpeg public headers (install); FFmpeg internal
# headers (src tree — version must match); MinGW headers (external lib headers).
INCS="-I${WRAP_SRC} -I${FFMPEG_BUILD} -I${INSTALL}/include -I${SRC_FFMPEG} -I/mingw64/include"
[ -f "${FFMPEG_BUILD}/config.h" ] || echo "WARNING: ${FFMPEG_BUILD}/config.h not found — fftools need FFmpeg's generated config.h."
DEFS="-DWIN32 -D_WIN32_WINNT=0x0A00 -DFFMPEGKIT_EXPORTS -D__STDC_CONSTANT_MACROS -DFFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d)"
# Arch define consumed by ArchDetect::getArch() (windows/src/ArchDetect.cpp).
case "${ARCH}" in
  x86_64) DEFS+=" -DFFMPEG_KIT_X86_64=1" ;;
  x86)    DEFS+=" -DFFMPEG_KIT_I386=1" ;;
  arm64)  DEFS+=" -DFFMPEG_KIT_ARM64=1" ;;
esac
COMMON="-O2 -fPIC ${DEFS} ${INCS}"

objs=()
fail=0

# C++ wrapper classes
for f in "${WRAP_SRC}"/*.cpp; do
  o="${OBJ_DIR}/$(basename "${f}").o"
  if ! "${CXX_BIN}" -std=c++17 ${COMMON} -c "${f}" -o "${o}"; then
    echo "ERROR compiling ${f}"; fail=1; fi
  objs+=("${o}")
done

# C fftools (FFmpeg command-line tools, vendored)
for f in "${WRAP_SRC}"/fftools_*.c; do
  o="${OBJ_DIR}/$(basename "${f}").o"
  if ! "${CC_BIN}" -std=c11 ${COMMON} -Wno-deprecated-declarations -c "${f}" -o "${o}"; then
    echo "ERROR compiling ${f}"; fail=1; fi
  objs+=("${o}")
done

if [ "${fail}" -ne 0 ]; then echo "ERROR: wrapper compilation failed."; exit 1; fi

# Link the shared lib + import lib, against the FFmpeg shared DLLs.
mkdir -p "${INSTALL}/bin" "${INSTALL}/lib"
"${CXX_BIN}" -shared -o "${INSTALL}/bin/libffmpegkit.dll" "${objs[@]}" \
  -Wl,--out-implib,"${INSTALL}/lib/libffmpegkit.dll.a" \
  -L"${INSTALL}/lib" \
  -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil \
  -lws2_32 -lbcrypt -lcrypt32 \
  -Wl,--default-image-base-low \
  || { echo "ERROR: wrapper link failed."; exit 1; }

# Install public headers next to the FFmpeg ones.
cp "${WRAP_SRC}"/*.h "${INSTALL}/include/" 2>/dev/null || true

echo "libffmpegkit installed: ${INSTALL}/bin/libffmpegkit.dll"
