# Contributing

Thanks for helping keep `idlefish` useful and boring in the best way.

## Project boundaries

Contributions should help people run and monitor the official fishnet client. Please do not add code that impersonates fishnet, reverse-engineers Lichess, scrapes private data, or handles fishnet keys in the dashboard.

## Development style

- Prefer Bash, Python 3 standard library, and plain static HTML/CSS/JS.
- Keep scripts readable and conservative.
- Avoid build steps and external CDNs.
- Document operational risks clearly.
- Treat CPU-hours as an estimate.

## Testing changes

Before opening a pull request, try:

```bash
shellcheck scripts/*.sh
python3 -m py_compile scripts/*.py
python3 scripts/generate-site.py
python3 -m http.server -d site 8000
```

`shellcheck` is optional if it is not installed, but please run it when available.
