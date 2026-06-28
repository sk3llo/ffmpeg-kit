#!/bin/bash

# HARFBUZZ >= 6.0 DROPPED AUTOTOOLS AND IS BUILT WITH MESON (LIKE dav1d).
CROSS_FILE="${BASEDIR}"/src/"${LIB_NAME}"/$ARCH-$FFMPEG_KIT_BUILD_TYPE.meson

create_mason_cross_file "$CROSS_FILE" || return 1

rm -rf "${BUILD_DIR}" || return 1

# freetype IS RESOLVED VIA pkg-config (freetype2.pc INSTALLED BY THE freetype STEP);
# run-windows.sh ALREADY EXPORTS PKG_CONFIG_LIBDIR=${INSTALL_PKG_CONFIG_DIR}.
meson "${BUILD_DIR}" \
  --cross-file="$CROSS_FILE" \
  -Db_lto=false \
  -Ddefault_library=static \
  -Dfreetype=enabled \
  -Dglib=disabled \
  -Dgobject=disabled \
  -Dcairo=disabled \
  -Dicu=disabled \
  -Dgraphite=disabled \
  -Dtests=disabled \
  -Ddocs=disabled \
  -Dutilities=disabled \
  -Dbenchmark=disabled || return 1

cd "${BUILD_DIR}" || return 1

ninja -j$(get_cpu_count) || return 1

ninja install || return 1

cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/harfbuzz.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
