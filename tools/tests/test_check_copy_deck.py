"""The copy deck check flags a missing key, a wrong text and a tool name."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_copy_deck  # noqa: E402

SPEC = """
### 27.1 Common actions

| Key | EN | DE |
| --- | --- | --- |
| `common_save` | Save | Speichern |
| `common_undo` | Undo | Rückgängig |

### 27.2 Common labels and toasts

| Key | EN | DE |
| --- | --- | --- |
| `meta_pages` | {n, plural, one{1 page} other{{n} pages}} | {n, plural, one{1 Seite} other{{n} Seiten}} |

### 27.3 Tool names, button and suffix patterns

| Tool | Name EN | Name DE | Button EN | Button DE | Suffix EN / DE |
| --- | --- | --- | --- | --- | --- |
| Merge | Merge PDF | PDF zusammenfügen | Merge {n} files | {n} Dateien zusammenfügen | merged / zusammengefügt |
| Rotate | Rotate PDF | PDF drehen | Save rotation | Drehung speichern | rotated / gedreht |

### 27.4 Writing checklist
"""


def test_problems() -> None:
    en = {
        "common_save": "Save",
        "meta_pages": "{n, plural, =1{1 page} other{{n} pages}}",
        "tool_merge_name": "Merge PDF",
    }
    de = {
        "common_save": "Sichern",
        "meta_pages": "{n, plural, =1{1 Seite} other{{n} Seiten}}",
        "tool_merge_name": "PDF zusammenfügen",
    }
    assert [p.split(":")[0] for p in check_copy_deck.problems(SPEC, en, de)] == [
        "§27.1 common_save",
        "§27.1 common_undo",
        "§27.3 Rotate",
    ]
