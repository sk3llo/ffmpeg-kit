#!/bin/bash

cd "${BASEDIR}"/src/"${LIB_NAME}"/"${LIB_NAME}"/build/generic || return 1

# ASSEMBLY IS DISABLED ON WINDOWS TO AVOID OBJECT FORMAT / RELOCATION ISSUES
# WHEN CROSS-COMPILING WITH THE MINGW-W64 TOOLCHAIN
ASM_OPTIONS="--disable-assembly"

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/"${LIB_NAME}"/build/generic/configure ]] || [[ ${RECONF_xvidcore} -eq 1 ]]; then
  ./bootstrap.sh
fi

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  ${ASM_OPTIONS} \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_xvidcore_package_config "1.3.7" || return 1

# WORKAROUND TO REMOVE DYNAMIC LIBS AND FORCE STATIC LINKING
rm -f "${LIB_INSTALL_PREFIX}"/lib/*.dll
rm -f "${LIB_INSTALL_PREFIX}"/lib/*.dll.a

# xvidcore installs its static archive as xvidcore.a (no lib prefix), but FFmpeg
# links it with -lxvidcore, which needs libxvidcore.a. Provide the prefixed name.
if [ -f "${LIB_INSTALL_PREFIX}/lib/xvidcore.a" ] && [ ! -f "${LIB_INSTALL_PREFIX}/lib/libxvidcore.a" ]; then
  cp "${LIB_INSTALL_PREFIX}/lib/xvidcore.a" "${LIB_INSTALL_PREFIX}/lib/libxvidcore.a"
fi
