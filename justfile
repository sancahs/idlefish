default:
    @just --list

refresh:
    python3 scripts/fetch-node-metrics.py
    python3 scripts/generate-site.py

serve port="8000":
    python3 -m http.server -d site {{port}}

preview port="8000":
    just refresh
    just serve {{port}}
