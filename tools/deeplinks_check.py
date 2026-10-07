"""Deep-link device check (DK-1041): cold-start every route of the Developer
guide's table through dokulo://open/<route> and read the screen back.

    python tools/deeplinks_check.py [emulator-5554]

Needs a debug build of the dev flavor installed (flutter build apk --debug
--flavor dev) and the emulator held with `team.py device`. Reads the screen
through uiautomator, so the placeholder's screen ID must be on it. Not part
of the gate: it needs a device.
"""

import os
import re
import subprocess
import sys
import time

ADB = os.path.join(os.environ["LOCALAPPDATA"], "Android", "Sdk", "platform-tools", "adb.exe")
DEVICE = sys.argv[1] if len(sys.argv) > 1 else "emulator-5554"
APP = "app.dokulo.dev"
ROUTES = {
    "/home": ("H1", True), "/tools": ("T1", True), "/files": ("F1", True),
    "/files/locked": ("F2", True), "/me": ("M1", True), "/me/models": ("M2", True),
    "/me/settings/appearance": ("M3 appearance", True), "/welcome": ("Onboarding", False),
    "/scan": ("S1", False), "/scan/review": ("S2", False), "/tool/compress": ("T2 compress", False),
    "/tool/compress/result": ("T3 compress", False), "/viewer/f42": ("V1 f42", False),
    "/viewer/f42?mode=edit": ("V2 f42", False), "/organize/f42": ("P1 f42", False),
}


def adb(*args: str) -> str:
    return subprocess.run([ADB, "-s", DEVICE, *args], capture_output=True, text=True, encoding="utf-8").stdout


def screen() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/dk_ui.xml")
    return adb("shell", "cat", "/sdcard/dk_ui.xml")


def main() -> int:
    failures = 0
    for route, (title, tabs) in ROUTES.items():
        adb("shell", "am", "force-stop", APP)
        # Single quotes: the device shell must not split at "?".
        adb("shell", f"am start -W -a android.intent.action.VIEW -d 'dokulo://open{route}' {APP}")
        time.sleep(2.5)
        xml = screen()
        texts = re.findall(r'(?:text|content-desc)="([^"]+)"', xml)
        shows_title = any(t == title or t.startswith(title + "\n") for t in texts)
        shows_tabs = any(t.startswith(("Home", "Start")) for t in texts) and any(t.startswith(("Me", "Ich")) for t in texts)
        ok = shows_title and shows_tabs == tabs
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {route:28} title {'ok' if shows_title else 'missing'}"
              f", tab bar {'shown' if shows_tabs else 'hidden'} (expected {'shown' if tabs else 'hidden'})"
              + ("" if ok else f"  texts={texts[:8]}"))
    print(f"deep links: {len(ROUTES) - failures}/{len(ROUTES)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
