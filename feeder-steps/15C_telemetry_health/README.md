# 15C � Telemetry Health Metrics

Adds a dedicated health block to every telemetry publish so backend/app code can track uptime, last activity, MQTT retry counts, and RSSI. Firmware exposes a lightweight `HealthService` that is wired into the telemetry loop, while tooling now ships with a validator to assert the payload contract.

## What Changed\n- New `HealthService` tracks uptime, last publish timestamp, telemetry count, retry tallies, and latest RSSI sample.\n- Telemetry loop now emits a `health` object alongside the existing power/weight data.\n- Root firmware tree now carries the full hardware stack (HX711, INA260, LED/visit services, command routing) so production builds no longer depend on per-step snapshots.
- Discovery advertises the upgraded milestone (`sf_step15C_telemetry_health`) and the additional `health` capability.
- `tools/validator/telemetry_health_validator.py` checks payloads locally or in CI.
- Mock publisher mirrors the contract by synthesizing the same health structure.

## Firmware Validation
1. Flash the firmware or run the mock publisher.
2. Subscribe to telemetry:
   ```powershell
   mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/telemetry" -v
   ```
3. Observe payloads � each should include:
   ```json
   {
     "health": {
       "uptime_ms": <non-negative>,
       "last_seen_ms": <increasing>,
       "telemetry_count": <monotonic>,
       "mqtt_retries": <non-negative>,
       "rssi": -62
     }
   }
   ```
4. Run the validator against a captured payload:
   ```powershell
   mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/telemetry" -C 1 > latest.json
   python tools/validator/telemetry_health_validator.py latest.json
   ```
   ? Output: `[OK] Telemetry health block is valid`

## Mock Publisher Regression
```powershell
cd tools/mock-publisher
python publisher.py --device-id sf-mock01 --dry-run | Select-String 'health'
```
Expect each generated telemetry payload to include the `health` object with plausible values.

## Troubleshooting
- **Validator fails � missing keys**: ensure the firmware image was rebuilt after pulling this step. The OTA stub (15B) does not include health metrics.
- **`last_seen_ms` stuck at 0**: confirm the telemetry loop is running (device must be provisioned and MQTT connected).
- **RSSI absent**: RSSI is reported only when Wi-Fi is connected or a recent sample exists; check network status.

Continue with [16A � Security Hardening (Backend slice)](../16A_security_backend/README.md) after validating this step.
