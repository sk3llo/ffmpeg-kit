#!/bin/bash

# SET BUILD OPTIONS - USE THE NATIVE MINGW TARGETS PROVIDED BY libvpx's configure
TARGET=""
ASM_OPTIONS=""
case ${ARCH} in
x86-64)
  TARGET="x86_64-win64-gcc"
  ASM_OPTIONS="--enable-runtime-cpu-detect"
  ;;
x86)
  TARGET="x86-win32-gcc"
  ASM_OPTIONS="--enable-runtime-cpu-detect"
  ;;
arm64)
  TARGET="arm64-win64-gcc"
  ASM_OPTIONS="--disable-runtime-cpu-detect --enable-neon"
  ;;
esac

# NASM IS USED INSTEAD OF YASM: MSYS2 SHIPS yasm 1.3.0 WHICH CANNOT ASSEMBLE THE
# AVX-512 CODE EMITTED WHEN runtime-cpu-detect IS ON. nasm SUPPORTS IT (AND IS
# ALREADY THE ASSEMBLER USED BY x264/x265/openh264).
case ${ARCH} in
x86-64 | x86)
  if ! [ -x "$(command -v nasm)" ]; then
    echo -e "\n(*) nasm command not found\n"
    return 1
  fi
  ;;
esac

make distclean 2>/dev/null 1>/dev/null

# NOTE THAT RECONFIGURE IS NOT SUPPORTED BY LIBVPX

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --target="${TARGET}" \
  --extra-cflags="${CFLAGS}" \
  --extra-cxxflags="${CXXFLAGS}" \
  --as=nasm \
  --log=yes \
  --enable-libs \
  --enable-install-libs \
  --enable-pic \
  --enable-optimizations \
  --enable-better-hw-compatibility \
  --enable-vp9-highbitdepth \
  ${ASM_OPTIONS} \
  --enable-vp8 \
  --enable-vp9 \
  --enable-multithread \
  --enable-spatial-resampling \
  --enable-small \
  --enable-static \
  --disable-realtime-only \
  --disable-shared \
  --disable-debug \
  --disable-gprof \
  --disable-gcov \
  --disable-ccache \
  --disable-install-bins \
  --disable-install-srcs \
  --disable-install-docs \
  --disable-docs \
  --disable-tools \
  --disable-examples \
  --disable-unit-tests \
  --disable-decode-perf-tests \
  --disable-encode-perf-tests \
  --disable-codec-srcs \
  --disable-debug-libs \
  --disable-internal-stats || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
