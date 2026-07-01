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

## Local metrics vs global Lichess queue status

Local metrics come from machines participating in this community dashboard:

- fishnet service active or inactive
- estimated CPU-hours
- restarts
- load average
- memory available
- last seen timestamp

Global Lichess fishnet queue status comes from the public Lichess status endpoint. It describes the global fishnet queue, not the hackerspace's private contribution.
