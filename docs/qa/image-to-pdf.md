# Image to PDF: visual QA

Image to PDF's T2 (UI spec §21.7) against `14-tools-convert/tools-convert-img2pdf`
(light, dark). Board: `test/tools/img2pdf_tool_test.dart`'s
`img2pdf_options_*` (12 images) and `test/screens/tool_input_test.dart`'s
`img2pdf_qa_skipped` (a pick with two files that aren't images). Frames in
[image-to-pdf/](image-to-pdf/).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0871 | `tools-convert-img2pdf` | Match, 2 approved |

What matches: the privacy line, Images (12) with Add, the numbered strip,
Page size (Fit image · A4 · Letter), Margins (None · Small), Output (One PDF
· One per image), Clean up like a scan (off) with its help, the warning
banner "2 files aren't images and were skipped.", the estimate line and
"Create PDF · 12 images".

Approved:

- The "Options" header over the options: §21's T2 layout (row 4) has it;
  the frame leaves it out.
- The skipped-files banner sits above the strip, where it's seen on the
  pick; the frame puts it under the options (§21.7 names no place).
