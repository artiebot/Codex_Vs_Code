# SkyFeeder Step 13A — AMB82 Camera Orchestration (HTTP control)

## Delta vs Step 12
- `amb_service` now triggers the AMB82 camera through an HTTP bridge (`AMB_HTTP_BASE_URL` + `/test-snap`)
- The ESP32 still listens for AMB82 snapshot events on MQTT and republishes them on `event/camera/snapshot`
- Telemetry reports `camera.status` (`idle`, `snap_pending`, `http_error`, `snap_timeout`)

## Library Dependencies
- ESP32: ArduinoJson, PubSubClient, HTTPClient, Adafruit NeoPixel, HX711 (all previously used)
- AMB82 side continues to run the bridge sketch in `../../AMB/AMB.ino`

## Build & Flash (ESP32)
1. Open `sf_step13_camera_amb/sf_step13_camera_amb.ino`
2. Board: `ESP32 Dev Module`
3. Verify + Upload

### AMB82 Companion
1. Open `feeder-steps/AMB/AMB.ino` with the Ameba core
2. Board: AmebaPro2 / AMB82 Mini
3. Upload and open Serial Monitor @115200 — quick self-test should log:
   ```
   [boot] AMB82 MQTT Camera Bridge
   [mqtt] cmd topic: skyfeeder/dev1/amb/camera/cmd
   [mqtt] evt topic: skyfeeder/dev1/amb/camera/event/snapshot
   [wifi] connecting to wififordays
   ....
   [mqtt] connecting to 10.0.0.4:1883 ... ok
   [mqtt] subscribe skyfeeder/dev1/amb/camera/cmd -> ok
   ```
   If you do not see the `ok` lines, fix Wi-Fi/MQTT connectivity before moving on.

## Success Criteria
1. Set the AMB base URL in `config.h` if it differs (defaults to `http://10.0.0.197`).
2. Start subscribers (no quotes around topics when using Mosquitto on Windows):
   ```bash
   mosquitto_sub -h 10.0.0.4 -t skyfeeder/dev1/event/camera/# -v
   mosquitto_sub -h 10.0.0.4 -t skyfeeder/dev1/amb/camera/event/# -v
   mosquitto_sub -h 10.0.0.4 -t skyfeeder/dev1/ack -v
   ```
3. Trigger a camera snap through the orchestration path:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t skyfeeder/dev1/cmd/camera --file samples\cam_snap.json
   ```
   - ESP32 ACK: `{"cmd":"camera","ok":true,"status":"snap_pending"}`
   - AMB82 serial: `[mqtt] callback triggered` ? `[mqtt] action=snap` ? `[snap] captured … bytes`
   - Event: `skyfeeder/dev1/amb/camera/event/snapshot` followed by the mirrored `skyfeeder/dev1/event/camera/snapshot`
   - `/status` on `http://<AMB_IP>` shows updated `last_snap_ms` and `/snapshot.jpg` serves the still.
4. Test a failure scenario by disconnecting the camera briefly, then issuing `snap` — ESP32 should ACK `http_error` and `status` stays unchanged.

## Troubleshooting
- **ACK `no_action`**: payload missing `{"action":"snap"}`.
- **ACK `http_error`**: ESP32 could not reach the AMB82 HTTP endpoint — check `AMB_HTTP_BASE_URL`, network, or fetch `/test-snap` manually with `curl`.
- **ACK `snap_timeout`**: AMB82 did not publish an event within 10s — check serial output for `[snap] frame not ready` or MQTT disconnects.
- **No event mirrored**: watch `skyfeeder/dev1/amb/camera/event/#` to confirm the AMB publish. If present there but not on `event/camera/#`, check ESP32 MQTT connection.
- **Serial quiet after command**: the AMB sketch is not receiving the HTTP request. Hit `http://<AMB_IP>/test-snap` in a browser; if that works, re-check the ESP32 base URL.
