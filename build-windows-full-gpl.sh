#!/usr/bin/env bash
#
# build-windows-full-gpl.sh
# --------------------------------------------------------------------------
# Scaffold for building a CANONICAL "full-gpl" FFmpegKit for Windows (x86_64)
# under MSYS2 / MinGW-w64, producing a bundle whose `Packages::getPackageName()`
# reports "full-gpl" (i.e. all 27 external libraries that the detector in
# windows/src/Packages.cpp requires, with the GPL components enabled).
#
# The published sk3llo Windows artifacts ("8.0.0-full" / "8.0.0-full-gpl") are
# actually a reduced custom configuration (x264/aom/dav1d/openh264/kvazaar/
# ilbc/zimg/openssl/srt + gpl) that the detector classifies as "min". This
# script builds the real, complete set.
#
# WHAT IT DOES
#   1. Verifies it is running inside an MSYS2 MINGW64 shell.
#   2. Installs the toolchain + the 27 external libraries via pacman.
#   3. Configures + builds + installs FFmpeg 7.1.1 (from src/ffmpeg) with
#      --enable-gpl --enable-version3 and the full canonical --enable-lib* set.
#      External libs are linked statically (--pkg-config-flags=--static) so the
#      codecs are embedded into the av* DLLs, matching the existing bundle shape
#      (no per-codec sidecar DLLs).
#   4. Builds the libffmpegkit wrapper (windows/ CMake project) against FFmpeg.
#   5. Assembles the bundle (bin/ + include/) and zips it as
#      ffmpeg-kit-windows-x86_64-full-gpl-<version>.zip.
#   6. Prints verification steps.
#
# STATUS: SCAFFOLD. The library/flag wiring and bundle layout are complete and
# grounded in the existing build system, but a full run takes a long time and
# has NOT been executed end-to-end here. Sections that are most likely to need
# adjustment on the first real run are marked with `# VALIDATE:`.
#
# USAGE (from an "MSYS2 MINGW64" shell, NOT cmd/PowerShell):
#   cd /c/Users/<you>/StudioProjects/ffmpeg-kit
#   ./build-windows-full-gpl.sh                 # build everything
#   ./build-windows-full-gpl.sh --skip-deps     # skip pacman install
#   ./build-windows-full-gpl.sh --skip-ffmpeg   # reuse an existing FFmpeg build
# --------------------------------------------------------------------------

set -euo pipefail

# ----------------------------------------------------------------------------
# 0. Configuration
# ----------------------------------------------------------------------------
ARCH="x86_64"
HOST="x86_64-w64-mingw32"
MINGW_PREFIX_DIR="/mingw64"

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG_SRC="${BASEDIR}/src/ffmpeg"                                  # vendored FFmpeg 7.1.1
WRAPPER_SRC="${BASEDIR}/windows"                                    # libffmpegkit CMake project
FFMPEG_PREFIX="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg"          # FFmpeg install prefix
WRAPPER_PREFIX="${BASEDIR}/prebuilt/windows-${ARCH}/ffmpeg-kit"     # wrapper install prefix
BUNDLE_DIR="${BASEDIR}/prebuilt/bundle-windows-${ARCH}/ffmpeg-kit"  # final bundle (bin/ + include/)
BUILD_TMP="${BASEDIR}/.tmp/windows-${ARCH}-full-gpl"
LOG="${BASEDIR}/build-windows-full-gpl.log"

SKIP_DEPS=0; SKIP_FFMPEG=0; SKIP_WRAPPER=0
for a in "$@"; do case "$a" in
  --skip-deps) SKIP_DEPS=1 ;;
  --skip-ffmpeg) SKIP_FFMPEG=1 ;;
  --skip-wrapper) SKIP_WRAPPER=1 ;;
  *) echo "unknown option: $a" >&2; exit 2 ;;
esac; done

: > "${LOG}"
log()  { echo "[full-gpl] $*"; }
run()  { echo "+ $*" >>"${LOG}"; "$@" >>"${LOG}" 2>&1; }

