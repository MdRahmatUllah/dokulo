"""Layer check: dependencies between Dokulo's packages point one way only,
app_pdf → doc_tools → doc_core / doc_vision → ai_core. DK-0001.

    python tools/check_layers.py [repo root]

A package may depend (dependencies or dev_dependencies) only on our packages of
a strictly lower layer; doc_core and doc_vision share a layer, so neither may
depend on the other. And the UI never touches native code (DK-0003): no file
in app_pdf/lib imports FFI or a native binding; that work runs in the lower
layers' worker isolates. Exit 1 on a violation or on a package missing from
LAYERS.
"""

import re
import sys
from pathlib import Path

LAYERS = {"app_pdf": 1, "doc_tools": 2, "doc_core": 3, "doc_vision": 3, "ai_core": 4}
# Imports app_pdf/lib must not use. pdfrx is allowed: its viewer widget runs
# PDFium on pdfrx's own worker isolate.
NATIVE_IMPORTS = re.compile(
    r"""^\s*import\s+['"](dart:ffi|package:(ffi|opencv_dart|dartcv4|flutter_onnxruntime|llamadart|qpdf_ffi)/)""",
    re.M)


def our_dependencies(pubspec: Path) -> set[str]:
    """Names of our packages listed under dependencies or dev_dependencies."""
    deps, section = set(), None
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if m := re.match(r"^(\w+):", line):
            section = m[1]
        elif section in ("dependencies", "dev_dependencies") and (m := re.match(r"^  (\w+):", line)):
            if m[1] in LAYERS:
                deps.add(m[1])
    return deps


def check(root: Path) -> list[str]:
    problems = []
    for pubspec in sorted((root / "packages").glob("*/pubspec.yaml")):
        name = pubspec.parent.name
        if name not in LAYERS:
            problems.append(f"{name}: not in LAYERS (tools/check_layers.py); give it a layer")
            continue
        for dep in sorted(our_dependencies(pubspec)):
            if LAYERS[dep] <= LAYERS[name]:
                problems.append(f"{name} (layer {LAYERS[name]}) must not depend on {dep} (layer {LAYERS[dep]})")
    for source in sorted((root / "packages" / "app_pdf" / "lib").rglob("*.dart")):
        if m := NATIVE_IMPORTS.search(source.read_text(encoding="utf-8")):
            where = source.relative_to(root).as_posix()
            problems.append(f"{where}: imports {m[1]}; the UI never touches native code (use a job or service)")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = check(root)
    for problem in problems:
        print(problem)
    print("layer check: " + (f"{len(problems)} problem(s)" if problems else "clean"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
