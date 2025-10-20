# SkyFeeder Execution Playbook (Local-First Option A)

_Last updated: 2025-10-19_

---

## 0. Snapshot

- Device architecture: ESP32 <-> AMB82 Mini over UART (PE1/PE2) with GPIO16 wake pulse (~80-100 ms). Mini deep-sleeps when idle; wake-to-ready is about 10 s. No SD card, no MQTT on-device.
- Control plane: Local `ws-relay` (JWT rooms on port 8081). ESP32 reconnects with exponential backoff and queues outbound telemetry.
- Media path: `presign-api` issues PUT targets that proxy to MinIO. Uploads buffer in RAM with retry queue (1 min + 5 min + 15 min, max 3 attempts).
- Storage: MinIO buckets `photos/<deviceId>/...` (30-day retention + day indices) and `clips/<deviceId>/...` (1-day retention). Day index JSON files live inside `photos/<deviceId>/indices/`.
- OTA: ESP32/Mini fetch firmware from `OTA_BASE` (`http://<LAN-IP>:9180/fw/...`), verify sha256/signature, and roll back on failed boots.
- Auth: Local stack trusts any deviceId (dev-only). Real JWT validation begins at Cloud gate CF-1.
- Active focus: **A1.1 - Local Stack Validation (Owner: Codex)**. OTA A/B smoke (A0.4) is still outstanding.

### Phase Status

| Phase | Status | Owner | Notes |
|-------|--------|-------|-------|
| A0.2-DS | [x] complete | Codex | Deep sleep + UART control validated. |
| A0.3 | [x] complete | Codex | UART Wi-Fi provisioning complete. |
| A0.4 | [ ] pending | Codex | OTA A/B smoke + rollback logs required. |
| **A1.1** | [~] in progress | Codex | Local stack validation + artifact capture. |
| A1.2 | [ ] pending | Codex | Discovery v0.2 + WS resilience. |
| A1.3 | [ ] pending | Codex | iOS LOCAL gallery (Save to Photos, badges). |
| A1.4 | [ ] pending | Codex | Reliability & power soak (local stack). |
| B-series | [ ] planned | Codex | App “Button-Up” milestones (B1-B6). |
| A2 | [ ] planned | Codex | Field application pilot (1-3 units). |
| C-series | [ ] planned | Codex | Post-deployment ops outline. |
| CF-1 | [ ] gated | Codex | Cloudflare Worker + Durable Object + R2. |
| CF-2 | [ ] gated | Codex | Apple Dev + APNs/TestFlight. |

---

## 1. Local Stack Overview & Bring-Up

Directory structure (partial):

```
ops/local/
  docker-compose.yml             # minio, presign-api, ws-relay, ota-server
  presign-api/                   # SigV4 -> MinIO proxy, discovery, day index writer, faults
  ws-relay/                      # JWT-protected rooms, metrics endpoint
  ota-server/                    # Firmware host + heartbeat/rollback API
  minio/init.sh                  # Creates photos/clips buckets + lifecycle rules
  EXAMPLES.md                    # curl & wscat samples
```

### Quick start

```bash
cd ops/local
docker compose up -d
```

Services run on:

| Service       | Port | Description |
|---------------|------|-------------|
| MinIO         | 9200 | S3-compatible API (root user defaults to `minioadmin`). |
| MinIO Console | 9201 | Web UI. |
| presign-api   | 8080 | Presign + discovery + fault injection + day index writer. |
| ws-relay      | 8081 | WebSocket relay (rooms keyed by deviceId) + metrics. |
| ota-server    | 9180 | Firmware file host + heartbeat/rollback API. |

### Environment configuration

- `ops/local/docker-compose.yml` inlines all presign-api env vars (`S3_*`, `JWT_SECRET`, `PUBLIC_BASE`, `S3_PHOTOS_BASE`, `S3_CLIPS_BASE`, etc.). Update the compose file (or export overrides) if endpoints change. No `.env` file is required for Docker.
- `.env.local.example` (repo root) provides sample values for ESP32, Mini, and iOS LOCAL builds.
- `ops/local/presign-api/.env.example` is reference-only for manual `npm start` outside Docker.

### Buckets & lifecycle

The MinIO init helper (`docker compose up -d minio-init`) creates separate buckets:

```
photos/
  <deviceId>/
    indices/day-YYYY-MM-DD.json
    ... uploaded thumbnails (jpg/png)
clips/
  <deviceId>/
    ... uploaded clips (mp4)
```

