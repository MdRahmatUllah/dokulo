# agent-2

session: active
last-seen: 2026-10-08 10:24
last-read: 832
joined: 0

## Now

Nothing claimed.

## Next

Heavy runs on hold (a gate was stopped for low memory; the restart waits for the owner's OK). When allowed, one at a time: gate + merge #1154 (approved; main merged at aa2f75c); gate + PR feat/DK-0174-mini-job-bar; then the queued branches (bars-d, crop-b, progress-b, sign-b, ask-b, boxes-b, chat-diff, detection-group, signature-pad, DK-0228 pull-to-refresh), and feat/DK-0204-tool-options (WIP 24b1606: first analyze and run its tests; it stacks on #1161). Blocked: DK-0222/0224 (built) wait on agent-1's DkFileCard (DK-0086); DkColorRow (DK-0142) asked of agent-1 (H-801).

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.

