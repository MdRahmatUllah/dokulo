# Sign: visual QA

The signatures sheet and the signature pad (UI spec §17.3) against the
design export's `08-sign` frames, and Me › Signatures (`22-me-settings/
me-signatures`). Boards: `test/screens/sign/signatures_sheet_test.dart`
(`signatures_sheet_*`, `signatures_sheet_empty_*`, light, dark, German),
`test/components/dk_signature_pad_test.dart` (`signature_pad_{draw,type,
image}_*`, landscape 852 × 393) and `test/screens/m1_me/` (`signatures_*`).
Frames in [sign/](sign/) (the pad's at 980 × 520: the frames are landscape)
and [me/](me/). The German the frames show is checked in the gate by
`tools/check_design_de.py`.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0792 | `sign-list` | **DK-1135**: 'Add date next to signature' starts off |
| DK-0793 | `sign-empty` | **DK-1134**: the switches fall below the screen |
| DK-0795 | `signature-pad-draw` | Match, 1 approved |
| DK-0796 | `signature-pad-type` | Match |
| DK-0797 | `signature-pad-image` | Match |
| DK-0948 | `me-signatures` | **DK-1133**: the banner's icon |

Match: the pad's bar (Cancel, "Add signature", Save), Draw · Type · Image,
the ink swatches with their name, the baseline and Clear; Type's name field
and three handwriting previews, the first selected; Image's line and Take
photo / Choose photo (Save off until a photo is chosen). Me › Signatures:
Signatures and Initials with their cards, the dashed Add cards, the "Blue
ink · added 2 Oct" lines and the banner.

**DK-1134** (P3, lane C): at the medium detent the empty sheet's
illustration (112) and spacing push "Add date next to signature" and
"Initials on every page" below the screen; the frame fits them.
**DK-1133** (P3, lane B): Me › Signatures' banner leads with the info icon;
the frame's is a lock, as its text says the signatures are encrypted.

Approved: the pad's "Sign on the line" hint shows only while the pad is
empty (a hint, gone once you sign); the frame keeps it under a drawn
signature.

**DK-1135** (P3, lane C): the date switch starts off; sign-list and
sign-empty both show it on (§17.3 gives no default).

Next pass: DK-0794 (a placed signature with its date), on the V2 board.
