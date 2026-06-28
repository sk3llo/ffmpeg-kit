#!/bin/bash

# ASSEMBLY IS DISABLED ON WINDOWS TO AVOID OBJECT FORMAT / RELOCATION ISSUES
# WHEN CROSS-COMPILING WITH THE MINGW-W64 TOOLCHAIN
ASM_OPTIONS="--disable-asm"

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libass} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --disable-libtool-lock \
  --enable-static \
  --disable-shared \
  --disable-require-system-font-provider \
  --disable-fast-install \
  --disable-test \
  --disable-profile \
  ${ASM_OPTIONS} \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
