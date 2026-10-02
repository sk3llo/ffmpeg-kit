#!/usr/bin/env bash
# Generate third-party license notices for the Windows ffmpeg-kit release zips.
# Must run on the machine that built them (MSYS2 MINGW64), with the same
# packages installed: every bundled DLL is checked byte-for-byte against
# /mingw64/bin and the script aborts on any mismatch.
#
# License texts come from each package's installed /mingw64/share/licenses;
# for packages that install none, they are extracted from the upstream sources
# inside the package's MSYS2 source package (repo.msys2.org/mingw/sources).
#
# Usage: [SRCCACHE=dir] tools/windows/gen-licenses.sh [out_dir]
#   SRCCACHE: optional directory to keep/reuse downloaded source packages.
set -euo pipefail

VER=8.1.2
SRC_TAG=windows-8.1.2
OUT=${1:-licenses/windows-$VER}
FFSRC=src/ffmpeg
TAR=/c/Windows/System32/tar.exe
RELEASES=https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download
SOURCES=https://repo.msys2.org/mingw/sources

declare -A ZIP_SHA=(
  [min]=d838b6db39e1eb95a2ba04c5376c58ebd137e2bb0bb815b677465706ce8f85e0
  [min-gpl]=16104e1ab9912c75571f1046c7b7910bdd08a7293e83d5d63712c97883401263
  [https]=68b8dcc97d0eedfcdd97d43d700f3f4668f8cdb61601f510f06a488328844e2d
  [https-gpl]=b561d9f647b5ecb89ea070607ad1af8ac50dbaec2a94e49edfbbf54851c45ee4
  [audio]=dcd9eabb067a3ef34ae8e7c1d01bf06592714978496e3b03c9015d2dc21ea94d
  [video]=bf63abaa249a1ffbf4ff4e33422981080614d21778dffd92fa57b0d6387b0305
  [full]=bc9653b6fae63f86ecd4338a6b4eed56bcca57bd84f3fcf214b3cec8490046ea
  [full-gpl]=83d67fec21e569c8e8177b3c7ac7d7579785582672b6ee3cab72fbec320b4215
)
VARIANTS="min min-gpl https https-gpl audio video full full-gpl"

die() { echo "FATAL: $*" >&2; exit 1; }

[ "$(git -C "$FFSRC" describe --tags --exact-match 2>/dev/null)" = "n8.1.2" ] \
  || die "$FFSRC is not at tag n8.1.2"
[ -x "$TAR" ] || die "$TAR not found"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
rm -rf "$OUT"
mkdir -p "$OUT"
MANIFEST="$OUT/manifest.tsv"
printf 'variant\tdll\tsha256\tpackage\tversion\tsource_base\tlicenses\n' > "$MANIFEST"

desc_field() {  # desc_field <desc file> <FIELD>  -> values, one per line
  awk -v f="%$2%" '$0==f{on=1;next} /^%/{on=0} on && NF' "$1"
}

# MSYS2 source packages, downloaded once per run (or reused from $SRCCACHE).
SRCCACHE=${SRCCACHE:-$WORK/msys2-src}
mkdir -p "$SRCCACHE"
LICRE='^(COPYING|COPYRIGHT|LICEN[CS]E|NOTICE|UNLICENSE)[A-Za-z0-9._-]*$'

# source_url <base> <ver>  -> prints the URL of the source package that exists
# (MSYS2 used .tar.gz/.tar.xz before switching to .tar.zst); empty if none.
source_url() {
  local ext u
  for ext in zst gz xz; do
    u="$SOURCES/$1-$2.src.tar.$ext"
    [ "$(curl -s -o /dev/null -w '%{http_code}' -I "$u")" = 200 ] && { echo "$u"; return; }
  done
}

