#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "error: run this script with sudo/root" >&2
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now fishnet 2>/dev/null || true
  rm -f /etc/systemd/system/fishnet.service
  systemctl daemon-reload
fi

rm -f /opt/fishnet/bin/fishnet

cat <<'DONE'
Removed the fishnet systemd service and /opt/fishnet/bin/fishnet.

The fishnet user and /var/lib/fishnet were left in place so keys and local
state are not deleted unexpectedly. Remove them manually only if you are sure:

  sudo userdel fishnet
  sudo rm -rf /var/lib/fishnet /opt/fishnet
DONE
