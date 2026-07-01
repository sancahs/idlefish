# Publishing node metrics

The central dashboard uses a pull model.

Each participating machine publishes one small JSON file over HTTPS. GitHub Actions fetches those files on a schedule, combines them with the public Lichess fishnet status, and republishes the GitHub Pages dashboard.

Node operators do not need GitHub push access.

The important contract is the JSON URL, not the specific tools used to create it. The examples below use cron, systemd, and Caddy because they are common on small Linux VPSes, but any equivalent setup is fine.

## What a node exposes

A node exposes output from:

```bash
IDLEFISH_NODE_NAME=my-node scripts/collect-local-metrics.sh
```

The JSON should be public, read-only, and should not contain secrets, IP addresses, fishnet keys, or private hostnames.

Example public URL:

```text
https://example.org/idlefish/my-node.json
```

## Metrics contract

The dashboard expects a public HTTPS URL that returns one JSON object. The recommended way to produce it is `collect-local-metrics.sh`, but contributors can adapt the idea to their environment if they keep the same basic fields.

Important fields:

- `node_name`: short public node name
- `timestamp_utc`: when the metrics were generated
- `fishnet_active`: whether fishnet is currently running
- `estimated_cpu_hours`: local estimate of donated CPU time
- `n_restarts`: local restart count, if available
- `load_average`: host load average, if available
- `memory_available_kb`: available memory, if available
- `notes`: short note making clear the metrics are local estimates

Example:

```json
{
  "node_name": "my-node",
  "timestamp_utc": "2026-07-01T12:00:00Z",
  "fishnet_active": true,
  "estimated_cpu_hours": 12.34,
  "n_restarts": 0,
  "load_average": "0.12 0.20 0.18",
  "memory_available_kb": 123456,
  "notes": "Local estimate only; not an official Lichess contribution counter."
}
```

## Minimal static file example

On a VPS that already has a web server, write the metrics file somewhere public:

```bash
sudo mkdir -p /var/www/idlefish
IDLEFISH_NODE_NAME=my-node scripts/collect-local-metrics.sh | sudo tee /var/www/idlefish/my-node.json >/dev/null
```

Then check it from another machine:

```bash
curl https://example.org/idlefish/my-node.json
```

## Run collection periodically

Use cron, a systemd timer, another init system, or your existing automation to refresh the JSON every few minutes.

### Example: cron

Install the metrics script somewhere stable:

```bash
sudo install -m 0755 scripts/collect-local-metrics.sh /usr/local/bin/collect-local-metrics.sh
sudo mkdir -p /var/www/idlefish
```

Edit root's crontab:

```bash
sudo crontab -e
```

Add:

```cron
*/15 * * * * IDLEFISH_NODE_NAME=my-node /usr/local/bin/collect-local-metrics.sh > /var/www/idlefish/my-node.json.tmp && mv /var/www/idlefish/my-node.json.tmp /var/www/idlefish/my-node.json
```

The temporary file plus `mv` keeps readers from seeing a half-written JSON file.

### Example: systemd timer

Install the script and timer units:

```bash
sudo install -m 0755 scripts/collect-local-metrics.sh /usr/local/bin/collect-local-metrics.sh
sudo install -m 0644 systemd/idlefish-metrics.service /etc/systemd/system/idlefish-metrics.service
sudo install -m 0644 systemd/idlefish-metrics.timer /etc/systemd/system/idlefish-metrics.timer
```

Create an environment override:

```bash
sudo mkdir -p /etc/idlefish /var/www/idlefish
sudo tee /etc/idlefish/metrics.env >/dev/null <<'EOF'
IDLEFISH_NODE_NAME=my-node
IDLEFISH_METRICS_DIR=/var/www/idlefish
IDLEFISH_METRICS_FILE=my-node.json
EOF
```

Enable the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now idlefish-metrics.timer
systemctl list-timers idlefish-metrics.timer
```

Run it once immediately and inspect the output:

```bash
sudo systemctl start idlefish-metrics.service
cat /var/www/idlefish/my-node.json
```

## Example: expose the JSON with Caddy

This example exposes only files under `/idlefish/*` from `/var/www`. Replace `metrics.example.org` with a domain that points at the VPS.

```caddyfile
metrics.example.org {
  encode zstd gzip

  @idlefish path /idlefish/*
  handle @idlefish {
    root * /var/www
    file_server
    header {
      Access-Control-Allow-Origin "*"
      Referrer-Policy "no-referrer"
      X-Content-Type-Options "nosniff"
    }
  }

  respond "not found" 404
}
```

With the file at `/var/www/idlefish/my-node.json`, the public URL is:

```text
https://metrics.example.org/idlefish/my-node.json
```

Reload Caddy:

```bash
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Check from outside the VPS:

```bash
curl https://metrics.example.org/idlefish/my-node.json
```

If you use nginx, Apache, OpenBSD httpd, a static object store, a tunnel, or an existing reverse proxy, the goal is the same: make exactly one low-sensitivity JSON file reachable by HTTPS.

## Add the node to the dashboard

A maintainer adds the public URL to `config/nodes.json`:

```json
[
  {
    "node_name": "my-node",
    "public_label": "My VPS",
    "metrics_url": "https://example.org/idlefish/my-node.json"
  }
]
```

The scheduled GitHub Actions workflow will fetch it and update the dashboard.

## Privacy checklist

- Use a pseudonymous `node_name`.
- Do not publish the server hostname if that is sensitive.
- Do not expose fishnet keys.
- Do not publish IP addresses in the JSON.
- Keep the endpoint read-only.
