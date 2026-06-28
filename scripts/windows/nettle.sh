#!/bin/bash

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_nettle} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

overwrite_file "${FFMPEG_KIT_TMPDIR}"/source/config/config.guess "${BASEDIR}"/src/"${LIB_NAME}"/config.guess || return 1
overwrite_file "${FFMPEG_KIT_TMPDIR}"/source/config/config.sub "${BASEDIR}"/src/"${LIB_NAME}"/config.sub || return 1

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --enable-pic \
  --enable-static \
  --with-include-path="${LIB_INSTALL_BASE}"/gmp/include \
  --with-lib-path="${LIB_INSTALL_BASE}"/gmp/lib \
  --disable-shared \
  --disable-mini-gmp \
  --disable-assembler \
  --disable-openssl \
  --disable-gcov \
  --disable-documentation \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
