# Constants & Variables Overview

## Device Firmware (`skyfeeder/config.h`)
- **`FW_VERSION` (`1.4.0`)** – OTA channel identifier baked into firmware; update alongside releases to keep OTA manager in sync. 【F:skyfeeder/config.h†L1-L12】【F:skyfeeder/ota_manager.cpp†L343-L360】
- **Provisioning defaults (`WIFI_DEFAULT_SSID`, `WIFI_DEFAULT_PASS`, `MQTT_DEFAULT_HOST`)** – Convenience values for lab bring-up but high-risk in production because credentials are public in source. Plan to populate from provisioning flow/NVS before shipping. 【F:skyfeeder/config.h†L6-L12】
- **LED and visit thresholds (`LED_IDLE_BRIGHTNESS`, `VISIT_ENTER_DELTA_G`, `PIR_EVENT_SNAPSHOT_COUNT`, `MINI_READY_TIMEOUT_MS`)** – Hard-coded heuristics that drive UX and sensor behavior. Consider exposing a tuning channel or config file so field data can adjust these without recompiles. 【F:skyfeeder/config.h†L16-L55】

## Local Services (Node)
- **`JWT_SECRET`** – Defaulted to `dev-only` in the presign API and inherited by the WebSocket relay; needs per-deployment rotation to prevent token forgery. 【F:ops/local/presign-api/src/index.js†L17-L64】【F:ops/local/ws-relay/src/index.js†L11-L80】
- **S3 bucket bindings (`S3_BUCKET_PHOTOS`, `S3_BUCKET_CLIPS`, `S3_BUCKET_INDICES`)** – Control where uploads and day indices land; indices currently share the `photos` bucket. Document expectations or split buckets if lifecycle policies diverge. 【F:ops/local/presign-api/src/index.js†L17-L163】
- **`HEARTBEAT_INTERVAL_MS`** – Governs ping cadence in the WebSocket relay; longer intervals reduce CPU but risk slower dead-connection detection. 【F:ops/local/ws-relay/src/index.js†L11-L170】
- **`OTA_MAX_BOOT_FAILS`** – Sets rollback threshold for the OTA heartbeat server; state is stored in RAM only, so persistence work is pending. 【F:ops/local/ota-server/src/index.js†L10-L56】

## Dashboard App (`app/skyfeeder-app/src/config.ts`)
- **`DEFAULT_WS_URL` and broker credentials** – Hard-coded to `ws://10.0.0.4:9001`, `dev1/dev1pass` for LAN demos. Swap to Expo env variables or discovery payloads when packaging for broader audiences. 【F:app/skyfeeder-app/src/config.ts†L1-L17】
- **`featureFlags.enableMdns`** – Controlled via Expo env; currently off by default. Keep the flag until native mDNS ships. 【F:app/skyfeeder-app/src/config.ts†L15-L17】

## Recommendations
1. Add startup guards that refuse to run with the known demo secrets (`dev-only`, `dev1`, `dev1pass`).
2. Persist OTA heartbeat state and WebSocket relay metrics to disk so restarts do not erase audit trails.
3. Define a configuration story (NVS or OTA-delivered JSON) for visit thresholds and lighting to avoid firmware churn during tuning.
