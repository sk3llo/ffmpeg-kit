#!/bin/bash

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_kvazaar} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --enable-static \
  --disable-shared \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/kvazaar.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
