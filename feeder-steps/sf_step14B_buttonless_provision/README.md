# SkyFeeder Step 14B - Buttonless Provisioning & Discovery

## Delta vs Step 14
- Provisioning AP no longer requires holding GPIO0; the device auto-enters setup when unprovisioned or after three rapid boots (<60 s)
- Wi-Fi retries are monitored and after three consecutive failures the captive portal reactivates automatically
- Discovery metadata now reports `sf_step14B_buttonless_provision` so downstream tooling can tell this build from Step 14

## Library Dependencies
- Core ESP32 libraries: DNSServer, WebServer, ESPmDNS
- Existing dependencies: ArduinoJson, PubSubClient, esp_camera, HX711, Adafruit NeoPixel

## Build & Flash
1. Open `sf_step14B_buttonless_provision/sf_step14_provision.ino`
2. Board: `ESP32 Dev Module` (PSRAM enabled for camera)
3. Verify + Upload

## Success Criteria
1. **Enter provisioning mode**
   - First boot with blank NVS drops directly into the `SkyFeeder-Setup` AP
   - To force reprovisioning later, power-cycle three times within a minute or let Wi-Fi fail three consecutive attempts; LEDs fall back to the idle heartbeat while in AP mode
2. **Capture credentials**
   - Connect to `SkyFeeder-Setup`, browser opens (or visit `http://192.168.4.1`)
   - Submit Wi-Fi + MQTT host/port/user/pass + desired Device ID
   - Page confirms save, device reboots into STA mode
3. **Device comes online**
   - Reconnect your workstation to normal LAN
   - Watch MQTT topics:
     ```bash
     mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/+/discovery' -v
     mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/+/status' -v
     ```
   - Expect retained discovery doc for your Device ID and `status=online`
4. **Commands honour new Device ID**
   - Using the new ID (e.g., `dev3`), issue commands:
     ```bash
     mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev3/cmd/led' -m '{"pattern":"heartbeat"}'
     mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev3/cmd/camera' -m '{"action":"snap"}'
     ```
   - ACK/telemetry/events appear under `skyfeeder/dev3/...`
5. **mDNS discovery**
   - On the LAN, run `dns-sd -B _skyfeeder._tcp` (macOS) or `avahi-browse -rt _skyfeeder._tcp` (Linux) and see the device id advertised with `step=sf_step14B_buttonless_provision`

## Troubleshooting
- **Portal not appearing**: Ensure you power-cycle three times within a minute or erase NVS (`esptool.py erase_flash`). Fresh boots with valid Wi-Fi will skip AP mode
- **Portal unreachable**: Manually browse to `http://192.168.4.1`; disable cellular/LAN bridging while connected to the AP
- **Credential typo**: Let Wi-Fi fail three retries or repeat the triple-boot sequence to re-enter provisioning
- **No discovery doc**: Confirm MQTT credentials were accepted; watch `skyfeeder/<id>/status` for `offline` LWTs indicating reconnect issues
- **Compile errors about ConversionSupported or stray '#' in program**: Save `provisioning.*` and `mqtt_client.cpp` as UTF-8 without BOM and reinstall the ArduinoJson library (Library Manager -> ArduinoJson -> install 6.21.5 or later)