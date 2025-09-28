#!/usr/bin/env python3
"""Validate SkyFeeder telemetry health payloads."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List

REQUIRED_FIELDS = {
    "uptime_ms": int,
    "last_seen_ms": int,
    "telemetry_count": int,
    "mqtt_retries": int,
}

RSSI_RANGE = (-120, 0)


def load_payload(source: str | None) -> Dict[str, Any]:
    if source and source != "-":
        # Try multiple encodings to handle Windows PowerShell output
        path = Path(source)
        for encoding in ["utf-8", "utf-16-le", "utf-16-be", "utf-8-sig"]:
            try:
                data = path.read_text(encoding=encoding)
                # Strip UTF-8 BOM if present
                if data.startswith('\ufeff'):
                    data = data[1:]
                break
            except UnicodeDecodeError:
                continue
        else:
            raise SystemExit(f"Could not decode file {source} with any supported encoding")
    else:
        data = sys.stdin.read()

    try:
        return json.loads(data)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON: {exc}") from exc


def validate_health(payload: Dict[str, Any]) -> List[str]:
    errors: List[str] = []
    health = payload.get("health")
    if not isinstance(health, dict):
        errors.append("Missing 'health' object")
        return errors

    for field, expected_type in REQUIRED_FIELDS.items():
        value = health.get(field)
        if not isinstance(value, expected_type):
            errors.append(f"health.{field} must be {expected_type.__name__}")
        elif isinstance(value, int) and value < 0:
            errors.append(f"health.{field} must be non-negative")

    rssi = health.get("rssi")
    if rssi is not None:
        if not isinstance(rssi, int):
            errors.append("health.rssi must be int when present")
        elif not (RSSI_RANGE[0] <= rssi <= RSSI_RANGE[1]):
            errors.append(
                f"health.rssi expected between {RSSI_RANGE[0]} and {RSSI_RANGE[1]} dBm, got {rssi}"
            )

    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "payload",
        nargs="?",
        help="Path to telemetry JSON payload (defaults to stdin)",
    )
    args = parser.parse_args()

    payload = load_payload(args.payload)
    errors = validate_health(payload)
    if errors:
        for err in errors:
            print(f"[FAIL] {err}")
        raise SystemExit(1)
    print("[OK] Telemetry health block is valid")


if __name__ == "__main__":
    main()
