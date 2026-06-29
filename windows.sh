#!/bin/bash
#
# FFmpeg-Kit Build Script for Windows
#
# DISCLAIMER: This is an unofficial build script created by mirroring the official
# linux.sh and android.sh scripts. Building FFmpeg-Kit on Windows is not
# officially supported.
#
# Recommended Environment: MSYS2 MinGW 64-bit Shell or Windows Subsystem for Linux
#
# Windows-specific build options:
#   --enable-windows-media-foundation  Enable Windows Media Foundation support
#   --enable-windows-openssl           Enable OpenSSL support
#   --enable-windows-schannel          Enable SChannel support
#   --enable-windows-sdl2              Enable SDL2 support
#   --enable-windows-zlib              Enable zlib support
#   --enable-windows-bzip2             Enable bzip2 support
#   --enable-windows-lzma              Enable lzma support
#   --enable-windows-iconv             Enable iconv support
#
# Example: ./windows.sh --enable-windows-media-foundation --enable-windows-openssl
#
# NOTE: do NOT enable `set -e` here. The shared scripts/function.sh use `let var=0`
# (which returns exit status 1 when the result is 0) and other errexit-incompatible
# constructs (e.g. print_enabled_architectures); the framework relies on explicit
# `|| return 1` / `exit 1` / RC checks instead, exactly like android.sh/linux.sh.
# With errexit on, the run dies in print_enabled_architectures.

# Print error and exit with status 1
error_exit() {
    echo -e "\nERROR: $1"
    echo "See build.log for more details"
    exit 1
}

# Check for required Windows build tools
check_windows_build_tools() {
    echo -n "Checking for Windows build tools... "
    
    # Check for MSVC
    if [ -z "${VCINSTALLDIR}" ] && [ ! -d "/c/Program Files/Microsoft Visual Studio/" ]; then
        echo "WARNING: Visual Studio not found. Please ensure Visual Studio is installed."
    fi
    
    # Check for MSYS2
    if ! command -v pacman &> /dev/null; then
        error_exit "MSYS2 not found. Please install MSYS2 from https://www.msys2.org/"
    fi
    
    # Check for required MSYS2 packages
    for pkg in mingw-w64-x86_64-toolchain git make pkg-config; do
        if ! pacman -Qs $pkg &> /dev/null; then
            echo "WARNING: MSYS2 package $pkg is not installed. Run 'pacman -S $pkg' to install."
        fi
    done
    
    echo "OK"
}

# --- 0. CHECK BUILD ENVIRONMENT ---
echo -e "\n=== FFmpeg-Kit Windows Build ===\n"

export BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export FFMPEG_KIT_BUILD_TYPE="windows"

# Check for required build scripts
for script in "${BASEDIR}/scripts/variable.sh" "${BASEDIR}/scripts/function-${FFMPEG_KIT_BUILD_TYPE}.sh" "${BASEDIR}/scripts/main-${FFMPEG_KIT_BUILD_TYPE}.sh"; do
    if [ ! -f "${script}" ]; then
        error_exit "Required script ${script} not found"
    fi
done

# Load common variables and functions
source "${BASEDIR}/scripts/variable.sh"
source "${BASEDIR}/scripts/function-${FFMPEG_KIT_BUILD_TYPE}.sh"

# Initialize variables
disabled_libraries=()

# Check Windows build environment
check_windows_build_tools

# --- 2. SET DEFAULTS ---
# Enable default architectures for Windows
enable_default_windows_architectures

# Enable main build by default
enable_main_build

# Create build log directory
mkdir -p "${BASEDIR}/build/logs"
BUILD_LOG="${BASEDIR}/build/logs/windows-$(date +%Y%m%d-%H%M%S).log"

echo -e "Build started at $(date)" > "${BUILD_LOG}"
echo -e "Build command: $0 $*" >> "${BUILD_LOG}"
echo -e "Build options: $*\n" >> "${BUILD_LOG}"

# --- 3. SET DEFAULT BUILD OPTIONS ---
export GPL_ENABLED="no"
DISPLAY_HELP=""
BUILD_FULL=""
BUILD_TYPE_ID="windows"

# Get git version or use a default
if command -v git &> /dev/null; then
    BUILD_VERSION=$(git describe --tags --always 2>>"${BUILD_LOG}" || echo "unknown-$(date +%Y%m%d)")
else
    BUILD_VERSION="unknown-$(date +%Y%m%d)"
