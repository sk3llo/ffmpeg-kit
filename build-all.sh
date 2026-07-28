#!/usr/bin/env bash
#
# build-all.sh — build FFmpegKit variants for one platform, driven from the
# per-variant flag sets documented in BUILD.md.
#
# Usage:
#   ./build-all.sh <platform> [variant ...]
#
#   platform : ios | macos | android | linux | windows
#   variant  : any of: min min-gpl https https-gpl audio video full full-gpl
#              (default: all of them)
#
# Examples:
#   ./build-all.sh ios                      # all 8 variants for iOS
#   ./build-all.sh android min full-gpl     # just those two, Android
#   ./build-all.sh macos https              # https variant, macOS
#
# Environment overrides:
#   SUDO=                 run the platform scripts without sudo (default: sudo)
#   ANDROID_SDK_ROOT=...  default: $HOME/Library/Android/sdk
#   ANDROID_NDK_ROOT=...  default: $ANDROID_SDK_ROOT/ndk/29.0.13113456
#   ANDROID_DISABLE_ABIS="--disable-arm-v7a --disable-arm-v7a-neon --disable-x86 --disable-x86-64"
#                         restrict Android ABIs (default: empty = build all 4)
#   NO_GNUTLS_TOGGLE=1    do not auto-uncomment gnutls in scripts/apple/ffmpeg.sh
#
# Notes:
#   * https / https-gpl on Apple require the gnutls block in
#     scripts/apple/ffmpeg.sh to be uncommented. This script does that
#     automatically (backing the file up first) unless NO_GNUTLS_TOGGLE=1.
#     The change is git-revertable: `git checkout -- scripts/apple/ffmpeg.sh`.
#   * BUILD.md's Android full-gpl line disables non-arm64 ABIs (a dev shortcut).
#     This driver builds ALL ABIs by default for every variant; set
#     ANDROID_DISABLE_ABIS to restrict.
#   * Builds are long (hours) and need the full toolchain. Outputs land under
#     prebuilt/ and the bundle-* directories.
#
set -uo pipefail

cd "$(dirname "$0")"
BASEDIR="$(pwd)"

ALL_VARIANTS="min min-gpl https https-gpl audio video full full-gpl"
: "${SUDO=sudo}"   # use '=' not ':=' so an explicit empty SUDO= (run without sudo) is honored
: "${ANDROID_SDK_ROOT:=$HOME/Library/Android/sdk}"
: "${ANDROID_NDK_ROOT:=$ANDROID_SDK_ROOT/ndk/29.0.13113456}"
: "${ANDROID_DISABLE_ABIS:=}"
: "${NO_GNUTLS_TOGGLE:=}"

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# --- per-variant flag sets -------------------------------------------------
# Apple (ios.sh and macos.sh share the same flags). $2 = platform (ios|macos),
# used to pick the platform-specific built-in Apple framework tokens.
# VideoToolbox + AVFoundation are free Apple SDK frameworks (no patent-encumbered
# codecs), enabled for min/min-gpl so those variants get HW H.264/HEVC encode
# while staying LGPL/patent-clean (#148). full/full-gpl already get them via --full.
apple_flags() {
  local vt="" zl=""
  case "$2" in
    ios)   vt="--enable-ios-videotoolbox --enable-ios-avfoundation"; zl="--enable-ios-zlib" ;;
    macos) vt="--enable-macos-videotoolbox --enable-macos-avfoundation"; zl="--enable-macos-zlib" ;;
  esac
  # zlib is added to min/min-gpl/audio because FFmpeg's PNG/APNG decoders depend
  # on it; without zlib configure silently drops them (#105). The other variants
  # already get zlib transitively (gnutls/libwebp) or via --full.
  case "$1" in
    min)        echo "$vt $zl" ;;
    min-gpl)    echo "--enable-gpl --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore $vt $zl" ;;
    https)      echo "--enable-gmp --enable-gnutls" ;;
    https-gpl)  echo "--enable-gpl --enable-gmp --enable-gnutls --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore" ;;
    audio)      echo "--enable-twolame --enable-lame --enable-libilbc --enable-libvorbis --enable-opencore-amr --enable-opus --enable-shine --enable-soxr --enable-speex --enable-vo-amrwbenc $zl" ;;
    video)      echo "--enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-kvazaar --enable-libass --enable-ios-libiconv --enable-libtheora --enable-libvpx --enable-libwebp --enable-snappy --enable-zimg" ;;
    full)       echo "--full" ;;
    full-gpl)   echo "--full --enable-gpl" ;;
    *) return 1 ;;
  esac
}

