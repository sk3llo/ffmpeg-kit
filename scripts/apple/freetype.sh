#!/bin/bash

# UPDATE BUILD FLAGS
export LIBPNG_CFLAGS="-I${LIB_INSTALL_BASE}/libpng/include"
export LIBPNG_LIBS="-L${LIB_INSTALL_BASE}/libpng/lib"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/configure ]] || [[ ${RECONF_freetype} -eq 1 ]]; then

  # NOTE THAT FREETYPE DOES NOT SUPPORT AUTORECONF BUT IT COMES WITH AN autogen.sh
  ./autogen.sh || return 1
fi

# UPDATE CONFIG FILES TO SUPPORT APPLE ARCHITECTURES
overwrite_file "${FFMPEG_KIT_TMPDIR}"/source/config/config.guess "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/config.guess || return 1
overwrite_file "${FFMPEG_KIT_TMPDIR}"/source/config/config.sub "${BASEDIR}"/src/"${LIB_NAME}"/builds/unix/config.sub || return 1

# FreeType 2.15 builds its HVF driver whenever the SDK has hvf/Scaler.h, and the driver needs
# /usr/lib/libhvf.dylib (macOS 15.4, iOS 18.4 and later). freetype2.pc here doesn't list -lhvf,
# so every link against libfreetype.a fails; the cache variable keeps the driver out.
ac_cv_header_hvf_Scaler_h=no \
./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-zlib \
  --with-png \
  --with-sysroot="${SDK_PATH}" \
  --without-harfbuzz \
  --without-bzip2 \
  --without-fsref \
  --without-quickdraw-toolbox \
  --without-quickdraw-carbon \
  --without-ats \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-mmap \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_freetype_package_config "26.7.20" || return 1
