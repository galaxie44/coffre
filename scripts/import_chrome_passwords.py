"""Extract saved passwords from Google Chrome on Windows and write Coffre import JSON."""
from __future__ import annotations

import base64
import ctypes
import json
import os
import shutil
import sqlite3
import sys
import tempfile
from ctypes import wintypes
from pathlib import Path

try:
    from Cryptodome.Cipher import AES
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "pycryptodome", "-q"])
    from Cryptodome.Cipher import AES


class _DATA_BLOB(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_byte))]


def dpapi_decrypt(data: bytes) -> bytes:
    blob_in = _DATA_BLOB(len(data), ctypes.cast(ctypes.create_string_buffer(data), ctypes.POINTER(ctypes.c_byte)))
    blob_out = _DATA_BLOB()
    if not ctypes.windll.crypt32.CryptUnprotectData(
        ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out)
    ):
        raise OSError("CryptUnprotectData failed")
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(blob_out.pbData)


def chrome_user_data() -> Path:
    local = os.environ.get("LOCALAPPDATA", "")
    return Path(local) / "Google" / "Chrome" / "User Data"


def get_master_key(local_state: Path) -> bytes:
    data = json.loads(local_state.read_text(encoding="utf-8"))
    enc_key = base64.b64decode(data["os_crypt"]["encrypted_key"])
    # Strip "DPAPI" prefix
    return dpapi_decrypt(enc_key[5:])


def decrypt_value(raw: bytes, key: bytes) -> str:
    if not raw:
        return ""
    try:
        if raw[:3] in (b"v10", b"v11"):
            nonce = raw[3:15]
            payload = raw[15:]
            cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
            return cipher.decrypt_and_verify(payload[:-16], payload[-16:]).decode(
                "utf-8", errors="replace"
            )
        return dpapi_decrypt(raw).decode("utf-8", errors="replace")
    except Exception:
        try:
            return dpapi_decrypt(raw).decode("utf-8", errors="replace")
        except Exception:
            return ""


def read_profile_logins(profile_dir: Path, key: bytes) -> list[dict]:
    db = profile_dir / "Login Data"
    if not db.exists():
        return []
    tmp = Path(tempfile.gettempdir()) / f"coffre_login_{profile_dir.name}.db"
    try:
        shutil.copy2(db, tmp)
    except PermissionError:
        print(f"  ! Fermez Chrome pour lire {profile_dir.name}", file=sys.stderr)
        return []

    rows: list[dict] = []
    con = sqlite3.connect(tmp)
    try:
        cur = con.cursor()
        cur.execute(
            "SELECT origin_url, username_value, password_value, signon_realm "
            "FROM logins WHERE username_value != '' OR password_value != ''"
        )
        for url, username, pwd_blob, realm in cur.fetchall():
            password = decrypt_value(pwd_blob, key) if pwd_blob else ""
            if not username and not password:
                continue
            title = realm or url or "Chrome"
            if url.startswith("android://"):
                pkg = url.split("@")[-1].rstrip("/")
                title = _friendly_android_title(pkg, url)
            elif url.startswith("http"):
                title = _friendly_web_title(url, realm)
            rows.append(
                {
                    "title": title,
                    "username": username or "",
                    "password": password,
                    "url": url or "",
                }
            )
    finally:
        con.close()
        try:
            tmp.unlink(missing_ok=True)
        except Exception:
            pass
    return rows


def _friendly_web_title(url: str, realm: str) -> str:
    from urllib.parse import urlparse

    host = ""
    try:
        host = urlparse(url).hostname or ""
    except Exception:
        pass
    host = (host or realm or url).lower().replace("www.", "")
    labels = {
        "accounts.google.com": "Google",
        "google.com": "Google",
        "store.steampowered.com": "Steam",
        "steamcommunity.com": "Steam",
        "discord.com": "Discord",
        "netflix.com": "Netflix",
        "spotify.com": "Spotify",
        "facebook.com": "Facebook",
        "instagram.com": "Instagram",
        "paypal.com": "PayPal",
        "amazon.fr": "Amazon",
        "amazon.com": "Amazon",
        "github.com": "GitHub",
    }
    for key, label in labels.items():
        if host == key or host.endswith("." + key):
            return label
    parts = host.split(".")
    if len(parts) >= 2:
        core = parts[-2]
        if len(core) > 2:
            return core.capitalize()
    return host or "Site web"


def _friendly_android_title(package: str, url: str) -> str:
    known = {
        "com.google.android.gm": "Gmail",
        "com.valvesoftware.android.steam.community": "Steam",
        "com.discord": "Discord",
        "com.netflix.mediaclient": "Netflix",
        "com.spotify.music": "Spotify",
        "com.naver.linewebtoon": "Webtoon",
        "com.digitalplumecompany.boostyourteam": "Boost Your Team",
    }
    if package in known:
        return known[package]
    skip = {"com", "org", "net", "android", "app", "mobile"}
    parts = [p for p in package.split(".") if p and p not in skip and len(p) > 2]
    if not parts:
        return package
    return " ".join(p.replace("_", " ").capitalize() for p in parts[-2:])


def main() -> int:
    root = chrome_user_data()
    local_state = root / "Local State"
    if not local_state.exists():
        print("Chrome introuvable sur ce PC.", file=sys.stderr)
        return 1

    key = get_master_key(local_state)
    all_entries: list[dict] = []
    seen: set[tuple[str, str, str]] = set()

    profiles = [root / "Default"] + sorted(root.glob("Profile *"))
    for profile in profiles:
        if not profile.is_dir():
            continue
        logins = read_profile_logins(profile, key)
        print(f"{profile.name}: {len(logins)} entrée(s)")
        for item in logins:
            sig = (item["url"], item["username"], item["password"])
            if sig in seen:
                continue
            seen.add(sig)
            all_entries.append(item)

    out_dir = Path(os.environ.get("APPDATA", Path.home())) / "Coffre"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "chrome_import.json"
    out_file.write_text(
        json.dumps({"source": "chrome", "entries": all_entries}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"OK - {len(all_entries)} entrees -> {out_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
