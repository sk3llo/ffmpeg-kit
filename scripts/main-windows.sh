#!/bin/bash

# Set environment variables for Windows build
set -e

# Set the base directory
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source common functions
source "${BASEDIR}/scripts/function.sh"

# Source Windows specific functions
source "${BASEDIR}/scripts/function-windows.sh"

# Initialize variables
FFMPEG_KIT_BUILD_TYPE="windows"
BUILD_DIRECTORY="${BASEDIR}/build/windows"
ENABLED_ARCHITECTURES=(
  "x86"
  "x86_64"
  "arm64"
)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --disable-x86)
      ENABLED_ARCHITECTURES=("${ENABLED_ARCHITECTURES[@]/x86/}")
      shift
      ;;
    --disable-x86_64)
      ENABLED_ARCHITECTURES=("${ENABLED_ARCHITECTURES[@]/x86_64/}")
      shift
      ;;
    --disable-arm64)
      ENABLED_ARCHITECTURES=("${ENABLED_ARCHITECTURES[@]/arm64/}")
      shift
      ;;
    --full)
      # Enable all external libraries
      ENABLED_LIBRARIES=(
        "windows-media-foundation"
        "windows-msmpeg4v3"
        "windows-openssl"
        "windows-schannel"
        "windows-sdl2"
        "windows-zlib"
        "windows-zlibng"
        "windows-bzip2"
        "windows-lzma"
        "windows-iconv"
      )
      shift
      ;;
    --enable-windows-*)
      # Handle individual library enables
      ENABLED_LIBRARIES+=("${1#--enable-}")
      shift
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    -l|--lts)
      ENABLE_LTS_BUILD=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      display_help
      exit 1
      ;;
  esac
done

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIRECTORY}"

# Set up the build environment
setup_build_environment() {
  echo "Setting up build environment for Windows..."
  
  # Set up Visual Studio environment if available
  if [ -z "${VSINSTALLDIR}" ] && [ -f "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat" ]; then
    echo "Setting up Visual Studio 2022 environment..."
    cmd.exe /c "call \"C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat\" && set > %TEMP%\vs_env_vars.txt"
    while IFS='=' read -r key value; do
      if [[ ! -z "$key" && ! -z "$value" ]]; then
        export "$key"="$value"
      fi
    done < "${TEMP}/vs_env_vars.txt"
  fi
  
  # Set up MSYS2 environment if available
  if [ -z "${MSYSTEM}" ] && [ -d "/c/msys64" ]; then
    echo "Setting up MSYS2 environment..."
    export MSYSTEM=MINGW64
    export MSYS2_PATH_TYPE=inherit
    export PATH="/c/msys64/usr/bin:${PATH}"
  fi
}

# Build FFmpeg for a specific architecture
build_ffmpeg() {
  local arch=$1
  local build_dir="${BUILD_DIRECTORY}/${arch}"
  
  echo "Building FFmpeg for ${arch}..."
  
  # Create build directory
  mkdir -p "${build_dir}"
  
  # Configure FFmpeg
  cd "${build_dir}"
  "${BASEDIR}/ffmpeg/configure" \
    --arch=${arch} \
    --target-os=mingw32 \
    --cross-prefix=${arch}-w64-mingw32- \
    --enable-cross-compile \
    --prefix="${build_dir}/install" \
    --disable-static \
    --enable-shared \
    --enable-version3 \
    --enable-w32threads \
    --enable-avresample \
    --enable-libmfx \
    --enable-dxva2 \
    --enable-d3d11va \
    --enable-nvenc \
    --enable-nvdec \
    --enable-libmp3lame \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libfdk-aac \
    --enable-libass \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libopenjpeg \
    --enable-libspeex \
    --enable-libtheora \
    --enable-libtwolame \
    --enable-libwavpack \
    --enable-libxvid \
    --enable-libzvbi \
    --enable-libmysofa \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libmp3lame \
    --enable-libshine \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libspeex \
    --enable-libwavpack \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc \
    --enable-libopenjpeg \
    --enable-libwebp \
    --enable-libzimg \
    --enable-libsoxr \
    --enable-libmodplug \
    --enable-libsnappy \
    --enable-libaom \
    --enable-libdav1d \
    --enable-librav1e \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libxml2 \
    --enable-libzimg \
    --enable-libopenmpt \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libvo-amrwbenc
    
  # Build FFmpeg
  make -j$(nproc)
  make install
  
  cd - > /dev/null
}

# Main build function
build() {
  echo "Starting FFmpegKit build for Windows..."
  
  # Set up build environment
  setup_build_environment
  
  # Build for each enabled architecture
  for arch in "${ENABLED_ARCHITECTURES[@]}"; do
    if [ -n "$arch" ]; then
      build_ffmpeg "$arch"
    fi
  done
  
  echo "FFmpegKit build completed successfully!"
}

# Run the build
build
