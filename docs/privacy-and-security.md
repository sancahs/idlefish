# Privacy and security

## Fishnet keys

Never commit fishnet keys. Never publish them in dashboard data, logs, issues, screenshots, or chat.

Configure keys manually on each node:

```bash
sudo -u fishnet -H sh -lc 'cd /var/lib/fishnet && /opt/fishnet/bin/fishnet configure'
```

## Node names

Do not publish hostnames if members prefer privacy. Use pseudonymous node names such as:

- `lab-desktop-1`
- `member-node-a`
- `tiny-vps-east`

Do not publish IP addresses.

## What the local metrics script collects

`scripts/collect-local-metrics.sh` collects:

- node name from `IDLEFISH_NODE_NAME` or hostname
- current UTC timestamp
- fishnet service active state
- fishnet service active-enter timestamp
- fishnet service restart count
- fishnet service CPU usage from systemd
- optional aggregate fishnet log counters, without publishing individual game IDs
- persisted lifetime totals from the local idlefish state file
- load average from `/proc/loadavg`
- available memory from `/proc/meminfo`

## What it does not collect

The script does not collect:

- fishnet keys
- individual Lichess game IDs from fishnet logs
- IP addresses
- Lichess usernames
- private Lichess data
- shell history
- process command lines beyond systemd service properties

## Removing a node from the public page

Remove that node's entry from `config/nodes.json`, regenerate the site, and publish again:

```bash
python3 scripts/fetch-node-metrics.py
python3 scripts/generate-site.py
```

If the node name itself was sensitive, remove it from Git history according to your repository policy.