# ----------------------------------------------------------------------------
# 1. Environment check
# ----------------------------------------------------------------------------
if [[ "${MSYSTEM:-}" != "MINGW64" ]]; then
  echo "ERROR: run this from an 'MSYS2 MINGW64' shell (MSYSTEM=MINGW64), got '${MSYSTEM:-unset}'." >&2
  echo "       Launch C:\\msys64\\mingw64.exe and re-run." >&2
  exit 1
fi
[[ -d "${FFMPEG_SRC}" ]]  || { echo "ERROR: FFmpeg source not found at ${FFMPEG_SRC}" >&2; exit 1; }
[[ -f "${WRAPPER_SRC}/CMakeLists.txt" ]] || { echo "ERROR: wrapper project not found at ${WRAPPER_SRC}" >&2; exit 1; }
log "FFmpeg: $(cat "${FFMPEG_SRC}/RELEASE" 2>/dev/null || echo unknown)  arch: ${ARCH}"

# ----------------------------------------------------------------------------
# 2. Provision the canonical full-gpl libraries via pacman
#
#    Maps each library required by windows/src/Packages.cpp::getPackageName()
#    (the "full-gpl" branch) to its MSYS2 mingw-w64-x86_64 package. All 27 are
#    available in the MSYS2 repositories (verified), plus libogg as a transitive
#    dependency of vorbis/theora.
# ----------------------------------------------------------------------------
TOOL_PKGS=(gcc nasm yasm make cmake ninja meson pkgconf diffutils)
LIB_PKGS=(
  dav1d libaom kvazaar                 # av1 / hevc
  x264 x265 xvidcore vid.stab          # GPL components (require --enable-gpl)
  fontconfig freetype fribidi libass   # subtitle/text stack
  libxml2 gmp gnutls libiconv          # xml / crypto / tls / iconv
  lame opus libogg libvorbis libtheora # audio + containers
  libvpx libwebp speex twolame         # vpx / webp / speex / mp2
  shine snappy libsoxr                 # mp3(fixed) / snappy / resampler
  opencore-amr libilbc                 # amr / ilbc
)
if [[ ${SKIP_DEPS} -eq 0 ]]; then
  log "Installing ${#TOOL_PKGS[@]} build tools + ${#LIB_PKGS[@]} libraries via pacman ..."
  PKGS=()
  for p in "${TOOL_PKGS[@]}" "${LIB_PKGS[@]}"; do PKGS+=("mingw-w64-${ARCH}-${p}"); done
  # VALIDATE: on a fresh MSYS2 you may need `pacman -Syu` first (and restart the shell).
  run pacman -S --needed --noconfirm "${PKGS[@]}"
else
  log "Skipping pacman install (--skip-deps)."
fi

# ----------------------------------------------------------------------------
# 3. Build FFmpeg full-gpl
#
#    The canonical 27-library set, mapped to FFmpeg configure flags. Packages.cpp
#    detects each by scanning FFMPEG_CONFIGURATION for "enable-<lib>"/"enable-lib<lib>".
# ----------------------------------------------------------------------------
FFMPEG_GPL_FLAGS=(
  --enable-gpl --enable-version3
  # GPL components
  --enable-libx264 --enable-libx265 --enable-libxvid --enable-libvidstab
  # video
  --enable-libdav1d --enable-libaom --enable-libkvazaar
  --enable-libvpx --enable-libwebp --enable-libtheora
  # text/subtitles
  --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libass
  # xml / tls / iconv
  --enable-libxml2 --enable-gmp --enable-gnutls --enable-iconv
  # audio
  --enable-libmp3lame --enable-libopus --enable-libvorbis
  --enable-libspeex --enable-libtwolame --enable-libshine --enable-libsoxr
  --enable-libsnappy
  --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libilbc
)

