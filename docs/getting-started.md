# Getting started

This guide helps a Sanca Hackerspace member run the official fishnet client with conservative defaults.

## Request a fishnet key

Fishnet requires a personal key from Lichess. Follow the current instructions from the official fishnet project or Lichess fishnet page to request access.

Treat the key like a password:

- do not commit it
- do not paste it into issues
- do not publish it in dashboard data
- do not share it between members unless Lichess explicitly allows that

## Install the fishnet binary

Download or build the official fishnet binary from the official fishnet project. This repository does not provide a fishnet implementation.

After you have a local binary, install it:

```bash
sudo scripts/install-fishnet-systemd.sh ./fishnet
```

You may also pass a download URL:

```bash
sudo scripts/install-fishnet-systemd.sh https://example.invalid/path/to/fishnet
```

Use the real URL from the official project, not the placeholder above.

## Configure fishnet

Run configure manually as the unprivileged `fishnet` user:

```bash
sudo -u fishnet -H /opt/fishnet/bin/fishnet configure
```

Start with 1 core on shared machines, desktops, small VPSes, and anything already running community services.

## Start the service

```bash
sudo systemctl enable --now fishnet
systemctl status fishnet
```

## Check logs

```bash
journalctl -u fishnet -f
```

## Stop or disable fishnet

Stop fishnet temporarily:

```bash
sudo systemctl stop fishnet
```

Disable it across reboots:

```bash
sudo systemctl disable fishnet
```

Uninstall the systemd service and installed binary:

```bash
sudo scripts/uninstall-fishnet-systemd.sh
```
