#!/bin/bash

rm -rf "${BUILD_DIR}" || return 1
mkdir -p "${BUILD_DIR}" || return 1
cd "${BUILD_DIR}" || return 1

cmake -G "MSYS Makefiles" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DCMAKE_C_COMPILER="${CC}" \
  -DCMAKE_CXX_COMPILER="${CXX}" \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_INSTALL_PREFIX="${LIB_INSTALL_PREFIX}" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
  -DBUILD_SHARED_LIBS=0 \
  -DBUILD_TOOLS=0 \
  -DBUILD_TESTS=0 \
  -DFFT_LIB=kissfft \
  "${BASEDIR}"/src/"${LIB_NAME}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

create_chromaprint_package_config "$(grep -Eo 'PROJECT_VERSION [0-9.]+' "${BASEDIR}/src/${LIB_NAME}/CMakeLists.txt" | head -1 | sed 's/PROJECT_VERSION //')" || return 1