if [[ ${SKIP_FFMPEG} -eq 0 ]]; then
  log "Configuring + building FFmpeg full-gpl (this takes a while) ..."
  rm -rf "${BUILD_TMP}/ffmpeg" && mkdir -p "${BUILD_TMP}/ffmpeg"
  pushd "${BUILD_TMP}/ffmpeg" >/dev/null

  # Static external libs so codecs embed into the av* DLLs (matches release shape).
  export PKG_CONFIG_PATH="${MINGW_PREFIX_DIR}/lib/pkgconfig"
  # VALIDATE: static gnutls pulls nettle/hogweed/gmp + ws2_32/crypt32 — if configure
  # fails on gnutls, either install static deps or drop to --enable-openssl.
  run "${FFMPEG_SRC}/configure" \
    --prefix="${FFMPEG_PREFIX}" \
    --target-os=mingw32 --arch=x86_64 --cpu=x86-64 \
    --cross-prefix="${HOST}-" \
    --pkg-config=pkg-config --pkg-config-flags=--static \
    --enable-shared --disable-static \
    --enable-w32threads --enable-asm --enable-inline-asm \
    --enable-pic --disable-debug --disable-doc --disable-programs \
    "${FFMPEG_GPL_FLAGS[@]}"

  run make -j"$(nproc)"
  run make install
  popd >/dev/null
  log "FFmpeg installed to ${FFMPEG_PREFIX}"
else
  log "Skipping FFmpeg build (--skip-ffmpeg)."
fi

# Sanity-check the configuration string the wrapper will report.
CFG_H="${FFMPEG_PREFIX}/include/config.h"
if [[ -f "${CFG_H}" ]]; then
  if grep -q "enable-libx265" "${CFG_H}" && grep -q "enable-libass" "${CFG_H}" && grep -q "enable-gpl" "${CFG_H}"; then
    log "FFMPEG_CONFIGURATION looks like full-gpl (x265 + libass + gpl present)."
  else
    log "WARNING: config.h is missing expected full-gpl flags — getPackageName() may report 'min'/'custom'."
  fi
fi

# ----------------------------------------------------------------------------
# 4. Build the libffmpegkit wrapper against FFmpeg
#
#    Mirrors scripts/windows/ffmpeg-kit.sh: the wrapper needs both the installed
#    FFmpeg (libs + public headers) and the FFmpeg *source* tree (for internal
#    headers + config.h that the vendored fftools include).
# ----------------------------------------------------------------------------
if [[ ${SKIP_WRAPPER} -eq 0 ]]; then
  log "Building libffmpegkit wrapper ..."
  rm -rf "${BUILD_TMP}/wrapper" && mkdir -p "${BUILD_TMP}/wrapper"
  pushd "${BUILD_TMP}/wrapper" >/dev/null
  run cmake -G "MSYS Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_SYSTEM_PROCESSOR=AMD64 \
    -DCMAKE_INSTALL_PREFIX="$(cygpath -m "${WRAPPER_PREFIX}")" \
    -DCMAKE_PREFIX_PATH="$(cygpath -m "${FFMPEG_PREFIX}")" \
    -DFFMPEG_INCLUDE_DIR="$(cygpath -m "${FFMPEG_PREFIX}/include")" \
    -DFFMPEG_LIB_DIR="$(cygpath -m "${FFMPEG_PREFIX}/lib")" \
    -DMINGW_INCLUDE_DIR="$(cygpath -m "${MINGW_PREFIX_DIR}/include")" \
    -DFFMPEG_SRC_DIR="$(cygpath -m "${FFMPEG_SRC}")" \
    "$(cygpath -m "${WRAPPER_SRC}")"
  run make -j"$(nproc)" install
  popd >/dev/null
  log "Wrapper installed to ${WRAPPER_PREFIX}"
else
  log "Skipping wrapper build (--skip-wrapper)."
fi

# ----------------------------------------------------------------------------
# 5. Assemble the bundle (bin/ + include/) and compute the DLL dependency closure
# ----------------------------------------------------------------------------
log "Assembling bundle ..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/bin" "${BUNDLE_DIR}/include"

# FFmpeg + wrapper DLLs
shopt -s nullglob
for dll in "${FFMPEG_PREFIX}/bin/"*.dll "${WRAPPER_PREFIX}/bin/"*.dll "${WRAPPER_PREFIX}/lib/"*.dll; do
  cp -f "${dll}" "${BUNDLE_DIR}/bin/"
done

