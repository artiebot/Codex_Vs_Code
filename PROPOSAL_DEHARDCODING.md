# De-hardcoding Proposal (Post-A2)

**Validation guard:** No configuration or code changes will be applied until A1.1–A1.4 and B1–B2 validation is signed off. All actions below are staged for execution **after field deployment (post-A2)** unless noted otherwise.

## Executive summary
- **What changes later:** After A2 we will externalize tenant/security/OTA-sensitive values (JWT secrets, storage credentials, public endpoints, firmware version metadata, provisioning defaults, broker auth, OTA rollback thresholds, HLS feeds) via secrets/config services with dual-window rollouts so devices and dashboards retain connectivity.【F:ops/local/presign-api/src/index.js†L17-L243】【F:ops/local/docker-compose.yml†L37-L52】【F:skyfeeder/config.h†L3-L12】【F:app/skyfeeder-app/src/config.ts†L8-L15】【F:mosquitto_websocket.conf†L7-L47】
- **What stays constant:** Engineering invariants—object key schema, topic structure, LED timings, MinIO lifecycle policies, heartbeat interval—remain hardcoded with documentation; they do not expose customer data and changing them would break dependent tooling.【F:ops/local/presign-api/src/index.js†L116-L243】【F:skyfeeder/topics.cpp†L21-L61】【F:ops/local/minio/init.sh†L8-L20】【F:backend/r2_lifecycle.json†L1-L28】
- **Approach:** Execute in three post-A2 waves (Pre-prod hardening, Pilot rollout, Production cut-over) with explicit dual-secret windows, validation commands, artifact capture, and rollback levers. Provisioning keeps DEMO_DEFAULTS optional for emergency lab batches, but production builds will require operator input.

