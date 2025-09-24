# SkyFeeder Step 14 ? Provisioning & Discovery

## Delta vs Step 13B
- Added `provisioning` service with long-press entry (GPIO0, 4 s) to launch the `SkyFeeder-Setup` AP + captive portal
- Captive portal collects Wi-Fi, MQTT, and Device ID; credentials stored in NVS and applied on reboot
- Topics are now generated at runtime from the provisioned device id
- mDNS announces `_skyfeeder._tcp` and a retained discovery document (`skyfeeder/<device>/discovery`) is published after MQTT connect

## Library Dependencies
- Core ESP32 libraries: `DNSServer`, `WebServer`, `ESPmDNS`
- Existing dependencies: ArduinoJson, PubSubClient, esp_camera, HX711, Adafruit NeoPixel

## Build & Flash
1. Open `sf_step14_provision/sf_step14_provision.ino`
2. Board: `ESP32 Dev Module` (PSRAM enabled for camera)
3. Verify + Upload

## Success Criteria
1. **Enter provisioning mode**
   - Hold GPIO0 (BOOT) LOW while applying power (~4 s)
   - ESP32 starts AP `SkyFeeder-Setup` (indicator: LEDs idle heartbeat)
2. **Capture credentials**
   - Connect to `SkyFeeder-Setup`, browser opens (or visit `http://192.168.4.1`)
   - Submit Wi-Fi + MQTT host/port/user/pass + desired Device ID
   - Page confirms save, device reboots
3. **Device comes online**
   - Reconnect your workstation to normal LAN
   - Watch MQTT topics:
     ```bash
     mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/+/discovery' -v
     mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/+/status' -v
     ```
   - Expect retained discovery doc for your Device ID and status=`online`
4. **Commands honour new Device ID**
   - Using the new ID (e.g., `dev3`), issue commands:
     ```bash
     mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev3/cmd/led' -m '{"pattern":"heartbeat"}'
     mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev3/cmd/camera' -m '{"action":"snap"}'
     ```
   - ACK/telemetry/events appear under `skyfeeder/dev3/...`
5. **mDNS discovery**
   - On the LAN, run `dns-sd -B _skyfeeder._tcp` (macOS) or `avahi-browse -rt _skyfeeder._tcp` (Linux) and see the device id advertised

## Troubleshooting
- **AP not appearing**: Ensure GPIO0 is grounded before and during power-on for > `PROVISION_HOLD_MS`
- **Portal unreachable**: Manually browse to `http://192.168.4.1`; disable cellular/LAN bridging while connected to AP
- **Credential typo**: Re-enter provisioning by holding GPIO0 again or erase NVS (`esptool.py erase_flash`)
- **No discovery doc**: Confirm MQTT credentials were accepted; watch `skyfeeder/<id>/status` for `offline` LWTs indicating reconnect issues
