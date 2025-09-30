# 15D OTA Safe Staging — Changelog
- Added staged OTA manager with SHA-256 verification, SemVer gating, and event-driven telemetry.
- Persisted `lastGoodFw` / `pendingFw` metadata and boot counters in NVS schema v1.
- Introduced boot health watchdog to trigger automatic rollbacks after failed boots or explicit health failure.
- Added PowerShell helper for publishing OTA commands and a JSON schema documenting the contract.