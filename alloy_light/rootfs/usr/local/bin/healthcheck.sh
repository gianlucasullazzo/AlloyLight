#!/bin/bash
# Docker HEALTHCHECK: healthy when Alloy's /-/ready endpoint answers 200.
# The image has no curl/wget, so use bash's /dev/tcp.
set -eu
exec 3<>/dev/tcp/127.0.0.1/12345
printf 'GET /-/ready HTTP/1.0\r\nHost: localhost\r\n\r\n' >&3
IFS= read -r status <&3
case "$status" in
  "HTTP/1."?" 200"*) exit 0 ;;
  *) echo "not ready: $status"; exit 1 ;;
esac
