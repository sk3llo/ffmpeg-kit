#!/bin/bash

# SET BUILD OPTIONS
ASM_OPTIONS=""
case ${ARCH} in
arm*)
  ASM_OPTIONS="--enable-arm-neon"
  ;;
i386 | x86-64*)
  ASM_OPTIONS="--enable-x86-aesni"
  ;;
esac

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# UPDATE CONFIG FILES TO SUPPORT APPLE ARCHITECTURES
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
  ${ASM_OPTIONS} \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# MANUALLY COPY PKG-CONFIG FILES
cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
