# Folders: visual QA

The folder screen and its menu, the empty folder and New folder against the
design export. Board: `packages/app_pdf/test/qa/folders_qa_test.dart` (the
real F1 and folder screen in the shell at 393 × 852, light and dark, with the
frame's Taxes › 2026 and its four files); frames: [folders/](folders/),
headless Chrome as `docs/qa/design-system.md`. The goldens draw text as
blocks, so the copy is checked as values: the breadcrumb, Files and its count,
Rename folder, Colour, the six colour names, Delete folder, This folder is
empty, Move files here, New folder, Folder name, Cancel and Create match the
UI spec §16.1–§16.2 in EN and DE.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0735 | `04-files/files-folder` | Match, 1 approved |
| DK-0738 | `04-files/files-emptyfolder` | Match |
| DK-0746 | `04-files/files-newfolder` | Match, 1 approved |
| DK-0754 | `04-files/files-foldermenu` | 1 fixed |
| DK-0751 | `04-files/files-dragfolder` | Match (M2), 2 approved |

Fixed:

- M1. The folder menu shows the six colours as swatches under "Colour",
  the chosen one ringed, as files-foldermenu; Colour opened a second menu of
  names. The row still opens that list (with No colour). `DkAction.below`
  puts a widget under a menu row.
- M2. Dragging a file over a folder in grid view says "Drop on “{folder}” to
  move" / "Auf „{folder}“ ablegen zum Verschieben", as files-dragfolder
  (its board: `test/qa/files_drag_qa_test.dart`, the file held over
  Apartment in grid view).

Approved:

- The folder screen's title is centred on iOS and left-aligned on Android
  (DkTopBar, §11.6); the frames are iOS. The board runs as Android.
- New folder: Create stays disabled until a name is typed (DK-0273); the
  frame shows it enabled over an empty field.
- files-dragfolder: the grid's folder cards are 3 : 4 tiles in name order
  (UI spec §11.2, as in [files-root.md](files-root.md)); the frame draws
  3 : 2 wells in its own order.
- files-dragfolder: the dragged file is the grid card as it is (its
  thumbnail, name and meta), not tilted; the frame tilts a smaller card.
  §16.1 sets the folder's 2 dp primary ring, which matches.
