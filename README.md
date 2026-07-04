# idlefish

Hackerspace idle CPU for the free chess commons.

`idlefish` is a small Sanca Hackerspace project for donating spare CPU time to Lichess analysis through fishnet, the volunteer compute client used by Lichess.

The project helps members run fishnet carefully on desktops, homelab machines, and small VPSes, then publish simple community metrics such as uptime, active nodes, and estimated CPU-hours donated.

The dashboard uses a pull model: each participating machine publishes a small read-only JSON metrics file, and GitHub Actions periodically fetches those files to rebuild the public page. Contributors do not need GitHub push access, and they can adapt the publishing setup to their own Linux environment.

It is not a fishnet replacement and it is not affiliated with Lichess.

## Why this exists

Hackerspaces often have machines that sit idle for long stretches of time. When it is safe to do so, those machines can contribute useful Stockfish analysis capacity to the free chess community.

The goal is not to maximize numbers at any cost. The goal is to make spare compute donation visible, responsible, and easy to turn off.

## Safety first

Fishnet can use a lot of CPU.

On shared machines, small VPSes, or hosts already running services like MQTT, Grafana, Postgres, or TimescaleDB, start with 1 core and watch the machine for load, memory pressure, swap, and service slowdowns.

Fishnet keys are personal secrets. Never commit them, publish them in dashboard data, or paste them into issues or chat.

## What the dashboard shows

The public dashboard shows local community metrics:

- estimated CPU-hours donated
- active fishnet nodes
- fishnet service health
- service restarts
- load average and available memory

CPU-hours are local estimates from service/runtime data. They are not official Lichess contribution stats.

## Join with a machine

1. Request a fishnet key from Lichess.
2. Clone this project on the machine:

   ```bash
   git clone https://github.com/sancahs/idlefish.git
   cd idlefish
   ```

3. Download or build the fishnet binary from the [official fishnet releases](https://github.com/lichess-org/fishnet/releases), saving it as `./fishnet` inside this directory.

4. Install the conservative systemd service, or adapt the service setup to your environment:

   ```bash
   sudo scripts/install-fishnet-systemd.sh ./fishnet
   ```

5. Configure fishnet manually:

   ```bash
   sudo -u fishnet -H sh -lc 'cd /var/lib/fishnet && /opt/fishnet/bin/fishnet configure'
   ```

6. Start the service:

   ```bash
   sudo systemctl enable --now fishnet
   journalctl -u fishnet -f
   ```

7. Collect local metrics:

   ```bash
   IDLEFISH_NODE_NAME=my-node scripts/collect-local-metrics.sh > /var/www/idlefish/my-node.json
   ```

8. Ask a maintainer to add your public metrics URL to `config/nodes.json`.

More detailed setup notes are in [docs/getting-started.md](docs/getting-started.md), [docs/running-on-small-vps.md](docs/running-on-small-vps.md), and [docs/publishing-node-metrics.md](docs/publishing-node-metrics.md).

The v0 pull-based dashboard architecture is described in [docs/architecture-v0.md](docs/architecture-v0.md).

## Publish the dashboard

Generate the static dashboard data:

```bash
python3 scripts/fetch-node-metrics.py
python3 scripts/generate-site.py
```

Preview locally:

```bash
python3 -m http.server -d site 8000
```

Then open:

```text
http://localhost:8000
```

GitHub Pages publishes the `site/` directory using the workflow in [.github/workflows/pages.yml](.github/workflows/pages.yml). The workflow also runs on a schedule, fetches every URL listed in `config/nodes.json`, and rebuilds the dashboard without requiring node operators to commit anything.

## Project boundaries

This project helps people run and monitor fishnet responsibly.

It does not:

- implement a fishnet client
- reverse-engineer Lichess
- scrape private Lichess data
- store fishnet keys
- claim official contribution stats

## License

MIT. See [LICENSE](LICENSE).
