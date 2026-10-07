"""PP-DocLayout-S on the sample documents (DK-0401: an evaluation, not app code).

    pip install onnxruntime pypdfium2 pillow numpy
    python tools/eval_doclayout.py <PP-DocLayout-S_infer.onnx> [--save-dir dir]

Renders the fixture pages with PDFium, runs the model (480 × 480 input, the
model's own preprocessing from its inference.yml) and prints what it finds per
page and the CPU time. docs/evaluations/pp-doclayout.md holds the results.
"""

import argparse
import sys
import time
from pathlib import Path

import numpy as np
import onnxruntime as ort
import pypdfium2 as pdfium
from PIL import ImageDraw

LABELS = ["paragraph_title", "image", "text", "number", "abstract", "content", "figure_title", "formula",
          "table", "table_title", "reference", "doc_title", "footnote", "header", "algorithm", "footer", "seal",
          "chart_title", "chart", "formula_number", "header_image", "footer_image", "aside_text"]
PAGES = {  # file → 0-based pages (the same as the heuristics run)
    "Mietvertrag Musterstraße 12.pdf": [0, 1, 2],
    "Invoice INV-2026-014.pdf": [0],
    "Lebenslauf Max Mustermann.pdf": [0, 1],
    "Finanzamt München – Bescheid 2025.pdf": [0],
    "long-300-pages.pdf": [0, 1],
    "scanned-letters-bundle.pdf": [0, 2, 3],
}
SIZE, MEAN, STD = 480, np.array([0.485, 0.456, 0.406]), np.array([0.229, 0.224, 0.225])


def detect(session: ort.InferenceSession, image, threshold: float = 0.5) -> list[tuple[str, float, tuple]]:
    w, h = image.size
    x = np.asarray(image.convert("RGB").resize((SIZE, SIZE), resample=2), dtype=np.float32) / 255.0  # 2: bilinear
    x = ((x - MEAN) / STD).transpose(2, 0, 1)[None].astype(np.float32)
    scale = np.array([[SIZE / h, SIZE / w]], dtype=np.float32)
    boxes = session.run(None, {"image": x, "scale_factor": scale})[0]
    return [(LABELS[int(c)], float(s), (x1, y1, x2, y2)) for c, s, x1, y1, x2, y2 in boxes if s >= threshold]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("model")
    parser.add_argument("--save-dir", type=Path)
    parser.add_argument("--threshold", type=float, default=0.5)
    args = parser.parse_args()
    session = ort.InferenceSession(args.model, providers=["CPUExecutionProvider"])
    fixtures = Path(__file__).resolve().parents[1] / "test" / "fixtures"
    times = []
    for name, pages in PAGES.items():
        doc = pdfium.PdfDocument(fixtures / name)
        for p in pages:
            image = doc[p].render(scale=150 / 72).to_pil()
            start = time.perf_counter()
            found = detect(session, image, args.threshold)
            times.append(time.perf_counter() - start)
            counts: dict[str, int] = {}
            for label, _, _ in found:
                counts[label] = counts.get(label, 0) + 1
            print(f"{name} p{p}: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
            if args.save_dir:
                args.save_dir.mkdir(parents=True, exist_ok=True)
                draw = ImageDraw.Draw(image)
                for label, score, box in found:
                    draw.rectangle(box, outline="red", width=3)
                    draw.text((box[0] + 4, box[1] + 2), f"{label} {score:.2f}", fill="red")
                image.save(args.save_dir / f"{Path(name).stem}-p{p}.png")
    times.sort()
    print(f"CPU per page: median {times[len(times) // 2] * 1000:.0f} ms, max {times[-1] * 1000:.0f} ms "
          f"({len(times)} pages, onnxruntime {ort.__version__}, 1 session)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
