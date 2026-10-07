"""The token check flags raw colours in screens and components only."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_tokens  # noqa: E402


def test_raw_colours(tmp_path: Path) -> None:
    screens = tmp_path / "packages/app_pdf/lib/screens"
    screens.mkdir(parents=True)
    (screens / "home.dart").write_text(
        "color: t.color.surface,\n"
        "color: Color(0xFF2251E6),\n"
        "color: Colors.red,\n"
        "color: Colors.transparent,\n"
        "// Color(0xFF000000) in a comment is fine\n"
        "color: Color.fromARGB(255, 0, 0, 0),\n", encoding="utf-8")
    theme = tmp_path / "packages/app_pdf/lib/theme"
    theme.mkdir(parents=True)
    (theme / "dk_tokens.dart").write_text("primary: Color(0xFF2251E6),\n", encoding="utf-8")
    assert [p.split(": ", 1)[0] for p in check_tokens.check(tmp_path)] == [
        "packages/app_pdf/lib/screens/home.dart:2",
        "packages/app_pdf/lib/screens/home.dart:3",
        "packages/app_pdf/lib/screens/home.dart:6",
    ]
