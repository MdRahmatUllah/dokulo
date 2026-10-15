# Locked folder, app lock and privacy cover: visual QA

L1–L4, the unlock screen, the open folder with the move toast, the app
lock and the app-switcher cover against the design export. Board:
`packages/app_pdf/test/qa/locked_qa_test.dart` (the real F2, DkAppLock and
DkPrivacyCover at 393 × 852, light and dark; the content frame moves three
real files into a real vault); frames: [locked/](locked/), headless Chrome
as `docs/qa/design-system.md`. The goldens draw text as blocks, so the copy
is checked as values: "Keep files private", the warning, "Set up", "Create
a 6-digit PIN", "PINs don't match. Try again.", "Use Face ID?", "Locked
folder", "Moved 3 files to Locked folder" and "Dokulo is locked" match the
UI spec §16.6 in EN and DE.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0755 | `05-locked-folder/locked-folder-l1` | Match, 1 approved |
| DK-0756 | `05-locked-folder/locked-folder-l2` | 1 fixed |
| DK-0757 | `05-locked-folder/locked-folder-l3` | 1 fixed |
| DK-0758 | `05-locked-folder/locked-folder-l4` | 1 fixed |
| DK-0759 | `05-locked-folder/locked-folder-unlock` | 1 fixed |
| DK-0760 | `05-locked-folder/locked-folder-content` | Match, 1 approved |
| DK-0761 | `05-locked-folder/locked-folder-applock` | Match, 1 approved |
| DK-0762 | `05-locked-folder/locked-folder-cover` | Match, 1 approved |

Fixed:

- K1. The PIN pages (L2, L3, unlock) are centred: the title, the dots and
  the keypad sat at the start of the screen (left in English), because the
  scroll view under them gave the column a loose width and it shrank to the
  keypad's width.
- K2. L4's illustration is the 120 circle on `color.primaryContainer` with
  the glyph (48) in `color.iconPrimary`, as the frame; it was 80 with a
  primary-tinted glyph.
- K3. Moving several files in no longer fails on Windows test runs:
  `LockedStore` replaces its index with a short retry when another reader
  holds it open (Windows refuses the rename; Android and iOS never do).

Approved:

- L1: the text follows the illustration near the top; the frame pins it
  above the warning. §16.6 sets the content, not the layout.
- The folder's rows have their more button (DkFileCard, as in Files); the
  frame leaves it out.
- The app lock and the cover show the brand symbol (DkLogo, §31; "Dokulo
  symbol 56" / "72"); the frames still draw the earlier blue tile.
