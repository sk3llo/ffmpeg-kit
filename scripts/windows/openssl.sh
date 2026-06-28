#!/bin/bash

ASM_OPTIONS=""
case ${ARCH} in
x86-64)
  ASM_OPTIONS="mingw64 enable-ec_nistp_64_gcc_128"
  ;;
x86)
  ASM_OPTIONS="mingw"
  ;;
arm64)
  ASM_OPTIONS="mingw64 no-asm"
  ;;
esac

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_openssl} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

INT128_AVAILABLE=$($CC -dM -E - </dev/null 2>>"${BASEDIR}"/build.log | grep __SIZEOF_INT128__)

echo -e "INFO: __uint128_t detection output: $INT128_AVAILABLE\n" 1>>"${BASEDIR}"/build.log 2>&1

./Configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  zlib \
  no-shared \
  no-engine \
  no-dso \
  no-legacy \
  ${ASM_OPTIONS} \
  no-tests || return 1

make -j$(get_cpu_count) build_sw || return 1

make install_sw install_ssldirs || return 1

cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
