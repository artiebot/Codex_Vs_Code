# SkyFeeder Step 13B ? ESP32-CAM Fallback

## Delta vs Step 13A
- Replaced AMB82 bridge with on-board `camera_service_esp` that drives an ESP32-CAM sensor directly
- Snapshot events now embed a `data:image/jpeg;base64,...` payload on `event/camera/snapshot`
- Camera commands (`snap`, `sleep`, `wake`) act locally (init/deinit ESP32-CAM driver)

## Library Dependencies
- `esp_camera` (ESP32 core) ? enable PSRAM in board settings
- `mbedtls` base64 utilities (bundled with ESP32 core)
- Existing dependencies: ArduinoJson, PubSubClient, Adafruit NeoPixel, HX711

## Build & Flash
1. Open `sf_step13_camera_esp/sf_step13_camera_esp.ino`
2. Board: `ESP32 Dev Module` (PSRAM enabled), Partition: Large APP/OTA preferred
3. Verify + Upload; ensure camera pins match AI-Thinker defaults listed in `config.h`

## Success Criteria
1. Subscribe to camera snapshots + ACKs:
   ```bash
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/event/camera/#' -v &
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/ack' -v &
   ```
2. Trigger a still capture:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/camera' -m '{"action":"snap"}'
   ```
   - Expect ACK `{ "cmd":"camera","ok":true,"status":"idle" }`
   - Expect event payload containing `"base64":"data:image/jpeg;base64,..."` and `"size"`
3. Decode the base64 locally (example):
   ```bash
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/event/camera/snapshot' -C 1 | jq -r '.base64' | sed 's#data:image/jpeg;base64,##' | base64 -d > snap.jpg
   ```
   - Verify `snap.jpg` opens as a valid JPEG
4. Exercise power states:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/camera' -m '{"action":"sleep"}'
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/camera' -m '{"action":"wake"}'
   ```
   - ACKs reflect `status` `sleep` ? `idle`
5. Attempt a snap with the sensor disconnected to confirm ACK reports `camera_fail` / `snap_error`

## Troubleshooting
- **`camera_fail`**: Ensure PSRAM is enabled; confirm camera wiring matches constants in `config.h`
- **Image corrupted**: lower `CAM_FRAME_SIZE` (currently `FRAMESIZE_QVGA`) or reduce `CAM_JPEG_QUALITY`
- **Low-light captures**: momentarily drive `CAM_PIN_FLASH` (GPIO4) high in firmware or attach external LED/flash
