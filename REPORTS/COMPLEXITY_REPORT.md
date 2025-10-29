# Complexity Report

| File | Approx. size | Hotspots | Recommendation |
|------|--------------|----------|----------------|
| `app/skyfeeder-app/App.tsx` | ~870 lines | Mixes navigation setup, MQTT lifecycle, mock mDNS hooks, and full UI rendering in one component. Error handling (acks, telemetry, snackbar) is deeply nested. 【F:app/skyfeeder-app/App.tsx†L1-L870】 | Split into hooks (`useMqttClient`, `useDeviceList`), presentation components, and a smaller navigator file. Co-locate styles per screen to reduce diff churn. |
| `ops/local/presign-api/src/index.js` | ~220 lines | Single module handles env parsing, S3 clients, presign logic, fault injection, upload proxy, and day-index writes. Hard to unit test specific behaviors. 【F:ops/local/presign-api/src/index.js†L1-L245】 | Extract helpers (`s3Client`, `dayIndexStore`, `faultProfiles`) and move fault/test endpoints behind feature flags to keep production path lean. |
| `skyfeeder/ota_manager.cpp` | ~400 lines | OTA state machine mixes storage persistence, HTTP streaming, SHA validation, and MQTT event queuing in one translation unit. Channel metadata bug stems from shared globals. 【F:skyfeeder/ota_manager.cpp†L1-L398】 | Introduce a struct to encapsulate OTA session state, move persistence helpers to `ota_state.cpp`, and unit-test queue/flush logic separately. |

## Additional Notes
- WebSocket relay (`ops/local/ws-relay/src/index.js`) is short but handles auth, metrics, and broadcast logic; consider splitting metrics into middleware for clarity. 【F:ops/local/ws-relay/src/index.js†L1-L176】
- Dashboard styles sit inline within `App.tsx`; moving them to `styles/` keeps TS definitions shorter and avoids accidental reflows. 【F:app/skyfeeder-app/App.tsx†L741-L870】
