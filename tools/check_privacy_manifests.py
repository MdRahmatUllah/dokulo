"""iOS privacy manifests (DK-0682): the app has a valid one that declares no
tracking, and every iOS plugin with native code ships its own.

    python tools/check_privacy_manifests.py [repo root]

Reads the plugins Flutter resolved for app_pdf (.flutter-plugins-dependencies,
written by `flutter pub get`) and our own packages/*. A plugin with Swift, Objective-C or C sources
under ios/ or darwin/ needs a PrivacyInfo.xcprivacy there; a Dart-only plugin
(FFI, like path_provider_foundation 2.6) has no binary of its own and needs
none. What this can't see: SDKs a pod or Swift package downloads at build time
(ONNX Runtime's), and native-asset frameworks (sqlite3, pdfium): the Xcode
privacy report on a Mac covers those (docs/compliance/ios-privacy-manifest.md).
"""

import json
import plistlib
import sys
from pathlib import Path

APP_MANIFEST = Path("packages/app_pdf/ios/Runner/PrivacyInfo.xcprivacy")
PLUGINS = Path("packages/app_pdf/.flutter-plugins-dependencies")
NATIVE = {".swift", ".m", ".mm", ".c", ".cc", ".cpp"}


def native_dirs(plugin: Path) -> list[Path]:
    """The plugin's ios/ and darwin/ folders that hold native sources."""
    return [d for d in (plugin / "ios", plugin / "darwin")
            if d.is_dir() and any(f.suffix in NATIVE for f in d.rglob("*") if f.is_file())]


def check(root: Path) -> list[str]:
    problems = []
    app = root / APP_MANIFEST
    if not app.is_file():
        problems.append(f"{APP_MANIFEST.as_posix()}: missing")
    else:
        manifest = plistlib.loads(app.read_bytes())
        if manifest.get("NSPrivacyTracking") is not False or manifest.get("NSPrivacyTrackingDomains"):
            problems.append(f"{APP_MANIFEST.as_posix()}: Dokulo doesn't track: NSPrivacyTracking false, no domains")
        for api in manifest.get("NSPrivacyAccessedAPITypes", []):
            if not api.get("NSPrivacyAccessedAPITypeReasons"):
                problems.append(f"{APP_MANIFEST.as_posix()}: {api.get('NSPrivacyAccessedAPIType')} without a reason")
    deps = root / PLUGINS
    if not deps.is_file():
        return problems + [f"{PLUGINS.as_posix()}: missing (run flutter pub get)"]
    resolved = [(p["name"], Path(p["path"])) for p in json.loads(deps.read_text(encoding="utf-8"))["plugins"]["ios"]]
    # Our own plugins too, before the app depends on them.
    ours = [(p.name, p) for p in sorted((root / "packages").glob("*")) if p.is_dir()]
    seen = set()
    for name, path in resolved + ours:
        if path.resolve() in seen:
            continue
        seen.add(path.resolve())
        for folder in native_dirs(path):
            if not any(folder.rglob("PrivacyInfo.xcprivacy")):
                problems.append(f"{name}: native iOS code in {folder.name}/ but no PrivacyInfo.xcprivacy")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = check(root)
    for problem in problems:
        print(problem)
    print("privacy manifests: " + (f"{len(problems)} problem(s)" if problems else "clean"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
