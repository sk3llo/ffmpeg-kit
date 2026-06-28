#!/bin/bash

ASM_OPTIONS=""
DEBUG_OPTIONS=""
case ${ARCH} in
x86-64)
  if ! [ -x "$(command -v nasm)" ]; then
    echo -e "\n(*) nasm command not found\n"
    return 1
  fi
  export AS="$(command -v nasm)"
  ;;
x86)
  if ! [ -x "$(command -v nasm)" ]; then
    echo -e "\n(*) nasm command not found\n"
    return 1
  fi
  export AS="$(command -v nasm)"
  ;;
arm64)
  ASM_OPTIONS="--disable-asm"
  ;;
esac
if [[ -n ${FFMPEG_KIT_DEBUG} ]]; then
  DEBUG_OPTIONS="--enable-debug"
fi

make distclean 2>/dev/null 1>/dev/null

if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_x264} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --enable-pic \
  --enable-static \
  --disable-cli \
  ${ASM_OPTIONS} \
  ${DEBUG_OPTIONS} \
  --host="${HOST}" \
  --cross-prefix="${HOST}-" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp x264.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