## Analysis table
| Component | File / Location | Key / Value (example) | Category | Meets change policy? | Proposed change | Why change? (risk / benefit) | When (Phase) | OTA impact note | Validation (commands & artifacts) | Rollback plan |
|-----------|-----------------|-----------------------|----------|----------------------|-----------------|------------------------------|--------------|-----------------|----------------------------------|---------------|
| presign-api | ops/local/presign-api/src/index.js | `JWT_SECRET="dev-only"` fallback for upload tokens | Security | ✅ | Load primary/secondary secrets from a secrets store; refuse to start in production if unset.【F:ops/local/presign-api/src/index.js†L17-L64】 | Leaked secret allows attackers to mint presign URLs/WS tokens; dual-secret rotation prevents downtime.【F:ops/local/presign-api/src/index.js†L61-L191】 | Post-A2 Pre-prod | Tokens drive OTA/discovery auth; invalid secret blocks both upload and WS telemetry. | ```bash
curl -s https://$PRESIGN/v1/presign/put -H 'Content-Type: application/json' -d '{"deviceId":"devX","kind":"photos"}' | jq .headers.Authorization
wscat -c "wss://$RELAY?token=<old>"   # expect close 1008 after cut
wscat -c "wss://$RELAY?token=<new>"   # expect system connected
```
Artifacts: `reports/postA2/jwt_rotation.txt`. | Keep old secret as secondary; if failures spike, swap primary/secondary in secrets store and redeploy. |
| presign-api | ops/local/presign-api/src/index.js | `PUBLIC_BASE`, `S3_PHOTOS_BASE`, `WS_PUBLIC_BASE` default to localhost | Customer | ✅ | Require explicit env/parameter inputs; discovery renders configured host names. | Lab defaults break devices once endpoints move to cloud; forcing explicit config prevents misrouting. | Post-A2 Pre-prod | Wrong URLs break OTA download/discovery resolution. | ```bash
curl -s https://$PRESIGN/v1/discovery/dev1 | jq '.signal_ws, .video.thumb_base'
``` Expect production domains; artifact `reports/postA2/discovery_domains.json`. | Restore previous env map; redeploy with localhost defaults for lab fallback. |
| presign-api | ops/local/presign-api/src/index.js | `OTA_BASE="http://localhost:9180"` | OTA | ✅ | Inject CDN/storage OTA base via config with reachability check before publishing discovery. | Incorrect OTA base stalls firmware downloads. | Post-A2 Pre-prod | OTA manifest download depends on base; wrong host = download failures. | ```bash
curl -s https://$OTA/v1/ota/heartbeat -d '{"deviceId":"dev1","version":"1.4.2"}' | jq .rollback
curl -s https://$PRESIGN/v1/discovery/dev1 | jq .ota_base
```
Artifacts: `reports/postA2/ota_base.txt`. | Revert env override to previous OTA base; keep DNS for old host active during rollback. |
| presign-api | ops/local/presign-api/src/index.js | Day-index key schema + retention constants | Safe | ❌ | No change – keep constants and document contract. | Stable schema powers gallery queries; no security/customer impact. | — | None. | Existing tests already cover; no action. | N/A. |
| ws-relay | ops/local/ws-relay/src/index.js | `JWT_SECRET="dev-only"` fallback | Security | ✅ | Share dual-secret loader with presign API; disable fallback outside dev. | Spoofed WS tokens allow telemetry injection. | Post-A2 Pre-prod | WS auth failure blocks device telemetry and OTA status updates. | Same commands as presign (above); monitor `/v1/metrics` (`curl -s https://$RELAY/v1/metrics | jq .rooms`). Artifact `reports/postA2/ws_metrics.json`. | Maintain secondary secret; revert env if clients fail auth. |
| ws-relay | ops/local/ws-relay/src/index.js | `HEARTBEAT_INTERVAL_MS=30000` | Safe | ❌ | No change. | Interval is an engineering invariant. | — | None. | Existing heartbeat tests. | N/A. |
| ota-server | ops/local/ota-server/src/index.js | `OTA_MAX_BOOT_FAILS = 3` | OTA | ✅ | Parameterize via env/feature flag; emit metric to confirm threshold. | Fixed threshold may over/under-trigger rollback. | Post-A2 Pilot | Rollback gating depends on threshold. | ```bash
curl -s https://$OTA/v1/ota/heartbeat -H 'Content-Type: application/json' -d '{"deviceId":"dev1","version":"1.4.2","bootCount":3,"status":"boot"}' | jq .rollback
```
Artifact `reports/postA2/ota_threshold.txt`. | Reset env to old value; redeploy OTA service. |
| Local compose / MinIO | ops/local/docker-compose.yml | `MINIO_ROOT_USER/PASSWORD=minioadmin` | Security | ✅ | Use per-env service accounts via secrets manager/IAM; update deployment manifests. | Root creds allow storage takeover. | Post-A2 Pre-prod | Upload/download rely on MinIO auth; wrong creds block OTA artifact access. | ```bash
mc alias set prod https://$MINIO $ACCESS $SECRET
mc ls prod/photos
curl -s https://$PRESIGN/v1/presign/put ...
```
Artifacts: `reports/postA2/minio_credentials.txt`. | Re-enable previous MinIO user; redeploy with rollback secrets. |
| Firmware (ESP32) | skyfeeder/config.h | `FW_VERSION "1.4.0"`, Wi-Fi/MQTT defaults, `DEVICE_ID_DEFAULT` | OTA & Security/Customer | ✅ | Generate FW_VERSION at build time; gate provisioning defaults behind `DEMO_DEFAULTS` flag so production builds require operator input; surface warning when flag enabled. | Wrong version blocks OTA gating; shipping shared creds is insecure. | Post-A2 Pilot | Discovery heartbeat and OTA manifest rely on accurate version; provisioning must collect customer SSID/ID. | ```bash
idf.py build
strings build/firmware.bin | grep FW_VERSION
# Provisioning portal screenshot showing blank fields & warning if DEMO_DEFAULTS enabled
```
Artifacts: `reports/postA2/fw_version.txt`, `reports/postA2/provisioning_portal.png`. | Rebuild with `-DDEMO_DEFAULTS=1` for emergency lab batches; remove flag after incident. |
| Provisioning SoftAP | skyfeeder/provisioning.cpp | SSID `"SkyFeeder-Setup"` | Customer | ✅ | Allow SSID prefix override via config/provisioning blob; show tenant/site code. | Identical SSID cross-fleets invites confusion. | Post-A2 Pilot | None direct; but provisioning must succeed for OTA updates. | ```bash
# After flashing config
nmcli dev wifi list | grep SkyFeeder
```
Artifact `reports/postA2/softap_scan.txt`. | Revert build flag to default SSID; reflash devices if needed. |
| Dashboard (Expo) | app/skyfeeder-app/src/config.ts | Lab defaults for MQTT host/creds | Security | ✅ | Require env overrides; app exits with error if defaults detected in release builds. | Lab creds allow unauthorized control. | Post-A2 Pre-prod | Dashboard publishes commands used for OTA/capture; wrong auth blocks features. | ```bash
expo start --config app.prod.json
# Expect fatal error if env missing
```
Artifact `reports/postA2/dashboard_env.txt`. | Provide feature flag to allow defaults temporarily; issue hotfix reverting check if needed. |
| MQTT broker | mosquitto_websocket.conf | `allow_anonymous true` | Security | ✅ | Disable anonymous listener; require password/JWT aligned with dashboard creds. | Anonymous access enables command/OTA spoofing. | Post-A2 Pre-prod | OTA/camera commands delivered via MQTT; auth failure blocks control plane. | ```bash
mosquitto_sub -h $BROKER -p 1883 -t 'skyfeeder/+/discovery'
# Expect auth failure
mosquitto_sub -h $BROKER -p 1883 -u $USER -P $PASS -t 'skyfeeder/+/discovery'
```
Artifact `reports/postA2/mqtt_auth.txt`. | Keep alternate listener on separate port with anonymous access during transition; disable once clients confirmed. |
| HLS bridge | docker/hls-bridge/.env.example | `RTSP_URL=rtsp://10.0.0.198/live` | Customer | ✅ | Externalize RTSP URL/stream via deployment config; validation in staging before pilot. | Hardcoded RTSP feed fails on customer network. | Post-A2 Pre-prod | Gallery might ingest live feeds; wrong URL breaks capture pipeline. | ```bash
curl -s https://$HLS/hls/$STREAM.m3u8 | head
```
Artifact `reports/postA2/hls_playlist.m3u8`. | Restore previous .env values or disable bridge container. |
| MinIO / R2 lifecycle | backend/r2_lifecycle.json | Photos 30 d, clips 7 d | Safe | ❌ | No change. | Policy matches product requirement. | — | None. | Compliance check already in place. | N/A. |

