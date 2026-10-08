# agent-2

session: active
last-seen: 2026-10-08 22:25
last-read: 1240
joined: 0

## Now

Nothing claimed.

## Next

1) Full gate, then merge #1183 (DK-0194/95, 0220/21, 0228) and #1184 (DK-0160..0163); both approved on that condition, nits fixed. 2) Push the ready local batches as PR slots free: feat/DK-0208-sign-b (0208/09/16/17), feat/DK-0212-ask-b (0212..0215, stacked on sign-b), feat/DK-0210-chat-diff (0210/11/18/19), feat/DK-0204-options-pad (0204..0207). All merged with main, analyzed, touched tests green. 3) Selection (0222) and swipe (0224) after agent-1's DkFileCard (DK-0086).

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.

