# SkyFeeder Step 10 ? Weight + Calibration

## Delta vs Step 9
- Added HX711 load-cell HAL and weight service with median + EMA smoothing
- MQTT `cmd/calibrate` now supports tare and known-mass calibration flows
- Telemetry publishes `weight_g` plus raw/calibration diagnostics, persisted via NVS

## Library Dependencies
- HX711 by B. Bogdan Necula (`HX711` on Arduino Library Manager)
- Adafruit NeoPixel, ArduinoJson, PubSubClient, Preferences (already used in prior steps)

## Build & Flash
1. Open `sf_step10_weight/sf_step10_weight.ino` in Arduino IDE
2. Board: `ESP32 Dev Module`
3. Verify + Upload as usual (Serial monitor at 115200 for logs)

## Success Criteria
1. Subscribe to telemetry:
   ```bash
   mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/dev1/telemetry' -v
   ```
2. Clear the scale, then tare:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/calibrate' -m '{"tare":true}'
   ```
   - Expect `skyfeeder/dev1/ack` payload `{"cmd":"calibrate","ok":true}`
3. Place a known 500 g mass, then calibrate:
   ```bash
   mosquitto_pub -h 10.0.0.4 -t 'skyfeeder/dev1/cmd/calibrate' -m '{"known_mass_g":500}'
   ```
   - Expect ACK ok; telemetry `weight_g` ? 500
4. Power-cycle the ESP32, confirm telemetry still reports ~500 g with the weight applied (proves NVS persistence)

## Troubleshooting
- **ACK reports `tare_wait`**: wait for a few samples (scale must be steady) and resend the tare command
- **Telemetry `weight` section shows `ok:false`**: check HX711 wiring (DOUT=GPIO32, SCK=GPIO33) and verify the module has 3.3V/5V power
- **Weight drifts after calibration**: redo the tare step, ensure nothing touches the load cell, and re-run the known mass calibration