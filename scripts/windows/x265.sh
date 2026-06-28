#!/bin/bash

# SET BUILD OPTIONS
ASM_OPTIONS=""
case ${ARCH} in
x86-64 | x86)
  if ! [ -x "$(command -v nasm)" ]; then
    echo -e "\n(*) nasm command not found\n"
    return 1
  fi
  export AS="$(command -v nasm)"
  ASM_OPTIONS="-DENABLE_ASSEMBLY=1 -DCROSS_COMPILE_ARM=0"
  ;;
arm64)
  ASM_OPTIONS="-DENABLE_ASSEMBLY=0 -DCROSS_COMPILE_ARM=1"
  ;;
esac

rm -rf "${BUILD_DIR}" || return 1
mkdir -p "${BUILD_DIR}" || return 1
cd "${BUILD_DIR}" || return 1

# WORKAROUND TO FIX static_assert ERRORS
${SED_INLINE} 's/gnu++98/c++11/g' "${BASEDIR}"/src/"${LIB_NAME}"/source/CMakeLists.txt || return 1

# WORKAROUND FOR CMAKE 4.x: x265 3.4 forces the pre-3.5 policies CMP0025/CMP0054
# to OLD, which CMake >= 4.0 has removed (fatal error). Both are safe as NEW on
# MinGW/GCC (CMP0025 only affects AppleClang id; CMP0054 is the standard modern
# build of x265 3.4).
${SED_INLINE} 's/cmake_policy(SET CMP0025 OLD)/cmake_policy(SET CMP0025 NEW)/g' "${BASEDIR}"/src/"${LIB_NAME}"/source/CMakeLists.txt || return 1
${SED_INLINE} 's/cmake_policy(SET CMP0054 OLD)/cmake_policy(SET CMP0054 NEW)/g' "${BASEDIR}"/src/"${LIB_NAME}"/source/CMakeLists.txt || return 1

cmake -G "MSYS Makefiles" -Wno-dev \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DCMAKE_C_COMPILER="${CC}" \
  -DCMAKE_CXX_COMPILER="${CXX}" \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS} -frtti" \
  -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR="$(get_cmake_system_processor)" \
  -DCMAKE_INSTALL_PREFIX="${LIB_INSTALL_PREFIX}" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=1 \
  -DENABLE_PIC=1 \
  -DENABLE_CLI=0 \
  -DENABLE_SHARED=0 \
  -DHIGH_BIT_DEPTH=1 \
  ${ASM_OPTIONS} \
  "${BASEDIR}"/src/"${LIB_NAME}"/source || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_x265_package_config "3.4" || return 1
