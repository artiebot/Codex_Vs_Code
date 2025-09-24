## [15B_ota_stub] - 2025-09-21
- OTA service now listens on cmd/ota and emits deterministic progress + CRC events on event/ota.
- Discovery metadata and topics advertise the new OTA capability for device provisioning.
- Mock publisher adds OTA simulation with unit tests for the 0/25/50/75/100 sequence.
- Step docs refreshed with validation commands and tooling instructions.
