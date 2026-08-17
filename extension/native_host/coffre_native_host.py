#!/usr/bin/env python3
"""Native Messaging host for the Coffre browser extension."""

from __future__ import annotations

import json
import os
import struct
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def bridge_path() -> Path:
    appdata = os.environ.get("APPDATA") or str(Path.home())
    return Path(appdata) / "Coffre" / "bridge.json"


def read_message() -> dict | None:
    raw_len = sys.stdin.buffer.read(4)
    if not raw_len or len(raw_len) < 4:
        return None
    length = struct.unpack("<I", raw_len)[0]
    data = sys.stdin.buffer.read(length)
    if not data:
        return None
    return json.loads(data.decode("utf-8"))


def send_message(payload: dict) -> None:
    encoded = json.dumps(payload).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def call_bridge(path: str, data: dict | None = None) -> dict:
    bridge = bridge_path()
    if not bridge.exists():
        return {
            "error": "bridge_missing",
            "message": "Ouvrez et déverrouillez Coffre",
        }
    cfg = json.loads(bridge.read_text(encoding="utf-8"))
    port = cfg.get("port")
    token = cfg.get("token")
    if not port or not token:
        return {"error": "bridge_invalid"}
    url = f"http://127.0.0.1:{port}{path}"
    headers = {"Authorization": f"Bearer {token}"}
    body = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method="POST" if data is not None else "GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body_text)
            if e.code == 401:
                parsed["locked"] = True
            return parsed
        except Exception:
            return {"error": "http", "status": e.code, "body": body_text}
    except Exception as e:
        return {"error": str(e)}


def call_bridge_domain(domain: str) -> dict:
    query = urllib.parse.urlencode({"domain": domain})
    return call_bridge(f"/credentials?{query}")


def call_bridge_all() -> dict:
    return call_bridge("/entries")


def main() -> None:
    while True:
        msg = read_message()
        if msg is None:
            break
        if msg.get("type") == "credentials":
            send_message(call_bridge_domain(msg.get("domain") or ""))
        elif msg.get("type") == "allEntries":
            send_message(call_bridge_all())
        elif msg.get("type") == "saveCredential":
            send_message(
                call_bridge(
                    "/save",
                    {
                        "username": msg.get("username") or "",
                        "password": msg.get("password") or "",
                        "url": msg.get("url") or "",
                        "domain": msg.get("domain") or "",
                    },
                )
            )
        else:
            send_message({"error": "unknown_type"})


if __name__ == "__main__":
    main()
