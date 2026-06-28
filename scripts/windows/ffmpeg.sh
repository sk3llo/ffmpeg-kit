#!/bin/bash

HOST_PKG_CONFIG_PATH=$(command -v pkg-config)
if [ -z "${HOST_PKG_CONFIG_PATH}" ]; then
  echo -e "\n(*) pkg-config command not found\n"
  exit 1
fi

LIB_NAME="ffmpeg"

echo -e "----------------------------------------------------------------" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "\nINFO: Building ${LIB_NAME} for ${HOST} with the following environment variables\n" 1>>"${BASEDIR}"/build.log 2>&1
env 1>>"${BASEDIR}"/build.log 2>&1
echo -e "----------------------------------------------------------------\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "INFO: System information\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "INFO: $(uname -a)\n" 1>>"${BASEDIR}"/build.log 2>&1
echo -e "----------------------------------------------------------------\n" 1>>"${BASEDIR}"/build.log 2>&1

FFMPEG_LIBRARY_PATH="${LIB_INSTALL_BASE}/${LIB_NAME}"

set_toolchain_paths "${LIB_NAME}"

HOST=$(get_host)
export CFLAGS=$(get_cflags "${LIB_NAME}")
export CXXFLAGS=$(get_cxxflags "${LIB_NAME}")
export LDFLAGS=$(get_ldflags "${LIB_NAME}")
export PKG_CONFIG_PATH="${INSTALL_PKG_CONFIG_DIR}:$(pkg-config --variable pc_path pkg-config 2>/dev/null)"
export PKG_CONFIG_DONT_DEFINE_PREFIX=1

echo -e "\nINFO: Using PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}\n" 1>>"${BASEDIR}"/build.log 2>&1

cd "${BASEDIR}"/src/"${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1

TARGET_CPU=""
TARGET_ARCH=""
ASM_OPTIONS=""
case ${ARCH} in
x86-64)
  TARGET_CPU="x86-64"
  TARGET_ARCH="x86_64"
  ASM_OPTIONS=" --disable-neon --enable-asm --enable-inline-asm"
  ;;
x86)
  TARGET_CPU="i686"
  TARGET_ARCH="x86"
  ASM_OPTIONS=" --disable-neon --enable-asm --enable-inline-asm"
  ;;
arm64)
  TARGET_CPU="armv8-a"
  TARGET_ARCH="aarch64"
  ASM_OPTIONS=" --enable-neon --enable-asm --enable-inline-asm"
  ;;
esac

CONFIGURE_POSTFIX=""
HIGH_PRIORITY_INCLUDES=""

# External-library link flags are accumulated here and passed via --extra-libs
# (NOT --extra-ldflags). FFmpeg places --extra-libs in FFEXTRALIBS, which appears
# AFTER the object files on the link line - required for static linking so the
# objects' symbols resolve against the libraries (e.g. libiconv_open, BCrypt*).
# --extra-libs is also used in configure's link tests, so a C++-only library
# whose .pc omits -lstdc++ (e.g. libilbc) still detects, courtesy of the -lstdc++
# contributed by the other C++ libraries in the combined set.
FFKIT_EXTRALIBS=""

