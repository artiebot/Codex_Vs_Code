# 15B - OTA Command Stub

This step wires up a non-flashing OTA handler so the app/backends can practice the command flow. The firmware now subscribes to `cmd/ota`, simulates a download using a deterministic byte generator, publishes progress markers to `event/ota`, and finishes with a verified CRC message. Discovery metadata and the mock publisher were refreshed to expose the new topics.

## Firmware Notes
- `SF::OtaService` listens on `skyfeeder/<deviceId>/cmd/ota` and responds on `.../event/ota`.
- Payload shape: `{ "url": "mock.bin", "size": 4096 }` (optional `chunkBytes`, `reqId`).
- Progress sequence: `status=started` (0%), `status=progress` (25/50/75), `status=verified` (100% + `crc`).
- CRC matches a deterministic pseudo-image so tooling/tests can assert the value without flashing.
- Discovery advertises the new capability/topics (`cmd_ota`, `event_ota`) and includes the step marker `sf_step15B_ota_stub`.

## PowerShell Validation (deviceId=sf-mock01)
1. Start firmware or the mock publisher.
2. Subscribe to OTA events:
   ```powershell
   mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/event/ota" -v
   ```
3. Trigger the OTA stub (Windows-safe BOM-free JSON):
   ```powershell
   # Create BOM-free JSON file (recommended for Windows)
   $enc = New-Object System.Text.UTF8Encoding($false)
   [IO.File]::WriteAllText("ota.json", '{"url":"mock.bin","size":4096}', $enc)
   mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/cmd/ota" -f ota.json

   # Alternative: inline command (also BOM-free)
   mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/cmd/ota" -m '{"url":"mock.bin","size":4096}'

   # Test different payload formats:
   # Size-only format
   mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/cmd/ota" -m '{"size":4096}'

   # Wrapped OTA format
   mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/cmd/ota" -m '{"ota":{"url":"mock.bin","size":4096}}'
   ```
4. Expected output: JSON messages with `progress` 0 -> 25 -> 50 -> 75 -> 100; the final payload reports `status":"verified"` and an uppercase 8-digit CRC.

## Error Handling
The OTA handler now robustly handles:
- UTF-8 BOM payloads (common when creating JSON files with Windows tools)
- Multiple payload formats: `{"url":"..","size":N}`, `{"size":N}`, `{"ota":{...}}`
- Always publishes error events on `event/ota` with `{"status":"error","reason":"...","detail":"..."}`
- Never fails silently - all parse/validation errors produce event responses

For regression checks, run the mock publisher unit tests:
```powershell
cd tools/mock-publisher
pytest
```