# Android (android.sh). Always adds --enable-android-media-codec.
android_flags() {
  local base
  # --enable-android-zlib on min/min-gpl/audio: required for the PNG/APNG
  # decoders (#105); other variants get zlib transitively.
  case "$1" in
    min)        base="--enable-android-zlib" ;;
    min-gpl)    base="--enable-gpl --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore --enable-android-zlib" ;;
    https)      base="--enable-gmp --enable-gnutls" ;;
    https-gpl)  base="--enable-gpl --enable-gmp --enable-gnutls --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore" ;;
    audio)      base="--enable-twolame --enable-lame --enable-libilbc --enable-libvorbis --enable-opencore-amr --enable-opus --enable-shine --enable-soxr --enable-speex --enable-vo-amrwbenc --enable-android-zlib" ;;
    video)      base="--enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-kvazaar --enable-libass --enable-libiconv --enable-libtheora --enable-libvpx --enable-libwebp --enable-snappy --enable-zimg" ;;
    full)       base="--enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-gmp --enable-gnutls --enable-kvazaar --enable-lame --enable-libass --enable-libiconv --enable-libilbc --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libxml2 --enable-opencore-amr --enable-opus --enable-shine --enable-snappy --enable-soxr --enable-speex --enable-twolame --enable-vo-amrwbenc --enable-zimg" ;;
    full-gpl)   base="--full --enable-gpl" ;;
    *) return 1 ;;
  esac
  echo "${base} --enable-android-media-codec ${ANDROID_DISABLE_ABIS}"
}

# Linux (linux.sh). Two flavours of dependency here, unlike the other platforms:
# libraries with a scripts/linux/*.sh recipe are built from source and take a
# bare token (x264, dav1d, kvazaar, zimg, libilbc, openh264, openssl, srt,
# libaom, chromaprint); everything else is taken from the distro and takes a
# --enable-linux-<lib> token, which the build maps onto the matching FFmpeg
# --enable-lib<x> and resolves with pkg-config. The container must therefore
# provide the corresponding -dev packages.
# zlib is requested for every variant: FFmpeg silently drops the PNG/APNG
# decoders without it (same trap as #105 on the other platforms).
linux_flags() {
  local gpl="--enable-gpl --enable-linux-libvidstab --enable-x264 --enable-linux-x265 --enable-linux-xvidcore"
  local tls="--enable-linux-gmp --enable-linux-gnutls"
  local audio="--enable-linux-twolame --enable-linux-lame --enable-libilbc --enable-linux-libvorbis --enable-linux-opencore-amr --enable-linux-opus --enable-linux-shine --enable-linux-soxr --enable-linux-speex --enable-linux-vo-amrwbenc"
  local video="--enable-dav1d --enable-linux-fontconfig --enable-linux-freetype --enable-linux-fribidi --enable-kvazaar --enable-linux-libass --enable-linux-libiconv --enable-linux-libtheora --enable-linux-libvpx --enable-linux-libwebp --enable-linux-snappy --enable-zimg"
  local zlib="--enable-linux-zlib"
  case "$1" in
    min)        echo "$zlib" ;;
    min-gpl)    echo "$gpl $zlib" ;;
    https)      echo "$tls $zlib" ;;
    https-gpl)  echo "$gpl $tls $zlib" ;;
    audio)      echo "$audio $zlib" ;;
    video)      echo "$video $zlib" ;;
    full)       echo "$video $audio $tls --enable-linux-libxml2 $zlib" ;;
    full-gpl)   echo "$video $audio $tls --enable-linux-libxml2 $gpl $zlib" ;;
    *) return 1 ;;
  esac
}

