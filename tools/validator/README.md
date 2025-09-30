# Telemetry Health Validator

Simple helper to confirm telemetry payloads expose the required `health` block. Usage:

```powershell
python telemetry_health_validator.py payload.json
# or stream directly
type payload.json | python telemetry_health_validator.py
```

The script checks:
- `health.uptime_ms`, `health.last_seen_ms`, `health.telemetry_count`, `health.mqtt_retries` exist and are non-negative integers.
- Optional `health.rssi` stays within -120..0 dBm when present.

Exit code is non-zero when validation fails so the tool can be chained in CI or local scripts.
