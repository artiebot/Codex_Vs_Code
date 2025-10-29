# Validation A1.4b – OTA Rehearsal Acceptance Criteria

| AC | Description | Artifact |
| --- | --- | --- |
| 1 | Stage cadence profile `cfg-10s-12g-blink` via `tools/ota_stage.sh` and confirm OTA server returns `ok: true`. | `REPORTS/A1.4b/cfg-10s-12g-blink.json` |
| 2 | Stage weight threshold profile `cfg-30s-18g-solid` for the same device and confirm the server persists the payload. | `REPORTS/A1.4b/cfg-30s-18g-solid.json` |
| 3 | Stage LED override `cfg-5s-10g-off` and verify the OTA server stores the file with the requested `versionTag`. | `REPORTS/A1.4b/cfg-5s-10g-off.json` |
| 4 | Apply one of the staged configs on-device and capture telemetry showing the reported firmware version and config `versionTag` immediately after apply. | `REPORTS/A1.4b/telemetry_version_tag.log` |

Document command outputs alongside each artifact in the playbook when closing the validation run.
