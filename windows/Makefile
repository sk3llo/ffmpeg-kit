# Builds libffmpegkit.dll (the FFmpegKit wrapper) for Windows under MSYS2/MinGW.
#
# Sources in src/ are the FFmpegKit C++ API (Windows-adapted, incl. the
# ffmpegkit_c_api C ABI the Flutter plugin binds via LoadLibrary/GetProcAddress,
# so it must be compiled with -DFFMPEGKIT_EXPORTS) plus the bundled fftools_*
# copies (FFmpeg 8.x-correct, shared lineage with linux/src).
#
# Required variables (normally supplied by scripts/main-windows.sh):
#   FFMPEG_PREFIX  installed FFmpeg (include/, lib/ with import libs, bin/)
#   FFMPEG_BUILD   FFmpeg out-of-tree build dir (provides config.h)
#   FFMPEG_SRC     FFmpeg source tree (private headers used by fftools)
# Optional:
#   OUT            object/output dir (default: build)

ifeq ($(FFMPEG_PREFIX),)
$(error FFMPEG_PREFIX is required)
endif
ifeq ($(FFMPEG_BUILD),)
$(error FFMPEG_BUILD is required)
endif
ifeq ($(FFMPEG_SRC),)
$(error FFMPEG_SRC is required)
endif

OUT    ?= build
SRCDIR := src

C_SRCS   := $(wildcard $(SRCDIR)/fftools_*.c)
CPP_SRCS := $(wildcard $(SRCDIR)/*.cpp)
OBJS     := $(patsubst $(SRCDIR)/%.c,$(OUT)/%_c.o,$(C_SRCS)) \
            $(patsubst $(SRCDIR)/%.cpp,$(OUT)/%_cpp.o,$(CPP_SRCS))

INCLUDES := -I$(SRCDIR) -I$(FFMPEG_BUILD) -I$(FFMPEG_SRC) -I$(FFMPEG_PREFIX)/include
DEFS     := -DFFMPEGKIT_EXPORTS -D__USE_MINGW_ANSI_STDIO=1

CC       ?= gcc
CXX      ?= g++
CFLAGS   := -O2 -std=gnu11 $(INCLUDES) $(DEFS) -Wno-deprecated-declarations
CXXFLAGS := -O2 -std=c++17 $(INCLUDES) $(DEFS) -Wno-deprecated-declarations

# Link against the FFmpeg import libs from this build; keep the C/C++ runtimes
# static so the bundle doesn't grow extra MinGW runtime DLL dependencies.
LIBS := -L$(FFMPEG_PREFIX)/lib \
        -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil

DLL := $(OUT)/libffmpegkit.dll

all: $(DLL)

$(OUT):
	mkdir -p $(OUT)

$(OUT)/%_c.o: $(SRCDIR)/%.c | $(OUT)
	$(CC) $(CFLAGS) -c $< -o $@

$(OUT)/%_cpp.o: $(SRCDIR)/%.cpp | $(OUT)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(DLL): $(OBJS)
	$(CXX) -shared -o $@ $(OBJS) $(LIBS) \
	  -static-libgcc -static-libstdc++ \
	  -Wl,--out-implib,$(OUT)/libffmpegkit.dll.a

install: all
	install -d $(FFMPEG_PREFIX)/bin $(FFMPEG_PREFIX)/lib $(FFMPEG_PREFIX)/include/ffmpegkit
	install -m 755 $(DLL) $(FFMPEG_PREFIX)/bin/
	install -m 644 $(OUT)/libffmpegkit.dll.a $(FFMPEG_PREFIX)/lib/
	install -m 644 $(SRCDIR)/*.h $(FFMPEG_PREFIX)/include/ffmpegkit/

clean:
	rm -rf $(OUT)

.PHONY: all install clean
