# AMB82-Mini Camera Module

This module runs on the AMB82-Mini (Realtek RTL8735B) and provides MQTT-controlled camera functionality with RTSP (H.264) and HTTP MJPEG streaming.

## Hardware Requirements

- AMB82-Mini development board
- USB cable for programming and power
- WiFi network access

## Setup

### 1. Install Arduino IDE and Board Support

```bash
# Install Arduino IDE 2.x from https://www.arduino.cc/en/software

# Add the AMB82 board URL to Arduino IDE:
# File → Preferences → Additional Board Manager URLs:
https://github.com/ambiot/ambd_arduino/raw/master/Arduino_package/package_realtek.com_amebad_index.json

# Install board package:
# Tools → Board → Boards Manager → Search "Realtek Ameba Boards" → Install
```

### 2. Configuration

Credentials are pre-configured to match the SkyFeeder Option A field rig:
- WiFi: `wififordays`
- MQTT Broker: `10.0.0.4:1883`
- Device ID: `dev1`

To change these, edit `amb-mini.ino` (`WIFI_SSID`, `WIFI_PASS`, `MQTT_*`, `DEVICE_ID` at the top of the file).

### 3. Build and Flash

Use the provided scripts or Arduino IDE:

**Option A: Using scripts (recommended)**

```bash
# Build the firmware
cd amb-mini
./scripts/build.sh

# Flash to device
./scripts/flash.sh
```

**Option B: Using Arduino IDE**

1. Open `feeder-steps/AMB/AMB.ino`
2. Select board: `Tools → Board → Ameba ARM (32-bits) Boards → AMB82 MINI`
3. Select port: `Tools → Port → [your COM port]`
4. Click Upload

## Features

### Control Surface (UART via ESP32)

The AMB Mini is commanded over the ESP32 UART. Direct MQTT support remains behind the `MINI_MQTT` compile-time flag (disabled by default) for lab diagnostics, but production builds send **all** control via the ESP32 bridge. Typical request/response flow:

- Wake camera: `{"op":"wake"}`
- Sleep camera: `{"op":"sleep"}`
- Trigger snapshot: `{"op":"snapshot"}`
- Status probe: `{"op":"status"}`

Each command yields a single-line JSON response (example):

```json
{"mini":"status","state":"ready","ip":"10.0.0.198","rtsp":"rtsp://10.0.0.198/live"}
```

Snapshot requests produce a metadata frame:

```json
{"mini":"snapshot","ok":true,"bytes":16432,"sha256":"","path":"/snapshot.jpg"}
```

UART wiring (default harness):

- ESP32 GPIO23 → AMB82 Mini PE2 (Mini RX)
- ESP32 GPIO34 ← AMB82 Mini PE1 (Mini TX)
- Shared ground between boards

The ESP32 consumes these messages and republishes acknowledgements and snapshot metadata over MQTT (`skyfeeder/<device>/event/ack`, `skyfeeder/<device>/event/snapshot`). Any legacy documentation that references `skyfeeder/<id>/amb/...` MQTT topics is deprecated. Use the ESP32 `cmd/cam` interface instead.

### Streaming & HTTP Endpoints

Get the device IP from serial monitor after boot, then access:

- `http://{device-ip}/` - Status page with links
- `http://{device-ip}/status` - JSON status
- `http://{device-ip}/stream` - MJPEG video stream (open in browser/VLC)
- `http://{device-ip}/snapshot.jpg` - Latest captured image
- `http://{device-ip}/test-snap` - Trigger snapshot via HTTP
- `rtsp://{device-ip}:554/live` - H.264 RTSP stream (preferred for production)

### UART Control (ESP32 Link)

The ESP32 host communicates with the AMB Mini over a newline-delimited JSON stream on the debug UART:

- Wake: `{"op":"wake"}` → ensures camera + RTSP pipeline are running.
- Sleep: `{"op":"sleep"}` → stops streaming and powers down the camera.
- Status: `{"op":"status"}` → requests the current state without changing anything.

Each command yields a status frame such as:

```json
{"mini":"status","state":"ready","ip":"10.0.0.198","rtsp":"rtsp://10.0.0.198/live"}
```

When RTSP is active the JSON also includes `rtsp_url` so downstream hosts can latch onto the H.264 stream.

Example (assuming device IP is 10.0.0.100):
```bash
# Get status
curl http://10.0.0.100/status

# View MJPEG stream in VLC
vlc http://10.0.0.100/stream

# Download snapshot
curl http://10.0.0.100/snapshot.jpg -o snapshot.jpg

# Validate RTSP (plays in VLC / ffplay / ffprobe)
ffplay rtsp://10.0.0.100/live
```

## Testing

### Quick Test Sequence

1. **Monitor serial output** (115200 baud) - verify WiFi + MQTT connected

2. **Test MQTT command** - trigger snapshot:
   ```bash
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/amb/camera/cmd" -m '{"action":"snap"}'
   ```

3. **Monitor snapshot event**:
   ```bash
   mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/amb/camera/event/snapshot" -v
   ```

4. **Test HTTP stream** - open in browser (use IP from serial monitor):
   ```
   http://{device-ip}/stream
   ```

5. **Validate RTSP stream** with ffprobe to confirm H.264 video:
   ```bash
   ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1 "rtsp://{device-ip}/live"
   ```
   Expected output: `codec_name=h264`.

## Troubleshooting

- **Device not connecting to WiFi**: Check SSID/password, ensure 2.4GHz network
- **MQTT connection fails**: Verify broker IP, port 1883 open, credentials correct
- **Upload fails**: Install CP2102 USB driver, check COM port selection
- **Camera init fails**: Power cycle device, ensure sufficient USB power (500mA+)

## Development

Monitor serial output at 115200 baud to see diagnostic messages.
