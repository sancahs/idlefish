#!/usr/bin/env python3
"""Fetch public idlefish node metrics listed in config/nodes.json."""

from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "config" / "nodes.json"
DEFAULT_OUTPUT = ROOT / "metrics" / "nodes"
USER_AGENT = "idlefish-dashboard-fetcher/0.1"
NODE_RE = re.compile(r"[^A-Za-z0-9_.-]+")


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def safe_name(value: str) -> str:
    name = NODE_RE.sub("-", value.strip()).strip(".-")
    return name or "unknown-node"


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        body = response.read()
        data = json.loads(body.decode("utf-8"))
    if not isinstance(data, dict):
        raise ValueError("node metrics response must be a JSON object")
    return data


def error_node(node_name: str, url: str, exc: BaseException) -> dict[str, Any]:
    return {
        "node_name": node_name,
        "timestamp_utc": now_utc(),
        "fishnet_active": False,
        "estimated_cpu_hours": 0,
        "n_restarts": 0,
        "load_average": "",
        "memory_available_kb": 0,
        "metrics_fetch_ok": False,
        "metrics_url": url,
        "fetch_error": f"{type(exc).__name__}: {exc}",
        "notes": "Could not fetch node metrics. This is a dashboard fetch error, not an official Lichess status.",
    }


def load_nodes(config_path: Path) -> list[dict[str, Any]]:
    if not config_path.exists():
        return []
    data = read_json(config_path)
    if not isinstance(data, list):
        raise ValueError(f"{config_path} must contain a JSON array")
    return [node for node in data if isinstance(node, dict)]


def main() -> int:
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CONFIG
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT
    output_dir.mkdir(parents=True, exist_ok=True)

    for old_file in output_dir.glob("*.json"):
        old_file.unlink()

    nodes = load_nodes(config_path)
    for node in nodes:
        node_name = safe_name(str(node.get("node_name") or node.get("public_label") or "unknown-node"))
        url = str(node.get("metrics_url") or "")
        if not url:
            result = error_node(node_name, url, ValueError("missing metrics_url"))
        else:
            try:
                result = fetch_json(url)
                result.setdefault("node_name", node_name)
                result["node_name"] = safe_name(str(result["node_name"]))
                result["metrics_fetch_ok"] = True
                result["metrics_url"] = url
                if node.get("public_label"):
                    result["public_label"] = str(node["public_label"])
            except (urllib.error.URLError, TimeoutError, OSError, ValueError, json.JSONDecodeError) as exc:
                result = error_node(node_name, url, exc)

        output_path = output_dir / f"{safe_name(str(result.get('node_name', node_name)))}.json"
        output_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
