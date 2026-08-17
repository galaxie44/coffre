"""Disable Chrome / Edge native password autofill (user Preferences)."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def profiles(user_data: Path) -> list[Path]:
    if not user_data.is_dir():
        return []
    found = [user_data / "Default"]
    found.extend(sorted(user_data.glob("Profile *")))
    return [p for p in found if p.is_dir()]


def patch(prefs: Path, disable: bool) -> bool:
    if not prefs.exists():
        return False
    data = json.loads(prefs.read_text(encoding="utf-8"))
    data["credentials_enable_service"] = not disable
    data["credentials_enable_autosignin"] = False
    prefs.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return True


def main() -> int:
    disable = "--enable" not in sys.argv
    local = Path(os.environ.get("LOCALAPPDATA", ""))
    roots = [
        local / "Google" / "Chrome" / "User Data",
        local / "Microsoft" / "Edge" / "User Data",
    ]
    n = 0
    for root in roots:
        for profile in profiles(root):
            if patch(profile / "Preferences", disable):
                n += 1
                print(f"OK {profile}")
    if n == 0:
        print("Aucun profil Chrome/Edge trouve.", file=sys.stderr)
        return 1
    print(f"{n} profil(s) mis a jour. Relancez Chrome.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
