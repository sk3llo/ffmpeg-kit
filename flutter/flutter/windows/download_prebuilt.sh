#!/bin/bash

# Download and unzip Windows prebuilt FFmpeg libraries
WINDOWS_URL="https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.0.0-full/ffmpeg-kit-windows-x86_64-full-8.0.0.zip"
PREBUILT_DIR="../../prebuilt/bundle-windows-x86_64/ffmpeg-kit"

mkdir -p "$PREBUILT_DIR"
curl -L "$WINDOWS_URL" -o ffmpeg-kit-windows.zip
unzip -o ffmpeg-kit-windows.zip -d "$PREBUILT_DIR"
rm ffmpeg-kit-windows.zip