fi

export BUILD_VERSION

# Set Windows-specific environment variables
export PATH="/mingw64/bin:${PATH}"
export PKG_CONFIG_PATH="/mingw64/lib/pkgconfig:${PKG_CONFIG_PATH}"

# --- 4. PROCESS BUILD OPTIONS ---
while [ ! $# -eq 0 ]; do

  case $1 in
  -h | --help)
    DISPLAY_HELP="1"
    ;;
  -v | --version)
    display_version
    exit 0
    ;;
  --skip-*)
    SKIP_LIBRARY=$(echo "$1" | sed -e 's/^--[A-Za-z]*-//g')
    skip_library "${SKIP_LIBRARY}"
    ;;
  --no-output-redirection)
    no_output_redirection
    ;;
  --no-workspace-cleanup-*)
    NO_WORKSPACE_CLEANUP_LIBRARY=$(echo "$1" | sed -e 's/^--[A-Za-z]*-[A-Za-z]*-[A-Za-z]*-//g')
    no_workspace_cleanup_library "${NO_WORKSPACE_CLEANUP_LIBRARY}"
    ;;
  --no-link-time-optimization)
    no_link_time_optimization
    ;;
  -d | --debug)
    enable_debug
    ;;
  -s | --speed)
    optimize_for_speed
    ;;
  -l | --lts) ;;
  -f | --force)
    export BUILD_FORCE="1"
    ;;
  --reconf-*)
    CONF_LIBRARY=$(echo "$1" | sed -e 's/^--[A-Za-z]*-//g')
    reconf_library "${CONF_LIBRARY}"
    ;;
  --rebuild-*)
    BUILD_LIBRARY=$(echo "$1" | sed -e 's/^--[A-Za-z]*-//g')
    rebuild_library "${BUILD_LIBRARY}"
    ;;
  --redownload-*)
    DOWNLOAD_LIBRARY=$(echo "$1" | sed -e 's/^--[A-Za-z]*-//g')
    redownload_library "${DOWNLOAD_LIBRARY}"
    ;;
  --full)
    BUILD_FULL="1"
    ;;
  --enable-gpl)
    export GPL_ENABLED="yes"
    ;;
  --enable-custom-library-*)
    CUSTOM_LIBRARY_OPTION_KEY=$(echo "$1" | sed -e 's/^--enable-custom-//g;s/=.*$//g')
    CUSTOM_LIBRARY_OPTION_VALUE=$(echo "$1" | sed -e 's/^--enable-custom-.*=//g')
    generate_custom_library_environment_variables "${CUSTOM_LIBRARY_OPTION_KEY}" "${CUSTOM_LIBRARY_OPTION_VALUE}"
    ;;
  --enable-*)
    ENABLED_LIBRARY=$(echo "$1" | sed -e 's/^--[A-Za-z]*-//g')
    enable_library "${ENABLED_LIBRARY}"
    ;;
  --disable-lib-*)
    DISABLED_LIB=$(echo "$1" | sed -e 's/^--[A-Za-z]*-[A-Za-z]*-//g')
    disabled_libraries+=("${DISABLED_LIB}")
    ;;
  --disable-*)
    DISABLED_ARCH=$(echo "$1" | sed -e 's/^--[A-Za-z]*-//g')
    disable_arch "${DISABLED_ARCH}"
    ;;
  *)
    print_unknown_option "$1"
    ;;
  esac
  shift
done

if [[ -z ${BUILD_VERSION} ]]; then
  echo -e "\n(*) error: Can not run git commands in this folder. See build.log.\n"
  exit 1
fi

# PROCESS --full OPTION
if [[ -n ${BUILD_FULL} ]]; then
  # Assuming a similar range of libraries as linux
  for library in {0..91}; do
    if [ "${GPL_ENABLED}" == "yes" ] || [[ $(is_gpl_licensed $library) -ne 1 ]]; then
        enable_library "$(get_library_name $library)" 1
    fi
  done
fi

# DISABLE SPECIFIED LIBRARIES
for disabled_library in "${disabled_libraries[@]}"; do
  set_library "${disabled_library}" 0
done

# IF HELP DISPLAYED, EXIT
if [[ -n ${DISPLAY_HELP} ]]; then
  display_help
  exit 0
fi

