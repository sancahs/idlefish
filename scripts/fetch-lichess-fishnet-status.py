#!/usr/bin/env python3
"""Fetch public Lichess fishnet status without using a fishnet key."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

URL = "https://lichess.org/fishnet/status"
USER_AGENT = "idlefish-hackerspace-status/0.1"


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def fetch_status() -> dict:
    request = urllib.request.Request(URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        body = response.read()
        status_code = response.status

    try:
        payload = json.loads(body.decode("utf-8"))
    except json.JSONDecodeError:
        payload = {"raw": body.decode("utf-8", errors="replace")}

    return {
        "ok": True,
        "source": URL,
        "fetched_at_utc": now_utc(),
        "http_status": status_code,
        "data": payload,
    }


def error_status(exc: BaseException) -> dict:
    return {
        "ok": False,
        "source": URL,
        "fetched_at_utc": now_utc(),
        "error": type(exc).__name__,
        "message": str(exc),
        "data": None,
    }


def main() -> int:
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("metrics/global-status.json")
    output.parent.mkdir(parents=True, exist_ok=True)

    try:
        result = fetch_status()
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
        result = error_status(exc)

    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
