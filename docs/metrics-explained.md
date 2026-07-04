# Metrics explained

`idlefish` focuses on local, honest metrics that are easy to understand.

## CPU-hours

A CPU-hour is roughly one CPU core used for one hour. For example:

- 1 core for 10 hours is about 10 CPU-hours
- 2 cores for 10 hours is about 20 CPU-hours
- 4 cores for 1 hour is about 4 CPU-hours

Example phrasing:

> This node donated approximately 504 CPU-hours of Stockfish analysis capacity to the free chess commons.

## Why CPU-hours are an estimate

The local metrics script reads systemd's `CPUUsageNSec` value for the fishnet service when available. That is local service accounting from the machine, not an official Lichess counter.

Values may reset if the service, machine, or accounting state resets. Different Linux distributions may expose accounting differently.

## Why games analyzed is not shown by default

`idlefish` does not claim exact "games analyzed" unless official fishnet logs clearly and reliably expose that information locally. Guessing would be misleading because queue mix, analysis depth, hardware, and runtime conditions vary.

CPU-hours are the primary feel-good metric because they describe donated capacity without pretending to know more than the local node knows.

## Contribution counters

The most human-readable contribution counters are:

- `fishnet_analysis_jobs_finished`: completed fishnet work items found in local logs
- `fishnet_positions`: chess positions processed by fishnet
- `fishnet_stockfish_nodes`: Stockfish search-tree nodes evaluated by the engine

`fishnet_stockfish_nodes` and `fishnet_batches` are kept in the JSON because fishnet reports them, but they are lower-level counters and are not shown prominently on the public dashboard.

## Fishnet log counters

When the local system journal is readable, `idlefish` also reports a few fishnet-derived counters from the current service run:

- `fishnet_analysis_jobs_finished`: count of completed fishnet jobs logged as Lichess game URLs
- `fishnet_batches`: latest cumulative fishnet batch count
- `fishnet_positions`: latest cumulative position count
- `fishnet_stockfish_nodes`: latest cumulative Stockfish search node count

These counters are best-effort local metrics. They may reset when the fishnet service restarts, and they are not official Lichess contribution stats. The public JSON intentionally reports only counts, not individual game IDs.

In this context, a Stockfish node is a search-tree node evaluated by the chess engine. It is not a contributor machine or VPS.

## Lifetime counters

`idlefish` keeps a small local state file so totals can survive fishnet restarts and machine reboots. By default, root-run collection stores it under `/var/lib/idlefish`; unprivileged collection stores it under `${XDG_STATE_HOME}` or `~/.local/state/idlefish`.

Lifetime fields include:

- `lifetime_estimated_cpu_hours`
- `lifetime_fishnet_analysis_jobs_finished`
- `lifetime_fishnet_batches`
- `lifetime_fishnet_positions`
- `lifetime_fishnet_stockfish_nodes`

The state path can be changed with `IDLEFISH_STATE_FILE` or `IDLEFISH_STATE_DIR`. These are still local estimates, not official Lichess contribution stats.

## Local metrics

Local metrics come from machines participating in this community dashboard:

- fishnet service active or inactive
- estimated CPU-hours
- restarts
- load average
- memory available
- last seen timestamp
