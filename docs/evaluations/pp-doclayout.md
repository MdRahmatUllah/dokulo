# PP-DocLayout (small) for pdf_structure and Smart Split (DK-0401)

**Decision: skip for v1.** It is neither shipped nor offered as a download. `pdf_structure` stays heuristics only
(DK-0396), and the heuristics' three weak spots this evaluation found are
filed as fixes (below). Revisit if Smart Split on scanned bundles needs layout
regions that OCR lines can't give (the Smart Split task decides, with these
numbers).

Evaluated 2026-10-07 by agent-1.

## What was compared

| | PP-DocLayout-S | `pdf_structure` heuristics |
| --- | --- | --- |
| What | GFL detector, 23 layout classes, 480 × 480 input | PDFium characters: size, weight, position (DK-0396) |
| Licence | Apache-2.0 (official card `PaddlePaddle/PP-DocLayout-S`) | ours |
| Size | 4.9 MB ONNX (third-party conversion `x3zvawq/paddleocr-js-onnx` @ `51c2133b`, sha256 `bcd972f8…`, used for this evaluation only) | 0 |
| Runtime | ONNX Runtime (already in the app for OCR) | Dart |
| Time per page | median 48 ms, max 55 ms at threshold 0.5; 57 / 135 ms at 0.3 (desktop CPU, onnxruntime 1.20.1); expect about 3–5× on a mid phone | 8–53 ms per **document** (the same pages, PDFium character extraction included) |

The sample set is 12 pages of `test/fixtures` whose structure is known
because we generated them (DK-0023): the Mietvertrag (3 pages, title + 8 §
headings), the invoice (2 headings, one item table), the CV (title + 5
section headings), the tax assessment, two pages of the 300-page manual (one
chapter heading each) and three pages of the scanned-letter bundle (two letter
first pages, one blank separator). Rerun it with
`python tools/eval_doclayout.py <model.onnx> [--threshold 0.3] [--save-dir out]`.

## Results

| Element (gold count) | Heuristics | PP-DocLayout-S @ 0.5 | @ 0.3 |
| --- | --- | --- | --- |
| Headings, born-digital (18) | **18** (all 9 Mietvertrag, all 6 CV, both invoice, the assessment's) | 7 | at most 16 |
| Headings, scanned (2) | 0: no text layer | 1 | 2 |
| Item table (1) | **1** | 0 | 0 |
| False tables | 2 (the two-column address blocks of the invoice and the assessment) | 0 | 0 |
| Chapter headings of the 300-page manual (2) | 0: dropped as running headers (see below) | 0 | 2 |
| Page-number footers, scanned (2) | n/a (no text) | 2 | 2 |
| Blank separator page | nothing, correct | nothing, correct | nothing, correct |

The model's columns count detections per class, capped at the gold count (a
few boxes were checked on the saved images: the invoice, Mietvertrag page 2
and the first scanned letter, where they sat on the right lines).

What the numbers say:

- **On born-digital PDFs the heuristics are as good or better.** They find
  all 18 headings and the only table; the model finds at most 16 headings even
  at its own NMS threshold (0.3) and misses the table at every threshold. The model's input is a 480 × 480 picture of the whole page, so
  11 pt body text is about 6 px tall, and fine structure (table rules, small
  headings) gets lost.
- **The model's real advantage is scans,** where there are no PDF characters.
  But the OCR facade (DK-0400) gives lines with boxes and sizes, so the same
  heuristics can run on OCR lines. That is cheaper than a second model, and it
  is what Smart Split needs (page boundaries, not regions).
- **Cost:** 4.9 MB (5 % of the per-ABI budget, `docs/size-budget.md`) plus
  50–250 ms per page on a phone, for headings the heuristics mostly find.

## Fixes the heuristics need (filed)

1. **Chapter headings in the top band are dropped as running headers.**
   `dropRunningLines` normalises digits, so "Kapitel 1 · Abschnitt 1",
   "Kapitel 1 · Abschnitt 2", … look like one repeated header. A line that is
   larger or bolder than the body should never count as running.
2. **Two-column address blocks become tables** ("Bill to: … | Invoice …",
   "Herrn … | Datum: …"). A table needs a header row or at least three aligned
   columns, or a ruled header.
3. **Heading levels differ between pages** (§ 1–3 are level 2 on page 1, § 4–8
   level 1 on pages 2–3): the level should be ranked over the whole document,
   not per page.

## Intake (if it is ever revisited)

Per the model intake checklist (`docs/compliance/ai-models.md`): convert the
official `PaddlePaddle/PP-DocLayout-S` Paddle model ourselves (paddle2onnx),
pin the revision and the SHA-256, and record the RAM working set. The
third-party ONNX used here is not a shipping source.
