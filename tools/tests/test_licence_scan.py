"""The licence scan passes permissive packages and fails denied names, copyleft
or unknown licences and unregistered direct dependencies."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import licence_scan  # noqa: E402

MIT = "MIT License\n\nPermission is hereby granted, free of charge, to any person"
MPL = "Mozilla Public License Version 2.0\n\n... the GNU General Public License ..."


def package(name: str, dependency: str, version: str = "1.0.0", source: str = "hosted") -> str:
    return (f"  {name}:\n    dependency: \"{dependency}\"\n    description:\n"
            f"      name: {name}\n      url: \"https://pub.dev\"\n"
            f"    source: {source}\n    version: \"{version}\"\n")


def test_scan(tmp_path: Path) -> None:
    root, cache = tmp_path / "repo", tmp_path / "cache"
    (root / "docs" / "compliance").mkdir(parents=True)
    (root / licence_scan.REGISTER).write_text(
        "| Package | Licence |\n| --- | --- |\n| `pdfrx` | MIT |\n| `bergamot` | MPL-2.0 |\n",
        encoding="utf-8")
    for name, text in (("pdfrx", MIT), ("helper", MIT), ("bergamot", MPL), ("dbus", MPL),
                       ("unregistered", MIT), ("mystery", "All rights reserved.")):
        (cache / "hosted" / "pub.dev" / f"{name}-1.0.0").mkdir(parents=True)
        (cache / "hosted" / "pub.dev" / f"{name}-1.0.0" / "LICENSE").write_text(text, encoding="utf-8")
    app = root / "packages" / "app_pdf"
    app.mkdir(parents=True)
    (app / "pubspec.lock").write_text("packages:\n" + "".join((
        package("pdfrx", "direct main"),            # registered, MIT: ok
        package("helper", "transitive"),            # MIT: ok without a line
        package("bergamot", "transitive"),          # MPL with a register line: ok
        package("flutter", "direct main", "0.0.0", "sdk"),  # SDK: skipped
        package("doc_core", "direct main", "0.0.1", "path"),  # ours: skipped
        package("dbus", "transitive"),              # MPL, no line: fail
        package("unregistered", "direct main"),     # direct, no line: fail
        package("mystery", "transitive"),           # unknown licence: fail
        package("syncfusion_flutter_pdf", "transitive"),  # denied: fail
        package("missing", "transitive"),           # not in the cache: fail
    )) + "sdks:\n  dart: \">=3.13.0 <4.0.0\"\n", encoding="utf-8")
    (root / ".dart_tool").mkdir()
    (root / ".dart_tool" / "pubspec.lock").write_text("packages:\n" + package("dbus", "transitive"),
                                                      encoding="utf-8")

    problems = licence_scan.scan(root, cache)

    assert [p.split(": ", 1)[1].split(" ", 1)[0] for p in problems] == [
        "dbus", "unregistered", "mystery", "syncfusion_flutter_pdf", "missing"]
    assert "MPL" in problems[0] and "no register line" in problems[1]
    assert "unrecognised" in problems[2] and "excluded" in problems[3]


def test_classify_prefers_the_licence_named_first(tmp_path: Path) -> None:
    (tmp_path / "LICENSE").write_text(MPL, encoding="utf-8")
    assert licence_scan.classify(tmp_path) == "MPL"
