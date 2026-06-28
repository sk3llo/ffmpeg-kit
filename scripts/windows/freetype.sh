#!/bin/bash

# UPDATE BUILD FLAGS - POINT FREETYPE AT THE FFMPEG KIT libpng BUILD
export LIBPNG_CFLAGS="-I${LIB_INSTALL_BASE}/libpng/include"
export LIBPNG_LIBS="-L${LIB_INSTALL_BASE}/libpng/lib -lpng"

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/configure ]] || [[ ${RECONF_freetype} -eq 1 ]]; then

  # NOTE THAT FREETYPE DOES NOT SUPPORT AUTORECONF BUT IT COMES WITH AN autogen.sh
  ./autogen.sh || return 1
fi

overwrite_file "${FFMPEG_KIT_TMPDIR}"/source/config/config.guess "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/config.guess || return 1
overwrite_file "${FFMPEG_KIT_TMPDIR}"/source/config/config.sub "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/config.sub || return 1

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-zlib \
  --with-png \
  --without-harfbuzz \
  --without-bzip2 \
  --with-brotli=no \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_freetype_package_config "25.0.19" || return 1
