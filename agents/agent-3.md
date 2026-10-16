# agent-3

session: active
last-seen: 2026-10-16 10:10
last-read: 3034
joined: 0

## Now

Nothing claimed.

## Next

Gates queued: sign QA (agent-3 worktree, DK-0795/0796/0797) and photo finder QA (a3c, DK-0832/0834/0836); merge each, done + close issues, remove a3c. Then: re-check blocked QA when bugs land (DK-1118 0969/0970, DK-1119 0860, DK-1124 0831, DK-1125 0823/0827/0828, DK-1126 0774, DK-1127 0825/0826, DK-1131 0780..0790, DK-1133 0948, DK-1134 0793, DK-1135 0792, DK-1136 0833/0835/0837, DK-1137 0977, DK-1140 0794); DK-1052 emulator re-run when heavy is free; DK-1099 when DK-0580/0561 land; DK-1139 awaits the lead.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-15 17:34: Session 2026-10-15: SQA routine is in developer-agents/agent-3/README.md (frames via headless Chrome with --virtual-time-budget=10000 --run-all-compositor-stages-before-draw; boards in packages/app_pdf/test/qa/*_qa_test.dart; findings docs/qa/*.md; bug blocks the QA task; skip:true with bug id when a board case fails). Second worktree .worktrees/a3b (copy .dk-agent) lets me prepare the next QA while a gate runs in agent-3. Golden corpus: packages/doc_tools/test/corpus (DK_CORPUS=full per release). Release checklist docs/qa/regression-checklist.md with a sign-off log. Device screenshots are black (Hide previews = FLAG_SECURE and the 5554 rendering issue): drive via uiautomator (sqa-evidence/drive.py, tool_sweep.py, untracked). Re-check when fixed: DK-0937 (DK-1097), DK-0941 (DK-1098), DK-0981 (DK-1100), DK-0637 (DK-1105), DK-0763/0773 (DK-1111), DK-0969/0970 (DK-1118), DK-0860 (DK-1119), DK-0806/0807 (DK-1120), DK-0816 (DK-1121).

