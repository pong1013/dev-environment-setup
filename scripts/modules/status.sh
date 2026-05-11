#!/usr/bin/env bash

print_env_status_table() {
  local env_name="$1"
  local compose_file="$2"
  local services_raw
  local ps_raw

  services_raw="$(compose_run "${env_name}" "${compose_file}" config --services || true)"
  ps_raw="$(compose_run "${env_name}" "${compose_file}" ps --format json || true)"

  ENV_NAME="${env_name}" SERVICES_RAW="${services_raw}" PS_RAW="${ps_raw}" python3 <<'PY'
import json
import os

env_name = os.environ.get("ENV_NAME", "")
services_raw = os.environ.get("SERVICES_RAW", "")
ps_raw = os.environ.get("PS_RAW", "")

services = [s.strip() for s in services_raw.splitlines() if s.strip()]
if not services:
    print(f"=== {env_name} ===")
    print("No services declared in compose file.\n")
    raise SystemExit(0)

containers = []
if ps_raw.strip():
    raw = ps_raw.strip()
    try:
        if raw.startswith("["):
            containers = json.loads(raw)
        else:
            containers = [json.loads(line) for line in raw.splitlines() if line.strip()]
    except Exception:
        containers = []

by_service = {}
for c in containers:
    service = c.get("Service", "").strip()
    if service:
        by_service[service] = c

def fmt_ports(published_ports):
    if not published_ports:
        return "-"
    parts = []
    for p in published_ports:
        target = p.get("TargetPort", "")
        published = p.get("PublishedPort", "")
        protocol = p.get("Protocol", "tcp")
        host_ip = p.get("HostIp", "0.0.0.0")
        if published and target:
            host_label = "localhost" if host_ip in ("0.0.0.0", "::") else host_ip
            parts.append(f"{host_label}:{published} -> container:{target}/{protocol}")
        elif target:
            parts.append(f"container:{target}/{protocol}")
    if not parts:
        return "-"
    seen = []
    for part in parts:
        if part not in seen:
            seen.append(part)
    return ", ".join(seen)

print(f"=== {env_name} ===")
rows = []
for service in services:
    c = by_service.get(service)
    if c is None:
        rows.append({
            "Service": service,
            "State": "not-created",
            "Ports": "-",
            "Container": "-",
            "Image": "-",
            "Command": "-",
        })
        continue

    rows.append({
        "Service": c.get("Service", "") or service,
        "State": c.get("State", "") or "-",
        "Ports": fmt_ports(c.get("Publishers") or []),
        "Container": c.get("Name", "") or "-",
        "Image": c.get("Image", "") or "-",
        "Command": c.get("Command", "") or "-",
    })

headers = ["Service", "State", "Ports", "Container", "Image"]
widths = {}
for h in headers:
    widths[h] = len(h)
for row in rows:
    for h in headers:
        widths[h] = max(widths[h], len(str(row[h])))

line = "  " + " | ".join(h.ljust(widths[h]) for h in headers)
sep = "  " + "-+-".join("-" * widths[h] for h in headers)

running_count = sum(1 for r in rows if r["State"] == "running")
print(f"Services: {len(rows)} total, {running_count} running")
print(line)
print(sep)
for row in rows:
    print("  " + " | ".join(str(row[h]).ljust(widths[h]) for h in headers))

print("")
PY
}
