#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME=${IDLEFISH_SERVICE_NAME:-fishnet}
NODE_NAME=${IDLEFISH_NODE_NAME:-$(hostname 2>/dev/null || echo "unknown-node")}
TIMESTAMP_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -n "${IDLEFISH_STATE_FILE:-}" ]]; then
  STATE_FILE=${IDLEFISH_STATE_FILE}
else
  STATE_DIR=${IDLEFISH_STATE_DIR:-}
  if [[ -z "${STATE_DIR}" ]]; then
    if [[ "${EUID}" -eq 0 ]]; then
      STATE_DIR=/var/lib/idlefish
    else
      STATE_DIR="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/idlefish"
    fi
  fi
  STATE_BASENAME=$(printf '%s-%s' "${SERVICE_NAME}" "${NODE_NAME}" | tr -cs 'A-Za-z0-9_.-' '-' | sed 's/^-//;s/-$//')
  STATE_FILE="${STATE_DIR}/${STATE_BASENAME:-fishnet}.json"
fi

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

show_prop() {
  local prop=$1
  systemctl show "${SERVICE_NAME}" --property="${prop}" --value 2>/dev/null || true
}

ACTIVE_STATE=$(show_prop ActiveState)
ACTIVE_ENTER_TIMESTAMP=$(show_prop ActiveEnterTimestamp)
N_RESTARTS=$(show_prop NRestarts)
CPU_USAGE_NSEC=$(show_prop CPUUsageNSec)

if [[ -z "${ACTIVE_STATE}" ]]; then
  FISHNET_ACTIVE=false
  ACTIVE_ENTER_TIMESTAMP=""
  N_RESTARTS=0
  CPU_USAGE_NSEC=0
else
  if [[ "${ACTIVE_STATE}" == "active" ]]; then
    FISHNET_ACTIVE=true
  else
    FISHNET_ACTIVE=false
  fi
fi

if [[ -z "${N_RESTARTS}" || "${N_RESTARTS}" == "[not set]" ]]; then
  N_RESTARTS=0
fi

if [[ -z "${CPU_USAGE_NSEC}" || "${CPU_USAGE_NSEC}" == "[not set]" ]]; then
  CPU_USAGE_NSEC=0
fi

LOAD_AVERAGE=$(cut -d ' ' -f 1-3 /proc/loadavg 2>/dev/null || echo "")
MEMORY_AVAILABLE_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
if [[ -z "${MEMORY_AVAILABLE_KB}" ]]; then
  MEMORY_AVAILABLE_KB=0
fi

ESTIMATED_CPU_HOURS=$(awk -v ns="${CPU_USAGE_NSEC}" 'BEGIN { printf "%.6f", ns / 1000000000 / 3600 }')

FISHNET_ANALYSIS_JOBS_FINISHED=null
FISHNET_BATCHES=null
FISHNET_POSITIONS=null
FISHNET_STOCKFISH_NODES=null

if [[ -n "${ACTIVE_ENTER_TIMESTAMP}" ]]; then
  if JOURNAL_TEXT=$(journalctl -u "${SERVICE_NAME}" --since "${ACTIVE_ENTER_TIMESTAMP}" --no-pager -o cat 2>/dev/null); then
    read -r FISHNET_ANALYSIS_JOBS_FINISHED FISHNET_BATCHES FISHNET_POSITIONS FISHNET_STOCKFISH_NODES < <(
      printf '%s\n' "${JOURNAL_TEXT}" | python3 -c '
import re
import sys

finished = 0
batches = positions = stockfish_nodes = "null"
finished_re = re.compile(r"https://lichess\.org/[A-Za-z0-9]+ finished")
summary_re = re.compile(
    r"><> v[^:]+:.*?,\s*([0-9.]+)\s+batches,\s*([0-9.]+)\s+positions,\s*([0-9.]+)\s+total nodes"
)

def clean_int(value):
    return str(int(value.replace(".", "")))

for line in sys.stdin:
    if finished_re.search(line):
        finished += 1
    match = summary_re.search(line)
    if match:
        batches = clean_int(match.group(1))
        positions = clean_int(match.group(2))
        stockfish_nodes = clean_int(match.group(3))

print(f"{finished} {batches} {positions} {stockfish_nodes}")
'
    )
  fi
fi

