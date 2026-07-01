# Security

## Secrets

Fishnet keys are personal secrets. Never commit them, publish them in dashboard data, or include them in issues.

Configure fishnet manually on each node:

```bash
sudo -u fishnet -H /opt/fishnet/bin/fishnet configure
```

## Reporting a security issue

If you find a problem that could expose fishnet keys, hostnames, IP addresses, or private member data, please report it privately to the repository maintainers or Sanca Hackerspace organizers before opening a public issue.

## Data minimization

The included metrics scripts are designed to collect only local service health and coarse host metrics. They do not collect IP addresses, fishnet keys, chess account names, or private Lichess data.