# Windows (windows.sh) — only min / full / full-gpl are exercised here.
windows_flags() {
  case "$1" in
    min)      echo "" ;;
    full)     echo "--full" ;;
    full-gpl) echo "--full --enable-gpl" ;;
    *) return 2 ;;  # 2 = unsupported on this platform
  esac
}

# --- gnutls toggle for Apple https builds ----------------------------------
ensure_apple_gnutls() {
  [ -n "$NO_GNUTLS_TOGGLE" ] && return 0
  local f="scripts/apple/ffmpeg.sh"
  if grep -qE '^#[[:space:]]*gnutls\)' "$f"; then
    echo "  [gnutls] uncommenting gnutls block in $f (backup: $f.bak)"
    cp "$f" "$f.bak"
    # Uncomment the whole 5-line gnutls case block INCLUDING its ';;' terminator.
    # (Dropping ';;' makes the case fall through to kvazaar) => bash syntax error.)
    perl -0pi -e 's/#(\s*gnutls\))\n#(\s*FFMPEG_CFLAGS[^\n]*)\n#(\s*FFMPEG_LDFLAGS[^\n]*)\n#(\s*CONFIGURE_POSTFIX[^\n]*--enable-gnutls[^\n]*)\n#(\s*;;)/$1\n$2\n$3\n$4\n$5/' "$f"
  else
    echo "  [gnutls] already enabled in $f"
  fi
}

# Restore scripts/apple/ffmpeg.sh to its committed state (gnutls case commented
# out => openssl-only). ensure_apple_gnutls() flips gnutls ON only for the https
# variants; without this reset that toggle leaks into later variants — e.g. full
# enables openssl and configure then aborts with
# "GnuTLS and OpenSSL must not be enabled at the same time."
reset_apple_ffmpeg_script() {
  git checkout -- scripts/apple/ffmpeg.sh 2>/dev/null
  rm -f scripts/apple/ffmpeg.sh.bak
}

# Reset the shared FFmpeg source to pristine between variants. Building several
# variants back-to-back in one src/ffmpeg leaves reconfigure/object residue that
# makes a later variant fail (e.g. full after https-gpl). External libs under
# src/<lib> are NOT touched (cached, FFmpeg-version-independent).
reset_ffmpeg_source() {
  if [ -d src/ffmpeg/.git ]; then
    echo "  [clean] resetting src/ffmpeg to pristine"
    git -C src/ffmpeg clean -xffd >/dev/null 2>&1
    git -C src/ffmpeg checkout -- . >/dev/null 2>&1
  fi
}

# Guard: shipped macOS/iOS framework binaries must reference ONLY system dylibs
# (/usr/lib, /System). A /opt/homebrew, /opt/local or /usr/local reference means
# a non-portable build that fails to dyld-load on end-user machines (see the
# PKG_CONFIG_PATH fix in scripts/apple/ffmpeg.sh + libxml2.sh). Returns non-zero
# if any leak is found so the variant is marked failed.
check_apple_portability() {
  local platform="$1" fw bad=0 bin
  case "$platform" in
    ios)   fw="prebuilt/bundle-apple-framework-ios" ;;
    macos) fw="prebuilt/bundle-apple-framework-macos" ;;
    *) return 0 ;;
  esac
  [ -d "$fw" ] || return 0
  for lib in libavutil libavcodec libavformat libavfilter libavdevice libswscale libswresample ffmpegkit; do
    bin="$fw/$lib.framework/Versions/A/$lib"; [ -f "$bin" ] || bin="$fw/$lib.framework/$lib"
    [ -f "$bin" ] || continue
    if otool -L "$bin" 2>/dev/null | grep -qE "/opt/homebrew|/opt/local|/usr/local"; then
      echo "  !! PORTABILITY: $lib references non-system dylibs (would fail to load off this machine):"
      otool -L "$bin" 2>/dev/null | grep -E "/opt/homebrew|/opt/local|/usr/local" | sed 's/^/        /'
      bad=1
    fi
  done
  return $bad
}

