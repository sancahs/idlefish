# Grafana and Prometheus ideas

These are optional future ideas. `idlefish` does not need Prometheus, Grafana, or TimescaleDB to work.

## Possible future integrations

- node_exporter textfile collector output for fishnet service health
- Prometheus scrape target for local idlefish metrics
- Grafana dashboard JSON for hackerspace infrastructure screens
- TimescaleDB storage for long-term CPU-hour trends

## Possible Grafana panels

- fishnet service up/down
- CPU-hours donated
- active nodes
- Lichess global queue
- host load impact

Keep this optional. The default project should stay simple: Bash, Python 3, and static files.
