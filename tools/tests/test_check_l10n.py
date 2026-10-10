"""The l10n check fails on missing or extra German keys, on placeholder
mismatches and on hard-coded user-facing strings."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_l10n  # noqa: E402


def repo(tmp_path: Path, en: dict, de: dict, dart: str) -> Path:
    arb = tmp_path / check_l10n.ARB_DIR
    arb.mkdir(parents=True)
    (arb / "app_en.arb").write_text(json.dumps(en), encoding="utf-8")
    (arb / "app_de.arb").write_text(json.dumps(de), encoding="utf-8")
    (arb / "app_localizations.dart").write_text("Text('generated, ignored')", encoding="utf-8")
    (tmp_path / check_l10n.LIB / "screen.dart").write_text(dart, encoding="utf-8")
    return tmp_path


def test_clean(tmp_path: Path) -> None:
    root = repo(tmp_path, {"a": "Saved to {folder}", "@a": {}}, {"a": "Gespeichert in {folder}"},
                "Text(l10n.a)\nText('$count')\nText('${n}')\ntitle: 'Dokulo', // l10n-ignore: brand\n"
                "// Text('in a comment')\nkey: ValueKey('save'),\n")
    assert check_l10n.check_arb(root) + check_l10n.check_strings(root) == []


def test_problems(tmp_path: Path) -> None:
    root = repo(tmp_path, {"a": "{n} files", "b": "Saved", "@b": {}}, {"a": "{count} Dateien", "c": "Extra"},
                "Text('Save')\n  tooltip: \"Delete\",\nText(\"$n pages\")\n")
    assert check_l10n.check_arb(root) == [
        "app_de.arb: missing b",
        "app_de.arb: c is not in app_en.arb",
        "app_de.arb: a has placeholders ['count'], English has ['n']",
    ]
    assert [p.split(": ", 1)[1] for p in check_l10n.check_strings(root)] == [
        "hard-coded string 'Save'", 'hard-coded string "Delete"', 'hard-coded string "$n pages"']


def test_catalogue_is_skipped(tmp_path: Path) -> None:
    root = repo(tmp_path, {}, {}, "")
    (root / check_l10n.LIB / "catalogue").mkdir()
    (root / check_l10n.LIB / "catalogue" / "catalogue.dart").write_text("Text('DkPageThumb')", encoding="utf-8")
    assert check_l10n.check_strings(root) == []


def test_duplicate_keys(tmp_path: Path) -> None:
    # A merge that kept both sides: JSON would keep the last silently.
    root = repo(tmp_path, {"a": "Saved"}, {"a": "Gespeichert"}, "")
    en = root / check_l10n.ARB_DIR / "app_en.arb"
    en.write_text('{"a": "Saved", "@a": {}, "a": "Saved"}', encoding="utf-8")
    assert check_l10n.check_arb(root) == ["app_en.arb: a appears twice"]
