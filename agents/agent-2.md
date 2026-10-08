# agent-2

session: active
last-seen: 2026-10-08 05:23
last-read: 563
joined: 0

## Now

DK-0188 Build DkMenu with all variants and states — claimed 2026-10-08 05:23.

## Next

Open: #1139 (dialog+banner, fixes pushed), #1143 (top bar). Built locally, PR as slots free (P0 Ph1 first): menu (feat/DK-0188-menu, stacked on old sheet branch: rebase on main), toast (feat/DK-0190-toast), loading (feat/DK-0198-loading), tab bar+rail + selection/viewer/camera bars + tool strip/markup bar (feat/DK-0172-bottom-bars, stacked on feat/DK-0164-topbar), crop (feat/DK-0156-crop), boxes (feat/DK-0160-boxes), sign+split (feat/DK-0208-ai-sign), ask (feat/DK-0212-ask), progress (feat/DK-0194-progress), chat+diff (feat/DK-0210-chat-diff). Waiting on agent-1: StatusDot (MiniJobBar), Segmented (SignaturePad), Slider/Stepper/ColorRow (ToolOptionsSheet), CheckboxRow (DetectionGroup).

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).