for library in {0..99}; do
  if [[ ${ENABLED_LIBRARIES[$library]} -eq 1 ]]; then
    ENABLED_LIBRARY=$(get_library_name ${library})

    echo -e "INFO: Enabling library ${ENABLED_LIBRARY}\n" 1>>"${BASEDIR}"/build.log 2>&1

    case ${ENABLED_LIBRARY} in
    windows-zlib)
      CONFIGURE_POSTFIX+=" --enable-zlib"
      ;;
    windows-dxva2)
      CONFIGURE_POSTFIX+=" --enable-dxva2"
      ;;
    windows-d3d11va)
      CONFIGURE_POSTFIX+=" --enable-d3d11va"
      ;;
    windows-schannel)
      if [[ ${CONFIGURE_POSTFIX} != *"--enable-openssl"* ]]; then
        CONFIGURE_POSTFIX+=" --enable-schannel"
      fi
      ;;
    chromaprint)
      CFLAGS+=" $(pkg-config --cflags libchromaprint 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libchromaprint 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-chromaprint"
      ;;
    dav1d)
      CFLAGS+=" $(pkg-config --cflags dav1d 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static dav1d 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libdav1d"
      ;;
    kvazaar)
      CFLAGS+=" $(pkg-config --cflags kvazaar 2>>"${BASEDIR}"/build.log) -DKVZ_STATIC_LIB"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static kvazaar 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libkvazaar"
      ;;
    libilbc)
      CFLAGS+=" $(pkg-config --cflags libilbc 2>>"${BASEDIR}"/build.log)"
      # libilbc is C++ but its .pc omits -lstdc++. In variants that also pull a
      # C++ codec (e.g. x265 in min-gpl/full*) the combined set supplies -lstdc++,
      # but the `audio` variant has no other C++ lib, so add it explicitly here.
      # It must follow -lilbc on the static link line; dedupe_keep_last preserves
      # this order if another C++ lib appends -lstdc++ later.
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libilbc 2>>"${BASEDIR}"/build.log) -lstdc++"
      CONFIGURE_POSTFIX+=" --enable-libilbc"
      ;;
    libaom)
      CFLAGS+=" $(pkg-config --cflags aom 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static aom 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libaom"
      ;;
    openh264)
      CFLAGS+=" $(pkg-config --cflags openh264 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static openh264 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libopenh264"
      ;;
    openssl)
      # FFmpeg refuses --enable-gnutls and --enable-openssl together. When both
      # libraries are built (e.g. full/full-gpl, where gnutls is required for the
      # package signature and openssl is still needed by libsrt), gnutls wins as
      # FFmpeg's TLS backend; openssl is left to libsrt (pulled in via srt.pc).
      if [[ ${ENABLED_LIBRARIES[$LIBRARY_GNUTLS]} -eq 1 ]]; then
        echo -e "INFO: gnutls enabled; not adding --enable-openssl (openssl kept for libsrt)\n" 1>>"${BASEDIR}"/build.log 2>&1
      else
        CFLAGS+=" $(pkg-config --cflags openssl 2>>"${BASEDIR}"/build.log)"
        FFKIT_EXTRALIBS+=" $(pkg-config --libs --static openssl 2>>"${BASEDIR}"/build.log)"
        CONFIGURE_POSTFIX+=" --enable-openssl"
      fi
      ;;
    srt)
      CFLAGS+=" $(pkg-config --cflags srt 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static srt 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libsrt"
      ;;
    x264)
      CFLAGS+=" $(pkg-config --cflags x264 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static x264 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libx264"
      ;;
    x265)
      CFLAGS+=" $(pkg-config --cflags x265 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static x265 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libx265"
      ;;
    xvidcore)
      CFLAGS+=" $(pkg-config --cflags xvidcore 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static xvidcore 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libxvid"
      ;;
    libvidstab)
      CFLAGS+=" $(pkg-config --cflags vidstab 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static vidstab 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libvidstab"
      ;;
    rubberband)
      CFLAGS+=" $(pkg-config --cflags rubberband 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static rubberband 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-librubberband"
      ;;
    zimg)
      CFLAGS+=" $(pkg-config --cflags zimg 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static zimg 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libzimg"
      ;;
    fontconfig)
      CFLAGS+=" $(pkg-config --cflags fontconfig 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static fontconfig 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libfontconfig"
      ;;
    freetype)
      CFLAGS+=" $(pkg-config --cflags freetype2 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static freetype2 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libfreetype"
      ;;
    fribidi)
      CFLAGS+=" $(pkg-config --cflags fribidi 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static fribidi 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libfribidi"
      ;;
    gmp)
      CFLAGS+=" $(pkg-config --cflags gmp 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static gmp 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-gmp"
      ;;
    gnutls)
      CFLAGS+=" $(pkg-config --cflags gnutls 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static gnutls 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-gnutls"
      ;;
    lame)
      CFLAGS+=" $(pkg-config --cflags libmp3lame 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libmp3lame 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libmp3lame"
      ;;
    libass)
      CFLAGS+=" $(pkg-config --cflags libass 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libass 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libass"
      ;;
    libiconv)
      CFLAGS+=" $(pkg-config --cflags libiconv 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libiconv 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-iconv"
      ;;
    libtheora)
      CFLAGS+=" $(pkg-config --cflags theora 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static theora 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libtheora"
      ;;
    libvorbis)
      CFLAGS+=" $(pkg-config --cflags vorbis 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static vorbis 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libvorbis"
      ;;
    libvpx)
      CFLAGS+=" $(pkg-config --cflags vpx 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static vpx 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libvpx"
      ;;
    libwebp)
      CFLAGS+=" $(pkg-config --cflags libwebp 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libwebp 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libwebp"
      ;;
    libxml2)
      # libxml2 headers default to __declspec(dllimport); LIBXML_STATIC selects the
      # static declarations (otherwise: undefined reference to __imp_xmlCheckVersion).
      CFLAGS+=" $(pkg-config --cflags libxml-2.0 2>>"${BASEDIR}"/build.log) -DLIBXML_STATIC"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static libxml-2.0 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libxml2"
      ;;
    opencore-amr)
      CFLAGS+=" $(pkg-config --cflags opencore-amrnb 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static opencore-amrnb 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libopencore-amrnb --enable-libopencore-amrwb"
      ;;
    shine)
      CFLAGS+=" $(pkg-config --cflags shine 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static shine 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libshine"
      ;;
    speex)
      CFLAGS+=" $(pkg-config --cflags speex 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static speex 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libspeex"
      ;;
    opus)
      CFLAGS+=" $(pkg-config --cflags opus 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static opus 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libopus"
      ;;
    snappy)
      CFLAGS+=" $(pkg-config --cflags snappy 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static snappy 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libsnappy"
      ;;
    soxr)
      CFLAGS+=" $(pkg-config --cflags soxr 2>>"${BASEDIR}"/build.log)"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static soxr 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libsoxr"
      ;;
    twolame)
      # twolame.h defaults to __declspec(dllimport); define LIBTWOLAME_STATIC so
      # the static archive links (otherwise: undefined reference to __imp_twolame_*).
      CFLAGS+=" $(pkg-config --cflags twolame 2>>"${BASEDIR}"/build.log) -DLIBTWOLAME_STATIC"
      FFKIT_EXTRALIBS+=" $(pkg-config --libs --static twolame 2>>"${BASEDIR}"/build.log)"
      CONFIGURE_POSTFIX+=" --enable-libtwolame"
      ;;
    esac
  else
    if [[ ${library} -eq ${LIBRARY_SYSTEM_ZLIB} ]]; then
      CONFIGURE_POSTFIX+=" --disable-zlib"
    elif [[ ${library} -eq ${LIBRARY_CHROMAPRINT} ]]; then
      CONFIGURE_POSTFIX+=" --disable-chromaprint"
    elif [[ ${library} -eq ${LIBRARY_DAV1D} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libdav1d"
    elif [[ ${library} -eq ${LIBRARY_KVAZAAR} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libkvazaar"
    elif [[ ${library} -eq ${LIBRARY_LIBILBC} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libilbc"
    elif [[ ${library} -eq ${LIBRARY_LIBAOM} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libaom"
    elif [[ ${library} -eq ${LIBRARY_OPENH264} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libopenh264"
    elif [[ ${library} -eq ${LIBRARY_OPENSSL} ]]; then
      CONFIGURE_POSTFIX+=" --disable-openssl"
    elif [[ ${library} -eq ${LIBRARY_SRT} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libsrt"
    elif [[ ${library} -eq ${LIBRARY_X264} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libx264"
    elif [[ ${library} -eq ${LIBRARY_X265} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libx265"
    elif [[ ${library} -eq ${LIBRARY_XVIDCORE} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libxvid"
    elif [[ ${library} -eq ${LIBRARY_LIBVIDSTAB} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libvidstab"
    elif [[ ${library} -eq ${LIBRARY_RUBBERBAND} ]]; then
      CONFIGURE_POSTFIX+=" --disable-librubberband"
    elif [[ ${library} -eq ${LIBRARY_ZIMG} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libzimg"
    elif [[ ${library} -eq ${LIBRARY_FONTCONFIG} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libfontconfig"
    elif [[ ${library} -eq ${LIBRARY_FREETYPE} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libfreetype"
    elif [[ ${library} -eq ${LIBRARY_FRIBIDI} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libfribidi"
    elif [[ ${library} -eq ${LIBRARY_GMP} ]]; then
      CONFIGURE_POSTFIX+=" --disable-gmp"
    elif [[ ${library} -eq ${LIBRARY_GNUTLS} ]]; then
      CONFIGURE_POSTFIX+=" --disable-gnutls"
    elif [[ ${library} -eq ${LIBRARY_LAME} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libmp3lame"
    elif [[ ${library} -eq ${LIBRARY_LIBASS} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libass"
    elif [[ ${library} -eq ${LIBRARY_LIBICONV} ]]; then
      CONFIGURE_POSTFIX+=" --disable-iconv"
    elif [[ ${library} -eq ${LIBRARY_LIBTHEORA} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libtheora"
    elif [[ ${library} -eq ${LIBRARY_LIBVORBIS} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libvorbis"
    elif [[ ${library} -eq ${LIBRARY_LIBVPX} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libvpx"
    elif [[ ${library} -eq ${LIBRARY_LIBWEBP} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libwebp"
    elif [[ ${library} -eq ${LIBRARY_LIBXML2} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libxml2"
    elif [[ ${library} -eq ${LIBRARY_OPENCOREAMR} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libopencore-amrnb --disable-libopencore-amrwb"
    elif [[ ${library} -eq ${LIBRARY_SHINE} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libshine"
    elif [[ ${library} -eq ${LIBRARY_SPEEX} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libspeex"
    elif [[ ${library} -eq ${LIBRARY_OPUS} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libopus"
    elif [[ ${library} -eq ${LIBRARY_SNAPPY} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libsnappy"
    elif [[ ${library} -eq ${LIBRARY_SOXR} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libsoxr"
    elif [[ ${library} -eq ${LIBRARY_TWOLAME} ]]; then
      CONFIGURE_POSTFIX+=" --disable-libtwolame"
    fi
  fi
done

for custom_library_index in "${CUSTOM_LIBRARIES[@]}"; do
  library_name="CUSTOM_LIBRARY_${custom_library_index}_NAME"
  pc_file_name="CUSTOM_LIBRARY_${custom_library_index}_PACKAGE_CONFIG_FILE_NAME"
  ffmpeg_flag_name="CUSTOM_LIBRARY_${custom_library_index}_FFMPEG_ENABLE_FLAG"

  echo -e "INFO: Enabling custom library ${!library_name}\n" 1>>"${BASEDIR}"/build.log 2>&1

  CFLAGS+=" $(pkg-config --cflags ${!pc_file_name} 2>>"${BASEDIR}"/build.log)"
  FFKIT_EXTRALIBS+=" $(pkg-config --libs --static ${!pc_file_name} 2>>"${BASEDIR}"/build.log)"
  CONFIGURE_POSTFIX+=" --enable-${!ffmpeg_flag_name}"
done

if [ "$GPL_ENABLED" == "yes" ]; then
  CONFIGURE_POSTFIX+=" --enable-gpl"
fi

BUILD_LIBRARY_OPTIONS="--disable-static --enable-shared"

if [[ -z ${FFMPEG_KIT_OPTIMIZED_FOR_SPEED} ]]; then
  SIZE_OPTIONS="--enable-small"
else
  SIZE_OPTIONS=""
fi

if [[ -z ${FFMPEG_KIT_DEBUG} ]]; then
  if [[ -z ${NO_LINK_TIME_OPTIMIZATION} ]]; then
    DEBUG_OPTIONS="--disable-debug --enable-lto"
  else
    DEBUG_OPTIONS="--disable-debug --disable-lto"
  fi
else
  DEBUG_OPTIONS="--enable-debug --disable-stripping"
fi

echo -n -e "\n${LIB_NAME}: "

if [[ -z ${NO_WORKSPACE_CLEANUP_ffmpeg} ]]; then
  echo -e "INFO: Cleaning workspace for ${LIB_NAME}\n" 1>>"${BASEDIR}"/build.log 2>&1
  make distclean 2>/dev/null 1>/dev/null

  rm -f "${BASEDIR}"/src/"${LIB_NAME}"/libavfilter/opencl/*.o 1>>"${BASEDIR}"/build.log 2>&1
  rm -f "${BASEDIR}"/src/"${LIB_NAME}"/libavcodec/neon/*.o 1>>"${BASEDIR}"/build.log 2>&1

  git checkout "${BASEDIR}/src/ffmpeg/ffbuild" 1>>"${BASEDIR}"/build.log 2>&1
fi

ulimit -n 2048 1>>"${BASEDIR}"/build.log 2>&1

########################### CUSTOMIZATIONS #######################
cd "${BASEDIR}"/src/"${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
git checkout libavformat/file.c 1>>"${BASEDIR}"/build.log 2>&1
git checkout libavformat/protocols.c 1>>"${BASEDIR}"/build.log 2>&1
git checkout libavutil 1>>"${BASEDIR}"/build.log 2>&1

${SED_INLINE} 's/static int av_log_level/__thread int av_log_level/g' "${BASEDIR}"/src/"${LIB_NAME}"/libavutil/log.c 1>>"${BASEDIR}"/build.log 2>&1 || return 1

###################################################################

# Deduplicate accumulated flags. Each --enable-libX case above appended that
# library's full static pkg-config closure; with the full (27-library) set the
# repeated -I/-L/-l tokens bloat the link command lines past the Windows limit
# (avcodec.dll link failed with "Argument list too long"). Keep the LAST
# occurrence of each token so static link ordering is preserved (a library must
# precede the libraries it depends on).
dedupe_keep_last() {
  awk '{o="";for(i=NF;i>=1;i--){if(!seen[$i]++){o=$i (o==""?"":" ") o}} print o}' <<<"$1"
}
CFLAGS="$(dedupe_keep_last "${CFLAGS}")"
CXXFLAGS="$(dedupe_keep_last "${CXXFLAGS}")"
LDFLAGS="$(dedupe_keep_last "${LDFLAGS}")"
FFKIT_EXTRALIBS="$(dedupe_keep_last "${FFKIT_EXTRALIBS}")"
export CFLAGS CXXFLAGS LDFLAGS

# NOTE: no --cross-prefix. This is a native MINGW64 build; --cc/--ar/--nm/etc.
# are set explicitly below, and the unprefixed binutils (dlltool, windres, ...)
# exist while the x86_64-w64-mingw32- prefixed ones do not. Passing a cross
# prefix makes FFmpeg derive a non-existent ${cross_prefix}dlltool/windres.
./configure \
  --prefix="${FFMPEG_LIBRARY_PATH}" \
  --pkg-config="${HOST_PKG_CONFIG_PATH}" \
  --pkg-config-flags=--static \
  --enable-version3 \
  --arch="${TARGET_ARCH}" \
  --cpu="${TARGET_CPU}" \
  --target-os=mingw32 \
  ${ASM_OPTIONS} \
  --ar="${AR}" \
  --cc="${CC}" \
  --cxx="${CXX}" \
  --ld="${BASEDIR}/scripts/windows/ld-rsp.sh" \
  --ranlib="${RANLIB}" \
  --strip="${STRIP}" \
  --nm="${NM}" \
  --disable-autodetect \
  --enable-cross-compile \
  --enable-pic \
  --enable-optimizations \
  --enable-swscale \
  ${BUILD_LIBRARY_OPTIONS} \
  --enable-w32threads \
  ${SIZE_OPTIONS} \
  --disable-xmm-clobber-test \
  ${DEBUG_OPTIONS} \
  --disable-neon-clobber-test \
  --disable-programs \
  --disable-postproc \
  --disable-doc \
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  --disable-sndio \
  --disable-securetransport \
  --disable-xlib \
  --disable-cuda \
  --disable-cuvid \
  --disable-nvenc \
  --disable-vaapi \
  --disable-vdpau \
  --disable-videotoolbox \
  --disable-audiotoolbox \
  --disable-appkit \
  --extra-ldsoflags="-Wl,--default-image-base-low" \
  --extra-libs="${FFKIT_EXTRALIBS}" \
  ${CONFIGURE_POSTFIX} 1>>"${BASEDIR}"/build.log 2>&1

if [[ $? -ne 0 ]]; then
  echo -e "failed\n\nSee build.log for details\n"
  exit 1
fi

if [[ -z ${NO_OUTPUT_REDIRECTION} ]]; then
  make -j$(get_cpu_count) 1>>"${BASEDIR}"/build.log 2>&1

  if [[ $? -ne 0 ]]; then
    echo -e "failed\n\nSee build.log for details\n"
    exit 1
  fi
else
  echo -e "started\n"
  make -j$(get_cpu_count)

  if [[ $? -ne 0 ]]; then
    echo -n -e "\n${LIB_NAME}: failed\n\nSee build.log for details\n"
    exit 1
  else
    echo -n -e "\n${LIB_NAME}: "
  fi
fi

if [ -d "${FFMPEG_LIBRARY_PATH}" ]; then
  rm -rf "${FFMPEG_LIBRARY_PATH}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi
make install 1>>"${BASEDIR}"/build.log 2>&1

if [[ $? -ne 0 ]]; then
  echo -e "failed\n\nSee build.log for details\n"
  exit 1
fi

overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libavformat.pc "${INSTALL_PKG_CONFIG_DIR}/libavformat.pc" || return 1
overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libswresample.pc "${INSTALL_PKG_CONFIG_DIR}/libswresample.pc" || return 1
overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libswscale.pc "${INSTALL_PKG_CONFIG_DIR}/libswscale.pc" || return 1
overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libavdevice.pc "${INSTALL_PKG_CONFIG_DIR}/libavdevice.pc" || return 1
overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libavfilter.pc "${INSTALL_PKG_CONFIG_DIR}/libavfilter.pc" || return 1
overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libavcodec.pc "${INSTALL_PKG_CONFIG_DIR}/libavcodec.pc" || return 1
overwrite_file "${FFMPEG_LIBRARY_PATH}"/lib/pkgconfig/libavutil.pc "${INSTALL_PKG_CONFIG_DIR}/libavutil.pc" || return 1

mkdir -p "${FFMPEG_LIBRARY_PATH}"/include/libavutil/x86 1>>"${BASEDIR}"/build.log 2>&1
mkdir -p "${FFMPEG_LIBRARY_PATH}"/include/libavutil/arm 1>>"${BASEDIR}"/build.log 2>&1
mkdir -p "${FFMPEG_LIBRARY_PATH}"/include/libavutil/aarch64 1>>"${BASEDIR}"/build.log 2>&1
mkdir -p "${FFMPEG_LIBRARY_PATH}"/include/libavcodec/x86 1>>"${BASEDIR}"/build.log 2>&1
mkdir -p "${FFMPEG_LIBRARY_PATH}"/include/libavcodec/arm 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/config.h "${FFMPEG_LIBRARY_PATH}"/include/config.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavcodec/mathops.h "${FFMPEG_LIBRARY_PATH}"/include/libavcodec/mathops.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavcodec/x86/mathops.h "${FFMPEG_LIBRARY_PATH}"/include/libavcodec/x86/mathops.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavcodec/arm/mathops.h "${FFMPEG_LIBRARY_PATH}"/include/libavcodec/arm/mathops.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavformat/network.h "${FFMPEG_LIBRARY_PATH}"/include/libavformat/network.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavformat/os_support.h "${FFMPEG_LIBRARY_PATH}"/include/libavformat/os_support.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavformat/url.h "${FFMPEG_LIBRARY_PATH}"/include/libavformat/url.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/attributes_internal.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/attributes_internal.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/bprint.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/bprint.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/getenv_utf8.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/getenv_utf8.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/internal.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/internal.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/libm.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/libm.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/reverse.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/reverse.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/thread.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/thread.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/timer.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/timer.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/x86/asm.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/x86/asm.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/x86/timer.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/x86/timer.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/arm/timer.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/arm/timer.h 1>>"${BASEDIR}"/build.log 2>&1
overwrite_file "${BASEDIR}"/src/ffmpeg/libavutil/aarch64/timer.h "${FFMPEG_LIBRARY_PATH}"/include/libavutil/aarch64/timer.h 1>>"${BASEDIR}"/build.log 2>&1
if [ $? -eq 0 ]; then
  echo "ok"
else
  echo -e "failed\n\nSee build.log for details\n"
  exit 1
fi
