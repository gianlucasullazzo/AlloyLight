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
    # Core / Supervisor: Docker logs stderr with priority 3, real level is in the text
    (8_900_000, 3, "docker.service", "homeassistant", "homeassistant",
     "2026-11-13 13:03:50.998+01:00 WARNING (MainThread) [x] E2E ha warning"),
    (8_800_000, 3, "docker.service", "homeassistant", "homeassistant",
     "2026-11-13 13:03:50.998+01:00 ERROR (MainThread) [x] E2E ha error"),
    (8_700_000, 3, "docker.service", "homeassistant", "homeassistant",
     "2026-11-13 13:03:50.998+01:00 CRITICAL (MainThread) [x] E2E ha critical"),
    (8_600_000, 3, "docker.service", "homeassistant", "homeassistant",
     "2026-11-13 13:03:50.998+01:00 DEBUG (MainThread) [x] E2E ha debug"),
    (8_550_000, 3, "docker.service", "homeassistant", "homeassistant",
     "2026-11-13 13:03:50.998+01:00 INFO (SyncWorker_3) [x] E2E ha info"),
    (8_500_000, 3, "docker.service", "homeassistant", "homeassistant",
     "Traceback (most recent call last): E2E ha traceback"),
    # Supervisor output carries ANSI colour codes
    (8_400_000, 3, "docker.service", "hassio_supervisor", "hassio_supervisor",
     "\x1b[32m2026-11-13 13:03:50.998 INFO (MainThread) [supervisor.x] E2E supervisor info\x1b[0m"),
    # Other containers are not re-levelled even if the text looks the same
    (8_300_000, 3, "docker.service", "zigbee", "addon_x_zigbee2mqtt",
     "2026-11-13 13:03:50.998+01:00 WARNING (MainThread) [x] E2E other container"),
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
