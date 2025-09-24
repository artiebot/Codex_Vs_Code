# 14E - App Alpha: Discovery

## Overview
Creates an Expo (React Native) client that connects to the SkyFeeder MQTT broker over WebSockets, listens for retained `discovery` payloads, and renders a live device list. A stubbed mDNS hook is included behind a feature flag so the UI can already surface LAN-resolved devices once we wire native discovery in a later step.

## Files changed / created
- `app/skyfeeder-app/` (new Expo workspace: `App.tsx`, config, polyfills, README, etc.)
- `feeder-steps/sf_step14E_app_alpha_discovery/README.md`
- `feeder-steps/sf_step14D_backend_staging_mock_publisher/README.md`
- `STEPS.md`

## Prerequisites
- Dev broker reachable on the LAN at `10.0.0.4`.
- Mosquitto running with a WebSocket listener on `ws://10.0.0.4:9001` (see `mosquitto_websocket.conf`).

## How to run (Expo web or device)
```bash
cd app/skyfeeder-app
npm install
# Configure broker creds (override if different)
setx EXPO_PUBLIC_BROKER_WS_URL ws://10.0.0.4:9001
setx EXPO_PUBLIC_BROKER_USERNAME dev1
setx EXPO_PUBLIC_BROKER_PASSWORD dev1pass
# Optional: surface mdns placeholder rows
setx EXPO_PUBLIC_ENABLE_MDNS 1
npm run start:web         # or `npm start` then choose device/Expo Go
```

Open `http://localhost:8082` for the web build (Expo may pick a different port; follow the CLI prompt). The header badge reflects connection state; once `Live`, retained discovery payloads appear almost immediately (try it with the Step 14D/14F mock publisher running).

## Success criteria checklist
- [ ] App shows `sf-mock01` (or other devices) populated from retained `discovery` messages.
- [ ] Connection status badge transitions through Connecting → Live → Reconnecting when the broker drops / returns.
- [ ] Pull-to-refresh on the list re-issues the subscription (verify by clearing retained discovery and publishing again).
- [ ] (Optional) Setting `EXPO_PUBLIC_ENABLE_MDNS=1` surfaces the stubbed mDNS entry, proving the UI can merge multiple discovery sources.

## Troubleshooting
- **`MQTT error: Navigator is undefined` / crypto errors**: Ensure you're running through `expo` (web or native) so the Metro bundler applies the Buffer/process polyfills.
- **`WebSocket connection failed`**: Confirm the WS listener (`ws://10.0.0.4:9001`) is listening and reachable from your machine/device; adjust `EXPO_PUBLIC_BROKER_WS_URL` as needed.
- **No devices listed**: Check that retained `discovery` exists (`mosquitto_sub -h 10.0.0.4 -t 'skyfeeder/+/discovery' -v`) and that the Step 14D mock publisher is running.

## Next step
Continue with [14F App Alpha: Control + ACKs](../sf_step14F_app_alpha_control_acks/README.md).
