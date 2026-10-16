# Me and its settings pages: visual QA

M1 and M3 (UI spec §23) against the design export's `22-me-settings`
frames. Board: `packages/app_pdf/test/qa/me_qa_test.dart` (the real M1 with
Pro owned, M3 Files & storage with a file on disk, M3 Security with a PIN,
App lock and Face ID on), light and dark at 393 × 852; goldens
`test/qa/goldens/qa_me_<frame>_<theme>.png`. Frames: [me/](me/), headless
Chrome at 520 × 940, light, dark and deutsch. The goldens draw text as blocks
(the test font), so the copy is checked as values: every string of the three
frames matches `app_en.arb` and `app_de.arb` (Me/Ich, Pro – yours for good /
Pro – für immer deins, Your things / Deine Sachen, Files & storage / Dateien
& Speicher, Keep deleted files / Gelöschte Dateien behalten, Clear cache /
Cache leeren, App lock / App-Sperre, Lock after / Sperren nach, 1 min /
1 Min., …).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0937 | `22-me-settings/me-mepro` | 2 deviations: DK-1097 |
| DK-0941 | `22-me-settings/me-files` | 1 deviation: DK-1098; 2 approved |
| DK-0942 | `22-me-settings/me-security` | Match, 1 approved |
| DK-0944 | `22-me-settings/me-language` | Match |

## M1 · Me – Pro (DK-0937)

Deviations, filed as DK-1097 (lane B):

- The Pro owned row is a plain settings row with "Thank you" as its value.
  §23.1 and the frame: an inset card row on `color.proContainer`,
  `workspace_premium` in `color.pro`, "Thank you" as a caption under the
  title.
- Your things shows no values. §23.1 and the frame: Signatures and Workflows
  show their counts, AI models the size used ("1.8 GB").

What matches: the large title, the section order (Pro, Your things, Settings,
About, the footer), the icons, Appearance and Language showing "System".

## M3 · Files & storage (DK-0941)

Deviation, filed as DK-1098 (lane B): the storage bar is 8 high with no gaps,
AI models in `color.success` and Cache in `color.outlineStrong`; the frame's
bar is 10 high (radius 5) with 2 px gaps, AI models in `color.warning`, Cache
in `color.iconSecondary`.

Approved:

- Default save folder has no chevron: Dokulo has one save folder for now
  (the ponytail note in `files_settings_screen.dart`); the chevron comes when
  choosing another folder does.
- Export all files has no action and no chevron yet: it opens the system
  share sheet once share_plus lands (DK-1077).

## M3 · Security (DK-0942)

Matches: the five rows in the frame's order, App lock's description with the
biometric name, the switches, "1 min" with its chevron, Change locked folder
PIN. Approved: the top bar's title is left-aligned on Android and centred on
iOS (§11.6 DkTopBar); the frame shows the iOS one, as on the other pushed
pages (`folders.md`, `search-trash.md`).

## M3 · Language (DK-0944)

Board: `qa_me_language_*` (light, dark, German), the real page with no
language chosen. Matches the frame: the three radio rows System · English ·
Deutsch (German: System · Englisch · Deutsch) in one inset card with the
check on System, and the caption "Changes immediately. No restart needed." /
"Wird sofort übernommen. Kein Neustart nötig." under it. The top bar's title
is left-aligned on Android (§11.6), as on the other pushed pages.
