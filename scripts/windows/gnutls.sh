#!/bin/bash

# Building gnutls from its git checkout requires bootstrapping with a gnulib
# revision that exactly matches the gnutls tag. On MSYS2 this is fragile
# (gtkdocize, the autopoint gettext archive, and ultimately gnulib-tool failing
# to apply gnutls' local override patches against a mismatched gnulib). MSYS2
# already ships gnutls with a static library, so we stage it and let pkg-config
# resolve the dependency chain (nettle/hogweed/libtasn1/libidn2/brotli/zstd/...).
# The FFmpeg step already has /mingw64/lib/pkgconfig on PKG_CONFIG_PATH, so the
# transitive .pc files we do not build ourselves are found there.

case ${ARCH} in
x86)
  MINGW_LIB_PREFIX="/mingw32"
  ;;
*)
  MINGW_LIB_PREFIX="/mingw64"
  ;;
esac

if [ ! -f "${MINGW_LIB_PREFIX}/lib/libgnutls.a" ] || [ ! -f "${MINGW_LIB_PREFIX}/lib/pkgconfig/gnutls.pc" ]; then
  echo -e "\n(*) system gnutls not found in ${MINGW_LIB_PREFIX} (install mingw-w64-x86_64-gnutls)\n"
  return 1
fi

rm -rf "${LIB_INSTALL_PREFIX}" || return 1
mkdir -p "${LIB_INSTALL_PREFIX}/include" "${LIB_INSTALL_PREFIX}/lib" || return 1

# Stage headers + the static library so library_is_installed() sees gnutls as
# built (the .pc below still points FFmpeg at the system copy + dep chain).
cp -r "${MINGW_LIB_PREFIX}/include/gnutls" "${LIB_INSTALL_PREFIX}/include/" || return 1
cp "${MINGW_LIB_PREFIX}/lib/libgnutls.a" "${LIB_INSTALL_PREFIX}/lib/" || return 1

# Use the system gnutls.pc verbatim: it references ${MINGW_LIB_PREFIX} and lists
# the full Requires/Libs.private chain, which pkg-config resolves at FFmpeg
# configure time.
cp "${MINGW_LIB_PREFIX}/lib/pkgconfig/gnutls.pc" "${INSTALL_PKG_CONFIG_DIR}/gnutls.pc" || return 1

# gnutls.pc Requires transitive deps we do NOT build ourselves. Copy their .pc
# from the system so FFmpeg's pkg-config can resolve the static chain (the
# matching static .a live in ${MINGW_LIB_PREFIX}/lib, referenced via -L in the
# .pc). nettle/hogweed/gmp are provided by our own builds.
for GNUTLS_DEP in libtasn1 libidn2 zlib libbrotlienc libbrotlidec libbrotlicommon libzstd libunistring; do
  if [ -f "${MINGW_LIB_PREFIX}/lib/pkgconfig/${GNUTLS_DEP}.pc" ]; then
    cp "${MINGW_LIB_PREFIX}/lib/pkgconfig/${GNUTLS_DEP}.pc" "${INSTALL_PKG_CONFIG_DIR}/" || return 1
  fi
done
