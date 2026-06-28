#!/bin/bash

source "${BASEDIR}"/scripts/function-"${FFMPEG_KIT_BUILD_TYPE}".sh 1>>"${BASEDIR}"/build.log 2>&1 || return 1

LIB_NAME="ffmpeg-kit"

echo -e "----------------------------------------------------------------" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "\nINFO: Building ${LIB_NAME} for ${HOST} with the following environment variables\n" 1>>"${BASEDIR}"/build.log 2>&1
env 1>>"${BASEDIR}"/build.log 2>&1
echo -e "----------------------------------------------------------------\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "INFO: System information\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "INFO: $(uname -a)\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "----------------------------------------------------------------\n" 1>>"${BASEDIR}"/build.log 2>&1

FFMPEG_KIT_LIBRARY_PATH="${LIB_INSTALL_BASE}/${LIB_NAME}"

set_toolchain_paths "${LIB_NAME}"

HOST=$(get_host)
export PKG_CONFIG_PATH="${INSTALL_PKG_CONFIG_DIR}"
export CFLAGS="$(get_cflags ${LIB_NAME}) -I${LIB_INSTALL_BASE}/ffmpeg/include"
export CXXFLAGS="$(get_cxxflags ${LIB_NAME}) -I${LIB_INSTALL_BASE}/ffmpeg/include"
export LDFLAGS="$(get_ldflags ${LIB_NAME})"

FFMPEG_INCLUDE_WIN=$(cygpath -m "${LIB_INSTALL_BASE}/ffmpeg/include")
FFMPEG_LIB_WIN=$(cygpath -m "${LIB_INSTALL_BASE}/ffmpeg/lib")
FFMPEG_PREFIX_WIN=$(cygpath -m "${LIB_INSTALL_BASE}/ffmpeg")
INSTALL_PREFIX_WIN=$(cygpath -m "${FFMPEG_KIT_LIBRARY_PATH}")
SOURCE_DIR_WIN=$(cygpath -m "${BASEDIR}/windows")
MINGW_INCLUDE_WIN=$(cygpath -m "/mingw64/include")
FFMPEG_SRC_WIN=$(cygpath -m "${BASEDIR}/src/ffmpeg")

cd "${BASEDIR}"/windows 1>>"${BASEDIR}"/build.log 2>&1 || return 1

echo -n -e "\n${LIB_NAME}: "

BUILD_DIR="${FFMPEG_KIT_TMPDIR}/cmake/build/$(get_build_directory)/${LIB_NAME}"
rm -rf "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1
mkdir -p "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1

cd "${BUILD_DIR}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

cmake -G "MSYS Makefiles" \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DCMAKE_C_COMPILER="${CC}" \
  -DCMAKE_CXX_COMPILER="${CXX}" \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX_WIN}" \
  -DCMAKE_PREFIX_PATH="${FFMPEG_PREFIX_WIN}" \
  -DFFMPEG_INCLUDE_DIR="${FFMPEG_INCLUDE_WIN}" \
  -DFFMPEG_LIB_DIR="${FFMPEG_LIB_WIN}" \
  -DMINGW_INCLUDE_DIR="${MINGW_INCLUDE_WIN}" \
  -DFFMPEG_SRC_DIR="${FFMPEG_SRC_WIN}" \
  "${SOURCE_DIR_WIN}" 1>>"${BASEDIR}"/build.log 2>&1

if [ $? -ne 0 ]; then
  echo -e "failed\n\nSee build.log for details\n"
  exit 1
fi

if [ -d "${FFMPEG_KIT_LIBRARY_PATH}" ]; then
  rm -rf "${FFMPEG_KIT_LIBRARY_PATH}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

make -j$(get_cpu_count) install 1>>"${BASEDIR}"/build.log 2>&1

if [ $? -eq 0 ]; then
  echo "ok"
else
  echo -e "failed\n\nSee build.log for details\n"
  exit 1
fi

create_ffmpegkit_package_config "$(get_ffmpeg_kit_version)" || return 1