# copy_source_licenses <src url> <ver> <dst>  -> number of files copied
# Extracts the top-level license files from the upstream sources inside the
# MSYS2 source package: release tarballs, or a bare git mirror (VCS packages,
# read at the commit encoded in the package version).
copy_source_licenses() {
  local url=$1 ver=$2 dst=$3 f x top a e b rev n=0
  f="$SRCCACHE/$(basename "$url")"
  [ -s "$f" ] || curl -fsSL -o "$f" "$url" || die "download $url"
  x="$SRCCACHE/$(basename "$url").d"
  [ -d "$x" ] || { mkdir -p "$x" && bsdtar -xf "$f" -C "$x"; } || die "extract $f"
  top=$(ls "$x")
  for a in "$x/$top"/*; do
    case "$a" in *.sig|*.asc|*.patch|*.diff|*/PKGBUILD|*.in) continue ;; esac
    if [ -d "$a" ] && [ -f "$a/HEAD" ]; then
      rev=$(echo "$ver" | grep -oE '\.[0-9a-f]{7,40}-[0-9]+$' | sed -E 's/^\.//; s/-[0-9]+$//') \
        || die "$(basename "$url"): git mirror but no commit in version $ver"
      while read -r b; do
        [ -e "$dst/$b" ] && die "$(basename "$url"): license file name clash $b"
        git --git-dir="$a" show "$rev:$b" > "$dst/$b"; n=$((n+1))
      done < <(git --git-dir="$a" ls-tree --name-only "$rev" | grep -E "$LICRE" || true)
    elif [ -f "$a" ] && bsdtar -tf "$a" > "$SRCCACHE/list" 2>/dev/null; then
      while read -r e; do
        b=${e#*/}
        [ -e "$dst/$b" ] && die "$(basename "$url"): license file name clash $b"
        bsdtar -xOf "$a" "$e" > "$dst/$b"; n=$((n+1))
      done < <(awk -F/ 'NF==2 && $2!=""' "$SRCCACHE/list" | while read -r e; do
                 [[ "${e#*/}" =~ $LICRE ]] && echo "$e"; done)
    fi
  done
  echo "$n"
}

