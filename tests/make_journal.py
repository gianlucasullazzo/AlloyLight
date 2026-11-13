#!/usr/bin/env python3
"""Emit systemd journal *export format* test entries on stdout.

Pipe into `systemd-journal-remote --output=<file>.journal -` to build a
journal file for the end-to-end test.
"""
import sys, time, uuid

boot = uuid.uuid4().hex
now = int(time.time() * 1_000_000)
HOUR = 3600 * 1_000_000

# (age_us, priority, unit, ident, container, message)
ENTRIES = [
    (48 * HOUR, 6, "old.service", "old", None, "E2E old entry beyond max_age"),
    (10_000_000, 6, "docker.service", "hassio_supervisor", "hassio_supervisor", "E2E keep supervisor info"),
    (9_000_000, 3, "docker.service", "homeassistant", "homeassistant", "E2E keep core error"),
    (8_000_000, 7, "docker.service", "homeassistant", "homeassistant", "E2E drop debug line"),
    (7_000_000, 6, "docker.service", "alloy", "addon_abcd1234_alloy_light", "E2E drop self addon"),
    (6_000_000, 6, "docker.service", "alloy", "app_abcd1234_alloy_light", "E2E drop self app"),
    (5_000_000, 6, "docker.service", "hassio_supervisor", "hassio_supervisor", "E2E Request secret samba_password noise"),
    (4_000_000, 4, "docker.service", "nut", "addon_x_nut", "E2E Unknown option 'desc' for Network UPS Tools"),
    (3_000_000, 6, "systemd-journald.service", "systemd-journald", None, "E2E keep host line"),
]

out = sys.stdout.buffer
for i, (age, prio, unit, ident, cont, msg) in enumerate(ENTRIES):
    ts = now - age
    fields = {
        "__CURSOR": f"s=e2e;i={i}",
        "__REALTIME_TIMESTAMP": str(ts),
        "__MONOTONIC_TIMESTAMP": str(ts),
        "_BOOT_ID": boot,
        "_HOSTNAME": "homeassistant",
        "_SYSTEMD_UNIT": unit,
        "SYSLOG_IDENTIFIER": ident,
        "PRIORITY": str(prio),
        "MESSAGE": msg,
    }
    if cont:
        fields["CONTAINER_NAME"] = cont
    for k, v in fields.items():
        out.write(f"{k}={v}\n".encode())
    out.write(b"\n")
