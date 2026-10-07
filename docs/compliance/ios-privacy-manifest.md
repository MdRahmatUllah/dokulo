# iOS privacy manifest (DK-0682)

Apple requires a privacy manifest (`PrivacyInfo.xcprivacy`) from the app and
from every SDK in it, declaring tracking, collected data and the reasons for
"required-reason" APIs. Checked 2026-10-07.

## The app's (`packages/app_pdf/ios/Runner/PrivacyInfo.xcprivacy`)

| Key | Value | Why |
| --- | --- | --- |
| `NSPrivacyTracking` | false | Dokulo doesn't track; no ads, no analytics |
| `NSPrivacyTrackingDomains` | none | |
| `NSPrivacyCollectedDataTypes` | none yet | Must match the App Store labels: DK-0679 (blocked on the owner's DK-0700). The crash report the user sends by email (DK-0011) is decided there |
| File timestamp | C617.1, 3B52.1 | The file index and thumbnail cache read modification dates of files in the app's container, and of files the user opens from the picker or share sheet |
| Disk space | E174.1, 85F4.1 | The free-storage check before a job writes (DK-0020) and Settings → Storage |
| System boot time | 35F9.1 | Monotonic time for job progress and time left (the job queue's stopwatch) |

UserDefaults isn't declared: nothing in the app uses it. The extensions' app
group will (1C8F.1); their targets add their own manifests when they exist.

## The SDKs

`tools/check_privacy_manifests.py` (a gate step) fails if an iOS plugin with
native code ships no manifest:

| Plugin | Native code | Manifest |
| --- | --- | --- |
| `flutter_onnxruntime` | Swift | Ships its own |
| `vision_ocr` (ours) | Swift | Added (no required-reason APIs), in Package.swift and the podspec |
| `path_provider_foundation` 2.6 | None (Dart FFI) | Not needed |

Not visible from Windows: the ONNX Runtime binary the plugin's pod or Swift
package downloads, Flutter.framework (Flutter ships its manifest), and the
native-asset frameworks `sqlite3` and PDFium. The Xcode privacy report on a
Mac lists all of them: DK-1054.
