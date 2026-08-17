"""Generate and register the Native Messaging host manifest.

Installs into an ASCII-only path under %LOCALAPPDATA%\\Coffre\\native_host
so Chrome can launch the host even when the project folder has accents.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import winreg
from pathlib import Path


def install_dir() -> Path:
    local = os.environ.get("LOCALAPPDATA") or str(Path.home())
    return Path(local) / "Coffre" / "native_host"


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python install_host.py <chrome-extension-id>")
        return 1

    ext_id = sys.argv[1].strip().lower()
    if not ext_id or any(c not in "abcdefghijklmnopqrstuvwxyz" for c in ext_id):
        print("ID d'extension invalide.")
        return 1

    src_dir = Path(__file__).resolve().parent
    dst = install_dir()
    dst.mkdir(parents=True, exist_ok=True)

    # Copy host script to ASCII path
    src_py = src_dir / "coffre_native_host.py"
    dst_py = dst / "coffre_native_host.py"
    shutil.copy2(src_py, dst_py)

    # Resolve python.exe (ASCII path typically)
    py = Path(sys.executable).resolve()
    wrapper = dst / "run_host.bat"
    # Use short ASCII-only launcher; avoid path-with-accents issues
    wrapper.write_text(
        f'@echo off\r\n"{py}" "{dst_py}" %*\r\n',
        encoding="ascii",
        newline="\r\n",
    )

    manifest_path = dst / "com.coffre.bridge.json"
    manifest = {
        "name": "com.coffre.bridge",
        "description": "Coffre Native Messaging Host",
        "path": str(wrapper),
        "type": "stdio",
        "allowed_origins": [f"chrome-extension://{ext_id}/"],
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="ascii")

    for root in (
        r"Software\Google\Chrome\NativeMessagingHosts\com.coffre.bridge",
        r"Software\Microsoft\Edge\NativeMessagingHosts\com.coffre.bridge",
    ):
        key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, root)
        winreg.SetValueEx(key, None, 0, winreg.REG_SZ, str(manifest_path))
        winreg.CloseKey(key)

    # Keep a copy next to sources for reference
    (src_dir / "com.coffre.bridge.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )

    print(f"Host enregistre: {manifest_path}")
    print(f"Launcher: {wrapper}")
    print(f"Extension: chrome-extension://{ext_id}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
