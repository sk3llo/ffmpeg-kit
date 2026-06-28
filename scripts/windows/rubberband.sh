#!/bin/bash

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# WORKAROUND TO DISABLE OPTIONAL FEATURES MANUALLY, SINCE ./configure DOES NOT PROVIDE OPTIONS FOR THEM.
# THE WINDOWS VARIANTS DROP THE EXTERNAL samplerate/sndfile DEPENDENCIES AND USE THE BUNDLED
# SPEEX RESAMPLER + BUILT-IN FFT, PRODUCING A SELF-CONTAINED STATIC LIBRARY.
overwrite_file "${BASEDIR}"/tools/patch/make/rubberband/configure.windows.ac "${BASEDIR}"/src/"${LIB_NAME}"/configure.ac || return 1
overwrite_file "${BASEDIR}"/tools/patch/make/rubberband/Makefile.windows.in "${BASEDIR}"/src/"${LIB_NAME}"/Makefile.in || return 1

# WORKAROUND TO FIX PACKAGE CONFIG FILE DEPENDENCIES
overwrite_file "${BASEDIR}"/tools/patch/make/rubberband/rubberband.pc.in "${BASEDIR}"/src/"${LIB_NAME}"/rubberband.pc.in || return 1
${SED_INLINE} 's/%DEPENDENCIES%//g' "${BASEDIR}"/src/"${LIB_NAME}"/rubberband.pc.in || return 1

# ALWAYS REGENERATE BUILD FILES - NECESSARY TO APPLY THE WORKAROUNDS
autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --host="${HOST}" || return 1

make AR="$AR" -j$(get_cpu_count) || return 1

make install || return 1

# MANUALLY COPY PKG-CONFIG FILES
cp ./*.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1
