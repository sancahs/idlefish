#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: sudo scripts/install-fishnet-systemd.sh <local-fishnet-binary-or-download-url>

Installs the official fishnet binary to /opt/fishnet/bin/fishnet and installs
a conservative systemd service example as fishnet.service.

This script does not ask for, store, or print your fishnet key. Configure the
key manually after installation:

  sudo -u fishnet -H sh -lc 'cd /var/lib/fishnet && /opt/fishnet/bin/fishnet configure'
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "error: run this script with sudo/root so it can create users and install systemd units" >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "error: systemctl was not found; this installer requires Linux with systemd" >&2
  exit 1
fi

SOURCE=$1
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SERVICE_SOURCE="${REPO_DIR}/systemd/fishnet.service.example"

if [[ ! -f "${SERVICE_SOURCE}" ]]; then
  echo "error: missing ${SERVICE_SOURCE}" >&2
  exit 1
fi

echo "Installing fishnet with conservative resource limits."
echo "Do not run fishnet unrestricted on machines with important services."

if ! id -u fishnet >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/fishnet --create-home --shell /usr/sbin/nologin fishnet
  echo "Created system user: fishnet"
else
  echo "System user already exists: fishnet"
fi

install -d -o root -g root -m 0755 /opt/fishnet/bin
install -d -o fishnet -g fishnet -m 0750 /var/lib/fishnet

TMP_FILE=$(mktemp)
cleanup() {
  rm -f "${TMP_FILE}"
}
trap cleanup EXIT

case "${SOURCE}" in
  http://*|https://*)
    if command -v curl >/dev/null 2>&1; then
      curl --fail --location --show-error --output "${TMP_FILE}" "${SOURCE}"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "${TMP_FILE}" "${SOURCE}"
    else
      echo "error: need curl or wget to download fishnet" >&2
      exit 1
    fi
    ;;
  *)
    if [[ ! -f "${SOURCE}" ]]; then
      echo "error: local fishnet binary not found: ${SOURCE}" >&2
      exit 1
    fi
    cp "${SOURCE}" "${TMP_FILE}"
    ;;
esac

install -o root -g root -m 0755 "${TMP_FILE}" /opt/fishnet/bin/fishnet
install -o root -g root -m 0644 "${SERVICE_SOURCE}" /etc/systemd/system/fishnet.service
systemctl daemon-reload

cat <<'NEXT'

Installed /opt/fishnet/bin/fishnet and /etc/systemd/system/fishnet.service.

Next steps:

  1. Configure your personal fishnet key manually:

       sudo -u fishnet -H sh -lc 'cd /var/lib/fishnet && /opt/fishnet/bin/fishnet configure'

     Never commit or publish this key.

  2. Start with conservative settings:

       sudo systemctl enable --now fishnet
       systemctl status fishnet
       journalctl -u fishnet -f

  3. On shared or small machines, start with 1 core and watch load, memory,
     swap, MQTT, Grafana, Postgres, TimescaleDB, and other local services.

To stop fishnet:

  sudo systemctl stop fishnet

To disable fishnet:

  sudo systemctl disable fishnet
NEXT
