# Home Assistant Add-on: Alloy Light

Lightweight, filtered shipper of the Home Assistant OS journal to Loki, based
on [Grafana Alloy](https://grafana.com/docs/alloy/).

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

- Reads the HAOS systemd journal (read-only).
- Limited history on first start (`max_age`), persistent read position
  afterwards – a restart never re-reads the journal.
- Drops its own logs, debug lines and configurable noise patterns.
- Rate limit and Go memory limit (`GOMEMLIMIT`) to keep the host safe.
- Same labels as `ecohash-co/ha-addon-alloy`: existing Grafana queries keep
  working.

See the **Documentation** tab for configuration.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
