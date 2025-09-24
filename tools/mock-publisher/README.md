# SkyFeeder Mock Publisher

Utility for publishing retained discovery/status messages, periodic telemetry, and command ACK stubs so the mobile app and backend can exercise end-to-end flows without flashing firmware.

## Install
```
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

## 4-Terminal Validation (deviceId=sf-mock01)
1. **Publisher** - start the mock:
   ```powershell
   python publisher.py --device-id sf-mock01 --enable-logs
   ```
2. **Discovery/Status** - watch retained state:
   ```powershell
   mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/discovery" -v
   ```
3. **OTA Events** - monitor OTA progress:
   ```powershell
   mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/event/ota" -v
   ```
4. **Trigger OTA Stub** - send command on the OTA topic:
   ```powershell
   mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/cmd/ota" -m '{"url":"mock.bin","size":4096}'
   ```

Expected result: terminal 3 prints progress payloads with `progress` 0/25/50/75/100 and the final message includes `status":"verified"` plus an 8-digit CRC matching the firmware stub.

Use `--dry-run` to dump payloads without touching the broker.
