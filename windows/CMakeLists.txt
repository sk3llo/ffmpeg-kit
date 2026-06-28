cmake_minimum_required(VERSION 3.16)
project(ffmpegkit VERSION 6.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(FFMPEGKIT_SOURCES
    src/AbstractSession.cpp
    src/ArchDetect.cpp
    src/Chapter.cpp
    src/FFmpegKit.cpp
    src/FFmpegKitConfig.cpp
    src/FFmpegSession.cpp
    src/FFprobeKit.cpp
    src/FFprobeSession.cpp
    src/Log.cpp
    src/MediaInformation.cpp
    src/MediaInformationJsonParser.cpp
    src/MediaInformationSession.cpp
    src/Packages.cpp
    src/ReturnCode.cpp
    src/Statistics.cpp
    src/StreamInformation.cpp
    src/ffmpegkit_exception.cpp
    src/ffmpegkit_c_api.cpp
    src/fftools_cmdutils.c
    src/fftools_ffmpeg.c
    src/fftools_ffmpeg_demux.c
    src/fftools_ffmpeg_filter.c
    src/fftools_ffmpeg_hw.c
    src/fftools_ffmpeg_mux.c
    src/fftools_ffmpeg_mux_init.c
    src/fftools_ffmpeg_opt.c
    src/fftools_ffprobe.c
    src/fftools_objpool.c
    src/fftools_opt_common.c
    src/fftools_sync_queue.c
    src/fftools_thread_queue.c
)

set(FFMPEGKIT_HEADERS
    src/AbstractSession.h
    src/ArchDetect.h
    src/Chapter.h
    src/FFmpegKit.h
    src/FFmpegKitConfig.h
    src/FFmpegSession.h
    src/FFmpegSessionCompleteCallback.h
    src/FFprobeKit.h
    src/FFprobeSession.h
    src/FFprobeSessionCompleteCallback.h
    src/Level.h
    src/Log.h
    src/LogCallback.h
    src/LogRedirectionStrategy.h
    src/MediaInformation.h
    src/MediaInformationJsonParser.h
    src/MediaInformationSession.h
    src/MediaInformationSessionCompleteCallback.h
    src/Packages.h
    src/ReturnCode.h
    src/Session.h
    src/SessionState.h
    src/FFmpegKitSignal.h
    src/Statistics.h
    src/StatisticsCallback.h
    src/StreamInformation.h
    src/ffmpegkit_exception.h
    src/fftools_cmdutils.h
    src/fftools_ffmpeg.h
    src/fftools_ffmpeg_mux.h
    src/fftools_fopen_utf8.h
    src/fftools_objpool.h
    src/fftools_opt_common.h
    src/fftools_sync_queue.h
    src/fftools_thread_queue.h
    src/ffmpegkit_c_api.h
)

add_library(ffmpegkit SHARED ${FFMPEGKIT_SOURCES})

target_compile_definitions(ffmpegkit PRIVATE FFMPEGKIT_EXPORTS)

target_include_directories(ffmpegkit
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<INSTALL_INTERFACE:include>
)

target_compile_definitions(ffmpegkit PRIVATE WIN32 _WIN32_WINNT=0x0A00)

if(DEFINED FFMPEG_INCLUDE_DIR)
    target_include_directories(ffmpegkit PRIVATE "${FFMPEG_INCLUDE_DIR}")
endif()

if(DEFINED MINGW_INCLUDE_DIR)
    target_include_directories(ffmpegkit PRIVATE "${MINGW_INCLUDE_DIR}")
endif()

if(DEFINED FFMPEG_SRC_DIR)
    target_include_directories(ffmpegkit PRIVATE "${FFMPEG_SRC_DIR}")
endif()

if(DEFINED FFMPEG_LIB_DIR)
    target_link_directories(ffmpegkit PRIVATE "${FFMPEG_LIB_DIR}")
endif()

target_link_libraries(ffmpegkit PRIVATE
    avdevice avfilter avformat avcodec swresample swscale avutil
    ws2_32 bcrypt crypt32
)

target_link_options(ffmpegkit PRIVATE "-Wl,--default-image-base-low")

install(TARGETS ffmpegkit
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

install(FILES ${FFMPEGKIT_HEADERS} DESTINATION include)
install(FILES src/ffmpegkit_c_api.h DESTINATION include)
