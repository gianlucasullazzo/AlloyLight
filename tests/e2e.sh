#!/usr/bin/env bash
# End-to-end test for the Alloy Light image.
#
#   tests/e2e.sh <image>
#
# Builds a synthetic journal (tests/make_journal.py + systemd-journal-remote),
# runs the add-on image against it with a test Alloy receiver
# (loki.source.api -> loki.echo) and checks:
#   * every component is healthy;
#   * exactly the expected lines arrive, with the expected labels;
#   * a restart does not re-ship anything (persistent position in /data/alloy);
#   * drop_debug=false / empty drop_patterns / basic auth variants work.
set -euo pipefail

IMAGE="${1:?usage: $0 <image>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
NET="alloy-light-e2e-$$"
RX="alloy-light-rx-$$"
AL="alloy-light-al-$$"

# Containers run as root and write root-owned files into bind mounts; on a
# non-root host (GitHub runners) remove them from inside a container.
wipe() {
  docker run --rm -v "$(dirname "$1"):/p" ubuntu:24.04 rm -rf "/p/$(basename "$1")" >/dev/null 2>&1 || true
  rm -rf "$1" 2>/dev/null || true
}

cleanup() {
  docker rm -f "$AL" "$RX" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  wipe "$WORK"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; echo "--- add-on logs"; docker logs "$AL" 2>&1 | tail -30 || true; exit 1; }

echo "==> building synthetic journal"
mkdir -p "$WORK/journal"
python3 "$HERE/make_journal.py" > "$WORK/export.txt"
docker run --rm -v "$WORK:/w" ubuntu:24.04 sh -c '
  apt-get update -qq >/dev/null &&
  apt-get install -y -qq --no-install-recommends systemd-journal-remote >/dev/null 2>&1 &&
  /lib/systemd/systemd-journal-remote --output=/w/journal/test.journal /w/export.txt &&
  chmod -R a+rX /w/journal'

docker network create "$NET" >/dev/null
# start_rx : (re)create the test receiver with an empty log
start_rx() {
  docker rm -f "$RX" >/dev/null 2>&1 || true
  docker run -d --name "$RX" --network "$NET" \
    -v "$HERE/receiver.alloy:/r.alloy:ro" --entrypoint /bin/alloy "$IMAGE" \
    run /r.alloy --server.http.listen-addr=0.0.0.0:12346 --disable-reporting >/dev/null
  sleep 3
}

received() { docker logs "$RX" 2>&1 | grep 'msg="received log entry"' || true; }

# start_addon <options.json> : fresh /data, start the add-on container
start_addon() {
  docker rm -f "$AL" >/dev/null 2>&1 || true
  wipe "$WORK/data"; mkdir -p "$WORK/data"
  sed "s#127.0.0.1:3500#$RX:3500#" "$1" > "$WORK/data/options.json"
  docker run -d --name "$AL" --network "$NET" -p 127.0.0.1::12345 \
    -v "$WORK/data:/data" -v "$WORK/journal:/var/log/journal:ro" "$IMAGE" >/dev/null
}

wait_healthy() {
  local states
  for _ in $(seq 1 30); do
    states="$(curl -sf "http://$(docker port "$AL" 12345/tcp | head -1)/api/v0/web/components" 2>/dev/null || true)"
    if [ -n "$states" ] && echo "$states" | jq -e 'length > 0 and all(.[]; .health.state == "healthy")' >/dev/null; then
      echo "$states" | jq -r '.[] | "    \(.localID): \(.health.state)"'
      return 0
    fi
    sleep 1
  done
  echo "$states" | jq . 2>/dev/null || true
  fail "components not healthy"
}

# wait_count <n> : wait until the receiver has seen n entries, then a bit more
wait_count() {
  for _ in $(seq 1 30); do
    [ "$(received | wc -l)" -ge "$1" ] && break
    sleep 1
  done
  sleep 7  # > batch_wait, catch anything unexpected
}

expect_lines() {
  local got; got="$(received | sed -n 's/.* entry="\([^"]*\)".*/\1/p' | sort)"
  local want; want="$(printf '%s\n' "$@" | sort)"
  if [ "$got" != "$want" ]; then
    echo "expected:"; echo "$want"; echo "got:"; echo "$got"
    fail "unexpected set of shipped lines"
  fi
}

KEEP=("E2E keep supervisor info" "E2E keep core error" "E2E keep host line")

echo "==> [1] default options"
start_rx
start_addon "$HERE/options.json"
wait_healthy
wait_count 3
expect_lines "${KEEP[@]}"
grep -qF 'labels="{container_name=\"homeassistant\", hostname=\"homeassistant\", instance=\"homeassistant\", job=\"systemd-journal\", level=\"error\", syslog_identifier=\"homeassistant\", unit=\"docker.service\"}"' <<<"$(received)" \
  || fail "labels do not match"
[ -d "$WORK/data/alloy" ] || fail "/data/alloy not created"
echo "    ok: 3 lines, labels ok"

echo "==> [2] restart keeps position (no re-read)"
docker restart "$AL" >/dev/null
wait_healthy
sleep 8
[ "$(received | wc -l)" -eq 3 ] || fail "lines re-shipped after restart ($(received | wc -l))"
echo "    ok: nothing re-shipped"

echo "==> [3] drop_debug=false, drop_patterns=[]"
start_rx
jq '.drop_debug=false | .drop_patterns=[]' "$HERE/options.json" > "$WORK/opts3.json"
start_addon "$WORK/opts3.json"
wait_healthy
wait_count 6
expect_lines "${KEEP[@]}" "E2E drop debug line" \
  "E2E Request secret samba_password noise" "E2E Unknown option 'desc' for Network UPS Tools"
echo "    ok: debug and pattern lines pass through when filters are off"

echo "==> [4] basic auth variant"
start_rx
jq '.loki_username="user" | .loki_password="secret" | .log_level="info" | .memory_limit_mib=128' \
  "$HERE/options.json" > "$WORK/opts4.json"
start_addon "$WORK/opts4.json"
wait_healthy
wait_count 3
expect_lines "${KEEP[@]}"
grep -qF 'GOMEMLIMIT=128MiB GOGC=50 log_level=info auth=basic' <<<"$(docker logs "$AL" 2>&1)" \
  || fail "entrypoint did not apply memory_limit_mib/log_level/auth"
docker exec "$AL" grep -q basic_auth /tmp/alloy-config/write.alloy || fail "basic_auth config not selected"
echo "    ok: basic auth config selected, GOMEMLIMIT=128MiB"

echo "==> all e2e checks passed"
