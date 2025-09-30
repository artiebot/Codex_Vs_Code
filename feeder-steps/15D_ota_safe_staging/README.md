# 15D — OTA Safe Staging, Versioning, and Integrity Gate

This milestone graduates the OTA stub into a recoverable staged updater with semantic versioning, SHA-256 integrity checks, and boot health enforcement. Firmware now persists `lastGoodFw` and `pendingFw` records in NVS (schema v1), exposes an OTA state machine over MQTT, and rolls back automatically when the post-update health gate fails.

## Key Deliverables
- `skyfeeder/ota_manager.*` streams OTA images to the inactive partition, verifies SHA-256, enforces SemVer and optional force upgrades, and publishes state-driven OTA events.
- `skyfeeder/boot_health.*` tracks pending boots, counts consecutive failures, and requests rollback after two unhealthy restarts or on explicit health failure.
- Discovery/mDNS advertises step `sf_step15D_ota_safe_staging` so tooling recognises the new capability.
- `code/server/ota_admin_cli/ota-publish.ps1` simplifies publishing OTA commands with the required schema.
- `docs/ota_command.schema.json` codifies the OTA command contract for firmware, tooling, and CI validation.

## OTA State Machine
```
IDLE ? DOWNLOAD_STAGED ? VERIFY ? APPLY_PENDING ? (Boot) ? REPORT_RESULT
                                           ¦
                                           +-- health failure ? ROLLBACK ? IDLE
                                           +-- success        ? APPLIED  ? IDLE
```
- **DOWNLOAD_STAGED**: stream image via HTTP(S) to the inactive OTA partition while hashing.
- **VERIFY**: compare SHA-256 digest with the `sha256` command field.
- **APPLY_PENDING**: mark the staged image as next boot, persist `pendingFw`, and (optionally) reboot if `staged=false`.
- **REPORT_RESULT**: after a healthy boot, mark the firmware valid, persist `lastGoodFw`, and emit `state:"applied"`.
- **ROLLBACK**: after =2 failed health boots or an explicit `markFailed`, queue `state:"rollback"`, clear `pendingFw`, and trigger `esp_ota_mark_app_invalid_rollback_and_reboot()`.

## NVS Retention
Namespace `ota/state` stores:
- `lastGood` (SemVer string)
- `pending` (SemVer string)
- `pendingChannel`
Namespace `boot/state` stores:
- `pendingVersion`
- `consecutiveFails`
- `awaitingHealth`

## Definition of Done
- Reject OTA when the requested version is = the running `FW_VERSION` unless `force=true`.
- SHA-256 digest must match before marking the image pending.
- Pending and last-good firmware tracked in NVS schema v1 (`ota/state`).
- Boot watchdog rolls back after two consecutive unhealthy boots or explicit health failure.
- MQTT events emitted on `skyfeeder/<deviceId>/event/ota`:
  - `download_started`, `download_ok`, `verify_ok`, `apply_pending`, `applied`, `rollback`, `error`.
- mDNS TXT `step=sf_step15D_ota_safe_staging` and discovery payload reflect the new step marker.

## Validation Walkthrough
1. **Stage the firmware**
   ```powershell
   cd D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code/feeder-steps/15D_ota_safe_staging
   ./code/server/ota_admin_cli/ota-publish.ps1 `
     -DeviceId sf-mock01 `
     -Version 1.2.0 `
     -Url http://10.0.0.4/fw/sf-esp32-1.2.0.bin `
     -Size 534912 `
     -Sha256 c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7c2f7
   ```

2. **Observe OTA telemetry** — capture a screenshot of the streaming output.
   ```powershell
   mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/event/ota" -v
   ```
   Expected sequence:
   ```json
   skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"download_started","version":"1.2.0","channel":"beta"}
   skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"download_ok","version":"1.2.0","channel":"beta"}
   skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"verify_ok","version":"1.2.0","channel":"beta"}
   skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"apply_pending","version":"1.2.0","channel":"beta"}
   ```

3. **Reboot / Await staged apply** — if `staged=false`, the device reboots immediately. Otherwise trigger a safe reboot when convenient.

4. **Confirm applied event**
   After the first healthy telemetry publish:
   ```json
   skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"applied","version":"1.2.0"}
   ```
   Verify `ota/state` in NVS (e.g., via `esptool.py read_flash`) reflects `lastGoodFw=1.2.0` and no `pendingFw`.

5. **Rollback test** (optional but recommended)
   - Flash a build with `FW_VERSION=1.2.0-test` that intentionally fails health (call `SF::BootHealth::markFailed("test")` in `setup()`).
   - Stage OTA version `1.2.1`.
   - Observe two consecutive boots emit `state:"rollback"` with `{"from":"1.2.1","to":"1.2.0"}` and the device returns to the last good partition.

6. **Discovery check**
   ```powershell
   mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -C 1 -t "skyfeeder/sf-mock01/discovery" -v
   ```
   Ensure payload contains `"step":"sf_step15D_ota_safe_staging"` and that `dns-sd -B _skyfeeder._tcp` shows TXT `step=sf_step15D_ota_safe_staging`.

7. **Schema validation**
   ```powershell
   type sample_command.json | npx ajv-cli validate -s docs/ota_command.schema.json -d -
   ```
   Replace `sample_command.json` with the command payload used above.

## Troubleshooting
- **`state:"error"` with `reason:"version_not_newer"`** — bump the requested SemVer or add `"force":true` for replays.
- **SHA-256 mismatch** — confirm the digest is hex encoded (64 chars) and matches the staged binary; the device aborts the Update and remains on the last good image.
- **No `applied` event after reboot** — verify telemetry publishes successfully; `boot_health` only marks success after the first MQTT telemetry payload. Check Wi-Fi/MQTT logs.
- **Immediate rollback after update** — the boot watchdog observed two unhealthy restarts. Inspect `reason` in the rollback event and device logs.

## Reference Files
- Firmware: `skyfeeder/ota_manager.*`, `skyfeeder/boot_health.*`
- CLI helper: `feeder-steps/15D_ota_safe_staging/code/server/ota_admin_cli/ota-publish.ps1`
- Schema: `feeder-steps/15D_ota_safe_staging/docs/ota_command.schema.json`
