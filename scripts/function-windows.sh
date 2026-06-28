#!/bin/bash

source "${BASEDIR}/scripts/function.sh"

prepare_inline_sed

enable_default_windows_architectures() {
  ENABLED_ARCHITECTURES[ARCH_X86_64]=1
}

get_ffmpeg_kit_version() {
  local FFMPEG_KIT_VERSION=$(grep -Eo 'FFmpegKitVersion = .*' "${BASEDIR}/windows/src/FFmpegKitConfig.h" 2>>"${BASEDIR}"/build.log | grep -Eo ' \".*' | tr -d '"; ')

  echo "${FFMPEG_KIT_VERSION}"
}

display_help() {
  local COMMAND=$(echo "$0" | sed -e 's/\.\///g')

  echo -e "\n'$COMMAND' builds FFmpegKit for Windows platform. By default one Windows architecture \
(x86-64) is built without any external libraries enabled. Options can be used to enable/disable \
architectures and/or enable external libraries. Please note that GPL libraries (external libraries \
with GPL license) need --enable-gpl flag to be set explicitly. When compilation ends, \
libraries are created under the prebuilt folder.\n"
  echo -e "Usage: ./$COMMAND [OPTION]...\n"
  echo -e "Specify environment variables as VARIABLE=VALUE to override default build options.\n"

  display_help_options "  -l, --lts\t\t\tbuild lts packages to support older Windows versions"
  display_help_licensing

  echo -e "Architectures:"
  echo -e "  --enable-x86\t\t\tbuild x86 (32-bit) architecture [no]"
  echo -e "  --enable-arm64\t\tbuild arm64 (aarch64) architecture [no]"
  echo -e "  --disable-x86-64\t\tdo not build x86-64 architecture [yes]\n"

  echo -e "Libraries:"
  echo -e "  --full\t\t\tenables all external libraries"
  echo -e "  --enable-windows-zlib\t\tbuild with built-in zlib support [no]"
  echo -e "  --enable-windows-dxva2\tbuild with DXVA2 hardware acceleration [no]"
  echo -e "  --enable-windows-d3d11va\tbuild with D3D11VA hardware acceleration [no]"
  echo -e "  --enable-windows-schannel\tbuild with SChannel TLS support [no]"
  echo -e "  --enable-chromaprint\t\tbuild with chromaprint support [no]"
  echo -e "  --enable-dav1d\t\tbuild with dav1d [no]"
  echo -e "  --enable-kvazaar\t\tbuild with kvazaar [no]"
  echo -e "  --enable-libaom\t\tbuild with libaom [no]"
  echo -e "  --enable-libilbc\t\tbuild with libilbc [no]"
  echo -e "  --enable-openh264\t\tbuild with openh264 [no]"
  echo -e "  --enable-openssl\t\tbuild with openssl [no]"
  echo -e "  --enable-srt\t\t\tbuild with srt [no]"
  echo -e "  --enable-zimg\t\t\tbuild with zimg [no]"
  echo -e "  --enable-fontconfig\t\tbuild with fontconfig [no]"
  echo -e "  --enable-freetype\t\tbuild with freetype [no]"
  echo -e "  --enable-fribidi\t\tbuild with fribidi [no]"
  echo -e "  --enable-gmp\t\t\tbuild with gmp [no]"
  echo -e "  --enable-gnutls\t\tbuild with gnutls [no]"
  echo -e "  --enable-lame\t\t\tbuild with lame (libmp3lame) [no]"
  echo -e "  --enable-libass\t\tbuild with libass [no]"
  echo -e "  --enable-libiconv\t\tbuild with libiconv [no]"
  echo -e "  --enable-libtheora\t\tbuild with libtheora [no]"
  echo -e "  --enable-libvorbis\t\tbuild with libvorbis [no]"
  echo -e "  --enable-libvpx\t\tbuild with libvpx [no]"
  echo -e "  --enable-libwebp\t\tbuild with libwebp [no]"
  echo -e "  --enable-libxml2\t\tbuild with libxml2 [no]"
  echo -e "  --enable-opencore-amr\t\tbuild with opencore-amr [no]"
  echo -e "  --enable-opus\t\t\tbuild with opus [no]"
  echo -e "  --enable-shine\t\tbuild with shine [no]"
  echo -e "  --enable-snappy\t\tbuild with snappy [no]"
  echo -e "  --enable-soxr\t\t\tbuild with soxr [no]"
  echo -e "  --enable-speex\t\tbuild with speex [no]"
  echo -e "  --enable-twolame\t\tbuild with twolame [no]\n"

  echo -e "GPL libraries:"
  echo -e "  --enable-libvidstab\t\tbuild with libvidstab [no]"
  echo -e "  --enable-rubberband\t\tbuild with rubber band [no]"
  echo -e "  --enable-x264\t\t\tbuild with x264 [no]"
  echo -e "  --enable-x265\t\t\tbuild with x265 [no]"
  echo -e "  --enable-xvidcore\t\tbuild with xvidcore [no]\n"

  display_help_custom_libraries
  display_help_advanced_options
}

