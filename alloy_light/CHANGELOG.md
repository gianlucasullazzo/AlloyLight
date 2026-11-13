# Changelog

All notable changes to this add-on are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the add-on uses
[SemVer](https://semver.org/).

## [1.0.1] - 2026-11-13

### Fixed

- `level` for Home Assistant Core (`homeassistant`) and Supervisor
  (`hassio_supervisor`) is now taken from the log text (`DEBUG`, `INFO`,
  `WARNING`, `ERROR`, `CRITICAL` → `debug`, `info`, `warning`, `error`,
  `crit`) instead of the journal priority, which Docker always sets to 3
  (`error`) for stderr. Queries by level now work for Core and Supervisor, and
  `drop_debug` now also drops Core debug lines. Lines without a level prefix
  (tracebacks, continuation lines) keep the journal level.

## [1.0.0] - 2026-11-13

### Added

- First release, based on Grafana Alloy `v1.21.3`.
- HAOS journal → Loki push with labels `job`, `unit`, `hostname`,
  `syslog_identifier`, `container_name`, `level`, `instance`.
- `max_age` for the first start; persistent read position in `/data/alloy`.
- Filters: own container, `drop_debug`, `drop_patterns`; `rate_limit` /
  `rate_burst`.
- Optional basic auth (`loki_username` / `loki_password`).
- `memory_limit_mib` (GOMEMLIMIT, default 200 MiB), `GOGC=50`, `log_level`.
- Optional debug UI on port 12345 (not exposed by default).
- Docker `HEALTHCHECK` on Alloy's `/-/ready` endpoint.
