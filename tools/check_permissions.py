"""Android permissions check (DK-0016): Dokulo declares only the permissions the
spec lists, no contacts, location or anything else.

    python tools/check_permissions.py [app.apk]

Without an argument it reads the app's main AndroidManifest.xml. With an APK it
reads the merged manifest through aapt2 (Android SDK build-tools), which also
catches a permission a plugin adds.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

MANIFEST = Path("packages/app_pdf/android/app/src/main/AndroidManifest.xml")
ALLOWED = {
    "android.permission.CAMERA",                           # the scanner
    "android.permission.READ_MEDIA_IMAGES",                # the photo finder, Android 13+
    "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",  # the photo finder, partial access
    "android.permission.READ_EXTERNAL_STORAGE",            # the photo finder, Android 8-12 (maxSdkVersion 32)
    "android.permission.POST_NOTIFICATIONS",               # "long job finished"
    "android.permission.FOREGROUND_SERVICE",               # long jobs
    "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
    "android.permission.USE_BIOMETRIC",                    # locked folder, app lock
    "android.permission.INTERNET",                         # model downloads, Web to PDF, purchases
    "android.permission.WRITE_EXTERNAL_STORAGE",           # Documents/Dokulo on Android 8-9 (maxSdkVersion 28, DK-0006)
}
# androidx adds <package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION, a signature permission of the app itself.
OWN = re.compile(r"\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION$")


def declared(text: str) -> set[str]:
    """Permission names from manifest XML or from `aapt2 dump permissions` output."""
    return set(re.findall(r"""uses-permission(?:-sdk-23)?[^>]*?name=['"]([\w.]+)['"]""", text))


def problems(names: set[str]) -> list[str]:
    return [f"{n} is not on the allowed list (tools/check_permissions.py, DK-0016)"
            for n in sorted(names) if n not in ALLOWED and not OWN.search(n)]


def aapt2() -> str:
    tools = Path(os.environ.get("ANDROID_HOME") or Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk") / "build-tools"
    found = sorted(tools.glob("*/aapt2*"))
    if not found:
        raise SystemExit("check_permissions: aapt2 not found (Android SDK build-tools); set ANDROID_HOME")
    return str(found[-1])


def main() -> int:
    if len(sys.argv) > 1:
        text = subprocess.run([aapt2(), "dump", "permissions", sys.argv[1]], capture_output=True, text=True, check=True).stdout
        where = sys.argv[1]
    else:
        text, where = MANIFEST.read_text(encoding="utf-8"), MANIFEST.as_posix()
    found = problems(declared(text))
    for p in found:
        print(f"{where}: {p}")
    print("permissions check: " + (f"{len(found)} problem(s)" if found else "clean"))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