Retention rules: photos expire in 30 days, clips in 1 day. Re-run `docker compose up -d minio-init` if the buckets vanish after pruning volumes.

### Troubleshooting

- **presign-api crash loops**: run `docker compose logs presign-api`. Missing `S3_*` variables means the compose overrides are stale.
- **Missing buckets or lifecycle rules**: `docker compose up -d minio-init` recreates `photos` and `clips` with expirations.
- **Upload auth errors**: ensure PUTs reuse the `Authorization` header from the presign response.

### Validation quick reference

```powershell
# Stack health
cd ops/local
docker compose up -d
docker compose ps
docker compose logs presign-api --tail=20
curl http://localhost:8080/healthz | jq .

# Presign upload
curl -s http://localhost:8080/v1/presign/put `
  -H 'Content-Type: application/json' `
  -d '{"deviceId":"dev1","kind":"photos","contentType":"image/jpeg"}' | jq .
# -> use uploadUrl/Authorization to PUT file

# Discovery + day index
curl http://localhost:8080/v1/discovery/dev1 | jq .
# verify MinIO photos/dev1/... (indices/day-YYYY-MM-DD.json)

# WebSocket relay
$TOKEN = node -e "console.log(require('jsonwebtoken').sign({deviceId:'dev1'}, 'dev-only'))"
wscat -c "ws://localhost:8081?token=$TOKEN"
> {"type":"ping"}
< {"type":"pong","ts":1697136000000}
# send upload_status message and observe deviceId/ts injection
curl http://localhost:8081/v1/metrics | jq .

# OTA heartbeat
curl -X POST http://localhost:9180/v1/ota/heartbeat `
  -H "Content-Type: application/json" `
  -d '{"deviceId":"dev1","version":"1.2.3","bootCount":1,"status":"boot"}' | jq .
```

Day index files (`photos/<deviceId>/indices/day-YYYY-MM-DD.json`) confirm uploads for gallery consumption.

---

## 2. Phase Execution Checklists (Owner: Codex)

### A0.4 - OTA Smoke & Rollback Validation

- [ ] Pre-checks: `curl http://localhost:9180/healthz | jq .` and `curl http://localhost:8080/v1/discovery/<deviceId> | jq .` to confirm `ota_base` and current `fw_version`.  
  Artifacts: `/REPORTS/A0.4/ota_status_before.json`, `/REPORTS/A0.4/discovery_before.json`
- [ ] Build firmware **B** (bump `FW_VERSION`, compile, export binary). Capture SHA256 + size (`python -m esptool image_info <bin>` or `tools/ota-validator/validate-ota.ps1 -GenerateInfo`).  
  Artifacts: `/REPORTS/A0.4/firmware_b_info.txt`, staged binary under `ops/local/ota-server/public/fw/<version>/skyfeeder.bin`
- [ ] Trigger OTA A->B via MQTT (`skyfeeder/<deviceId>/command/ota`) with `{url,version,sha256,size,staged:true}` pointing at `http://localhost:9180/fw/<version>/skyfeeder.bin`. Monitor MQTT `event/ota` and device serial for download/verify/apply.  
  Artifacts: `/REPORTS/A0.4/ota_runA_events.log`, `/REPORTS/A0.4/serial_runA.log`
- [ ] After reboot, confirm heartbeat + discovery show new version; snapshot `curl http://localhost:9180/v1/ota/status | jq .`.  
  Artifact: `/REPORTS/A0.4/ota_status_after_b.json`
- [ ] Rollback path: either (a) send deliberately failing OTA (bad SHA/URL) to exercise automatic revert, or (b) downgrade to prior version with `"force":true`. Capture rollback event sequence and final heartbeat.  
  Artifacts: `/REPORTS/A0.4/ota_runB_rollback.log`, `/REPORTS/A0.4/serial_rollback.log`, `/REPORTS/A0.4/ota_status_final.json`
- [ ] Summarize timings + result codes (download, verify, apply, rollback) in `/REPORTS/A0.4/summary.md`.

Exit: Demonstrated successful A->B upgrade and rollback evidence (automatic revert or forced downgrade) with matching heartbeat snapshots.

### A1.1 - Local Stack Validation (finish)

Goal: Prove the local backend works end-to-end and capture artifacts in `REPORTS/A1.1/`.

