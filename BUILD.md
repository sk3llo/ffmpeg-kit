ERROR LIB: libilbc

## BUILDING SCRIPTS

* LIBS TO REBUILD:
*   --rebuild-libiconv (from .17 to .18)

* As usual for GNU packages:

```
OLD:
sudo ./configure --prefix=/usr/local && sudo make && sudo make install

NEW: 
sudo ./configure && sudo make && sudo make install

SOME LIBS (LIKE `libxml2):
./autogen.sh

SOMETIMES:
sudo ./configure --prefix=/usr/local --enable-shared
```

* SOMETIMES:

autoreconf -f -i

* CLEAR READ ONLY STATUS

```
sudo chown -R $USER /Users/me/StudioProjects/ffmpeg-kit-6.0.LTS
```

* Clean make
```
sudo make clean && sudo make distclean
```

* Android:      ( --disable-arm-v7a --disable-arm-v7a-neon --disable-x86 --disable-x86-64 )

full-gpl
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --full --enable-gpl --enable-android-media-codec --disable-arm-v7a --disable-arm-v7a-neon --disable-x86 --disable-x86-64
```

full
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-gmp --enable-gnutls --enable-kvazaar --enable-lame --enable-libass --enable-libiconv --enable-libilbc --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libxml2 --enable-opencore-amr --enable- --enable-opus --enable-shine --enable-snappy --enable-soxr --enable-speex --enable-twolame --enable-vo-amrwbenc --enable-zimg --enable-android-media-codec 
```

video
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-kvazaar --enable-libass --enable-libiconv --enable-libtheora --enable-libvpx --enable-libwebp --enable-snappy --enable-zimg --enable-android-media-codec
```

audio
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-twolame --enable-lame --enable-libilbc --enable-libvorbis --enable-opencore-amr --enable-opus --enable-shine --enable-soxr --enable-speex --enable-vo-amrwbenc --enable-android-media-codec 
```

https-gpl (WHEN BUILDING - ENABLE gnutls IN scripts/android/ffmpeg.sh)
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-gpl --enable-gmp --enable-gnutls --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore --enable-android-media-codec
```

https (WHEN BUILDING - ENABLE gnutls IN scripts/android/ffmpeg.sh)
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-gmp --enable-gnutls --enable-android-media-codec
```

min-gpl
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-gpl --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore --enable-android-media-codec
```

min
```
export ANDROID_SDK_ROOT=/Users/me/Library/Android/sdk && export ANDROID_NDK_ROOT=/Users/me/Library/Android/sdk/ndk/29.0.13113456 && sudo -E ./android.sh --enable-android-media-codec
```







* iOS:

full-gpl
```
sudo ./ios.sh --full --enable-gpl
```

full
```
sudo ./ios.sh --full
```

video
```
sudo ./ios.sh --enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-kvazaar --enable-libass --enable-ios-libiconv --enable-libtheora --enable-libvpx --enable-libwebp --enable-snappy --enable-zimg
```

audio
```
sudo ./ios.sh --enable-twolame --enable-lame --enable-libilbc --enable-libvorbis --enable-opencore-amr --enable-opus --enable-shine --enable-soxr --enable-speex --enable-vo-amrwbenc
```

https-gpl (WHEN BUILDING - ENABLE gnutls IN scripts/apple/ffmpeg.sh)
```
sudo ./ios.sh --enable-gpl --enable-gmp --enable-gnutls --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore
```

https (WHEN BUILDING - ENABLE gnutls IN scripts/apple/ffmpeg.sh)
```
sudo ./ios.sh --enable-gmp --enable-gnutls
```

min-gpl
```
sudo ./ios.sh --enable-gpl --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore
```

min
```
sudo ./ios.sh
```




* MacOS: `./macos.sh`

full-gpl
```
sudo ./macos.sh --full --enable-gpl
```

full
```
sudo ./macos.sh --full
```

video
```
sudo ./macos.sh --enable-dav1d --enable-fontconfig --enable-freetype --enable-fribidi --enable-kvazaar --enable-libass --enable-ios-libiconv --enable-libtheora --enable-libvpx --enable-libwebp --enable-snappy --enable-zimg
```

audio
```
sudo ./macos.sh --enable-twolame --enable-lame --enable-libilbc --enable-libvorbis --enable-opencore-amr --enable-opus --enable-shine --enable-soxr --enable-speex --enable-vo-amrwbenc
```

https-gpl (WHEN BUILDING - ENABLE gnutls IN scripts/apple/ffmpeg.sh)
```
sudo ./macos.sh --enable-gpl --enable-gmp --enable-gnutls --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore
```

https (WHEN BUILDING - ENABLE gnutls IN scripts/apple/ffmpeg.sh)
```
sudo ./macos.sh --enable-gmp --enable-gnutls
```

min-gpl (No Videotoolbox)
```
sudo ./macos.sh --enable-gpl --enable-libvidstab --enable-x264 --enable-x265 --enable-xvidcore
```

min (No Videotoolbox support)
```
sudo ./macos.sh
```


MACOS:
* BUILD MACOS FRAMEWORKS:     ./macos.sh -x --full --enable-gpl



### FIX FOR CERTAIN LIBS

# LIBSRT

(INSIDE `src/srt` directory):
1. rm -rf CMakeCache.txt CMakeFiles/
2. sudo cmake . -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++
3. sudo make && sudo make install

# LIBVORBIS

1. sudo make distclean
2. sudo autoreconf -fiv
3. sudo make && sudo make install

# LIBTHEORA

1. sudo make distclean
2. sudo ./autogen.sh
3. sudo ./configure && sudo make && sudo make install