enable_main_build() {
  unset FFMPEG_KIT_LTS_BUILD
}

enable_lts_build() {
  export FFMPEG_KIT_LTS_BUILD="1"
}

install_pkg_config_file() {
  local FILE_NAME="$1"
  local SOURCE="${INSTALL_PKG_CONFIG_DIR}/${FILE_NAME}"
  local DESTINATION="${FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY}/${FILE_NAME}"

  rm -f "$DESTINATION" 2>>"${BASEDIR}"/build.log
  if [[ $? -ne 0 ]]; then
    echo -e "failed\n\nSee build.log for details\n"
    exit 1
  fi

  cp "$SOURCE" "$DESTINATION" 2>>"${BASEDIR}"/build.log
  if [[ $? -ne 0 ]]; then
    echo -e "failed\n\nSee build.log for details\n"
    exit 1
  fi

  ${SED_INLINE} "s|${LIB_INSTALL_BASE}/ffmpeg-kit|${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit|g" "$DESTINATION" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
  ${SED_INLINE} "s|${LIB_INSTALL_BASE}/ffmpeg|${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit|g" "$DESTINATION" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
}

get_bundle_directory() {
  local LTS_POSTFIX=""
  if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
    LTS_POSTFIX="-lts"
  fi

  echo "bundle-windows-$(get_target_cpu)${LTS_POSTFIX}"
}