STATE_RESULT=$(IDLEFISH_STATE_FILE_RESOLVED="${STATE_FILE}" \
  IDLEFISH_SERVICE_NAME_RESOLVED="${SERVICE_NAME}" \
  IDLEFISH_NODE_NAME_RESOLVED="${NODE_NAME}" \
  IDLEFISH_TIMESTAMP_UTC="${TIMESTAMP_UTC}" \
  IDLEFISH_ACTIVE_ENTER_TIMESTAMP="${ACTIVE_ENTER_TIMESTAMP}" \
  IDLEFISH_CPU_USAGE_NSEC="${CPU_USAGE_NSEC}" \
  IDLEFISH_JOBS_FINISHED="${FISHNET_ANALYSIS_JOBS_FINISHED}" \
  IDLEFISH_BATCHES="${FISHNET_BATCHES}" \
  IDLEFISH_POSITIONS="${FISHNET_POSITIONS}" \
  IDLEFISH_STOCKFISH_NODES="${FISHNET_STOCKFISH_NODES}" \
  python3 -c '
import json
import os
import sys
from pathlib import Path

state_file = Path(os.environ["IDLEFISH_STATE_FILE_RESOLVED"])
timestamp = os.environ["IDLEFISH_TIMESTAMP_UTC"]
active_enter = os.environ["IDLEFISH_ACTIVE_ENTER_TIMESTAMP"]

def parse_int(name):
    value = os.environ.get(name, "")
    if value in ("", "null", "[not set]"):
        return None
    return int(value)

current = {
    "cpu_usage_nsec": parse_int("IDLEFISH_CPU_USAGE_NSEC"),
    "fishnet_analysis_jobs_finished": parse_int("IDLEFISH_JOBS_FINISHED"),
    "fishnet_batches": parse_int("IDLEFISH_BATCHES"),
    "fishnet_positions": parse_int("IDLEFISH_POSITIONS"),
    "fishnet_stockfish_nodes": parse_int("IDLEFISH_STOCKFISH_NODES"),
}

state = {}
try:
    with state_file.open("r", encoding="utf-8") as handle:
        loaded = json.load(handle)
        if isinstance(loaded, dict):
            state = loaded
except (OSError, json.JSONDecodeError):
    state = {}

lifetime = state.get("lifetime")
if not isinstance(lifetime, dict):
    lifetime = {}
last = state.get("last")
if not isinstance(last, dict):
    last = {}
lifetime = {key: lifetime.get(key) for key in current if key in lifetime}
last = {
    "active_enter_timestamp": last.get("active_enter_timestamp"),
    **{key: last.get(key) for key in current if key in last},
}

same_run = bool(active_enter) and active_enter == last.get("active_enter_timestamp")
keys = tuple(current)
for key in keys:
    value = current[key]
    if value is None:
        lifetime.setdefault(key, None)
        continue
    previous_total = lifetime.get(key)
    if not isinstance(previous_total, int):
        previous_total = 0
    previous_value = last.get(key)
    if same_run and isinstance(previous_value, int):
        delta = max(0, value - previous_value)
    else:
        delta = value
    lifetime[key] = previous_total + delta

new_state = {
    "version": 1,
    "service_name": os.environ["IDLEFISH_SERVICE_NAME_RESOLVED"],
    "node_name": os.environ["IDLEFISH_NODE_NAME_RESOLVED"],
    "updated_at_utc": timestamp,
    "last": {
        "active_enter_timestamp": active_enter,
        **current,
    },
    "lifetime": lifetime,
}

state_ok = "true"
try:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    tmp = state_file.with_name(f".{state_file.name}.tmp")
    tmp.write_text(json.dumps(new_state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(state_file)
except OSError:
    state_ok = "false"

def out_int(value):
    return str(value) if isinstance(value, int) else "null"

cpu_nsec = lifetime.get("cpu_usage_nsec")
cpu_hours = "null" if not isinstance(cpu_nsec, int) else f"{cpu_nsec / 1000000000 / 3600:.6f}"
print(
    " ".join(
        [
            out_int(cpu_nsec),
            cpu_hours,
            out_int(lifetime.get("fishnet_analysis_jobs_finished")),
            out_int(lifetime.get("fishnet_batches")),
            out_int(lifetime.get("fishnet_positions")),
            out_int(lifetime.get("fishnet_stockfish_nodes")),
            state_ok,
        ]
    )
)
' 2>/dev/null || printf 'null null null null null null false')
read -r LIFETIME_CPU_USAGE_NSEC LIFETIME_ESTIMATED_CPU_HOURS LIFETIME_JOBS_FINISHED LIFETIME_BATCHES LIFETIME_POSITIONS LIFETIME_STOCKFISH_NODES STATE_WRITE_OK <<<"${STATE_RESULT}"

NODE_JSON=$(printf '%s' "${NODE_NAME}" | json_escape)
ACTIVE_TS_JSON=$(printf '%s' "${ACTIVE_ENTER_TIMESTAMP}" | json_escape)
LOAD_JSON=$(printf '%s' "${LOAD_AVERAGE}" | json_escape)

cat <<JSON
{
  "node_name": ${NODE_JSON},
  "timestamp_utc": "${TIMESTAMP_UTC}",
  "fishnet_active": ${FISHNET_ACTIVE},
  "active_enter_timestamp": ${ACTIVE_TS_JSON},
  "n_restarts": ${N_RESTARTS},
  "cpu_usage_nsec": ${CPU_USAGE_NSEC},
  "estimated_cpu_hours": ${ESTIMATED_CPU_HOURS},
  "fishnet_analysis_jobs_finished": ${FISHNET_ANALYSIS_JOBS_FINISHED},
  "fishnet_batches": ${FISHNET_BATCHES},
  "fishnet_positions": ${FISHNET_POSITIONS},
  "fishnet_stockfish_nodes": ${FISHNET_STOCKFISH_NODES},
  "lifetime_cpu_usage_nsec": ${LIFETIME_CPU_USAGE_NSEC},
  "lifetime_estimated_cpu_hours": ${LIFETIME_ESTIMATED_CPU_HOURS},
  "lifetime_fishnet_analysis_jobs_finished": ${LIFETIME_JOBS_FINISHED},
  "lifetime_fishnet_batches": ${LIFETIME_BATCHES},
  "lifetime_fishnet_positions": ${LIFETIME_POSITIONS},
  "lifetime_fishnet_stockfish_nodes": ${LIFETIME_STOCKFISH_NODES},
  "lifetime_state_write_ok": ${STATE_WRITE_OK},
  "load_average": ${LOAD_JSON},
  "memory_available_kb": ${MEMORY_AVAILABLE_KB},
  "notes": "Local estimate only; not an official Lichess contribution counter."
}
JSON
