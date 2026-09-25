#!/usr/bin/env python3
"""Bounded test telemetry. Never record process arguments, env, or raw errors."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

LIMIT = 16 * 1024 * 1024
UNITS = ["packetfence-" + name + ".service" for name in (
    "config", "mariadb", "pfperl-api", "iptables", "pfipset", "pfdns",
    "api-frontend", "radiusd-load_balancer", "httpd.portal",
)]
STATES = {"active", "inactive", "activating", "deactivating", "failed",
          "reloading", "maintenance", "refreshing"}


def read(path):
    try:
        return Path(path).read_text().splitlines()
    except (OSError, UnicodeError):
        return []


def sample(guest=False):
    result = {"time_unix": time.time()}
    for name in ("stat", "meminfo", "vmstat"):
        counters = {}
        for line in read("/proc/" + name):
            parts = line.replace(":", "").split()
            if name == "stat" and parts and not (
                re.fullmatch(r"cpu[0-9]*", parts[0])
                or parts[0] in ("ctxt", "btime", "processes", "procs_running", "procs_blocked")
            ):
                continue
            if len(parts) > 1 and re.fullmatch(r"[A-Za-z_0-9]+", parts[0]):
                values = parts[1:]
                if values[-1:] == ["kB"]:
                    values = values[:-1]
                if all(v.isdigit() for v in values):
                    counters[parts[0]] = [int(v) for v in values]
        result[name] = counters
    result["pressure"] = {}
    for resource in ("cpu", "memory", "io"):
        for line in read("/proc/pressure/" + resource):
            fields = line.split()
            if not fields or fields[0] not in ("some", "full"):
                continue
            result["pressure"][resource + "_" + fields[0]] = {
                key: float(value)
                for field in fields[1:] if "=" in field
                for key, value in [field.split("=", 1)]
                if key in ("avg10", "avg60", "avg300", "total")
                and re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", value)
            }
    # Key disks by numeric major:minor, never by a user-controlled device label.
    result["diskstats"] = {}
    for line in read("/proc/diskstats"):
        fields = line.split()
        if len(fields) >= 14 and all(v.isdigit() for v in fields[:2] + fields[3:]):
            result["diskstats"][":".join(fields[:2])] = [int(v) for v in fields[3:]]
    if guest:
        try:
            status = subprocess.run(
                ["systemctl", "show", "--property=Id,ActiveState,Job"] + UNITS,
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                timeout=3, universal_newlines=True, check=False,
            )
            result["units"] = {}
            for block in status.stdout.split("\n\n"):
                properties = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
                unit = properties.get("Id")
                state = properties.get("ActiveState")
                if unit in UNITS and state in STATES:
                    job = properties.get("Job", "").split(" ", 1)[0]
                    result["units"][unit] = {"state": state, "job_pending": job.isdigit() and int(job) != 0}
        except (OSError, subprocess.TimeoutExpired):
            result["unit_query_failed"] = True
    return result


def main():
    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    # Append across guest reboots, with a hard size and runtime bound.
    with output.open("a") as stream:
        os.chmod(str(output), 0o600)
        deadline = time.monotonic() + 6 * 3600
        while time.monotonic() < deadline:
            row = json.dumps(sample("--guest" in sys.argv), separators=(",", ":")) + "\n"
            if stream.tell() + len(row) > LIMIT:
                break
            stream.write(row)
            stream.flush()
            time.sleep(10)


if __name__ == "__main__":
    main()
