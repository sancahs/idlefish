# idlefish

Hackerspace idle CPU for the free chess commons.

`idlefish` is a small community helper project for Sanca Hackerspace members who want to donate spare CPU cycles to Lichess using the official fishnet client. It provides conservative systemd examples, local metrics scripts, and a lightweight static dashboard that can be published with GitHub Pages.

This project does not replace fishnet. It helps people install, run, monitor, and explain the official fishnet client responsibly.

## What Lichess fishnet is

Lichess fishnet is the official distributed analysis client used by Lichess to run Stockfish analysis for the free chess community. Volunteers run fishnet on their own machines and donate compute capacity.

`idlefish` is unofficial. It is not affiliated with Lichess, and it does not use Lichess branding in a way that suggests endorsement.

## Why donate idle CPU

A hackerspace often has Linux desktops, homelab machines, or small VPSes that are idle for many hours. Donating a small, controlled amount of spare CPU can support free chess analysis while giving members a transparent way to see local uptime, service health, and estimated CPU-hours donated.

The goal is responsible civic compute, not competition. Keep machines useful for their primary jobs first.

## Important safety notes

Fishnet can use significant CPU. On shared desktops, tiny VPSes, and machines already running services such as MQTT, Grafana, Postgres, TimescaleDB, or community dashboards, start with 1 core and watch system load.

Fishnet keys are personal secrets. Never commit a fishnet key to this repository, a dashboard, a paste, an issue, or a chat log. Run `fishnet configure` manually as the unprivileged `fishnet` user on each machine.

## Quick start for members

1. Request a fishnet key from Lichess. See [docs/getting-started.md](docs/getting-started.md).
2. Download or build the official fishnet binary.
3. Install the conservative service:

   ```bash
   sudo scripts/install-fishnet-systemd.sh ./fishnet
   ```

   You can also pass a download URL instead of a local path.

4. Configure fishnet manually as the `fishnet` user:

   ```bash
   sudo -u fishnet -H /opt/fishnet/bin/fishnet configure
   ```

5. Start and inspect the service:

   ```bash
   sudo systemctl enable --now fishnet
   systemctl status fishnet
   journalctl -u fishnet -f
   ```

6. Collect local metrics:

   ```bash
   IDLEFISH_NODE_NAME=my-node scripts/collect-local-metrics.sh > metrics/nodes/my-node.json
   ```

7. Generate the static dashboard data:

   ```bash
   python3 scripts/generate-site.py
   python3 -m http.server -d site 8000
   ```

Open <http://localhost:8000>.

## Quick start for maintainers

The public page is static and can be published by GitHub Pages without secrets.

1. Put node metric JSON files in `metrics/nodes/`.
2. Optionally fetch the global public Lichess fishnet status:

   ```bash
   python3 scripts/fetch-lichess-fishnet-status.py metrics/global-status.json
   ```

3. Generate dashboard data:

   ```bash
   python3 scripts/generate-site.py
   ```

4. Commit `site/` updates and push. The workflow in `.github/workflows/pages.yml` publishes `site/`.

## Feel-good metrics

`idlefish` focuses on honest local metrics:

- donated CPU-hours, estimated from local service/runtime data
- fishnet service uptime
- number of participating nodes
- estimated daily CPU-hours when node data includes enough timestamps
- global Lichess fishnet queue status from the public status endpoint

These are local community metrics. They are not official Lichess contribution stats.

## Why not show exact games analyzed

`idlefish` does not claim exact "games analyzed" by default because that would be easy to overstate. Unless official fishnet logs clearly and reliably expose that information on a local node, the dashboard sticks to CPU-hours donated and service health. CPU-hours are understandable, local, and honest: they describe compute capacity offered, not guaranteed completed work.

## Boundaries

- Do not implement a fake fishnet client.
- Do not reverse-engineer Lichess.
- Do not scrape private Lichess data.
- Do not expose fishnet API keys.
- Do not claim exact games analyzed unless fishnet logs clearly provide that information.
- Treat CPU-hours donated as the primary local metric.

## License

MIT. See [LICENSE](LICENSE).
