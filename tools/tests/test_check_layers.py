"""The layer check passes downward dependencies and fails upward, sideways and
unknown packages."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_layers  # noqa: E402


def pubspec(root: Path, name: str, deps: list[str], dev: list[str] = ()) -> None:
    lines = [f"name: {name}", "environment:", "  sdk: ^3.13.0", "dependencies:", "  flutter:", "    sdk: flutter"]
    lines += [f"  {d}:\n    path: ../{d}" for d in deps]
    lines += ["dev_dependencies:"] + [f"  {d}:\n    path: ../{d}" for d in dev]
    (root / "packages" / name).mkdir(parents=True)
    (root / "packages" / name / "pubspec.yaml").write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_check(tmp_path: Path) -> None:
    pubspec(tmp_path, "app_pdf", ["doc_tools", "doc_core"])  # down, skipping a layer: ok
    pubspec(tmp_path, "doc_tools", ["doc_core", "doc_vision"])  # ok
    pubspec(tmp_path, "doc_core", ["ai_core", "doc_vision"])  # sideways: fail
    pubspec(tmp_path, "doc_vision", ["ai_core"])  # ok
    pubspec(tmp_path, "ai_core", [], dev=["app_pdf"])  # upward via dev: fail
    pubspec(tmp_path, "stray", [])  # no layer: fail

    assert check_layers.check(tmp_path) == [
        "ai_core (layer 4) must not depend on app_pdf (layer 1)",
        "doc_core (layer 3) must not depend on doc_vision (layer 3)",
        "stray: not in LAYERS (tools/check_layers.py); give it a layer",
    ]


def test_the_repo_is_clean() -> None:
    assert check_layers.check(Path(__file__).resolve().parents[2]) == []
