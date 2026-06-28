#!/bin/bash

# ENABLE COMMON FUNCTIONS
source "${BASEDIR}"/scripts/function-"${FFMPEG_KIT_BUILD_TYPE}".sh || return 1

LIB_NAME=$1
ENABLED_LIBRARY_PATH="${LIB_INSTALL_BASE}/${LIB_NAME}"

# DELETE THE PREVIOUS BUILD OF THE LIBRARY
if [ -d "${ENABLED_LIBRARY_PATH}" ]; then
  rm -rf "${ENABLED_LIBRARY_PATH}" || return 1
fi

# PREPARE PATHS & DEFINE ${INSTALL_PKG_CONFIG_DIR}
SCRIPT_PATH="${BASEDIR}/scripts/windows/${LIB_NAME}.sh"
set_toolchain_paths "${LIB_NAME}"

# SET BUILD FLAGS
HOST=$(get_host)
export CFLAGS=$(get_cflags "${LIB_NAME}")
export CXXFLAGS=$(get_cxxflags "${LIB_NAME}")
export LDFLAGS=$(get_ldflags "${LIB_NAME}")
export PKG_CONFIG_LIBDIR="${INSTALL_PKG_CONFIG_DIR}"

# Our .pc files live in <base>/pkgconfig (not <prefix>/lib/pkgconfig) with absolute
# prefixes baked in. MSYS2's pkgconf otherwise auto-redefines prefix from the .pc
# location and mangles every path (e.g. freetype2 Cflags resolve to prebuilt/include
# instead of .../windows-x86_64/freetype/include). Honor the explicit prefix instead.
# (ffmpeg.sh already sets this for the FFmpeg configure step.)
export PKG_CONFIG_DONT_DEFINE_PREFIX=1

cd "${BASEDIR}"/src/"${LIB_NAME}" || return 1

LIB_INSTALL_PREFIX="${ENABLED_LIBRARY_PATH}"
BUILD_DIR=$(get_cmake_build_directory)

echo -e "----------------------------------------------------------------"
echo -e "\nINFO: Building ${LIB_NAME} for ${HOST} with the following environment variables\n"
env
echo -e "----------------------------------------------------------------\n"
echo -e "INFO: System information\n"
echo -e "INFO: $(uname -a)\n"
echo -e "----------------------------------------------------------------\n"

rm -rf "${LIB_INSTALL_PREFIX}" || return 1
rm -rf "${BUILD_DIR}" || return 1

# EXECUTE BUILD SCRIPT OF EACH ENABLED LIBRARY
source "${SCRIPT_PATH}"
