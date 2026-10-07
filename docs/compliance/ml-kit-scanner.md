# ML Kit document scanner: not enabled (DK-0677)

**Decision:** Dokulo does not ship Google's ML Kit document scanner
(`google_mlkit_document_scanner`), not even as the optional Android fast path
the Technology & Package Plan left open. Android uses our own `doc_scanner`
(CameraX + OpenCV) only; iOS uses VisionKit / Vision, as planned. No ML Kit
artifact (scanner, text recognition, or any other ML Kit API) goes into the
app, so the privacy policy needs no ML Kit disclosure.

This applies rules already set: permissive licences only in the app, no
network traffic during a tool run, and the Privacy page's "No analytics, no
ads, no account". Turning the fast path on later would break all three, so it
would be a new decision for the owner (`team.py decision`), with this page,
the Privacy page and the privacy policy updated in the same PR.

Checked 2026-10-07 against the ML Kit terms, the Android data-disclosure page,
the Document Scanner page and the plugin's pub.dev page (sources below).

## What the terms say

| Point | What Google states | Effect on Dokulo |
|---|---|---|
| Processing | On-device; ML Kit "does not send that data and the resultant outputs to Google servers". The scanner flow "operates on-device". | Fine on its own. |
| Metrics | ML Kit sends usage and performance metrics to Google (device info, app info, device or per-installation identifiers, performance metrics, API configuration, input/output size, feature version, event types, error codes), for diagnostics and usage analytics, over HTTPS, not passed to third parties. No opt-out is documented. | Contradicts the Privacy page ("No analytics") and the "no network traffic during any tool run" rule. Would need a Play Data safety entry and a privacy-policy section. |
| Server contact | ML Kit contacts Google "from time to time" for bug fixes, updated models and accelerator compatibility. | Network use we don't control, during or around a scan. |
| Delivery | The scanner's UI, models and resources are delivered by Google Play services, not bundled. | Needs Play services (none on Huawei / de-Googled phones) and may need a download on first use, offline included. |
| Disclosure duty | "You are responsible for informing users of your app about Google's processing of ML Kit metrics data." | Mandatory disclosure if enabled. |
| Licence | Proprietary Google terms (plus the Google APIs Terms of Service); no reverse engineering. The Flutter plugin is MIT, but it only bridges to the closed SDK. | Not a permissive licence. The rule is permissive only in the app. |
| Platforms | Android only; minSdk 21 (plugin 0.6.1). | iOS gains nothing. |
| UI | Google's scanner UI runs in Play services; the app gets the result files. | Can't follow S1/S2 of the UI spec (auto-capture, filters, ID and book modes, page tray). |

## Consequences

- `doc_scanner` (CameraX + OpenCV) is the only Android scanner. It is not a
  fallback, so its quality bar is the scanner bar (Technology plan,
  "Scanner"; the quad-detection corpus test).
- The Android scanner needs the app's own `CAMERA` permission (DK-0016).
  ML Kit's "no camera permission needed" doesn't apply to us.
- OCR on Android stays PP-OCRv5 on ONNX Runtime. ML Kit Text Recognition,
  named in the product doc's stack table, is out for the same metrics reason.
- The licence register lists ML Kit as **not used** (DK-0672).
- DK-0337 (blocked by this task) builds on the in-house scanner only.

## Sources

- ML Kit terms: <https://developers.google.com/ml-kit/terms>
- ML Kit Android data disclosure: <https://developers.google.com/ml-kit/android-data-disclosure>
- Document Scanner: <https://developers.google.com/ml-kit/vision/doc-scanner>
- Plugin: <https://pub.dev/packages/google_mlkit_document_scanner> (0.6.1, MIT, Android only)
