#!/bin/bash
#
# Linker wrapper used as FFmpeg's --ld on Windows.
#
# FFmpeg links each shared library (libavcodec.dll has ~1150 object files) with a
# single command listing every object plus the static-library closure. On Windows
# the spawned compiler call is capped at ~32 KB (CreateProcessW), which
# avcodec/avformat/avfilter exceed ("Argument list too long").
#
# We move the bulk - the RELATIVE object paths (libavcodec/foo.o, ...) - into a
# GCC response file (@file), substituting "@file" IN PLACE at the position of the
# first such object so the original argument order is preserved. Order matters:
# for static linking the objects must precede the libraries (-l...) that satisfy
# their symbols (otherwise: undefined reference to BCryptGenRandom, etc.).
#
# Everything else stays on the command line, because MSYS only translates POSIX
# paths to native Windows paths for command-line arguments - NOT for arguments
# read from a response file. Relative object paths need no translation (gcc
# resolves them against the build CWD); absolute object paths (e.g. configure's
# /tmp/ffconf.XXX/test.o) are therefore kept on the command line.

RSP="$(mktemp "${TMPDIR:-/tmp}/ffk-ld-XXXXXX.rsp")"
objs=()
rest=()
inserted=0
for arg in "$@"; do
  case "${arg}" in
    /*.o | /*.obj | [A-Za-z]:*.o | [A-Za-z]:*.obj)
      # absolute object path -> keep on command line so MSYS translates it
      rest+=("${arg}")
      ;;
    *.o | *.obj)
      # relative object path -> response file; drop a single "@rsp" placeholder
      # at the position of the first one to preserve link order
      objs+=("${arg}")
      if [ ${inserted} -eq 0 ]; then
        rest+=("@${RSP}")
        inserted=1
      fi
      ;;
    *)
      rest+=("${arg}")
      ;;
  esac
done

: >"${RSP}"
if [ ${#objs[@]} -gt 0 ]; then
  printf '%s\n' "${objs[@]}" >"${RSP}"
fi

x86_64-w64-mingw32-gcc "${rest[@]}"
STATUS=$?

rm -f "${RSP}"
exit ${STATUS}
