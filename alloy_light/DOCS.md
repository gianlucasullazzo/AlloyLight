# Alloy Light

Ships the Home Assistant OS systemd journal to a Loki push endpoint using a
small, resource-capped [Grafana Alloy](https://grafana.com/docs/alloy/).

```
HAOS journal ──► Alloy Light ──► Loki push endpoint (Loki, or another Alloy with loki.source.api)
```

## Installation

1. Add the repository `https://github.com/gianlucasullazzo/AlloyLight` to the
   Add-on Store.
2. Install **Alloy Light** (a pre-built image is pulled, nothing is compiled).
3. Set `loki_url` and start the add-on.

### Migrating from `ecohash-co/ha-addon-alloy`

The labels are the same, so existing Grafana queries keep working.

1. **Stop and uninstall the old add-on first**, or every line is shipped twice.
2. On the very first start Alloy Light ships up to `max_age` of history. If the
   old add-on already shipped those lines, set `max_age` to e.g. `5m` before
   the first start to avoid duplicates.

## Configuration

```yaml
loki_url: "http://192.168.2.126:3500/loki/api/v1/push"
max_age: "6h"
drop_debug: true
drop_patterns:
  - "Request secret (ssh|samba|mosquitto)_password"
  - "Unknown option '(desc|langid_fix)' for Network UPS Tools"
rate_limit: 50
rate_burst: 200
memory_limit_mib: 200
log_level: warn
```

| Option | Default | Description |
|---|---|---|
| `loki_url` | `http://192.168.2.126:3500/loki/api/v1/push` | Loki push endpoint (required). |
| `loki_username` | – | Optional basic auth user. When empty, no `Authorization` header is sent. |
| `loki_password` | – | Optional basic auth password, used only together with `loki_username`. |
| `max_age` | `6h` | History read when there is **no saved position** (first start). Format `<n>s`, `<n>m`, `<n>h`. |
| `drop_debug` | `true` | Discard entries with priority `debug`. |
| `drop_patterns` | see above | RE2 regular expressions; matching lines are discarded. An empty list disables this filter. |
| `rate_limit` | `50` | Lines per second sent to Loki; lines above the limit are **dropped**. |
| `rate_burst` | `200` | Burst allowed above `rate_limit`. |
| `memory_limit_mib` | `200` | Go soft memory limit (`GOMEMLIMIT`). `GOGC` is fixed at `50`. |
| `log_level` | `warn` | Alloy's own log level (`debug`, `info`, `warn`, `error`). Keep `warn`: Alloy's logs end up in the journal too. |

### Read position

The journal cursor is stored in `/data/alloy` (the add-on's private data
folder), so restarting or updating the add-on resumes where it stopped and does
not re-read the journal. `max_age` only matters when no position is saved,
i.e. on the first start or after a reinstall.

### Labels

| Label | Source |
|---|---|
| `job` | `systemd-journal` |
| `unit` | `_SYSTEMD_UNIT` |
| `hostname` | `_HOSTNAME` |
| `syslog_identifier` | `SYSLOG_IDENTIFIER` |
| `container_name` | `CONTAINER_NAME` |
| `level` | priority keyword (`emerg` … `debug`) |
| `instance` | `homeassistant` |

Example queries:

```logql
{job="systemd-journal", container_name="homeassistant"} |= "error"
{job="systemd-journal", level=~"error|crit|alert|emerg"}
```

### Filters

Applied in this order:

1. Logs of this add-on's own container
   (`container_name=~"(addon|app)_[a-z0-9]+_alloy_light"`) are always dropped,
   to avoid a feedback loop.
2. `level="debug"` lines, if `drop_debug` is on.
3. Lines matching any of `drop_patterns`.
4. Rate limit (`rate_limit` / `rate_burst`).

## Debug UI

Alloy's UI listens on port `12345` inside the container. It is **not exposed**
by default; to use it, set a host port under *Network* in the add-on
configuration and open `http://<home-assistant>:<port>/`. All components should
be *healthy*.

## Resources

- Memory: `GOMEMLIMIT` (default 200 MiB) and `GOGC=50` keep the heap small.
- Disk: only new journal entries are read; history is bounded by `max_age`.
- No privileged access: no host network, Docker API, Supervisor API or full
  access. The journal is mounted read-only by the Supervisor (`journald: true`).

## Troubleshooting

- **Nothing arrives in Loki**: set `log_level: info`, restart, and check the
  add-on log for `loki.write` errors (wrong URL, endpoint unreachable, 401).
- **Lines missing during bursts**: they were dropped by the rate limit; raise
  `rate_limit` / `rate_burst`.
- **Re-ship history**: uninstall and reinstall the add-on (this clears
  `/data/alloy`); the next start reads `max_age` of history again.
