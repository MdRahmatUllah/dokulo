# Release builds (DK-0015)

How Dokulo is built for testing and for the stores. There is no CI/CD (the
owner, 2026-10-07): every build is made locally, from a green
`python tools/check.py`, by the person who holds the keys.

## Flavors

Three flavors install side by side on one phone. The app id is the owner's
decision (2026-10-07): `app.dokulo`.

| Flavor | Android application id | iOS bundle id | Name on the phone | For |
| --- | --- | --- | --- | --- |
| `dev` | `app.dokulo.dev` | `app.dokulo.dev` | Dokulo Dev | Daily work; the default (`flutter run`) |
| `staging` | `app.dokulo.staging` | `app.dokulo.staging` | Dokulo Staging | Release candidates, SQA's device checks |
| `prod` | `app.dokulo` | `app.dokulo` | Dokulo | The stores |

`packages/app_pdf/pubspec.yaml` sets `flutter: default-flavor: dev`, so a plain
`flutter run` or `flutter build apk` builds dev. Dart code that needs the flavor
reads `appFlavor` (`package:flutter/services.dart`).

The OCR models and the icon font are not in git. On a fresh clone, fetch them
before the first build (the gate does it too): without the font, every icon
draws as a box.

```bash
python tools/fetch_ocr_models.py               # once per clone, hash-checked
python tools/fetch_icon_font.py                # once per clone, hash-checked
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
boundary, as Google Play requires. It also checks the size budget
([size-budget.md](size-budget.md)): each ABI's APK within budget, no bundled
model but the OCR det/rec/cls. Our own native builds (`qpdf_ffi`,
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

## iOS (DK-1046)

Each flavor has its Xcode scheme (`dev`, `staging`, `prod`, in
`ios/Runner.xcodeproj/xcshareddata/xcschemes`) and its build configurations
`Debug-<flavor>`, `Release-<flavor>` and `Profile-<flavor>`, as Flutter's
`--flavor` needs. The plain `Debug`/`Release`/`Profile` stay for Xcode's
`Runner` scheme. Per flavor, the Runner target sets `PRODUCT_BUNDLE_IDENTIFIER`
(the table above) and `FLAVOR_DISPLAY_NAME`, which `CFBundleDisplayName` reads,
so the three install side by side. `BGTaskSchedulerPermittedIdentifiers` uses
`$(PRODUCT_BUNDLE_IDENTIFIER).jobs`, so it follows the flavor.

```bash
cd packages/app_pdf
flutter run -d <iPhone>                          # dev (default-flavor)
flutter build ios --flavor staging --release
flutter build ipa --flavor prod --release --obfuscate --split-debug-info=../../build/symbols/1.0.0+100
```

Plugins come in through Swift Package Manager (`FlutterGeneratedPluginSwiftPackage`).
If a plugin ever needs CocoaPods, Flutter writes an `ios/Podfile`. Map every
flavor configuration there, or the `Debug-*` builds link release pods:
`'Debug-dev' => :debug, 'Release-dev' => :release, 'Profile-dev' => :release`,
and the same for `staging` and `prod`.

Still open:
- the first build of the schemes on a Mac (`flutter build ios --flavor <f>` for all three, side by side on one iPhone);
- signing with the owner's Apple team (`DEVELOPMENT_TEAM`, never in git when it is personal);
- one App Group shared by the app, the Share Extension, the Files Action Extension and the widgets, once those targets exist.