- [ ] Containers healthy: `docker compose ps -a` shows `minio`, `presign-api`, `ws-relay`, `ota-server` all `Up`, `minio-init` `Exited (0)`.  
  Artifact: `/REPORTS/A1.1/ps.txt`
- [ ] Buckets present: MinIO Console shows `photos` and `clips` buckets (legacy docs may call this `skyfeeder`).  
  Artifact: `/REPORTS/A1.1/bucket.png`
- [ ] Presign -> PUT flow: upload `thumb.jpg`; object visible under `photos/dev1/.../thumb.jpg`.  
  Artifacts: `/REPORTS/A1.1/presign.json`, `/REPORTS/A1.1/object.png`
- [ ] Discovery sane: `GET :8080/v1/discovery/dev1` returns correct `signal_ws`, `ota_base`, `step:"A1.1-local"`.  
  Artifact: `/REPORTS/A1.1/discovery.json`
- [ ] Day index present (optional): confirm `photos/dev1/indices/day-YYYY-MM-DD.json`, or add policy note.  
  Artifact: `/REPORTS/A1.1/dayindex.json` or `/REPORTS/A1.1/dayindex_note.txt`
- [ ] WS relay exercise: `wscat` ping -> pong; `GET :8081/v1/metrics` increments after sending an event.  
  Artifacts: `/REPORTS/A1.1/ws_metrics_before.json`, `/REPORTS/A1.1/ws_metrics_after.json`, `/REPORTS/A1.1/wscat.png`
- [ ] OTA heartbeat: `POST :9180/v1/ota/heartbeat` returns `{ "rollback": false }`; capture status snapshot.  
  Artifacts: `/REPORTS/A1.1/ota_heartbeat.json`, `/REPORTS/A1.1/ota_status.json`

Exit criteria: All checkboxes complete with artifacts committed.

### A1.2 - Discovery v0.2 + WS Resilience (local)

- Device (or simulator) uploads via presign; day index updates reliably.  
  Artifacts: `/REPORTS/A1.2/device_log.txt`, `/REPORTS/A1.2/index.json`
- WS resilience: forced disconnects trigger reconnect/backoff and queued telemetry.  
  Artifacts: `/REPORTS/A1.2/ws_reconnect.log`, `/REPORTS/A1.2/notifications.md`
- Notification latency histogram / success metrics for local testing.  
  Artifact: `/REPORTS/A1.2/latency_hist.json`

Exit: Discovery payloads accurate, reconnection stable, metrics recorded.

### A1.3 - WS End-to-End + Gallery

- Observe `event.upload_status` from device through ws-relay.  
  Artifacts: `/REPORTS/A1.3/ws_capture.json`, `/REPORTS/A1.3/metrics_before_after.json`
- iOS LOCAL gallery build shows uploads, Save to Photos, badges, success tile.  
  Artifacts: `/REPORTS/A1.3/ios_run_notes.md`, `/REPORTS/A1.3/gallery_recording.mp4`

Exit: Upload telemetry visible end-to-end; gallery MVP working locally.

### A1.4 - Fault Injection + Reliability

- Run `scripts/dev/faults.sh dev1 --rate 0.25 --code 500 --minutes 5 --api http://localhost:8080`; ensure retries succeed without crashes.  
  Artifacts: `/REPORTS/A1.4/device_retry_log.txt`, `/REPORTS/A1.4/ws_metrics.json`, `/REPORTS/A1.4/object.png`
- Capture power/success metrics over soak period (<200 mAh per event, success >= 85%).  
  Artifacts: `/REPORTS/A1.4/power.csv`, `/REPORTS/A1.4/power_summary.md`, `/REPORTS/A1.4/reliability.md`

Exit: Faults recover, retries log cleanly, indices and WS metrics remain consistent.

---

## 3. B-Series - App “Button-Up” (Owner: Codex)

### B1 - Provisioning polish

- Implement AP + captive portal when no Wi-Fi; triple power-cycle re-enters AP.
- LED states: `PROVISIONING`, `CONNECTING_WIFI`, `ONLINE` without blocking main loop.
- Produce operator quick guide.  
  Artifacts: `/REPORTS/B1/provisioning_demo.mp4`, `docs/PROVISIONING.md`

DoD: New device provisioned in ≤60 s; triple-cycle recovery verified.

### B2 - Dashboard MVP (local)

