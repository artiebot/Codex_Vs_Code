## [15D_ota_safe_staging] - 2025-09-28
- OTA manager now stages firmware with SHA-256 verification, SemVer gating, and MQTT status events.
- Boot health watchdog persists last-good/pending firmware and triggers rollbacks after two failed boots.
- Added OTA admin CLI helper plus JSON schema documenting the OTA command contract.
## [15C_telemetry_health] - 2025-09-24\n- Telemetry service now emits a health block with uptime, last seen, retry counts, and RSSI.\n- New HealthService tracks metrics and discovery advertises the health capability for clients.\n- Consolidated firmware modules (MQTT, sensor drivers, LED/visit services) into the root tree for production builds.\n- Validator script and mock publisher updates keep tooling aligned with the telemetry contract.\n
## [15B_ota_stub] - 2025-09-21
- OTA service now listens on cmd/ota and emits deterministic progress + CRC events on event/ota.
- Discovery metadata and topics advertise the new OTA capability for device provisioning.
- Mock publisher adds OTA simulation with unit tests for the 0/25/50/75/100 sequence.
- Step docs refreshed with validation commands and tooling instructions.
- OTA handler + mock now tolerate UTF-8 BOM payloads, emit explicit error events, and re-subscribe after MQTT reconnects.

