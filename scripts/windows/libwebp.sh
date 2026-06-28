#!/bin/bash

# SET BUILD OPTIONS
ASM_OPTIONS=""
case ${ARCH} in
arm*)
  ASM_OPTIONS="--enable-neon --enable-neon-rtcd"
  ;;
*)
  ASM_OPTIONS="--enable-sse2 --enable-sse4.1"
  ;;
esac

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libwebp} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

# NOTE: THE OPTIONAL png/jpeg/gif/tiff IMAGE DEPENDENCIES ARE ONLY USED BY THE
# cwebp/dwebp BINARIES (DISABLED HERE), SO THEY ARE NOT BUILT FOR WINDOWS.
./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --enable-static \
  --disable-shared \
  --disable-dependency-tracking \
  --enable-libwebpmux \
  ${ASM_OPTIONS} \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