- Stand up dashboard (Vite on 5173 or Next on 3000) with CORS allowances for 8080/8081/9180.
- Features: device list (start with dev1), detail view (discovery payload, latest image, day index, live WS data), simple OTA status panel.
- If MinIO blocks GETs, add index proxy `GET /v1/index/:id/:yyyy-mm-dd` in presign-api.
- Artifacts: `/REPORTS/B2/list.png`, `/REPORTS/B2/detail.png`, `/REPORTS/B2/dashboard.env.example`

DoD: Operator inspects dev1 health and last upload without a terminal.

### B3 - Lightweight auth

- Password gate (env `DASHBOARD_PASSWORD`) and httpOnly session handling.
- Artifact: `/REPORTS/B3/auth_screenshot.png`

### B4 - OTA panel (read-first, optional write)

- Show `version`, `bootCount`, `rollback` status; optionally scaffold POST `/v1/ota/command`.
- Artifacts: `/REPORTS/B4/ota_panel.png`, `/REPORTS/B4/ota_command_example.json`

### B5 - Logs & diagnostics

- Client error boundary + `/v1/client-log` (dev only).
- “Download logs” button bundles `docker compose logs -n 300 presign-api ws-relay ota-server`.
- Artifact: `/REPORTS/B5/logs_bundle_example.txt`

### B6 - Operator docs

- `docs/LOCAL_PILOT.md`: bring-up, provisioning, dashboard operations, troubleshooting, artifact capture checklist.

---

## 4. Firmware Packaging Hygiene (Owner: Codex)

- Build fresh ESP32 app; verify OTA artifact with `python -m esptool image_info <firmware.bin>`.  
  Artifacts: `/REPORTS/firmware/image_info.txt`, `/REPORTS/firmware/firmware.sha256`
- CI targets:  
  - `build-ota` -> `releases/firmware-<VER>.bin` (app-only) + `.sha256`  
  - `build-factory` -> merged image (bootloader + partitions + app) for bench
- Record outputs under `/releases/`.
- Move hardcoded knobs to runtime config (NVS/JSON): JPEG quality, retry/backoff, power thresholds, visit delta-g, LED brightness, PIR parameters.  
  Artifacts: `config/schema/device-config.v1.json`, `docs/CONFIG.md`

Claude audits only when explicitly requested.

---

## 5. A2 - Field Application (Pilot, 1-3 units) (Owner: Codex)

- Site prep, mounting plan, Wi-Fi survey.
- Provision devices via captive portal; verify on dashboard.
- Targets over 7 days: ≥95% heartbeat continuity, ≥90% upload success, ≤1 manual intervention/week/device.
- Apply at least one OTA config change in the field.
- Artifacts: `/REPORTS/A2/*` (daily screenshots, metrics, logs)

---

## 6. C-Series - Post-Deployment Ops (Outline)

- Observability tiles and alerting (offline devices, low battery, high failure rate).
- OTA canary + health gate + automatic rollback strategy.
- Security hardening (auth, tokens, signed URLs).
- Ops playbook and weekly operations report.

---

## 7. Cloud Flip Gates (Deferred)

- **CF-1**: Cloudflare Worker + Durable Object + R2. Enforce real JWT validation, migrate discovery URLs, run 50-event success test (≥90%).  
  Environment targets: `API_BASE=https://api.skyfeeder.workers.dev`, `WS_URL=wss://...`.
- **CF-2**: Apple Developer setup + APNs/TestFlight pipeline. Achieve 100 background pushes with ≥90% success and P95 latency < 5 s.

Both gates remain blocked until local phases close.

---

## 8. “Audit on Demand” Template (Claude Only When Asked)

When requesting an audit from Claude, copy/paste and fill in this template:

```
Claude, audit request:

Build fresh app and post `python -m esptool image_info <firmware.bin>` output.
Verify OTA artifact is app-only; publish SHA256 + size.
Scan repo for hardcoded config in config.h and propose NVS keys.
Produce a Markdown table of artifacts (Path | Type | OTA-Safe | Why | Update Method).

Limit to read-only audit; no code changes.
```

---

## 9. Immediate Focus Recap

1. Finish A1.1 checklist and stash artifacts.  
2. Run OTA A/B smoke (A0.4) and capture required logs.  
3. Complete Mini HTTPS uploader + ESP32 WS telemetry loop.  
4. Spin up reporting scripts (latency, upload success, power, WS metrics).  
5. Prepare for B-series provisioning/dashboard work once A1.x phases are green.

Stay aligned with this playbook; update sections as phases advance.

