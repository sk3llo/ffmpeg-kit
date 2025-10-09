#!/bin/bash

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# REMOVED the incorrect PKG_CONFIG_PATH export.
export LDFLAGS="-L/opt/homebrew/opt/libiconv/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libiconv/include"

# REGENERATE BUILD FILES IF NECESSARY OR REQUESTED
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libxml2} -eq 1 ]]; then
  ${SED_INLINE} 's|^AC_PREREQ|#AC_PREREQ|g' "${BASEDIR}"/src/"${LIB_NAME}"/configure.ac || return 1
  ${SED_INLINE} 's|AM_INIT_AUTOMAKE(\[[0-9.]* |AM_INIT_AUTOMAKE(\[|g' "${BASEDIR}"/src/"${LIB_NAME}"/configure.ac || return 1
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

# 3. REMOVED sudo and the problematic --with-iconv flag.
./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${SDK_PATH}" \
  --with-zlib \
  --with-sax1 \
  --without-python \
  --without-debug \
  --without-lzma \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --host="${HOST}" || return 1

# 4. REMOVED sudo from make.
make -j$(get_cpu_count) || return 1

make install || return 1

# CREATE PACKAGE CONFIG MANUALLY
create_libxml2_package_config "2.14.5" || return 1