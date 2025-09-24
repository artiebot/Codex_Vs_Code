# 14G - App Alpha: Telemetry

## Overview
Extends the Expo app with live telemetry rendering on the device detail screen. The client now subscribes to `skyfeeder/+/telemetry`, stores a rolling window per device, and surfaces the most recent metrics (voltage, amps, watts, SoC, weight, RSSI) plus a short history list. The mock publisher emits slightly jittered telemetry so charts update without real hardware.

## Files changed / created
- `app/skyfeeder-app/App.tsx`
- `app/skyfeeder-app/src/types.ts`
- `tools/mock-publisher/publisher.py`
- `feeder-steps/sf_step14G_app_alpha_telemetry/README.md`
- `app/skyfeeder-app/README.md`
- `STEPS.md`

## How to run
```bash
# Terminal 1 – Mosquitto with WS listener
mosquitto.exe -c D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code/mosquitto_websocket.conf -v

# Terminal 2 – Mock device (now responds to commands + publishes jittered telemetry)
cd D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code/tools/mock-publisher
. .\.venv\Scripts\Activate.ps1
python publisher.py --device-id sf-mock01

# Terminal 3 – Expo app
cd D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code/app/skyfeeder-app
$env:EXPO_PUBLIC_BROKER_WS_URL = "ws://10.0.0.4:9001"
$env:EXPO_PUBLIC_BROKER_USERNAME = "dev1"
$env:EXPO_PUBLIC_BROKER_PASSWORD = "dev1pass"
npm run start:web
```
Open `http://localhost:8082`, tap `sf-mock01`, and observe the telemetry cards updating every 15 s.

## Verification checklist
- [ ] Latest telemetry card updates with new volts/amps/watts/SoC/weight/RSSI values every interval.
- [ ] History list under Telemetry shows a rolling series of the last few samples (time + watts + weight).
- [ ] Command/ACK controls still function while telemetry streams in.
- [ ] `mosquitto_sub -t 'skyfeeder/sf-mock01/telemetry' -v` matches the values presented in the app.

## Troubleshooting
- **No telemetry showing** – confirm the mock is running and publishing (`Telemetry X sent -> ...` logs). Check that Expo subscribed to `skyfeeder/+/telemetry` (no MQTT errors in Metro console).
- **Telemetry freezes after reconnect** – use pull-to-refresh in the list view; the app resubscribes to discovery/ack/telemetry wildcards.
- **Metrics look stale** – mock publishes every 15 s by default; adjust with `--interval` when launching `publisher.py`.

## Next step
Continue with [15A Logging & Diagnostics](../sf_step15A_logging_diagnostics/README.md).

