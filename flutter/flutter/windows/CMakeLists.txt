cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "ffmpeg_kit_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "ffmpeg_kit_flutter_plugin")

add_library(${PLUGIN_NAME} SHARED
  "ffmpeg_kit_flutter_plugin.cpp"
  "ffmpeg_kit_flutter_plugin_c_api.cpp"
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_STANDARD 17
  CXX_VISIBILITY_PRESET hidden)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Locate prebuilt ffmpegkit binaries
# Flutter creates directory junctions on Windows under .plugin_symlinks/.
# Resolve the junction to find the real plugin root, then navigate to the prebuilt dir.
get_filename_component(JUNCTION_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
file(READ_SYMLINK "${JUNCTION_DIR}" PLUGIN_REAL_ROOT)
# Windows junction targets may have NT prefix (\??\) which shows as /??/ in CMake
string(REGEX REPLACE "^/\\?\\?/" "" PLUGIN_REAL_ROOT "${PLUGIN_REAL_ROOT}")
string(REGEX REPLACE "^\\\\\\?\\?\\\\(.)" "\\1" PLUGIN_REAL_ROOT "${PLUGIN_REAL_ROOT}")
if(NOT IS_ABSOLUTE "${PLUGIN_REAL_ROOT}")
  get_filename_component(PLUGIN_REAL_ROOT "${JUNCTION_DIR}/${PLUGIN_REAL_ROOT}" ABSOLUTE)
endif()
# Map CMAKE_SYSTEM_PROCESSOR to the ffmpeg-kit bundle architecture name
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
  set(FFMPEGKIT_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "X86" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "i686")
  set(FFMPEGKIT_ARCH "i686")
elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
  set(FFMPEGKIT_ARCH "aarch64")
else()
  set(FFMPEGKIT_ARCH "x86_64")
endif()

set(FFMPEGKIT_PREBUILT_DIR "${PLUGIN_REAL_ROOT}/../../prebuilt/bundle-windows-${FFMPEGKIT_ARCH}/ffmpeg-kit")
get_filename_component(FFMPEGKIT_PREBUILT_DIR "${FFMPEGKIT_PREBUILT_DIR}" ABSOLUTE)
message(STATUS "FFmpegKit prebuilt dir: ${FFMPEGKIT_PREBUILT_DIR} (arch: ${FFMPEGKIT_ARCH})")

# Auto-download prebuilt binaries if not present
set(FFMPEGKIT_VERSION "8.0.0")
set(FFMPEGKIT_RELEASE_TAG "${FFMPEGKIT_VERSION}-full")
set(FFMPEGKIT_ZIP_NAME "ffmpeg-kit-windows-${FFMPEGKIT_ARCH}-full-${FFMPEGKIT_VERSION}.zip")
set(FFMPEGKIT_DOWNLOAD_URL "https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/${FFMPEGKIT_RELEASE_TAG}/${FFMPEGKIT_ZIP_NAME}")
set(FFMPEGKIT_ZIP_PATH "${FFMPEGKIT_PREBUILT_DIR}/${FFMPEGKIT_ZIP_NAME}")

if(NOT EXISTS "${FFMPEGKIT_PREBUILT_DIR}/bin/libffmpegkit.dll")
  message(STATUS "FFmpegKit prebuilt binaries not found — downloading from ${FFMPEGKIT_DOWNLOAD_URL}")
  file(MAKE_DIRECTORY "${FFMPEGKIT_PREBUILT_DIR}")
  file(DOWNLOAD
    "${FFMPEGKIT_DOWNLOAD_URL}"
    "${FFMPEGKIT_ZIP_PATH}"
    SHOW_PROGRESS
    STATUS FFMPEGKIT_DOWNLOAD_STATUS
  )
  list(GET FFMPEGKIT_DOWNLOAD_STATUS 0 FFMPEGKIT_DOWNLOAD_CODE)
  list(GET FFMPEGKIT_DOWNLOAD_STATUS 1 FFMPEGKIT_DOWNLOAD_MSG)
  if(NOT FFMPEGKIT_DOWNLOAD_CODE EQUAL 0)
    file(REMOVE "${FFMPEGKIT_ZIP_PATH}")
    message(FATAL_ERROR "Failed to download FFmpegKit: ${FFMPEGKIT_DOWNLOAD_MSG}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xf "${FFMPEGKIT_ZIP_PATH}"
    WORKING_DIRECTORY "${FFMPEGKIT_PREBUILT_DIR}"
    RESULT_VARIABLE FFMPEGKIT_UNZIP_RESULT
  )
  file(REMOVE "${FFMPEGKIT_ZIP_PATH}")
  if(NOT FFMPEGKIT_UNZIP_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to extract FFmpegKit archive")
  endif()
  message(STATUS "FFmpegKit prebuilt binaries downloaded and extracted successfully")
endif()

# Strip HIGH_ENTROPY_VA flag from MinGW-built DLLs to prevent
# "32 bit pseudo relocation out of range" crashes on first launch.
set(FFMPEGKIT_HEVA_MARKER "${FFMPEGKIT_PREBUILT_DIR}/bin/.heva_stripped")
if(NOT EXISTS "${FFMPEGKIT_HEVA_MARKER}" AND EXISTS "${FFMPEGKIT_PREBUILT_DIR}/bin/libffmpegkit.dll")
  message(STATUS "Stripping HIGH_ENTROPY_VA from prebuilt DLLs")
  execute_process(
    COMMAND powershell -NoProfile -Command "
      foreach ($dll in Get-ChildItem -Path '${FFMPEGKIT_PREBUILT_DIR}/bin/*.dll') {
        $bytes = [System.IO.File]::ReadAllBytes($dll.FullName)
        $peOff = [BitConverter]::ToInt32($bytes, 0x3C)
        $off = $peOff + 0x5E
        $val = [BitConverter]::ToUInt16($bytes, $off)
        if ($val -band 0x0020) {
          $val = $val -band (0xFFFF -bxor 0x0020)
          $nb = [BitConverter]::GetBytes([UInt16]$val)
          $bytes[$off] = $nb[0]; $bytes[$off+1] = $nb[1]
          [System.IO.File]::WriteAllBytes($dll.FullName, $bytes)
          Write-Host \"Patched: $($dll.Name)\"
        }
      }
      New-Item -Path '${FFMPEGKIT_PREBUILT_DIR}/bin/.heva_stripped' -ItemType File -Force | Out-Null
    "
    RESULT_VARIABLE FFMPEGKIT_HEVA_RESULT
  )
  if(NOT FFMPEGKIT_HEVA_RESULT EQUAL 0)
    message(WARNING "Failed to strip HIGH_ENTROPY_VA from DLLs (non-fatal)")
  endif()
endif()

set(FFMPEGKIT_DLLS
  "${FFMPEGKIT_PREBUILT_DIR}/bin/libffmpegkit.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/avcodec-61.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/avdevice-61.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/avfilter-10.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/avformat-61.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/avutil-59.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/swresample-5.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/swscale-8.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/libgcc_s_seh-1.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/libwinpthread-1.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/libstdc++-6.dll"
  "${FFMPEGKIT_PREBUILT_DIR}/bin/zlib1.dll"
)

set(ffmpeg_kit_flutter_bundled_libraries
  ${FFMPEGKIT_DLLS}
  PARENT_SCOPE
)
