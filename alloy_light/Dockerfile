# Keep ALLOY_VERSION in sync with build.yaml and .github/workflows/lint.yaml.
ARG BUILD_FROM=grafana/alloy:v1.21.3
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

# jq is the only extra dependency: used by run.sh to read process-level options.
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

ENV GOMEMLIMIT=200MiB \
    GOGC=50

COPY rootfs/ /
RUN chmod 0755 /usr/local/bin/run.sh /usr/local/bin/healthcheck.sh

LABEL \
    io.hass.name="Alloy Light" \
    io.hass.description="HAOS journal to Loki, lightweight and filtered" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/gianlucasullazzo/AlloyLight" \
    org.opencontainers.image.licenses="MIT"

EXPOSE 12345
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]
ENTRYPOINT ["/usr/local/bin/run.sh"]
CMD []
