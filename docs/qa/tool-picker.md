# X1 with several files: visual QA

DK-0849: `12-tool-shell/tool-shell-x1multi` against the real X1
(`showToolPicker`, DK-0387) with 4 files. Board: the
`tool_shell_x1multi_*` goldens in `test/patterns/dk_tool_picker_test.dart`
(light, dark, German); frames: `docs/qa/tool-shell/tool-shell-x1multi-*.png`.
The single-file frame (DK-0848) is in [design-system.md](design-system.md).

Match: "4 files" with the stacked thumbnails and the close ×, Search tools,
Suggested (the pinned tools that fit) and All tools (only the compatible
ones), DkToolRow rows with the Pro badge.

Approved:

- The rows end in DkToolRow's chevron, as in x1single; the frame leaves it
  out.
- The board's 4 files are PDFs, so the lists hold PDF tools; the frame's
  "3 PDFs · 1 image" adds Image to PDF and drops Merge's peers. The lists
  follow the files (`compatibleTools`), which is the rule.