# --- run one variant -------------------------------------------------------
run_variant() {
  local platform="$1" variant="$2" flags rc
  case "$platform" in
    ios|macos)
      flags="$(apple_flags "$variant" "$platform")" || { echo "  SKIP $variant (unknown)"; return 0; }
      reset_apple_ffmpeg_script
      case "$variant" in https|https-gpl) ensure_apple_gnutls ;; esac
      echo ">>> [$platform/$variant] $SUDO ./$platform.sh $flags"
      $SUDO ./"$platform".sh $flags ;;
    android)
      flags="$(android_flags "$variant")" || { echo "  SKIP $variant (unknown)"; return 0; }
      echo ">>> [android/$variant] ${SUDO:+sudo -E }./android.sh $flags"
      if [ -n "$SUDO" ]; then
        ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" "$SUDO" -E ./android.sh $flags
      else
        ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" ./android.sh $flags
      fi ;;
    linux)
      flags="$(linux_flags "$variant")" || { echo "  SKIP $variant (unknown)"; return 0; }
      echo ">>> [linux/$variant] ./linux.sh $flags"
      ./linux.sh $flags ;;
    windows)
      flags="$(windows_flags "$variant")"; rc=$?
      [ "$rc" = "2" ] && { echo "  SKIP $variant (windows: only min/full/full-gpl are scripted here)"; return 0; }
      echo ">>> [windows/$variant] $SUDO ./windows.sh $flags"
      $SUDO ./windows.sh $flags ;;
    *) echo "Unknown platform: $platform"; usage 1 ;;
  esac
}

# --- main ------------------------------------------------------------------
[ $# -lt 1 ] && usage 1
PLATFORM="$1"; shift
case "$PLATFORM" in ios|macos|android|linux|windows) ;; -h|--help) usage 0 ;; *) echo "Unknown platform: $PLATFORM"; usage 1 ;; esac

VARIANTS="${*:-$ALL_VARIANTS}"
echo "Platform: $PLATFORM   Variants: $VARIANTS"
[ "$PLATFORM" = android ] && echo "SDK=$ANDROID_SDK_ROOT  NDK=$ANDROID_NDK_ROOT  DISABLE_ABIS='${ANDROID_DISABLE_ABIS:-<none, all ABIs>}'"
echo

# Assign empty explicitly: under `set -u` bash treats an array that was
# declared but never assigned as unset, so the ${#FAIL_LIST[@]} test at the end
# aborts the script on a run where nothing failed.
declare -a OK_LIST=() FAIL_LIST=()
for v in $VARIANTS; do
  echo "=================================================================="
  reset_ffmpeg_source
  if run_variant "$PLATFORM" "$v"; then
    if check_apple_portability "$PLATFORM"; then OK_LIST+=("$v"); else FAIL_LIST+=("$v"); echo "  !! FAILED (portability): $v"; fi
  else FAIL_LIST+=("$v"); echo "  !! FAILED: $v"; fi
done

echo "=================================================================="
echo "DONE ($PLATFORM).  ok: ${OK_LIST[*]:-none}   failed: ${FAIL_LIST[*]:-none}"
echo
echo "Next:"
echo "  - Apple : zip prebuilt frameworks -> ffmpeg-kit-{ios,macos}-<variant>-<ver>.zip, upload to the GitHub release."
echo "  - Android: copy prebuilt/android-*/.../*.so into ffmpeg_kit_flutter_android/android/src/main/jniLibs/<abi>/, then publish Maven."
echo "  - Windows: zip the windows bundle -> ffmpeg-kit-windows-<arch>-<variant>-<ver>.zip, upload to the release."
[ "${#FAIL_LIST[@]}" -gt 0 ] && exit 1 || exit 0
