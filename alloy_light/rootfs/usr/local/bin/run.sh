#!/bin/sh
# Alloy Light entrypoint.
#
# Alloy reads most options straight from /data/options.json (see
# /etc/alloy/config.alloy). This wrapper only handles what Alloy cannot do from
# its own config: GOMEMLIMIT (must be set before the Go runtime starts), the
# log level, and choosing the loki.write variant with or without basic auth.
set -eu

OPTIONS="${ALLOY_OPTIONS_FILE:-/data/options.json}"
CONFIG_SRC="${ALLOY_CONFIG_SRC:-/etc/alloy}"
CONFIG_DIR="${ALLOY_CONFIG_DIR:-/tmp/alloy-config}"
STORAGE="${ALLOY_STORAGE_PATH:-/data/alloy}"

if [ ! -r "$OPTIONS" ]; then
  echo "[alloy-light] ERROR: options file $OPTIONS not readable" >&2
  exit 1
fi

opt() { jq -r --arg k "$1" '.[$k] // empty' "$OPTIONS"; }

mem="$(opt memory_limit_mib)"
level="$(opt log_level)"
user="$(opt loki_username)"

export GOMEMLIMIT="${mem:-200}MiB"
export GOGC="${GOGC:-50}"
export ALLOY_LOG_LEVEL="${level:-warn}"
export ALLOY_OPTIONS_FILE="$OPTIONS"
export ALLOY_JOURNAL_PATH="${ALLOY_JOURNAL_PATH:-/var/log/journal}"

rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR" "$STORAGE"
cp "$CONFIG_SRC/config.alloy" "$CONFIG_DIR/config.alloy"
if [ -n "$user" ]; then
  cp "$CONFIG_SRC/write/basic_auth.alloy" "$CONFIG_DIR/write.alloy"
  auth="basic"
else
  cp "$CONFIG_SRC/write/noauth.alloy" "$CONFIG_DIR/write.alloy"
  auth="none"
fi

echo "[alloy-light] GOMEMLIMIT=$GOMEMLIMIT GOGC=$GOGC log_level=$ALLOY_LOG_LEVEL auth=$auth journal=$ALLOY_JOURNAL_PATH"

exec /bin/alloy run "$CONFIG_DIR" \
  --storage.path="$STORAGE" \
  --server.http.listen-addr="${ALLOY_LISTEN_ADDR:-0.0.0.0:12345}" \
  --disable-reporting \
  "$@"