# Public + internal headers expected by consumers (mirror the release layout).
cp -rf "${FFMPEG_PREFIX}/include/." "${BUNDLE_DIR}/include/"
cp -f  "${WRAPPER_SRC}/src/"*.h     "${BUNDLE_DIR}/include/" 2>/dev/null || true

# Resolve the runtime DLL closure with ldd and pull in any missing /mingw64 deps
# (libgcc, libstdc++, libwinpthread, zlib, and anything static linking missed).
log "Resolving runtime DLL dependencies ..."
resolve_deps() {
  local changed=1
  while [[ ${changed} -eq 1 ]]; do
    changed=0
    for dll in "${BUNDLE_DIR}/bin/"*.dll; do
      while read -r dep path; do
        case "${path}" in
          "${MINGW_PREFIX_DIR}"/*)
            local base; base="$(basename "${path}")"
            if [[ ! -f "${BUNDLE_DIR}/bin/${base}" ]]; then
              cp -f "${path}" "${BUNDLE_DIR}/bin/"; changed=1
            fi ;;
        esac
      done < <(ldd "${dll}" 2>/dev/null | awk '{print $1, $3}')
    done
  done
}
resolve_deps

# ASLR/rebase fix for MinGW DLLs (same rationale as windows/CMakeLists.txt in the
# Flutter plugin: clear ASLR + compact rebase so 32-bit pseudo-relocs don't overflow).
# VALIDATE: editbin is an MSVC tool; if unavailable, the Flutter plugin's CMake
# already performs this step at consume time, so it can be skipped here.
if command -v editbin >/dev/null 2>&1; then
  log "Rebasing bundled DLLs with editbin ..."
  run editbin /NOLOGO /HIGHENTROPYVA:NO /DYNAMICBASE:NO /REBASE:BASE=0x10000000 "${BUNDLE_DIR}/bin/"*.dll || \
    log "WARNING: editbin rebase failed (non-fatal; the consuming CMake repeats this step)."
fi

# ----------------------------------------------------------------------------
# 6. Zip + verify
# ----------------------------------------------------------------------------
VERSION="$(git -C "${BASEDIR}" describe --tags --always 2>/dev/null | sed 's/-full-gpl$//' || echo 8.0.0)"
ZIP_NAME="ffmpeg-kit-windows-${ARCH}-full-gpl-${VERSION}.zip"
ZIP_PATH="${BASEDIR}/prebuilt/${ZIP_NAME}"
log "Creating ${ZIP_NAME} ..."
( cd "$(dirname "${BUNDLE_DIR}")" && rm -f "${ZIP_PATH}" && \
  ( command -v zip >/dev/null && zip -rq "${ZIP_PATH}" "$(basename "${BUNDLE_DIR}")" \
    || powershell.exe -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$(dirname "${BUNDLE_DIR}")")\\ffmpeg-kit\\*' -DestinationPath '$(cygpath -w "${ZIP_PATH}")' -Force" ) )

cat <<EOF

================================================================================
DONE (scaffold run). Output:
  bundle : ${BUNDLE_DIR}
  zip    : ${ZIP_PATH}
  log    : ${LOG}

VERIFY the package is genuinely full-gpl:
  1. grep FFMPEG_CONFIGURATION "${FFMPEG_PREFIX}/include/config.h"
     -> must contain: enable-gpl, enable-libx264, enable-libx265, enable-libxvid,
        enable-libvidstab, enable-libass, enable-gnutls, enable-libvorbis, ... (all 27)
  2. Point the Flutter plugin at this artifact and run the example; the log must read:
        Loaded ffmpeg-kit-full-gpl-x86_64-...
  3. A GPL-codec command must succeed, e.g.:
        -i in.mov -c:v libx265 out.mp4

NEXT STEPS (outside this script):
  * Host \${ZIP_NAME} on the release and update windows/CMakeLists.txt in the
    Flutter plugin: FFMPEGKIT_RELEASE_TAG=8.0.0-full-gpl and the zip name.
  * The wrapper source here (windows/src) DIFFERS from the Flutter plugin's
    windows/src — the threading/leak/locking fixes made in the plugin must also
    be applied here for them to ship in this DLL.
================================================================================
EOF
