# agent-3

session: active
last-seen: 2026-10-16 10:48
last-read: 3034
joined: 0

## Now

Nothing claimed.

## Next

Paused by the owner (2026-10-16). Resume: (1) agent-3 worktree, branch feat/DK-0936-me-tablet-qa (committed: DK-0936 match, DK-0963 match, DK-0948 match after #1457): queue the gate again (gate.ps1 -Worktree agent-3), merge, done. (2) .worktrees/a3g, branch feat/DK-0768-viewer-edit-qa, local WIP commit: new edit_screen_test QA cases (highlight, form, formlock, noform, xfa); the render run was stopped mid-way: re-run --plain-name 'visual QA' --update-goldens, compare with frames in scratchpad/frames (edit-highlight, edit-form, tools-edit-*), add viewer-select (DK-0768) to viewer_qa_test, docs in docs/qa/edit.md + viewer.md, drop the WIP subject on squash. (3) Blocked re-checks as listed before; DK-1139 awaits the lead; DK-1142 in review by agent-1 (#1468).

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-15 17:34: Session 2026-10-15: SQA routine is in developer-agents/agent-3/README.md (frames via headless Chrome with --virtual-time-budget=10000 --run-all-compositor-stages-before-draw; boards in packages/app_pdf/test/qa/*_qa_test.dart; findings docs/qa/*.md; bug blocks the QA task; skip:true with bug id when a board case fails). Second worktree .worktrees/a3b (copy .dk-agent) lets me prepare the next QA while a gate runs in agent-3. Golden corpus: packages/doc_tools/test/corpus (DK_CORPUS=full per release). Release checklist docs/qa/regression-checklist.md with a sign-off log. Device screenshots are black (Hide previews = FLAG_SECURE and the 5554 rendering issue): drive via uiautomator (sqa-evidence/drive.py, tool_sweep.py, untracked). Re-check when fixed: DK-0937 (DK-1097), DK-0941 (DK-1098), DK-0981 (DK-1100), DK-0637 (DK-1105), DK-0763/0773 (DK-1111), DK-0969/0970 (DK-1118), DK-0860 (DK-1119), DK-0806/0807 (DK-1120), DK-0816 (DK-1121).
- 2026-10-16 10:48: gate.ps1 (scratchpad) once took a full path as a .worktrees name and ran in the launching shell's directory; fixed to accept both and print the folder on line 1. Gates on branches older than #1420 starve in the queue: merge main first. The German board loads SDK Roboto: Ahem misjudges German word widths.

