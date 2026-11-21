#!/bin/bash

# UPDATE BUILD FLAGS
export CFLAGS="$(get_cflags ${LIB_NAME}) -I${SDK_PATH}/usr/include"
export CXXFLAGS=$(get_cxxflags "${LIB_NAME}")
export LDFLAGS="$(get_ldflags ${LIB_NAME}) -L${SDK_PATH}/usr/lib"

export NETTLE_CFLAGS="-I${LIB_INSTALL_BASE}/nettle/include"
export NETTLE_LIBS="-L${LIB_INSTALL_BASE}/nettle/lib -lnettle -L${LIB_INSTALL_BASE}/gmp/lib -lgmp"
export HOGWEED_CFLAGS="-I${LIB_INSTALL_BASE}/nettle/include"
export HOGWEED_LIBS="-L${LIB_INSTALL_BASE}/nettle/lib -lhogweed -L${LIB_INSTALL_BASE}/gmp/lib -lgmp"
export GMP_CFLAGS="-I${LIB_INSTALL_BASE}/gmp/include"
export GMP_LIBS="-L${LIB_INSTALL_BASE}/gmp/lib -lgmp"

build_libtasn1_for_gnutls "${SDK_PATH}" || return 1

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${SDK_PATH}" \
  --with-included-unistring \
  --without-idn \
  --without-p11-kit \
  --enable-hardware-acceleration \
  --enable-static \
  --disable-openssl-compatibility \
  --disable-shared \
  --disable-fast-install \
  --disable-code-coverage \
  --disable-doc \
  --disable-manpages \
  --disable-guile \
  --disable-tests \
  --disable-tools \
  --disable-maintainer-mode \
  --disable-full-test-suite \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
if [[ ${FFMPEG_KIT_BUILD_TYPE} == "macos" ]]; then
  create_gnutls_package_config "3.8.14" "-framework Security" || return 1
else
  create_gnutls_package_config "3.8.14" || return 1
fi
