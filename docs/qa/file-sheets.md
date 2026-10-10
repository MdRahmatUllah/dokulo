# File sheets and Recently deleted: visual QA

The file action sheet, Info, Rename, Move and R1 against the design export.
Board: `packages/app_pdf/test/qa/file_sheets_qa_test.dart` (the real F1, its
sheets and R1 in the shell at 393 × 852, light and dark, with the frames'
files); frames: [file-sheets/](file-sheets/), headless Chrome as
`docs/qa/design-system.md`. The goldens draw text as blocks, so the copy is
checked as values: the sheet's rows, Info's labels, Rename's "A file with
this name already exists.", Move's title and Move here, R1's banner, Empty
and "{n} days left" match the UI spec §16.3–§16.5 in EN and DE.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0742 | `04-files/files-action` | 1 fixed, 2 approved |
| DK-0743 | `04-files/files-info` | 2 fixed |
| DK-0744 | `04-files/files-rename` | Match, 1 approved |
| DK-0745 | `04-files/files-move` | 3 fixed, 1 approved |
| DK-0747 | `04-files/files-trash` | Match |

Fixed:

- S1. The action sheet's header shows a white page for a file whose first
  page can't be drawn, as the cards do; it showed nothing.
- S2. Info: the page is 72 × 96 with its outline, as files-info; it was a
  40 × 52 page without one (white on the white sheet).
- S3. Info: a hairline under each detail row, as the frame.
- S4. Move: Move here sits in the sheet's sticky action area at the bottom,
  as files-move; it followed the list.
- S5. Move: New folder is a row in `color.primary` with its icon, no
  chevron, as the frame; it was a settings row.
- S6. Move: the folders are DkFolderCard rows, as in Files (the tag colour,
  the count under the name, the chevron); they were settings rows with the
  count as a value.

Approved:

- The action sheet suggests up to 5 tools (DK-0271; the frame shows 4), and
  Share is shown disabled until share_plus lands (DK-1077).
- Rename: the extension sits at the field's end (DkTextField's suffix), not
  right after the selected name as the frame draws it.
- Move: the sheet closes with its × (DkSheet), where the frame has Cancel at
  the top left.
