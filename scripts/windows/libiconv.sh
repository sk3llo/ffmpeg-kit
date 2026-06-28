#!/bin/bash

# MSYS2 already provides libiconv (mingw-w64-x86_64-libiconv) at the same version
# pinned in scripts/source.sh (1.18), with static archives. Building the GNU
# libiconv git tree from source on Windows requires fetching its gnulib subtree
# (./gitsub.sh pull -> git://git.savannah.gnu.org), which is fragile and
# version-pinned. Instead we stage the system libiconv into our prefix so that
# fontconfig/libxml2/ffmpeg consume it via the generated libiconv.pc.

case ${ARCH} in
x86)
  MINGW_LIB_PREFIX="/mingw32"
  ;;
*)
  MINGW_LIB_PREFIX="/mingw64"
  ;;
esac

if [ ! -f "${MINGW_LIB_PREFIX}/lib/libiconv.a" ] || [ ! -f "${MINGW_LIB_PREFIX}/include/iconv.h" ]; then
  echo -e "\n(*) system libiconv not found in ${MINGW_LIB_PREFIX} (install mingw-w64-x86_64-libiconv)\n"
  return 1
fi

rm -rf "${LIB_INSTALL_PREFIX}" || return 1
mkdir -p "${LIB_INSTALL_PREFIX}/include" "${LIB_INSTALL_PREFIX}/lib" || return 1

cp "${MINGW_LIB_PREFIX}/include/iconv.h" "${LIB_INSTALL_PREFIX}/include/" || return 1
cp "${MINGW_LIB_PREFIX}"/include/libcharset.h "${LIB_INSTALL_PREFIX}/include/" 2>/dev/null
cp "${MINGW_LIB_PREFIX}"/include/localcharset.h "${LIB_INSTALL_PREFIX}/include/" 2>/dev/null
cp "${MINGW_LIB_PREFIX}/lib/libiconv.a" "${LIB_INSTALL_PREFIX}/lib/" || return 1
cp "${MINGW_LIB_PREFIX}/lib/libcharset.a" "${LIB_INSTALL_PREFIX}/lib/" 2>/dev/null

# CREATE PACKAGE CONFIG MANUALLY (libiconv does not ship a .pc)
create_libiconv_package_config "1.18" || return 1
