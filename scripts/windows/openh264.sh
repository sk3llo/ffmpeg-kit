#!/bin/bash

ASM_OPTIONS=""
OPENH264_ARCH=""
ENABLE_64BIT="Yes"
case ${ARCH} in
x86-64)
  if ! [ -x "$(command -v nasm)" ]; then
    echo -e "\n(*) nasm command not found\n"
    return 1
  fi
  ASM_OPTIONS="ASM=nasm"
  OPENH264_ARCH="x86_64"
  ;;
x86)
  if ! [ -x "$(command -v nasm)" ]; then
    echo -e "\n(*) nasm command not found\n"
    return 1
  fi
  ASM_OPTIONS="ASM=nasm"
  OPENH264_ARCH="x86"
  ENABLE_64BIT="No"
  ;;
arm64)
  ASM_OPTIONS="ASM=gas"
  OPENH264_ARCH="arm64"
  ;;
esac

make clean 2>/dev/null 1>/dev/null

make -j$(get_cpu_count) \
  ARCH=${OPENH264_ARCH} \
  OS=mingw_nt \
  ${ASM_OPTIONS} \
  PREFIX="${LIB_INSTALL_PREFIX}" \
  BUILDTYPE=Release \
  ENABLEPIC=Yes \
  ENABLE64BIT=${ENABLE_64BIT} \
  CC="${CC}" \
  CXX="${CXX}" \
  AR="${AR}" \
  libraries || return 1

make \
  ARCH=${OPENH264_ARCH} \
  OS=mingw_nt \
  PREFIX="${LIB_INSTALL_PREFIX}" \
  install-headers install-static || return 1

cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/openh264.pc "${INSTALL_PKG_CONFIG_DIR}" 2>>"${BASEDIR}"/build.log || return 1
