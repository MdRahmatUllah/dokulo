"""The design German check pairs light/deutsch texts and flags drift."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_design_de  # noqa: E402


def page(text: str) -> str:
    return f'<div class="dk-frame"><span class="i">close</span>{text}</div>'


def test_problems(tmp_path: Path) -> None:
    for theme, a, b in [
        ("light", "<b>Saved</b><p>Not now</p>", "<b>Clear</b>"),
        ("deutsch", "<b>Gespeichert</b><p>Nicht jetzt</p>", "<b>Löschen</b>"),
    ]:
        (tmp_path / theme / "x").mkdir(parents=True)
        (tmp_path / theme / "x" / "a.html").write_text(page(a), encoding="utf-8")
        (tmp_path / theme / "x" / "b.html").write_text(page(b), encoding="utf-8")
    pairs = check_design_de.design_pairs(tmp_path)
    assert pairs["Saved"] == {"Gespeichert": "x/a.html"}
    assert "close" not in pairs  # icon names are not text
    en = {"toast_saved": "Saved", "common_not_now": "Not now", "common_clear": "Clear"}
    de = {"toast_saved": "Gesichert", "common_not_now": "Nicht jetzt", "common_clear": "Leeren"}
    assert [p.split(":")[0] for p in check_design_de.problems(pairs, en, de)] == [
        "toast_saved",  # common_clear is a CONTEXT key
    ]
