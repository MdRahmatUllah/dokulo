"""The privacy-manifest check: the app's manifest, and one per native iOS plugin."""

import json
import plistlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_privacy_manifests as c  # noqa: E402


def manifest(path: Path, **extra) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps({"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], **extra}))


def plugin(root: Path, name: str, files: dict[str, str]) -> dict:
    for relative, text in files.items():
        (root / name / relative).parent.mkdir(parents=True, exist_ok=True)
        (root / name / relative).write_text(text, encoding="utf-8")
    return {"name": name, "path": str(root / name)}


def test_check(tmp_path: Path) -> None:
    repo, cache = tmp_path / "repo", tmp_path / "cache"
    manifest(repo / c.APP_MANIFEST, NSPrivacyAccessedAPITypes=[
        {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryDiskSpace", "NSPrivacyAccessedAPITypeReasons": ["E174.1"]},
        {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp", "NSPrivacyAccessedAPITypeReasons": []},
    ])
    plugins = [
        plugin(cache, "good", {"ios/Classes/Good.swift": "", "ios/Resources/PrivacyInfo.xcprivacy": ""}),
        plugin(cache, "dart_only", {"lib/dart_only.dart": ""}),
        plugin(cache, "bad", {"darwin/bad/Sources/Bad.m": ""}),
    ]
    (repo / c.PLUGINS).write_text(json.dumps({"plugins": {"ios": plugins}}), encoding="utf-8")
    plugin(repo / "packages", "ours", {"ios/ours/Sources/ours/Ours.swift": ""})  # not resolved yet

    assert c.check(repo) == [
        "packages/app_pdf/ios/Runner/PrivacyInfo.xcprivacy: NSPrivacyAccessedAPICategoryFileTimestamp without a reason",
        "bad: native iOS code in darwin/ but no PrivacyInfo.xcprivacy",
        "ours: native iOS code in ios/ but no PrivacyInfo.xcprivacy",
    ]

    manifest(repo / c.APP_MANIFEST, NSPrivacyTracking=True)
    assert "doesn't track" in c.check(repo)[0]


def test_the_repo_is_clean() -> None:
    root = Path(__file__).resolve().parents[2]
    if not (root / c.PLUGINS).is_file():
        return  # needs flutter pub get; the gate runs it first
    assert c.check(root) == []
