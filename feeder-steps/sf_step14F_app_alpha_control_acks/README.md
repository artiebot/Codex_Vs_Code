# 14F - App Alpha: Control + ACKs

## Overview
Extends the Expo discovery client by adding a device detail screen with LED and camera controls. Commands publish MQTT envelopes (QoS 1) to `skyfeeder/<id>/cmd` and track acknowledgments from `skyfeeder/<id>/ack`. The Step 14D mock publisher now listens for commands and emits realistic ACK payloads so you can test the full command→ack round-trip without hardware.

## Files changed / created
- `app/skyfeeder-app/App.tsx`
- `app/skyfeeder-app/src/types.ts`
- `tools/mock-publisher/publisher.py`
- `feeder-steps/sf_step14F_app_alpha_control_acks/README.md`
- `STEPS.md`

## How to run (web)
```bash
# Terminal 1 – start Mosquitto with WebSocket listener (if not already running)
mosquitto.exe -c D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code/mosquitto_websocket.conf -v

# Terminal 2 – mock device with command/ack support
cd D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code
python tools/mock-publisher/publisher.py --device-id sf-mock01

# Terminal 3 – Expo app
cd D:/OneDrive/Etsy/Feeder-Project/SW/feeder-project/ESP32/Codex_Vs_Code/app/skyfeeder-app
$env:EXPO_PUBLIC_BROKER_WS_URL = "ws://10.0.0.4:9001"   # adjust if needed
$env:EXPO_PUBLIC_BROKER_USERNAME = "dev1"
$env:EXPO_PUBLIC_BROKER_PASSWORD = "dev1pass"
npm run start:web
```
Open `http://localhost:8082`, select `sf-mock01`, then trigger LED and camera controls.

## Verification checklist
- [ ] Tapping **LED Heartbeat/Blink/Off** publishes a command and shows "Command sent — awaiting ACK".
- [ ] An ACK chip appears with `ACK OK` and the mock publisher logs the ACK; pending state clears.
- [ ] Camera Snap publishes a command, receives `camera.snap` ACK, and the snackbar shows the result.
- [ ] If you send an invalid LED pattern (e.g., modify the code or publish manually), the UI surfaces `ACK error` with the broker’s error code.
- [ ] `mosquitto_sub -t 'skyfeeder/sf-mock01/ack' -v` shows matching ACK payloads.

## Troubleshooting
- **No ACK received** – ensure `tools/mock-publisher` is running and connected to the same broker/WS port as the Expo app.
- **"MQTT client not connected" snackbar** – verify the app header is not in the `Offline` state; reconnect the broker or restart Expo.
- **Commands stuck pending** – check the broker console for ACL/auth errors and confirm the mock publisher subscribed to `cmd/#` (`Listening for commands…` log).

## Next step
Continue with [14G App Alpha: Telemetry](../sf_step14G_app_alpha_telemetry/README.md).

