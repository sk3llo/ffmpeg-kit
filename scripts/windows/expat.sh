#!/bin/bash

# THE arthenica/libexpat REPOSITORY KEEPS THE PROJECT UNDER A NESTED expat/ FOLDER
cd "${LIB_NAME}" || return 1

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/"${LIB_NAME}"/configure ]] || [[ ${RECONF_expat} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --without-docbook \
  --without-xmlwf \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp ./expat.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
