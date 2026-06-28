#!/bin/bash

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_opencore_amr} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-maintainer-mode \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# COPY BOTH opencore-amrnb.pc AND opencore-amrwb.pc FROM THE INSTALL TREE
# (--enable-libopencore-amrwb IN ffmpeg.sh REQUIRES opencore-amrwb.pc)
cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
