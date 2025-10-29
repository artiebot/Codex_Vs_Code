# Review Summary

## Low-Hanging Fruit Fixes — PASS/IN PROGRESS
- ✅ Dashboard TypeScript build now passes with a defined `styles.muted` and module shim; see `REPORTS/B2/tsc_pass.txt`. 【F:app/skyfeeder-app/App.tsx†L1-L720】【F:app/skyfeeder-app/src/styles/dashboard.ts†L1-L91】【F:app/skyfeeder-app/src/global.d.ts†L1-L1】
- ✅ Presign API exposes `/v1/healthz` with a weak-secret flag and fails fast in production when misconfigured. 【F:ops/local/presign-api/src/index.js†L1-L210】【F:REPORTS/A1.1/healthz_presign.json†L1-L8】
- ✅ OTA heartbeat state persists to disk and survives restarts; snapshots captured before/after reboot. 【F:ops/local/ota-server/src/index.js†L1-L122】【F:REPORTS/B4/ota_persist_after_restart.json†L1-L11】
- ✅ WebSocket strict mode drops oversized payloads with 1008 policy close while emitting metrics. 【F:ops/local/ws-relay/src/index.js†L1-L199】【F:REPORTS/A1.3/ws_validation_close.txt†L1-L1】
- ⚠️ Day-index safe append implementation ships behind `INDEX_SAFE_APPEND`; concurrency test deferred pending S3/MinIO access (see `REPORTS/A1.4/index_race_test.json`).

## Highlights
- The local stack components are cohesive and easy to boot thanks to the Compose file that wires MinIO, presign API, WebSocket relay, and OTA services with sensible defaults for quick LAN validation. 【F:ops/local/docker-compose.yml†L1-L83】
- OTA firmware handling defensively verifies size and SHA-256 before staging, and publishes progress/telemetry hooks that keep the MQTT surface aware of long downloads. 【F:skyfeeder/ota_manager.cpp†L164-L272】【F:skyfeeder/ota_manager.cpp†L343-L376】

## Key Risks & Faults
- The Expo dashboard fails TypeScript builds and runtime styling because `styles.muted` is referenced but never declared, and the shim lacks types for `process/browser`. This surfaced in `tsc --noEmit` output and blocks CI. 【F:app/skyfeeder-app/App.tsx†L510-L523】【ccc0af†L1-L9】
- Presign API issues upload tokens with a hard-coded `dev-only` secret and rewrites daily indices without concurrency control or bounds, risking credential reuse and manifest corruption under concurrent uploads. 【F:ops/local/presign-api/src/index.js†L17-L64】【F:ops/local/presign-api/src/index.js†L107-L163】
- OTA event queuing drops the `channel` hint because `PendingEvent` never stores it, so rebooted devices emit follow-up events without channel context, weakening multi-channel rollout observability. 【F:skyfeeder/ota_manager.cpp†L112-L151】
- WebSocket relay accepts any JWT containing a `deviceId` and rebroadcasts arbitrary payloads without per-type limits, so a compromised client can flood all viewers or inject spoofed telemetry. 【F:ops/local/ws-relay/src/index.js†L69-L158】

## Efficiency & Maintainability Opportunities
- The 800+ line `App.tsx` combines navigation, MQTT wiring, mock mDNS, and full UI rendering; splitting connection logic and presentation components would shrink bundle size and ease testing. 【F:app/skyfeeder-app/App.tsx†L1-L870】
- Day index writes in the presign API always stringify full JSON blobs, even for single-object append operations. Streaming or partial merges would avoid quadratic JSON growth on busy feeders. 【F:ops/local/presign-api/src/index.js†L107-L163】
- OTA firmware progress publishes every two seconds regardless of delta, causing extra MQTT chatter during large downloads; exposing a tunable interval would let deployments trade fidelity for airtime. 【F:skyfeeder/ota_manager.cpp†L222-L235】

## Pending Validation
Claude’s playbook still flags three manual validation buckets—iOS gallery, 24 h soak/power capture, and provisioning polish—that remain unchecked. None of the new changes address those gaps, so the items stay outstanding. 【F:README_PLAYBOOK.md†L42-L86】

## Static Analysis Snapshot
- ESLint/depcheck/madge required local config installs that weren’t provided, so runs aborted after `npx` prompts. 【F:REPORTS/STATIC_ANALYSIS/eslint.txt†L1-L16】【F:REPORTS/STATIC_ANALYSIS/depcheck.txt†L1-L10】【F:REPORTS/STATIC_ANALYSIS/madge.txt†L1-L5】
- `npm audit` revealed a low-severity `send` advisory pulled in via Expo; upgrading Expo or overriding `send` is recommended before shipping. 【F:REPORTS/STATIC_ANALYSIS/audit.txt†L1-L44】
- Firmware toolchain (`arduino-cli`, `cppcheck`) isn’t installed in the container, so compile/static checks could not run. 【F:REPORTS/STATIC_ANALYSIS/compile_firmware.txt†L1-L1】【F:REPORTS/STATIC_ANALYSIS/cppcheck.txt†L1-L1】
