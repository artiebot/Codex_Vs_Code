# SkyFeeder Step 11 ? Motion + Visit Fusion

## Delta vs Step 10
- Added PIR-driven `motion_service` with debounce/cooldown (GPIO27)
- Added `visit_service` that fuses motion with HX711 weight delta to emit visit events
- New MQTT topic `skyfeeder/dev1/event/visit`

## Library Dependencies
- Same as Step 10 (HX711, ArduinoJson, PubSubClient, Adafruit NeoPixel)

## Build & Flash
1. Open `sf_step11_motion/sf_step11_motion.ino` in Arduino IDE
2. Board: `ESP32 Dev Module`
3. Verify + Upload

## Success Criteria
1. Subscribe to events and telemetry:
   ```bash
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/event/#' -v
   ```
2. Ensure the feeder is tared/calibrated (reuse Step 10 commands if needed)
3. Wave your hand in front of the PIR, then place a small weight (>25 g delta) on the tray within ~2 s
   - Expect an `event/visit` payload such as `{"start_ts":12345,"duration_ms":6000,"peak_weight_g":180}`
4. Leave the tray untouched for >5 s; confirm the visit event publishes once idle

## Troubleshooting
- **No visit event**: verify PIR output on GPIO27 (logic HIGH on motion) and that weight delta exceeds `VISIT_WEIGHT_THRESHOLD_G`
- **Visit ends immediately**: increase actual weight delta or adjust `VISIT_IDLE_TIMEOUT_MS` for longer dwell (recompile)
- **Too many triggers**: ensure PIR has proper 3.3V supply and optionally raise cooldown/threshold values