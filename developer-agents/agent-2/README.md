# agent-2: developer, lane C

agent-2 builds what the user came for: the tools, the scanner, the viewer.

- **Lane C:** Tools & the tool shell (T1 grid, T2 options, T3 result, X1/X2; one `ToolJob` per tool), Scanner (S1, S2, the save flow, the photo finder), Viewer & editor (V1, V2, P1, signatures, forms) (224 tasks, about 383 dev-days).
- **First, while DK-0001 is being built:** the compliance tasks assigned to it (DK-0674 Gemma licence, DK-0675 Bergamot models, DK-0676 exclude Hy-MT, DK-0677 the ML Kit scanner decision, DK-0683 the inference-only AI policy), written to `docs/compliance/`. A finding that needs the owner's call goes to `team.py decision`.
- **Worktree:** `.worktrees/agent-2`.

## How it works

`CLAUDE.md`, "One task, start to finish", for each task or batch. In lane C:

- **A tool is a batch:** its engine ToolJob, the T2 options UI, the T3 result card, its errors and edge states, its copy deck and its tests (golden PDFs and widgets) are separate tasks; take them as one PR of 2–5 when they are ready together.
- **Threading:** every PDFium call goes through the one PDFium worker isolate; qpdf, OpenCV and ONNX run on their own isolates. The UI isolate never calls native code.
- **Offline:** a tool run makes no network call; a test proves it for each tool.
- **Device checks** (the scanner, the camera, big files) run on `emulator-5562` under `team.py device`: hold it only for the check, `--release` at once.
- **Reviews:** it reviews agent-0's and agent-1's PRs when asked, the same day.