## Dual-window procedure (applies to secret/URL rotations)
1. Introduce new secret/config as **secondary**; services accept both primary and secondary values.
2. Issue updated tokens/config to devices/dashboards; monitor 2xx/4xx metrics.
3. Promote secondary to primary; keep previous value as secondary for a defined overlap window.
4. Retire old value once metrics stable; monitor for spikes in 401/connection failures.
5. If errors appear, revert primary/secondary roles immediately and investigate.

## Phased plan
### Phase 1 – Post-A2 Pre-prod hardening
Tasks, validations, and artifacts:
1. Rotate presign-api/ws-relay JWT secrets (dual-secret loader). Validate with `curl` + `wscat`; capture `jwt_rotation.txt`.
2. Replace MinIO credentials with IAM/service accounts (mc alias + presign PUT). Save `minio_credentials.txt`.
3. Require production endpoints (PUBLIC_BASE/S3/WS/OTA) via config; verify discovery/OTA heartbeats; store `discovery_domains.json`, `ota_base.txt`.
4. Enforce dashboard env requirements; run Expo build to confirm failure without env and success with env; store console output.
5. Enable MQTT auth (mosquitto_sub tests) for both dashboard user and device user; capture `mqtt_auth.txt`.
6. Parameterize HLS bridge (curl playlist) and confirm logs show correct RTSP source; store playlist snippet.

### Phase 2 – Post-A2 Pilot rollout
1. Build firmware with generated FW_VERSION; verify via serial log and discovery. Artifacts: `fw_version.txt`.
2. Provisioning defaults removed unless `DEMO_DEFAULTS` flag set; capture portal screenshot showing warning when flag enabled.
3. SoftAP SSID override validated via Wi-Fi scan; artifact `softap_scan.txt`.
4. OTA rollback threshold configurable; heartbeat tests produce `ota_threshold.txt`.
5. Document device discovery caching/backoff behavior in firmware notes (devices retain last good discovery and retry exponential when base unreachable).

### Phase 3 – Production cut-over
1. Retire secondary secrets/legacy creds; monitor auth metrics for 24h.
2. Finalize OTA threshold; run staged OTA (successful + intentionally failed pack to confirm sha256 rejection logged).
3. Confirm R2 lifecycle policies match specification via AWS CLI export.
4. Remove anonymous MQTT listener; penetration test verifies auth only.

## Change readiness checklist
- [ ] Monitoring dashboards set up (auth failures, upload 4xx/5xx, WS disconnects, OTA heartbeat/rollback metrics).
- [ ] Rollback levers exercised in staging (env toggle, secret swap, feature flag).
- [ ] Staging test device runs through new settings end-to-end (upload, OTA, provisioning).
- [ ] Documentation updated (discovery contract, provisioning SOP, secret rotation runbooks).
- [ ] Artifact storage path agreed (`reports/postA2/...`).

## Risk & impact brief
- **JWT/credential rotation:** Misconfig blocks uploads/telemetry; mitigate via dual-secret and monitoring.【F:ops/local/presign-api/src/index.js†L17-L243】【F:ops/local/ws-relay/src/index.js†L11-L155】
- **Endpoint reconfiguration:** Wrong public bases or OTA base cause download failures; discovery caching/backoff in firmware keeps last good config while retries run. Mitigate via preflight curls and staged rollout.【F:ops/local/presign-api/src/index.js†L185-L243】
- **Provisioning changes:** Removing defaults could impede installers; DEMO_DEFAULTS flag + on-screen warning offers emergency fallback.【F:skyfeeder/config.h†L3-L12】【F:skyfeeder/provisioning.cpp†L41-L148】
- **OTA thresholds & sha256 verification:** Incorrect configuration triggers rollbacks or allows tampered firmware. Mitigate by testing heartbeats and verifying sha mismatch rejection during Phase 3. | Rollback: reset env to previous threshold, restore old sha allowances only temporarily.【F:ops/local/ota-server/src/index.js†L25-L56】
- **Broker authentication:** New auth may block dashboard/device commands temporarily; keep alternative listener during transition and monitor connection failures.【F:mosquitto_websocket.conf†L7-L47】
- **Storage IAM:** Wrong credentials stop uploads; keep previous credentials disabled but recoverable until confidence achieved.【F:ops/local/docker-compose.yml†L37-L52】
- **HLS bridge:** Misconfigured RTSP stops live capture; verify reachability before cut-over and keep prior .env for rollback.【F:docker/hls-bridge/docker-compose.yml†L4-L27】
- **Lifecycle policies:** No change; ensure production matches spec to avoid accidental data loss.【F:backend/r2_lifecycle.json†L1-L28】

All validations generate artifacts stored under `reports/postA2/` to support audit readiness.
