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
  "load_average": ${LOAD_JSON},
  "memory_available_kb": ${MEMORY_AVAILABLE_KB},
  "notes": "Local estimate only; not an official Lichess contribution counter."
}
JSON
