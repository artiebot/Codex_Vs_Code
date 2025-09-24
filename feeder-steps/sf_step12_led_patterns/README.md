# SkyFeeder Step 12 ? LED Patterns & UX

## Delta vs Step 11
- Added `led_ux` orchestration layer with power-aware defaults and timed overrides
- Upgraded `ws2812_service` to run non-blocking patterns (`heartbeat`, `amber`, `alert`, `solid`)
- `cmd/led` now accepts `{ "pattern": "heartbeat" }` and optional color/brightness overrides
- Telemetry reports active LED pattern and brightness

## Library Dependencies
- Same as Step 11 (no new external libraries beyond Adafruit NeoPixel / ArduinoJson / PubSubClient)

## Build & Flash
1. Open `sf_step12_led_patterns/sf_step12_led_patterns.ino`
2. Board: `ESP32 Dev Module`
3. Verify + Upload

## Success Criteria
1. Subscribe to telemetry and ack topics:
   ```bash
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/telemetry' -v &
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/ack' -v &
   ```
2. Send a heartbeat pattern override:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/led' -m '{"pattern":"heartbeat"}'
   ```
   - Expect ACK `{ "cmd":"led","ok":true,"pattern":"heartbeat",... }` and telemetry `led.pattern="heartbeat"`
3. Force WARN behavior by simulating low battery (e.g., lower `CELL_WARN_V` temporarily or mock via `power_manager` test); when WARN triggers, LEDs go amber unless you send a new override
4. Send a temporary solid white override with brightness capping:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/led' -m '{"on":true,"brightness":200}'
   ```
   - ACK should show brightness limited to `power.brightnessLimit()`
5. After ~15 s (default override window), confirm the LEDs return to the power-driven pattern automatically

## Troubleshooting
- **Pattern command rejected (`pattern_unknown`)**: check spelling; valid options: `heartbeat`, `amber`, `alert`, `solid`, `off`
- **Override never expires**: ensure device clock is running; override duration defaults to `LED_OVERRIDE_MS` (15 s) unless `hold_ms` provided
- **Amber alert missing during WARN**: verify INA260 telemetry reports WARN (`power.state=1`); `led_ux` only forces amber when WARN/CRIT is active and no fresh override is set