echo -e "\nBuilding ffmpeg-kit ${BUILD_TYPE_ID}library for Windows\n"
echo -e -n "INFO: Building ffmpeg-kit ${BUILD_VERSION} ${BUILD_TYPE_ID}library for Windows: " 1>>"${BASEDIR}"/build.log 2>&1
echo -e "$(date)\n" 1>>"${BASEDIR}"/build.log 2>&1

# --- 5. PRINT BUILD SUMMARY & VALIDATE ---
print_enabled_architectures
print_enabled_libraries
print_reconfigure_requested_libraries
print_rebuild_requested_libraries
print_redownload_requested_libraries
print_custom_libraries

# VALIDATE GPL FLAGS (using a similar list to linux)
for gpl_library in {$LIBRARY_X264,$LIBRARY_XVIDCORE,$LIBRARY_X265,$LIBRARY_LIBVIDSTAB,$LIBRARY_RUBBERBAND}; do
  if [[ ${ENABLED_LIBRARIES[$gpl_library]} -eq 1 ]]; then
    library_name=$(get_library_name "${gpl_library}")
    if [ "${GPL_ENABLED}" != "yes" ]; then
      echo -e "\n(*) Invalid configuration detected. GPL library ${library_name} enabled without --enable-gpl flag.\n" 1>>"${BASEDIR}"/build.log 2>&1
      exit 1
    fi
  fi
done

# --- 6. DOWNLOAD SOURCES ---
echo -n -e "\nDownloading sources: "
echo -e "INFO: Downloading the source code of ffmpeg and external libraries.\n" 1>>"${BASEDIR}"/build.log 2>&1
download_gnu_config
downloaded_library_sources "${ENABLED_LIBRARIES[@]}"

# --- 7. BUILD LIBRARIES FOR EACH ARCHITECTURE ---
TARGET_ARCH_LIST=()

# Create build directory
mkdir -p "${BASEDIR}/build/windows"

for run_arch in {0..12}; do
  if [[ ${ENABLED_ARCHITECTURES[$run_arch]} -eq 1 ]]; then
    export ARCH=$(get_arch_name "$run_arch")
    export FULL_ARCH=$(get_full_arch_name "$run_arch")
    
    echo -e "\n=== Building for ${FULL_ARCH} ===" | tee -a "${BUILD_LOG}"
    
    # Create architecture-specific build directory
    export BUILD_DIR="${BASEDIR}/build/windows/${FULL_ARCH}"
    mkdir -p "${BUILD_DIR}"
    
    # Set up architecture-specific environment variables
    case ${ARCH} in
        x86)
            export HOST="i686-w64-mingw32"
            export CROSS_PREFIX="${HOST}-"
            ;;
        x86-64 | x86_64)
            export HOST="x86_64-w64-mingw32"
            export CROSS_PREFIX="${HOST}-"
            # get_arch_name() yields "x86-64"; normalize to the underscore form
            # FFmpeg's configure --arch expects.
            export ARCH="x86_64"
            ;;
        arm64)
            export HOST="aarch64-w64-mingw32"
            export CROSS_PREFIX="${HOST}-"
            ;;
        *)
            error_exit "Unsupported architecture: ${ARCH}"
            ;;
    esac
    
    # Execute main build script
    echo -e "Starting build for ${FULL_ARCH}..." | tee -a "${BUILD_LOG}"
    if ! . "${BASEDIR}/scripts/main-windows.sh" "${ENABLED_LIBRARIES[@]}" 2>&1 | tee -a "${BUILD_LOG}"; then
        error_exit "Build failed for ${FULL_ARCH}"
    fi

    TARGET_ARCH_LIST+=("${FULL_ARCH}")

    # CLEAR FLAGS
    for library in {0..91}; do
      library_name=$(get_library_name "${library}")
      unset "$(echo "OK_${library_name}" | sed "s/\-/\_/g")"
      unset "$(echo "DEPENDENCY_REBUILT_${library_name}" | sed "s/\-/\_/g")"
    done
  fi
done

# --- 8. CREATE FINAL BUNDLE ---
if [[ -n ${TARGET_ARCH_LIST[0]} ]]; then
  echo -e -n "\nCreating the bundle under prebuilt: "
  echo -e "DEBUG: Creating the bundle directory\n" 1>>"${BASEDIR}"/build.log 2>&1

  initialize_folder "${BASEDIR}/prebuilt/$(get_bundle_directory)"

  # Requires create_windows_bundle function in function-windows.sh
  create_windows_bundle

  echo -e "ok\n"
fi
