# Search and Recently deleted: visual QA

F1's search results and empty search, R1's file sheet and the Empty dialog
against the design export. Board:
`packages/app_pdf/test/qa/search_trash_qa_test.dart` (the real F1 and R1 in
the shell at 393 × 852, light and dark, with the frames' files); frames:
[search-trash/](search-trash/), headless Chrome as
`docs/qa/design-system.md`. The goldens draw text as blocks, so the copy is
checked as values: "Names", "Text inside files", "{n} scans have no
searchable text yet.", "Make searchable", "Nothing found for “{query}”",
Restore, Delete for good and "Delete {n} files for good?" match the UI spec
§16.2–§16.5 in EN and DE.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0739 | `04-files/files-search` | 2 fixed, 1 approved |
| DK-0740 | `04-files/files-searchempty` | 1 fixed, 3 approved |
| DK-0748 | `04-files/files-emptytrash` | 1 fixed, 2 approved |
| DK-0753 | `04-files/files-trashaction` | 3 approved |

Fixed:

- Q1. Searching, the field moves to the top in the large title's place and
  the view, sort and new-folder actions step aside (§16.2 "Search field
  focused at top"); the title and actions stayed above the field.
- Q2. The no-text banner comes with an empty result only (§16.2,
  files-searchempty); it also sat above the results.
- Q3. Confirm and text dialogs (`showDkConfirm`, `showDkTextDialog`) open on
  the root navigator, so their scrim covers the tab bar, as
  files-emptytrash and Flutter's showDialog; they opened on the tab's
  navigator and left the tab bar bright.

Approved:

- Result rows are DkFileCard rows with their more button (§16.2 names
  DkFileCard); the frame leaves it out.
- The search field has no 2 dp primary focus border: §11.4 gives DkSearchField
  none (the frame draws one). Same on T1.
- "Make searchable" has no Pro badge until the paywall's entitlement exists;
  the OCR tool asks for Pro itself.
- The empty state is centred in the space under the banner (DkEmptyState);
  the frame places it higher.
- R1's title is left-aligned on Android, centred on iOS (§11.6 DkTopBar);
  the frame is the iOS one.
- R1's file sheet is the medium detent (§16.3) with a hairline before the
  destructive row (DkActionSheet); the frame hugs its rows. Its header page
  is white once the file-sheets QA lands (S1 in
  [file-sheets.md](file-sheets.md)); the board's files can't be drawn.
- The Empty dialog stacks its buttons in the test font, which runs wider:
  DkConfirmDialog stacks them only when the labels don't fit (§11.7).
