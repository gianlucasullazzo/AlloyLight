# Changelog

All notable changes to this add-on are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the add-on uses
[SemVer](https://semver.org/).

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
