#!/bin/bash
set -e

# --- FFmpeg-Kit Unified Windows Build Script ---

# Set the base directory
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging and Error Handling ---
log_error_and_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

# --- Argument Parsing ---
ENABLED_ARCHITECTURES=("x86" "x86_64" "arm64")
FFMPEG_KIT_CFG_FLAGS=""

args=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --disable-x86)
      unset 'ENABLED_ARCHITECTURES[0]'
      shift
      ;;
    --disable-x86_64)
      unset 'ENABLED_ARCHITECTURES[1]'
      shift
      ;;
    --disable-arm64)
      unset 'ENABLED_ARCHITECTURES[2]'
      shift
      ;;
    *)
      # Pass any other arguments to FFmpeg configure
      args+=("$1")
      shift
      ;;
  esac
done

# Re-add arguments to be passed to configure
FFMPEG_KIT_CFG_FLAGS="${args[@]}"

# --- Build Function ---
build_ffmpeg_arch() {
  local arch=$1
  local build_dir="${BASEDIR}/build/windows/${arch}"

  echo "--- Building FFmpeg for ${arch} ---"

  mkdir -p "${build_dir}" || log_error_and_exit "Failed to create build directory: ${build_dir}"
  cd "${build_dir}" || log_error_and_exit "Failed to cd to ${build_dir}"

  local host=""
  local arch_flags=""
  local toolchain_flags=()

  case ${arch} in
    x86)
      host="i686-w64-mingw32"
      toolchain_flags+=(--cross-prefix="${host}-")
      arch_flags="--arch=i686"
      ;;
    x86_64)
      host="x86_64-w64-mingw32"
      toolchain_flags+=(--cross-prefix="${host}-")
      arch_flags="--arch=x86_64"
      ;;
    arm64)
      host="aarch64-w64-mingw32"
      arch_flags="--arch=aarch64 --cpu=armv8-a"
      toolchain_flags+=(--cc=clang --target=aarch64-w64-mingw32)
      ;;
    *)
      log_error_and_exit "Unsupported architecture: '${arch}'"
      ;;
  esac

  local configure_flags=(
    --prefix="${build_dir}/install"
    --pkg-config-flags=--static
    --enable-version3
    --enable-w32threads
    --target-os=mingw32
    --enable-cross-compile
    ${arch_flags}
    "${toolchain_flags[@]}"
    ${FFMPEG_KIT_CFG_FLAGS}
  )

  echo "Configuring FFmpeg for ${arch}..."
  "${BASEDIR}/ffmpeg/configure" "${configure_flags[@]}" || log_error_and_exit "FFmpeg configure failed for ${arch}."

  echo "Building FFmpeg for ${arch}..."
  make -j$(nproc) || log_error_and_exit "FFmpeg make failed for ${arch}."

  echo "Installing FFmpeg for ${arch}..."
  make install || log_error_and_exit "FFmpeg make install failed for ${arch}."

  echo "--- Successfully built for ${arch} ---"
}

# --- Main Execution ---
echo "Starting FFmpeg-Kit Windows build..."

for arch in "${ENABLED_ARCHITECTURES[@]}"; do
  if [ -n "$arch" ]; then
    (build_ffmpeg_arch "$arch") || log_error_and_exit "Build failed for architecture: $arch"
  fi
done

echo "FFmpeg-Kit Windows build completed successfully!"
