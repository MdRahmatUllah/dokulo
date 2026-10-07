# Store privacy labels (DK-0679)

What the owner enters in App Store Connect ("App Privacy") and the Play
Console ("Data safety"), with the reason for each answer. It follows from the
owner's decisions (no ads, no analytics, no account: `.team/MEMORY.md`) and
from `docs/privacy-policy.md`. A new SDK or network use changes this file
first (`docs/compliance/network-uses.md`).

## Apple: App Privacy

| Question | Answer | Why |
| --- | --- | --- |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app.** The label reads **"Data Not Collected"** | Nothing leaves the phone automatically: no analytics, no ads, no account, no crash upload, no server of ours |
| Tracking | **No** tracking | No ad SDK, no IDFA, `NSPrivacyTracking` false, no tracking domains (`ios/Runner/PrivacyInfo.xcprivacy`) |
| Privacy policy URL | the website's page with `docs/privacy-policy.md` | Required for every app |

Why the edge cases don't count as "collection" under Apple's definition (data
sent off the device in a way that lets the developer or partners access it
beyond the real-time request):

- **Crash report by email:** optional, user-initiated, infrequent, not part
  of the app's main function, and the user sees and sends it from their own
  mail app. That is Apple's "optional disclosure" exception. The report holds
  no personal data anyway (`docs/compliance/crash-reports.md`).
- **Model downloads and Web page to PDF:** plain downloads the user starts.
  We receive nothing; the host sees a normal request.
- **Purchases:** processed by Apple (StoreKit). We receive no data.

`NSPrivacyCollectedDataTypes` in the privacy manifest stays an empty array
(DK-0682 left it for this task: it is settled).

## Google Play: Data safety

| Question | Answer | Why |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **No** | As above: nothing is collected; transfers the user starts (downloads, the web page they load) are exempt |
| Is all of the user data collected by your app encrypted in transit? | n/a (no data collected); every network use is https except a web page the user types as http | `Network.downloadModel` refuses non-https |
| Do you provide a way for users to request that their data is deleted? | n/a (no data); the policy explains how to ask for an emailed crash report to be deleted | |
| Security practices shown | "No data collected", "No data shared with third parties" | |
| Ads | **Contains ads: No** (Play's app-content declaration) | The owner, 2026-10-08 |
| Account creation | None | |

Play's exemptions used: **user-initiated transfers to a third party** (the
model host, the web page) and **data processed on the device only** (files,
scans, AI, photos, the locked folder).

## Before each release (the release checklist, DK-0664)

- `docs/compliance/network-uses.md` still lists exactly three uses, and the
  airplane-mode test passes.
- No new SDK in `pubspec.lock` sends data (`python tools/licence_scan.py`
  lists every package; a new one is reviewed against this file).
- The website's privacy policy matches `docs/privacy-policy.md`.
