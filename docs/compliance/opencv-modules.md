# OpenCV: the modules we build (DK-0680)

**Decision:** Dokulo builds OpenCV (through `opencv_dart` / `dartcv4`) with
`core`, `imgproc` and `imgcodecs` only. Every other module is excluded,
explicitly, so a later default change in `dartcv4` can't pull one back in. With
`highgui` and `videoio` out, no FFmpeg library is built or bundled; with `dnn`
out, no protobuf; the contrib modules (`aruco`, `img_hash`, `freetype`, …) are
out. Checked against `opencv_dart` 2.2.2 with `dartcv4` 2.2.2 (what pub resolves) and 2.3.1 (the latest), 2026-10-07.

## What we need from OpenCV

| Feature (Technology plan) | OpenCV calls | Module |
| --- | --- | --- |
| Scanner quad detection | `resize`, `cvtColor`, `Canny`, `dilate`/`morphologyEx`, `findContours`, `approxPolyDP`, `contourArea` | imgproc |
| Perspective fix | `getPerspectiveTransform`, `warpPerspective` | imgproc |
| Filters: B/W, greyscale, colour boost, shadow removal | `adaptiveThreshold`, `cvtColor`, `createCLAHE`, `dilate`, `medianBlur`, `divide` | imgproc, core |
| Book mode spine | `HoughLinesP`, `reduce` (projection profile) | imgproc, core |
| Compress PDF, thumbnails | `resize`, `imencode`/`imdecode` (JPEG via libjpeg-turbo, PNG) | imgproc, imgcodecs |
| Smart Split pHash | `resize` to 32×32, `dct`, compare the 8×8 low band (own code, a few lines) | imgproc, core |
| Compare PDF visual mode | `absdiff`, `threshold` | core, imgproc |
| Compression test (SSIM ≥ 0.9) | SSIM from `GaussianBlur` and `multiply` (test code, a few lines) | imgproc, core |

pHash and SSIM are written on `core` + `imgproc` instead of pulling in the
contrib modules `img_hash` and `quality` for one function each.

## The configuration

In the root `pubspec.yaml` (the workspace root once DK-0001 sets up the
monorepo; `hooks.user_defines` are read from there), in the same PR that adds
`opencv_dart`:

```yaml
hooks:
  user_defines:
    dartcv4:
      include_modules: # `core` is always built
        - imgproc
        - imgcodecs
      exclude_modules: # all the others, explicitly (DK-0680)
        - highgui
        - videoio
        - video
        - dnn
        - calib3d
        - features2d
        - flann
        - freetype
        - objdetect
        - photo
        - stitching
        - aruco
        - img_hash
        - quality
        - wechat_qrcode
        - ximgproc
        - xobjdetect
```

Adding a module later is a change to this page and the licence register
(the third-party libraries it brings) in the same PR.

## Why it matters even though FFmpeg is "gone"

`dartcv4` 2.2.0's changelog says FFmpeg is no longer included, and its OpenCV
build sets `WITH_FFMPEG=OFF`. But its build hook still adds the FFmpeg
libraries (`avcodec`, `avformat`, `avutil`, `swscale`, `swresample`,
`avdevice`, `avfilter`) as code assets whenever `highgui` or `videoio` is
included (`lib/src/hook_helpers/run_build.dart`), and FFmpeg is LGPL/GPL. So
the exclusion is the rule, and the built app is checked (below).

## What the build links (for the licence register)

`dartcv4` builds OpenCV from source and links these statically into
`libdartcv.so` (Android) / the dartcv framework (iOS):

| Library | Licence | Platforms |
| --- | --- | --- |
| OpenCV 4.13.0 (core, imgproc, imgcodecs) | Apache-2.0 | both |
| zlib | Zlib | both |
| libjpeg-turbo | BSD-3 + IJG | both |
| libpng | libpng licence (permissive) | both |
| libwebp | BSD-3 | both |
| libtiff | libtiff licence (BSD-style) | Android (off on iOS) |
| OpenJPEG | BSD-2 | Android (off on iOS) |
| Carotene / KleidiCV (ARM HAL) | BSD-3 / Apache-2.0 | arm builds |

Excluded by the module list: FFmpeg (with highgui/videoio), protobuf (with
dnn), quirc (with objdetect), FreeType and HarfBuzz (with freetype). The probe
build's CMake cache confirms it: `WITH_FFMPEG=OFF`, and only
`BUILD_opencv_core`, `_imgproc` and `_imgcodecs` are on. `WITH_PROTOBUF`,
`WITH_QUIRC`, `WITH_FLATBUFFERS` and `WITH_VULKAN` stay on as flags, but only
the modules we don't build use them. OpenCL is on: OpenCV loads the device's
`libOpenCL.so` at run time if one exists, and nothing is bundled.

## Verified in the build

`python tools/native_libs_check.py <apk, aab or folder>` fails when the built
app contains an FFmpeg library, an OpenCV videoio/highgui/dnn library, or a
`libdartcv` that exports videoio, highgui or dnn functions. DK-0010 runs it on
every release build; until CI is on, run it on the APK of any PR that touches
the native build.

**Probe build, 2026-10-07:** Flutter 3.47.5, `opencv_dart` 2.2.2 / `dartcv4`
2.2.2, the configuration above, a two-line app calling `cvtColor` and
`imencode`, built with `flutter build apk --release --target-platform android-arm64`
in about 4.5 minutes (OpenCV compiled from source). The APK's native libraries
are `libapp.so`, `libflutter.so` and `libdartcv.so` (10.5 MB uncompressed;
DK-0017's size budget should count it). `libdartcv.so` exports 551 `cv_*`
functions, `cv_cvtColor` and `cv_imencode*` among them, and none from videoio,
highgui or dnn. It contains no FFmpeg strings. `native_libs_check.py`: clean.

**Windows path length:** the OpenCV source build fails with "Filename longer
than 260 characters" when the app sits deep (the probe failed at a 112-character
project path). It builds at `F:/appDevs/dokulo/.worktrees/agent-1/<52-char app
path>`. Keep the monorepo's app package paths short (DK-0001).
