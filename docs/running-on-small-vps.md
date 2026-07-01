# Running on a small VPS

Tiny VPSes are useful for community projects, but they often have limited CPU credits, memory, disk I/O, and swap. Fishnet can use CPU heavily, so start with 1 core and watch the machine.

## Recommended approach

- Start with 1 core.
- Keep the conservative systemd resource controls.
- Watch load average and memory for at least the first day.
- Stop fishnet quickly if the host becomes slow or swap-heavy.
- Prefer reliability of existing services over donated CPU.

Useful commands:

```bash
htop
free -h
uptime
vmstat 5
journalctl -u fishnet -f
systemctl stop fishnet
```

## Machines already running MQTT, Grafana, or TimescaleDB

If the VPS already runs MQTT, Grafana, Postgres, TimescaleDB, or a community dashboard, be extra conservative.

Watch for:

- MQTT reconnects or delayed messages
- Grafana dashboards becoming slow
- Postgres or TimescaleDB memory pressure
- high load average for long periods
- swap usage increasing
- disk I/O wait

If any important service degrades, stop fishnet:

```bash
sudo systemctl stop fishnet
```

Then either leave it disabled or lower fishnet's own core setting before starting again.

## Reading service health

```bash
systemctl status fishnet
journalctl -u fishnet -f
```

The idlefish metrics script reports local estimates only. It is not an official Lichess contribution counter.
