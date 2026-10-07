"""The permissions check reads both manifest XML and aapt2 output and flags
anything off the list."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_permissions  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def test_the_app_manifest_is_clean() -> None:
    names = check_permissions.declared((ROOT / check_permissions.MANIFEST).read_text(encoding="utf-8"))
    assert names == check_permissions.ALLOWED
    assert check_permissions.problems(names) == []


def test_unlisted_permissions_fail_in_xml_and_aapt2_output() -> None:
    xml = '<uses-permission android:name="android.permission.READ_CONTACTS"/>\n' \
          '<uses-permission android:name="android.permission.CAMERA"/>'
    aapt = "package: app.dokulo\n" \
           "uses-permission: name='android.permission.ACCESS_FINE_LOCATION'\n" \
           "uses-permission: name='app.dokulo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'\n" \
           "uses-permission: name='android.permission.INTERNET'"
    assert [p.split()[0] for p in check_permissions.problems(check_permissions.declared(xml))] == [
        "android.permission.READ_CONTACTS"]
    assert [p.split()[0] for p in check_permissions.problems(check_permissions.declared(aapt))] == [
        "android.permission.ACCESS_FINE_LOCATION"]