create_windows_bundle() {
  set_toolchain_paths ""

  # LIB_INSTALL_BASE is exported by main-windows.sh, but that runs in a subshell
  # (windows.sh pipes it through `tee`), so it is not visible here. Re-derive it.
  LIB_INSTALL_BASE="${BASEDIR}/prebuilt/$(get_build_directory)"

  local FFMPEG_KIT_VERSION=$(get_ffmpeg_kit_version)

  local FFMPEG_KIT_BUNDLE_DIRECTORY="${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit"
  local FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY="${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/include"
  local FFMPEG_KIT_BUNDLE_LIB_DIRECTORY="${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/lib"
  local FFMPEG_KIT_BUNDLE_BIN_DIRECTORY="${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/bin"
  local FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY="${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/pkgconfig"

  initialize_folder "${FFMPEG_KIT_BUNDLE_INCLUDE_DIRECTORY}"
  initialize_folder "${FFMPEG_KIT_BUNDLE_LIB_DIRECTORY}"
  initialize_folder "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"
  initialize_folder "${FFMPEG_KIT_BUNDLE_PKG_CONFIG_DIRECTORY}"

  cp -r -P "${LIB_INSTALL_BASE}"/ffmpeg-kit/include/* "${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/include" 2>>"${BASEDIR}"/build.log
  cp -r -P "${LIB_INSTALL_BASE}"/ffmpeg/include/* "${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/include" 2>>"${BASEDIR}"/build.log

  cp -P "${LIB_INSTALL_BASE}"/ffmpeg-kit/lib/lib* "${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/lib" 2>>"${BASEDIR}"/build.log
  cp -P "${LIB_INSTALL_BASE}"/ffmpeg/lib/lib* "${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/lib" 2>>"${BASEDIR}"/build.log

  # COPY DLLs
  cp -P "${LIB_INSTALL_BASE}"/ffmpeg-kit/bin/*.dll "${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/bin" 2>>"${BASEDIR}"/build.log
  cp -P "${LIB_INSTALL_BASE}"/ffmpeg/bin/*.dll "${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/bin" 2>>"${BASEDIR}"/build.log

  # COPY THE FULL RUNTIME DLL CLOSURE.
  #
  # The av* / libffmpegkit DLLs import MinGW runtime DLLs (libgcc/libstdc++/
  # libwinpthread/zlib1) AND any external library the FFmpeg link resolved as a
  # SHARED import rather than a static archive. With the full-gpl set this notably
  # includes the gnutls stack (libgnutls-30, libgmp-10, libnettle/hogweed,
  # libtasn1, libidn2, libp11-kit, libunistring, libffi, libbrotli*, libzstd,
  # libcrypto-3) plus libiconv-2/libintl-8/libmp3lame-0. A fixed list misses
  # these, so resolve the dependency closure with objdump and pull in every
  # imported DLL that lives under the MinGW bin dir (anything else is a Windows
  # system DLL present on the target).
  local MINGW_BIN_DIR
  MINGW_BIN_DIR="$(dirname "$(which "${CC}")")"
  local CLOSURE_CHANGED=1
  while [ ${CLOSURE_CHANGED} -eq 1 ]; do
    CLOSURE_CHANGED=0
    for DLL in "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}"/*.dll; do
      [ -f "${DLL}" ] || continue
      while read -r DEP; do
        if [ -f "${MINGW_BIN_DIR}/${DEP}" ] && [ ! -f "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}/${DEP}" ]; then
          cp -P "${MINGW_BIN_DIR}/${DEP}" "${FFMPEG_KIT_BUNDLE_BIN_DIRECTORY}" 2>>"${BASEDIR}"/build.log
          CLOSURE_CHANGED=1
        fi
      done < <(objdump -p "${DLL}" 2>/dev/null | grep -i "DLL Name" | sed 's/.*DLL Name: //')
    done
  done

  install_pkg_config_file "libavformat.pc"
  install_pkg_config_file "libswresample.pc"
  install_pkg_config_file "libswscale.pc"
  install_pkg_config_file "libavdevice.pc"
  install_pkg_config_file "libavfilter.pc"
  install_pkg_config_file "libavcodec.pc"
  install_pkg_config_file "libavutil.pc"
  install_pkg_config_file "ffmpeg-kit.pc"

  LICENSE_BASEDIR="${BASEDIR}/prebuilt/$(get_bundle_directory)/ffmpeg-kit/lib"
  rm -f "${LICENSE_BASEDIR}"/*.txt 1>>"${BASEDIR}"/build.log 2>&1 || exit 1
  for library in {0..49}; do
    if [[ ${ENABLED_LIBRARIES[$library]} -eq 1 ]]; then
      ENABLED_LIBRARY=$(get_library_name ${library} | sed 's/-/_/g')
      LICENSE_FILE="${LICENSE_BASEDIR}/license_${ENABLED_LIBRARY}.txt"

      RC=$(copy_external_library_license_file ${library} "${LICENSE_FILE}")

      if [[ ${RC} -ne 0 ]]; then
        # Non-fatal: the per-library license filename varies (e.g. gnutls ships
        # COPYING, not LICENSE; staged libs may differ). The authoritative
        # bundle license (LICENSE.GPLv3) is copied below, so a missing
        # per-library copy must not abort an otherwise-complete build.
        echo -e "WARNING: Could not copy the license file of ${ENABLED_LIBRARY}; continuing\n" 1>>"${BASEDIR}"/build.log 2>&1
      else
        echo -e "DEBUG: Copied the license file of ${ENABLED_LIBRARY} successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
      fi
    fi
  done

  for custom_library_index in "${CUSTOM_LIBRARIES[@]}"; do
    library_name="CUSTOM_LIBRARY_${custom_library_index}_NAME"
    relative_license_path="CUSTOM_LIBRARY_${custom_library_index}_LICENSE_FILE"

    destination_license_path="${LICENSE_BASEDIR}/license_${!library_name}.txt"

    cp "${BASEDIR}/src/${!library_name}/${!relative_license_path}" "${destination_license_path}" 1>>"${BASEDIR}"/build.log 2>&1

    RC=$?

    if [[ ${RC} -ne 0 ]]; then
      echo -e "DEBUG: Failed to copy the license file of custom library ${!library_name}\n" 1>>"${BASEDIR}"/build.log 2>&1
      echo -e "failed\n\nSee build.log for details\n"
      exit 1
    fi

    echo -e "DEBUG: Copied the license file of custom library ${!library_name} successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
  done

  if [[ ${GPL_ENABLED} == "yes" ]]; then
    cp "${BASEDIR}"/tools/license/LICENSE.GPLv3 "${LICENSE_BASEDIR}"/license.txt 1>>"${BASEDIR}"/build.log 2>&1 || exit 1
  else
    cp "${BASEDIR}"/LICENSE "${LICENSE_BASEDIR}"/license.txt 1>>"${BASEDIR}"/build.log 2>&1 || exit 1
  fi

  cp "${BASEDIR}"/tools/source/SOURCE "${LICENSE_BASEDIR}"/source.txt 1>>"${BASEDIR}"/build.log 2>&1 || exit 1

  echo -e "DEBUG: Copied the ffmpeg-kit license successfully\n" 1>>"${BASEDIR}"/build.log 2>&1
}

get_cmake_system_processor() {
  case ${ARCH} in
  x86-64)
    echo "x86_64"
    ;;
  x86)
    echo "i686"
    ;;
  arm64)
    echo "aarch64"
    ;;
  esac
}

get_target_cpu() {
  case ${ARCH} in
  x86-64)
    echo "x86_64"
    ;;
  x86)
    echo "i686"
    ;;
  arm64)
    echo "aarch64"
    ;;
  esac
}

get_target() {
  case ${ARCH} in
  x86-64)
    echo "x86_64-w64-mingw32"
    ;;
  x86)
    echo "i686-w64-mingw32"
    ;;
  arm64)
    echo "aarch64-w64-mingw32"
    ;;
  esac
}

get_host() {
  case ${ARCH} in
  x86-64)
    echo "x86_64-w64-mingw32"
    ;;
  x86)
    echo "i686-w64-mingw32"
    ;;
  arm64)
    echo "aarch64-w64-mingw32"
    ;;
  esac
}

get_common_includes() {
  echo ""
}

get_common_cflags() {
  if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
    local LTS_BUILD_FLAG="-DFFMPEG_KIT_LTS "
  fi

  echo "-fstrict-aliasing -DWIN32 -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00 ${LTS_BUILD_FLAG}"
}

get_arch_specific_cflags() {
  case ${ARCH} in
  x86-64)
    echo "-march=x86-64 -msse4.2 -mpopcnt -m64 -DFFMPEG_KIT_X86_64"
    ;;
  x86)
    echo "-march=i686 -mssse3 -mfpmath=sse -m32 -DFFMPEG_KIT_X86"
    ;;
  arm64)
    echo "-DFFMPEG_KIT_ARM64"
    ;;
  esac
}

get_size_optimization_cflags() {
  if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
    case ${ARCH} in
    arm64)
      local LINK_TIME_OPTIMIZATION_FLAGS="-flto=thin"
      ;;
    *)
      local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
      ;;
    esac
  else
    local LINK_TIME_OPTIMIZATION_FLAGS=""
  fi

  local ARCH_OPTIMIZATION=""
  case ${ARCH} in
  x86-64 | x86 | arm64)
    case $1 in
    ffmpeg)
      ARCH_OPTIMIZATION="${LINK_TIME_OPTIMIZATION_FLAGS} -Os -ffunction-sections -fdata-sections"
      ;;
    *)
      ARCH_OPTIMIZATION="-Os -ffunction-sections -fdata-sections"
      ;;
    esac
    ;;
  esac

  echo "${ARCH_OPTIMIZATION}"
}

get_app_specific_cflags() {
  local APP_FLAGS=""
  case $1 in
  ffmpeg)
    APP_FLAGS="-Wno-unused-function"
    ;;
  ffmpeg-kit)
    APP_FLAGS="-Wno-unused-function -Wno-pointer-sign -Wno-switch -Wno-deprecated-declarations"
    ;;
  kvazaar)
    APP_FLAGS="-std=gnu99 -Wno-unused-function"
    ;;
  openh264)
    APP_FLAGS="-std=gnu99 -Wno-unused-function -fstack-protector-all"
    ;;
  openssl | srt)
    APP_FLAGS="-Wno-unused-function"
    ;;
  *)
    APP_FLAGS="-std=c99 -Wno-unused-function"
    ;;
  esac

  echo "${APP_FLAGS}"
}

get_cflags() {
  local ARCH_FLAGS=$(get_arch_specific_cflags)
  local APP_FLAGS=$(get_app_specific_cflags "$1")
  local COMMON_FLAGS=$(get_common_cflags)
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS=$(get_size_optimization_cflags "$1")
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local COMMON_INCLUDES=$(get_common_includes)

  echo "${ARCH_FLAGS} ${APP_FLAGS} ${COMMON_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_INCLUDES}"
}

get_cxxflags() {
  if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
    case ${ARCH} in
    arm64)
      local LINK_TIME_OPTIMIZATION_FLAGS="-flto=thin"
      ;;
    *)
      local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
      ;;
    esac
  else
    local LINK_TIME_OPTIMIZATION_FLAGS=""
  fi

  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS="-Os -ffunction-sections -fdata-sections"
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi

  local BUILD_DATE="-DFFMPEG_KIT_BUILD_DATE=$(date +%Y%m%d 2>>"${BASEDIR}"/build.log)"
  local COMMON_FLAGS="-std=c++17 ${OPTIMIZATION_FLAGS} ${BUILD_DATE} $(get_arch_specific_cflags)"

  case $1 in
  ffmpeg)
    if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
      echo "${LINK_TIME_OPTIMIZATION_FLAGS} -std=c++17 -O2 -ffunction-sections -fdata-sections"
    else
      echo "${FFMPEG_KIT_DEBUG} -std=c++17"
    fi
    ;;
  ffmpeg-kit)
    echo "${COMMON_FLAGS}"
    ;;
  srt | tesseract | zimg)
    echo "${COMMON_FLAGS} -fexceptions"
    ;;
  *)
    echo "${COMMON_FLAGS} -fno-exceptions -fno-rtti"
    ;;
  esac
}

get_common_linked_libraries() {
  local COMMON_LIBRARIES="-lws2_32 -lbcrypt -lcrypt32"

  case $1 in
  chromaprint | ffmpeg-kit | kvazaar | srt | zimg)
    echo "-lstdc++ -lm ${COMMON_LIBRARIES}"
    ;;
  *)
    echo "-lm ${COMMON_LIBRARIES}"
    ;;
  esac
}

get_size_optimization_ldflags() {
  if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
    case ${ARCH} in
    arm64)
      local LINK_TIME_OPTIMIZATION_FLAGS="-flto=thin"
      ;;
    *)
      local LINK_TIME_OPTIMIZATION_FLAGS="-flto"
      ;;
    esac
  else
    local LINK_TIME_OPTIMIZATION_FLAGS=""
  fi

  case ${ARCH} in
  x86-64 | x86 | arm64)
    case $1 in
    ffmpeg)
      echo "${LINK_TIME_OPTIMIZATION_FLAGS} -O2 -ffunction-sections -fdata-sections -finline-functions"
      ;;
    *)
      echo "-Os -ffunction-sections -fdata-sections"
      ;;
    esac
    ;;
  esac
}

get_arch_specific_ldflags() {
  case ${ARCH} in
  x86-64)
    echo "-march=x86-64 -Wl,--default-image-base-low"
    ;;
  x86)
    echo "-march=i686 -m32"
    ;;
  arm64)
    echo "-Wl,--default-image-base-low"
    ;;
  esac
}

get_ldflags() {
  local ARCH_FLAGS=$(get_arch_specific_ldflags)
  if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
    local OPTIMIZATION_FLAGS="$(get_size_optimization_ldflags "$1")"
  else
    local OPTIMIZATION_FLAGS="${FFMPEG_KIT_DEBUG}"
  fi
  local COMMON_LINKED_LIBS=$(get_common_linked_libraries "$1")

  echo "${ARCH_FLAGS} ${OPTIMIZATION_FLAGS} ${COMMON_LINKED_LIBS}"
}

create_mason_cross_file() {
  local WIN_PREFIX
  WIN_PREFIX=$(cygpath -m "${LIB_INSTALL_PREFIX}")
  cat >"$1" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
pkgconfig = 'pkg-config'

[properties]
has_function_printf = true

[host_machine]
system = 'windows'
cpu_family = '$(get_meson_target_cpu_family)'
cpu = '$(get_cmake_system_processor)'
endian = 'little'

[built-in options]
default_library = 'static'
prefix = '${WIN_PREFIX}'
EOF
}

create_chromaprint_package_config() {
  local CHROMAPRINT_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/libchromaprint.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/chromaprint
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: chromaprint
Description: Audio fingerprint library
URL: http://acoustid.org/chromaprint
Version: ${CHROMAPRINT_VERSION}
Libs: -L\${libdir} -lchromaprint -lstdc++
Cflags: -I\${includedir} -DCHROMAPRINT_NODLL
EOF
}

create_ffmpegkit_package_config() {
  local FFMPEGKIT_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/ffmpeg-kit.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/ffmpeg-kit
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: ffmpeg-kit
Description: FFmpeg for applications
Version: ${FFMPEGKIT_VERSION}

Libs: -L\${libdir} -lstdc++ -lffmpegkit -lavutil
Requires: libavfilter, libswscale, libavformat, libavcodec, libswresample, libavutil
Cflags: -I\${includedir}
EOF
}

create_libaom_package_config() {
  local AOM_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/aom.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libaom
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: aom
Description: AV1 codec library v${AOM_VERSION}.
Version: ${AOM_VERSION}

Requires:
Libs: -L\${libdir} -laom -lm
Cflags: -I\${includedir}
EOF
}

create_x265_package_config() {
  local X265_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/x265.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/x265
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC video encoder
Version: ${X265_VERSION}

Libs: -L\${libdir} -lx265
Libs.private: -lstdc++ -lm
Cflags: -I\${includedir}
EOF
}

create_xvidcore_package_config() {
  local XVIDCORE_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/xvidcore.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/xvidcore
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: xvidcore
Description: the main MPEG-4 de-/encoding library
Version: ${XVIDCORE_VERSION}

Requires:
Libs: -L\${libdir}
Cflags: -I\${includedir}
EOF
}

create_vidstab_package_config() {
  local VIDSTAB_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/vidstab.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libvidstab
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: vidstab
Description: a library for stabilizing video clips
Version: ${VIDSTAB_VERSION}

Libs: -L\${libdir} -lvidstab
Libs.private: -lm
Cflags: -I\${includedir}
EOF
}

create_srt_package_config() {
  local SRT_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/srt.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/srt
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: srt
Description: SRT library set
Version: ${SRT_VERSION}

Libs: -L\${libdir} -lsrt -lm -lstdc++ -lws2_32
Cflags: -I\${includedir} -I\${includedir}/srt
Requires: openssl libcrypto
EOF
}

create_zimg_package_config() {
  local ZIMG_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/zimg.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/zimg
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zimg
Description: Scaling, colorspace conversion, and dithering library
Version: ${ZIMG_VERSION}

Libs: -L\${libdir} -lzimg -lstdc++
Cflags: -I\${includedir}
EOF
}

create_libmp3lame_package_config() {
  local LAME_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/libmp3lame.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/lame
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: lame mp3 encoder library
Version: ${LAME_VERSION}

Requires:
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
EOF
}

create_libvorbis_package_config() {
  local LIBVORBIS_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/vorbis.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libvorbis
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: vorbis
Description: vorbis is the primary Ogg Vorbis library
Version: ${LIBVORBIS_VERSION}

Requires: ogg
Libs: -L\${libdir} -lvorbis -lm
Cflags: -I\${includedir}
EOF

  cat >"${INSTALL_PKG_CONFIG_DIR}/vorbisenc.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libvorbis
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: vorbisenc
Description: vorbisenc is a library that provides a convenient API for setting up an encoding environment using libvorbis
Version: ${LIBVORBIS_VERSION}

Requires: vorbis
Conflicts:
Libs: -L\${libdir} -lvorbisenc
Cflags: -I\${includedir}
EOF

  cat >"${INSTALL_PKG_CONFIG_DIR}/vorbisfile.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libvorbis
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: vorbisfile
Description: vorbisfile is a library that provides a convenient high-level API for decoding and basic manipulation of all Vorbis I audio streams
Version: ${LIBVORBIS_VERSION}

Requires: vorbis
Conflicts:
Libs: -L\${libdir} -lvorbisfile
Cflags: -I\${includedir}
EOF
}

create_soxr_package_config() {
  local SOXR_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/soxr.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/soxr
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: soxr
Description: High quality, one-dimensional sample-rate conversion library
Version: ${SOXR_VERSION}

Requires:
Libs: -L\${libdir} -lsoxr
Cflags: -I\${includedir}
EOF
}

create_snappy_package_config() {
  local SNAPPY_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/snappy.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/snappy
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: snappy
Description: a fast compressor/decompressor
Version: ${SNAPPY_VERSION}

Requires:
Libs: -L\${libdir} -lsnappy -lstdc++
Cflags: -I\${includedir}
EOF
}

create_libiconv_package_config() {
  local LIBICONV_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/libiconv.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libiconv
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libiconv
Description: Character set conversion library
Version: ${LIBICONV_VERSION}

Requires:
Libs: -L\${libdir} -liconv -lcharset
Cflags: -I\${includedir}
EOF
}

create_libpng_package_config() {
  local LIBPNG_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/libpng.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libpng
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libpng
Description: Loads and saves PNG files
Version: ${LIBPNG_VERSION}
Requires:
Cflags: -I\${includedir}
Libs: -L\${libdir} -lpng
Libs.private: -lz
EOF
}

create_freetype_package_config() {
  local FREETYPE_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/freetype2.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/freetype
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: FreeType 2
URL: https://freetype.org
Description: A free, high-quality, and portable font engine.
Version: ${FREETYPE_VERSION}
Requires: libpng
Requires.private:
Libs: -L\${libdir} -lfreetype
Libs.private:
Cflags: -I\${includedir}/freetype2
EOF
}

create_fontconfig_package_config() {
  local FONTCONFIG_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/fontconfig.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/fontconfig
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
sysconfdir=\${prefix}/etc
localstatedir=\${prefix}/var
PACKAGE=fontconfig
confdir=\${sysconfdir}/fonts
cachedir=\${localstatedir}/cache/\${PACKAGE}

Name: Fontconfig
Description: Font configuration and customization library
Version: ${FONTCONFIG_VERSION}
Requires:  freetype2 >= 21.0.15, expat >= 2.2.0, libiconv
Requires.private:
Libs: -L\${libdir} -lfontconfig
Libs.private:
Cflags: -I\${includedir}
EOF
}

create_gmp_package_config() {
  local GMP_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/gmp.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/gmp
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: gmp
Description: gnu mp library
Version: ${GMP_VERSION}

Requires:
Libs: -L\${libdir} -lgmp
Cflags: -I\${includedir}
EOF
}

create_gnutls_package_config() {
  local GNUTLS_VERSION="$1"
  local EXTRA_LIBS="$2"

  cat >"${INSTALL_PKG_CONFIG_DIR}/gnutls.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/gnutls
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: gnutls
Description: GNU TLS Implementation

Version: ${GNUTLS_VERSION}
Requires: nettle, hogweed
Cflags: -I\${includedir}
Libs: -L\${libdir} -lgnutls ${EXTRA_LIBS}
Libs.private: -lgmp
EOF
}

create_libxml2_package_config() {
  local LIBXML2_VERSION="$1"

  cat >"${INSTALL_PKG_CONFIG_DIR}/libxml-2.0.pc" <<EOF
prefix=${LIB_INSTALL_BASE}/libxml2
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
modules=1

Name: libXML
Version: ${LIBXML2_VERSION}
Description: libXML library version2.
Requires: libiconv
Libs: -L\${libdir} -lxml2
Libs.private:   -lz -lm
Cflags: -I\${includedir} -I\${includedir}/libxml2
EOF
}

get_build_directory() {
  local LTS_POSTFIX=""
  if [[ -n ${FFMPEG_KIT_LTS_BUILD} ]]; then
    LTS_POSTFIX="-lts"
  fi

  echo "windows-$(get_target_cpu)${LTS_POSTFIX}"
}

set_toolchain_paths() {
  HOST=$(get_host)

  case ${ARCH} in
  # NOTE: in a native MSYS2 MINGW shell only gcc/g++ are published with the
  # x86_64-w64-mingw32- / i686-w64-mingw32- prefix; the binutils tools (as, ar,
  # ld, ranlib, strip, nm, windres) exist ONLY unprefixed in /mingw64/bin (they
  # ARE the target tools). Using the prefixed names for them points at missing
  # binaries and breaks any autoreconf'd configure that invokes $AR/$RANLIB
  # (e.g. automake's AM_PROG_AR -> "could not determine ar interface").
  x86-64)
    export CC="x86_64-w64-mingw32-gcc"
    export CXX="x86_64-w64-mingw32-g++"
    export AS="as"
    export AR="ar"
    export LD="ld"
    export RANLIB="ranlib"
    export STRIP="strip"
    export NM="nm"
    export WINDRES="windres"
    ;;
  x86)
    export CC="i686-w64-mingw32-gcc"
    export CXX="i686-w64-mingw32-g++"
    export AS="as"
    export AR="ar"
    export LD="ld"
    export RANLIB="ranlib"
    export STRIP="strip"
    export NM="nm"
    export WINDRES="windres"
    ;;
  arm64)
    export CC="aarch64-w64-mingw32-clang"
    export CXX="aarch64-w64-mingw32-clang++"
    export AS="aarch64-w64-mingw32-as"
    export AR="llvm-ar"
    export LD="lld"
    export RANLIB="llvm-ranlib"
    export STRIP="llvm-strip"
    export NM="llvm-nm"
    export WINDRES="aarch64-w64-mingw32-windres"
    ;;
  esac

  export INSTALL_PKG_CONFIG_DIR="${BASEDIR}"/prebuilt/$(get_build_directory)/pkgconfig

  if [ ! -d "${INSTALL_PKG_CONFIG_DIR}" ]; then
    mkdir -p "${INSTALL_PKG_CONFIG_DIR}" 1>>"${BASEDIR}"/build.log 2>&1
  fi
}
