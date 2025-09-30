# 15C_telemetry_health – Changelog
- Added `HealthService` to track uptime, last publish, MQTT retries, and RSSI snapshots.
- Telemetry loop now emits a `health` object and updates provisioning discovery metadata.
- Mock publisher mirrors the new schema; validator script checks payload health in CI.
