# Alloy Light – Home Assistant add-on repository

[![Lint & test](https://github.com/gianlucasullazzo/AlloyLight/actions/workflows/lint.yaml/badge.svg)](https://github.com/gianlucasullazzo/AlloyLight/actions/workflows/lint.yaml)
[![Build & publish](https://github.com/gianlucasullazzo/AlloyLight/actions/workflows/build.yaml/badge.svg)](https://github.com/gianlucasullazzo/AlloyLight/actions/workflows/build.yaml)

Home Assistant add-on repository containing **Alloy Light**: a small,
resource-capped [Grafana Alloy](https://grafana.com/docs/alloy/) that ships the
Home Assistant OS journal to a Loki push endpoint.

[![Add repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fgianlucasullazzo%2FAlloyLight)

## Add-ons

| Add-on | Description |
|---|---|
| [Alloy Light](alloy_light/) | HAOS journal → Loki, with limited history, persistent read position, filters, rate limit and memory cap |

## Installation

1. *Settings → Add-ons → Add-on Store → ⋮ → Repositories*.
2. Add `https://github.com/gianlucasullazzo/AlloyLight`.
3. Install **Alloy Light**, set `loki_url`, start it.

Pre-built images (`aarch64`, `amd64`) are published to GHCR as
`ghcr.io/gianlucasullazzo/{arch}-addon-alloy-light`, so nothing is compiled on
the device.

## Development

```
alloy_light/
├── config.yaml                       # add-on manifest, options + schema
├── build.yaml / Dockerfile           # image (grafana/alloy + jq)
└── rootfs/
    ├── etc/alloy/config.alloy        # pipeline; reads /data/options.json at runtime
    ├── etc/alloy/write/*.alloy       # loki.write with / without basic auth
    └── usr/local/bin/run.sh          # entrypoint: GOMEMLIMIT, log level, auth variant
tests/
├── e2e.sh                            # end-to-end test (synthetic journal → receiver)
├── make_journal.py                   # synthetic journal entries
├── receiver.alloy                    # loki.source.api → loki.echo
└── options.json                      # test options
```

Run the end-to-end test locally (needs Docker):

```bash
docker build -t alloy-light:dev --build-arg BUILD_ARCH=amd64 --build-arg BUILD_VERSION=dev alloy_light
tests/e2e.sh alloy-light:dev
```

### Releasing

1. Bump `version` in `alloy_light/config.yaml` and add an entry to
   `alloy_light/CHANGELOG.md`.
2. Merge to `main` – the *Build & publish* workflow pushes
   `ghcr.io/<owner>/{arch}-addon-alloy-light:<version>`.
3. Optionally tag `v<version>` (the workflow checks the tag matches
   `config.yaml`).

### Updating Alloy

The Alloy version is pinned in `alloy_light/Dockerfile` (`BUILD_FROM`) and
`alloy_light/build.yaml`; CI fails if they differ. Bump both, run the e2e test,
release a new add-on version.

## License

MIT
