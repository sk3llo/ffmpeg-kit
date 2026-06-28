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
  -DENABLE_SHARED=0 \
  -DENABLE_APPS=0 \
  -DENABLE_CXX11=1 \
  -DUSE_OPENSSL_PC=1 \
  -DENABLE_STDCXX_SYNC=1 \
  -DOPENSSL_ROOT_DIR="${LIB_INSTALL_BASE}/openssl" \
  -DOPENSSL_INCLUDE_DIR="${LIB_INSTALL_BASE}/openssl/include" \
  -DOPENSSL_CRYPTO_LIBRARY="${LIB_INSTALL_BASE}/openssl/lib/libcrypto.a" \
  -DOPENSSL_SSL_LIBRARY="${LIB_INSTALL_BASE}/openssl/lib/libssl.a" \
  "${BASEDIR}"/src/"${LIB_NAME}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

create_srt_package_config "$(grep Version "${LIB_INSTALL_PREFIX}/lib/pkgconfig/srt.pc" 2>/dev/null | sed 's/Version: //')" || return 1
