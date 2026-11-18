#!/bin/bash

# SET BUILD FLAGS
CROSS_FILE="${BASEDIR}"/src/"${LIB_NAME}"/package/crossfiles/$ARCH-$FFMPEG_KIT_BUILD_TYPE.meson

mkdir -p "$(dirname "$CROSS_FILE")" || return 1
create_mason_cross_file "$CROSS_FILE" || return 1

# Rubber Band uses size_t without including <stddef.h>. src/common/sysutils.h,
# its common header, includes only <stdint.h> and <math.h>, and Xcode 27's
# libc++ no longer declares size_t through either.
git checkout src/common/sysutils.h 1>>"${BASEDIR}"/build.log 2>&1 || return 1
${SED_INLINE} '/^#include <math.h>$/a\
#include <stddef.h>
' "${BASEDIR}"/src/"${LIB_NAME}"/src/common/sysutils.h || return 1

# ALWAYS CLEAN THE PREVIOUS BUILD
rm -rf "${BUILD_DIR}" || return 1

"${MESON:-meson}" setup "${BUILD_DIR}" \
  --cross-file="$CROSS_FILE" \
  --buildtype=release \
  --default-library=static \
  -Db_staticpic=true \
  -Db_lto=false \
  -Db_ndebug=if-release \
  -Dfft=vdsp \
  -Dresampler=libsamplerate \
  -Dcmdline=disabled \
  -Djni=disabled \
  -Dvamp=disabled \
  -Dladspa=disabled \
  -Dlv2=disabled \
  -Dtests=disabled || return 1

cd "${BUILD_DIR}" || return 1

ninja -j$(get_cpu_count) || return 1

ninja install || return 1

# MANUALLY COPY PKG-CONFIG FILES
cp "${BUILD_DIR}"/meson-private/rubberband.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
