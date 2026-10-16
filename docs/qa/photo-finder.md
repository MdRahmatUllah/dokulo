# Photo finder: visual QA

Find documents in photos (UI spec §19.5) against the design export's
`11-photo-finder` frames. Board: `test/photo_finder/photo_finder_screens_test.dart`,
its "visual QA" group (`goldens/pf_qa_<frame>_<light|dark|de>.png`) and the
results golden (`photo_finder_results_*`). Frames in
[photo-finder/](photo-finder/) (light, dark, German).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0832 | `photo-finder-intro` | Match: ILL-17, title, body, Allow photo access, Not now |
| DK-0833 | `photo-finder-scanning` | **DK-1136**: the card is on no screen; its colour |
| DK-0834 | `photo-finder-results` | Match: month headers, 3 columns, the badge, the check circles, Convert n to PDF |
| DK-0835 | `photo-finder-convert` | **DK-1136**: a segmented control, not radio rows |
| DK-0836 | `photo-finder-empty` | Match: ILL-17, No documents found, the line, Close |
| DK-0837 | `photo-finder-notdoc` | **DK-1136**: no scrim behind the menu |

**DK-1136** (P1, lane C): nothing in the app shows PhotoFinderCard or opens
the results route, so the feature can't be reached (Home should show the
card while a scan runs, and the card opens the results). The card is on
`surface`; the frame's is the subtle primary container. The convert sheet's
choice is a segmented control; the frame has radio rows. The long-press menu
has no scrim.

Approved: the results title sits left with the back arrow (DkTopBar, every
screen); the frames centre it. The empty frame's illustration sits left of
centre, an export slip; the app centres it.

Next pass: DK-0833, DK-0835, DK-0837 once DK-1136 merges.
