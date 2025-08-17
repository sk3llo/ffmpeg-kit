#!/bin/bash

source "${BASEDIR}/scripts/function.sh"

prepare_inline_sed

enable_default_windows_architectures() {
  ENABLED_ARCHITECTURES[ARCH_X86_64]=1
  ENABLED_ARCHITECTURES[ARCH_X86]=1
  ENABLED_ARCHITECTURES[ARCH_ARM64]=1
}

get_ffmpeg_kit_version() {
  local FFMPEG_KIT_VERSION=$(grep -Eo 'FFmpegKitVersion = .*' "${BASEDIR}/windows/src/FFmpegKitConfig.h" 2>>"${BASEDIR}"/build.log | grep -Eo ' ".*' | tr -d '"; ')

  echo "${FFMPEG_KIT_VERSION}"
}

display_help() {
  local COMMAND=$(echo "$0" | sed -e 's/\.\///g')

  echo -e "\n'$COMMAND' builds FFmpegKit for Windows platform. By default three Windows architectures (x86, x86-64, arm64) \
are built without any external libraries enabled. Options can be used to disable architectures and/or \
enable external libraries. Please note that GPL libraries (external libraries with GPL license) need --enable-gpl \
flag to be set explicitly. When compilation ends, libraries are created under the prebuilt folder.\n"
  echo -e "Usage: ./$COMMAND [OPTION]...\n"
  echo -e "Specify environment variables as VARIABLE=VALUE to override default build options.\n"

  display_help_options "  -l, --lts\t\t\tbuild lts packages to support older Windows versions"
  display_help_licensing

  echo -e "Architectures:"
  echo -e "  --disable-x86\t\tdo not build x86 architecture [yes]"
  echo -e "  --disable-x86-64\t\tdo not build x86-64 architecture [yes]"
  echo -e "  --disable-arm64\t\tdo not build arm64 architecture [yes]\n"

  echo -e "Libraries:"
  echo -e "  --full\t\t\tenables all external libraries"
  echo -e "  --enable-windows-media-foundation\tbuild with Windows Media Foundation support [no]"
  echo -e "  --enable-windows-msmpeg4v3\tbuild with Microsoft MPEG-4 v3 support [no]"
  echo -e "  --enable-windows-openssl\tbuild with OpenSSL support [no]"
  echo -e "  --enable-windows-schannel\tbuild with SChannel support [no]"
  echo -e "  --enable-windows-sdl2\tbuild with SDL2 support [no]"
  echo -e "  --enable-windows-zlib\tbuild with zlib support [no]"
  echo -e "  --enable-windows-zlibng\tbuild with zlib-ng support [no]"
  echo -e "  --enable-windows-bzip2\tbuild with bzip2 support [no]"
  echo -e "  --enable-windows-lzma\tbuild with lzma support [no]"
  echo -e "  --enable-windows-iconv\tbuild with iconv support [no]"
}

enable_main_build() {
  ENABLED_LIBRARIES[LIBRARY_CPU_FEATURES]=1
}

enable_lts_build() {
  ENABLED_LIBRARIES[LIBRARY_CPU_FEATURES]=1
}

get_common_includes() {
  echo ""
}

get_common_cflags() {
  echo ""
}

get_arch_specific_cflags() {
  echo ""
}

get_size_optimization_cflags() {
  echo ""
}

get_app_specific_cflags() {
  echo ""
}

get_cflags() {
  echo ""
}

get_cxxflags() {
  echo ""
}

get_common_linked_libraries() {
  echo ""
}

get_arch_specific_ldflags() {
  echo ""
}

get_size_optimization_ldflags() {
  echo ""
}

get_ldflags() {
  echo ""
}

get_build_directory() {
  echo "${BUILD_DIRECTORY}"
}