for v in $VARIANTS; do
  zip="ffmpeg-kit-windows-x86_64-$v-$VER.zip"
  curl -fsSL -o "$WORK/$zip" "$RELEASES/$VER-$v/$zip" || die "download $zip"
  got=$(sha256sum "$WORK/$zip" | cut -d' ' -f1)
  [ "$got" = "${ZIP_SHA[$v]}" ] || die "$zip sha256 $got != ${ZIP_SHA[$v]}"
  mkdir -p "$WORK/$v"
  "$TAR" -xf "$(cygpath -w "$WORK/$zip")" -C "$(cygpath -w "$WORK/$v")" bin

  cfg=$(strings -n 8 "$WORK/$v"/bin/avutil-*.dll | grep -m1 -- '--prefix=') \
    || die "$v: no configure string in avutil"
  case "$cfg" in
    *--enable-gpl*)      ff_lic="GPL-3.0-or-later";  ff_files="COPYING.GPLv3 COPYING.GPLv2" ;;
    *--enable-version3*) ff_lic="LGPL-3.0-or-later"; ff_files="COPYING.LGPLv3 COPYING.GPLv3" ;;
    *)                   ff_lic="LGPL-2.1-or-later"; ff_files="COPYING.LGPLv2.1" ;;
  esac
  case "$cfg" in *--enable-gpl*) [[ "$cfg" == *--enable-version3* ]] || die "$v: gpl without version3, recheck mapping" ;; esac

  vd="$OUT/$v"
  mkdir -p "$vd/FFmpeg" "$vd/ffmpeg-kit" "$vd/third-party"
  cp "$FFSRC/LICENSE.md" "$vd/FFmpeg/"
  for f in $ff_files; do cp "$FFSRC/$f" "$vd/FFmpeg/"; done
  cp LICENSE "$vd/ffmpeg-kit/LICENSE"

  notice="$vd/NOTICE.txt"
  {
    echo "FFmpegKit $VER for Windows x86_64, \"$v\" variant"
    echo
    echo "FFmpeg n8.1.2 (unmodified, https://github.com/arthenica/FFmpeg/tree/n8.1.2),"
    echo "built as shared libraries and licensed $ff_lic. See FFmpeg/."
    echo "libffmpegkit.dll is FFmpegKit, licensed LGPL-3.0. See ffmpeg-kit/LICENSE."
    echo "Build scripts and wrapper source: https://github.com/sk3llo/ffmpeg-kit/tree/$SRC_TAG"
    echo "Toolchain: $(gcc --version | head -1), $(ld --version | head -1)"
    echo
    echo "Bundled third-party DLLs. All are unmodified MSYS2 (mingw-w64-x86_64) package"
    echo "binaries. Each package's license files are under third-party/<package>/,"
    echo "and its complete corresponding source is the MSYS2 source package listed."
    echo
  } > "$notice"

  for p in "$WORK/$v"/bin/*.dll; do
    dll=$(basename "$p")
    [[ "$dll" =~ ^(av|sw)[a-z]+-[0-9]+\.dll$|^libffmpegkit\.dll$ ]] && continue
    sys=/mingw64/bin/$dll
    [ -f "$sys" ] || die "$v: $dll not found in /mingw64/bin"
    sha=$(sha256sum "$p" | cut -d' ' -f1)
    [ "$sha" = "$(sha256sum "$sys" | cut -d' ' -f1)" ] \
      || die "$v: $dll differs from $sys (package changed since build?)"
    pkg=$(pacman -Qqo "$sys") || die "$v: no package owns $sys"
    ver=$(pacman -Q "$pkg" | cut -d' ' -f2)
    desc=/var/lib/pacman/local/$pkg-$ver/desc
    [ -f "$desc" ] || die "$v: missing $desc"
    base=$(desc_field "$desc" BASE); base=${base:-$pkg}
    lics=$(desc_field "$desc" LICENSE | paste -sd' ' -)
    url=$(desc_field "$desc" URL)

    dst="$vd/third-party/$pkg"
    if [ ! -d "$dst" ]; then
      mkdir -p "$dst"
      src=$(source_url "$base" "$ver")
      [ -n "$src" ] || echo "SOURCE_MISSING $SOURCES/$base-$ver.src.tar.{zst,gz,xz}" >> "$OUT/problems.txt"
      n=0
      while read -r lf; do
        [ -f "$lf" ] || continue
        rel=${lf#/mingw64/share/licenses/}; rel=${rel#*/}   # keep subdirs (e.g. libiconv/libcharset/)
        mkdir -p "$dst/$(dirname "$rel")"
        cp "$lf" "$dst/$rel"; n=$((n+1))
      done < <(pacman -Qlq "$pkg" | grep '^/mingw64/share/licenses/' || true)
      lic_from="installed package (/mingw64/share/licenses)"
      if [ "$n" -eq 0 ] && [ -n "$src" ]; then
        n=$(copy_source_licenses "$src" "$ver" "$dst")
        lic_from="upstream sources in the MSYS2 source package (package installs none)"
      fi
      [ "$n" -gt 0 ] || echo "NO_LICENSE_FILES $pkg" >> "$OUT/problems.txt"
      {
        echo "$pkg $ver"
        echo "  License: $lics"
        echo "  License files: $lic_from"
        echo "  Upstream: $url"
        echo "  Source: ${src:-MISSING}"
        echo "  DLLs:"
      } > "$dst/.entry"
    fi
    echo "    $dll  sha256:$sha" >> "$dst/.entry"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$v" "$dll" "$sha" "$pkg" "$ver" "$base" "$lics" >> "$MANIFEST"
  done

  for e in "$vd"/third-party/*/.entry; do cat "$e"; echo; rm "$e"; done >> "$notice"
  echo "$v: $(ls "$vd/third-party" | wc -l) packages, FFmpeg $ff_lic"
done

if [ -s "$OUT/problems.txt" ]; then
  echo "PROBLEMS (see $OUT/problems.txt):"; cat "$OUT/problems.txt"; exit 2
fi
echo "OK: notices in $OUT"
