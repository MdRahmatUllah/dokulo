# Release builds (DK-0015)

How Dokulo is built for testing and for the stores. There is no CI/CD (the
owner, 2026-10-07): every build is made locally, from a green
`python tools/check.py`, by the person who holds the keys.

## Flavors

Three flavors install side by side on one phone. The app id is the owner's
decision (2026-10-07): `app.dokulo`.

| Flavor | Android application id | iOS bundle id | Name on the phone | For |
| --- | --- | --- | --- | --- |
| `dev` | `app.dokulo.dev` | `app.dokulo.dev` (follow-up) | Dokulo Dev | Daily work; the default (`flutter run`) |
| `staging` | `app.dokulo.staging` | `app.dokulo.staging` (follow-up) | Dokulo Staging | Release candidates, SQA's device checks |
| `prod` | `app.dokulo` | `app.dokulo` | Dokulo | The stores |

`packages/app_pdf/pubspec.yaml` sets `flutter: default-flavor: dev`, so a plain
`flutter run` or `flutter build apk` builds dev. Dart code that needs the flavor
reads `appFlavor` (`package:flutter/services.dart`).

```bash
cd packages/app_pdf
flutter run                                    # dev
flutter build apk --flavor staging --release   # build/app/outputs/flutter-apk/app-staging-release.apk
flutter build appbundle --flavor prod --release --obfuscate --split-debug-info=../../build/symbols/1.0.0+100
```

## Before a build leaves the machine

`python tools/check.py --apk <the flavor's apk>` must be green. It checks the
permissions in the merged manifest (DK-0016), the excluded OpenCV/FFmpeg
libraries (DK-0680) and **16 KB page alignment** (DK-0018): every 64-bit
(`arm64-v8a`, `x86_64`) library's LOAD segments are aligned to at least
16 KB, and every library stored uncompressed in the APK starts on a 16 KB
boundary, as Google Play requires. Our own native builds (`qpdf_ffi`,
Bergamot) link with `-Wl,-z,max-page-size=16384`; plugins built from source
with NDK r28+ (opencv_dart) get it by default.

## Version and build number

`version:` in `packages/app_pdf/pubspec.yaml` is `<name>+<build>`, e.g.
`1.0.0+100`. Me shows it as "Dokulo 1.0.0 (100)". The build number goes up by
one with every build that leaves the machine (a store upload or a build handed
to testers), on every flavor; the first store build is 100. Android uses it as
`versionCode`, iOS as `CFBundleVersion`.

## Android signing

- **Play App Signing:** Google keeps the app signing key. We sign uploads with
  an **upload key** that the owner creates and keeps, outside the repo (the repo
  is public):

  ```bash
  keytool -genkey -v -keystore ~/keys/dokulo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```

- `packages/app_pdf/android/key.properties` (gitignored, like `*.jks`) points
  the build at it:

  ```properties
  storeFile=C:/Users/<you>/keys/dokulo-upload.jks
  storePassword=…
  keyAlias=upload
  keyPassword=…
  ```

- With the file there, release builds of every flavor are signed with the
  upload key. Without it they are signed with the debug key, which is fine
  for `flutter run --release` and SQA's device checks, but not for a store.

## Obfuscation and symbols

Store builds use `--obfuscate --split-debug-info=<dir>`. The symbol files stay
with the owner, per version, outside the repo. They are only needed to read
a stack trace a user chose to send (the opt-in crash report, DK-0011):
`flutter symbolize -i <trace> -d <dir>/app.android-arm64.symbols`.

## iOS (follow-up: needs a Mac and the owner's Apple team)

Done here: the bundle id `app.dokulo` (and `app.dokulo.RunnerTests`).
Still open, in its own task: the Xcode schemes and build configurations per
flavor (`dev`, `staging`, `prod`; required by `default-flavor`, so before the
first iOS build), signing with the owner's Apple team, and one App Group shared
by the app, the Share Extension, the Files Action Extension and the widgets
once those targets exist.
