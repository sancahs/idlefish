#!/usr/bin/env python3
"""Generate static idlefish dashboard data from local JSON metrics."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
METRICS_NODES = ROOT / "metrics" / "nodes"
GLOBAL_STATUS = ROOT / "metrics" / "global-status.json"
SITE = ROOT / "site"
SITE_DATA = SITE / "data"


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def read_nodes() -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    paths = sorted(METRICS_NODES.glob("*.json")) if METRICS_NODES.exists() else []
    if not paths:
        sample = SITE_DATA / "sample-node-metrics.json"
        return [read_json(sample)] if sample.exists() else []

    for path in paths:
        try:
            data = read_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            data = {
                "node_name": path.stem,
                "timestamp_utc": now_utc(),
                "fishnet_active": False,
                "estimated_cpu_hours": 0,
                "n_restarts": 0,
                "load_average": "",
                "memory_available_kb": 0,
                "notes": f"Could not read metrics file: {exc}",
            }
        nodes.append(data)
    return nodes


def read_global_status() -> dict[str, Any]:
    if GLOBAL_STATUS.exists():
        try:
            return read_json(GLOBAL_STATUS)
        except (OSError, json.JSONDecodeError) as exc:
            return {"ok": False, "fetched_at_utc": now_utc(), "error": "JSONError", "message": str(exc)}

    sample = SITE_DATA / "sample-global-status.json"
    if sample.exists():
        return read_json(sample)
    return {"ok": False, "fetched_at_utc": now_utc(), "message": "No global status file available"}


def cpu_today(nodes: list[dict[str, Any]]) -> float | None:
    values = []
    for node in nodes:
        value = node.get("estimated_cpu_hours_today")
        if isinstance(value, (int, float)):
            values.append(float(value))
    if not values:
        return None
    return round(sum(values), 3)


def sum_optional_number(nodes: list[dict[str, Any]], key: str) -> int | None:
    values = []
    for node in nodes:
        value = node.get(key)
        if isinstance(value, (int, float)):
            values.append(int(value))
    if not values:
        return None
    return sum(values)


def prefer_optional_number(primary: int | None, fallback: int | None) -> int | None:
    if primary is not None:
        return primary
    return fallback


def aggregate(nodes: list[dict[str, Any]]) -> dict[str, Any]:
    timestamps = [node.get("timestamp_utc") for node in nodes if node.get("timestamp_utc")]
    total_cpu = sum(float(node.get("lifetime_estimated_cpu_hours") or node.get("estimated_cpu_hours") or 0) for node in nodes)
    return {
        "generated_at_utc": now_utc(),
        "total_nodes": len(nodes),
        "active_nodes": sum(1 for node in nodes if bool(node.get("fishnet_active"))),
        "total_estimated_cpu_hours": round(total_cpu, 3),
        "estimated_cpu_hours_today": cpu_today(nodes),
        "total_fishnet_analysis_jobs_finished": prefer_optional_number(
            sum_optional_number(nodes, "lifetime_fishnet_analysis_jobs_finished"),
            sum_optional_number(nodes, "fishnet_analysis_jobs_finished"),
        ),
        "total_fishnet_batches": prefer_optional_number(
            sum_optional_number(nodes, "lifetime_fishnet_batches"),
            sum_optional_number(nodes, "fishnet_batches"),
        ),
        "total_fishnet_positions": prefer_optional_number(
            sum_optional_number(nodes, "lifetime_fishnet_positions"),
            sum_optional_number(nodes, "fishnet_positions"),
        ),
        "total_fishnet_nodes": prefer_optional_number(
            sum_optional_number(nodes, "lifetime_fishnet_total_nodes"),
            sum_optional_number(nodes, "fishnet_total_nodes"),
        ),
        "last_update_utc": max(timestamps) if timestamps else None,
        "notes": "Local community metrics; not official Lichess contribution stats.",
    }


def ensure_index() -> None:
    index = SITE / "index.html"
    if index.exists():
        return
    index.write_text(
        """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>idlefish</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>idlefish</h1>
    <p>Hackerspace idle CPU for the free chess commons</p>
    <div id="app">Loading dashboard data...</div>
  </main>
  <script src="app.js"></script>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> int:
    SITE_DATA.mkdir(parents=True, exist_ok=True)
    nodes = read_nodes()
    global_status = read_global_status()
    payload = {"aggregate": aggregate(nodes), "nodes": nodes}

    (SITE_DATA / "nodes.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (SITE_DATA / "global-status.json").write_text(
        json.dumps(global_status, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    ensure_index()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
