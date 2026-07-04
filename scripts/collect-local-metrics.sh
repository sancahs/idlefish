#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME=${IDLEFISH_SERVICE_NAME:-fishnet}
NODE_NAME=${IDLEFISH_NODE_NAME:-$(hostname 2>/dev/null || echo "unknown-node")}
TIMESTAMP_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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
FISHNET_TOTAL_NODES=null

if [[ -n "${ACTIVE_ENTER_TIMESTAMP}" ]]; then
  if JOURNAL_TEXT=$(journalctl -u "${SERVICE_NAME}" --since "${ACTIVE_ENTER_TIMESTAMP}" --no-pager -o cat 2>/dev/null); then
    read -r FISHNET_ANALYSIS_JOBS_FINISHED FISHNET_BATCHES FISHNET_POSITIONS FISHNET_TOTAL_NODES < <(
      printf '%s\n' "${JOURNAL_TEXT}" | python3 -c '
import re
import sys

finished = 0
batches = positions = total_nodes = "null"
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
        total_nodes = clean_int(match.group(3))

print(f"{finished} {batches} {positions} {total_nodes}")
'
    )
  fi
fi

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
  "fishnet_total_nodes": ${FISHNET_TOTAL_NODES},
  "load_average": ${LOAD_JSON},
  "memory_available_kb": ${MEMORY_AVAILABLE_KB},
  "notes": "Local estimate only; not an official Lichess contribution counter."
}
JSON
