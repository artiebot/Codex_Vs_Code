# SkyFeeder Execution Playbook  
*(Codex + Claude shared context - keep current as the project evolves)*

---

## 0. Project Snapshot (2025-10-11)

- **Goal:** Field 10 smart feeders (ESP32 controller + AMB82 Mini camera) with OTA update path, then harden to production.
- **Active Phase:** **A1.1** (RTSP -> HLS bridge) — **A0.3 completed 2025-10-11**.
- **Device Identity:** `dev1` (hostnames, MQTT topics, helper scripts).
- **Recent changes (2025-10-11):**
  - AMB Mini now enforces an 800 ms warm-up before delivering a snapshot after wake (`lastCameraStart` tracking).
  - Ping heartbeats pause when the camera is in `sleep` (power-friendly behavior).
  - ESP32 bridge accepts `{"op":"status"}` and returns a `status` ACK.
  - PowerShell tools (`tools/cam-*.ps1`, `mqtt-cam-control.ps1`) emit pure ASCII JSON via `mosquitto_pub -f`.
  - MQTT discovery payload advertises `skyfeeder/dev1/...` topics.
  - A0.3 validation completed: Wi-Fi `stage_wifi` / `commit_wifi` flow exercised (fail + pass) with token-tagged feedback; artifacts in `REPORTS/validation_A0.3_wifi_stage_commit.log`.

---

## 1. Locked Architecture (do **not** diverge)

| Layer                  | Decision                                                                      |
|------------------------|-------------------------------------------------------------------------------|
| Identity               | Single MQTT identity (ESP32). Mini **never** runs MQTT.                      |
| Control plane          | UART JSON on AMB Serial3 (PE1=TX, PE2=RX), wake GPIO from ESP32.              |
| Data plane             | RTSP (`rtsp://<mini-ip>/live`) + HLS bridge + iOS app AVPlayer.              |
| Snapshots / events     | MQTT metadata only (`event/camera/snapshot` + URL). No image bytes.          |
| OTA                    | MQTT command + ESP32 fetches HTTPS binary. Phase B adds TLS + signatures.    |
| Mini power             | Deep sleep whenever idle. ESP32 wakes on PIR / weight triggers.              |
| Deprecated forever     | Mini MQTT client, MQTT image payloads, HTTP control of Mini, dual identities.|

---

## 2. Phase Roadmap (A0.2 -> B7)

| Phase | Scope (abridged) | DoD & Artifacts | Status |
|-------|------------------|-----------------|--------|
| **A0.2** | UART bridge w/ deep sleep, MQTT cmd+ack, settle window ~800 ms | `REPORTS/mini_A0.2DS_boot_status.txt`, `esp_A0.2DS_uart.log`, `esp_A0.2DS_mqtt.log`, `esp_A0.2DS_summary.md` | **Done (2025-10-10)** — wake->snapshot->sleep artifacts captured |
| **A0.3** | UART Wi-Fi stage/commit | `REPORTS/validation_A0.3_wifi_stage_commit.log` | **Done (2025-10-11)** — stage fail/pass + commit logs captured |
| A1.1 | RTSP->HLS bridge (Docker) | `REPORTS/validation_A1.1.txt` | Active |
| A1.2 | Discovery v0.2 (HLS + broker_ws) | `REPORTS/validation_A1.2.json`, `..._schema.txt` | Pending |
| A2.0 | App bootstrap + connectivity | Five artifacts listed in master plan | Pending |
| A2.1 | App video (HLS) | `REPORTS/validation_A2.1.txt` + user confirm | Pending |
| A2.2 | Motion/visit UX | `REPORTS/validation_A2.2.txt` + user confirm | Pending |
| A3.1–A3.3 | OTA gating + field packet | Artifacts per master plan | Pending |
| B1–B7 | Production hardening | See master plan | Pending |

**Rule:** Complete DoD + artifacts before advancing.

---

## 3. Firmware & Scripts — Current State

### AMB82 Mini (`amb-mini/amb-mini.ino`)
- UART: `#define MINI_UART Serial3` @115200 on PE1/PE2.
- `ensureCamera()` records `lastCameraStart`; `captureStill()` delays up to 800 ms post-wake.
- `stopCamera()` clears `lastCameraStart`.
- Ping heartbeat now gated by `camActive` (no pings during sleep).
- UART parser validates `op` type (prevents false `no_op` errors).
- Sleep command stops RTSP, updates status to `"sleeping"`. Wake command restarts pipeline.
- Wi-Fi staging commands validate SSID/PSK, run a connection smoke test, and emit tokenized `wifi_test` frames (stage/commit/abort).

### ESP32 (`skyfeeder`)
- `config.h` default device id: `dev1`.
- `command_handler.cpp` handles `wake`, `sleep`, `snapshot`, `status`, and now proxies Wi-Fi stage/commit/abort ops with token-aware ACKs.
- Discovery payload identifies `dev1` with topic map (`status`, `ack`, `event/#` paths).

### PowerShell tools (`tools/`)
| Script | Purpose | Notes |
|--------|---------|-------|
| `cam-status.ps1` | Publish `{"op":"status"}` | writes ASCII JSON temp file and publishes with `-f`.
| `cam-wake.ps1` / `cam-sleep.ps1` / `cam-snapshot.ps1` | Control commands | same JSON handling.
| `cam-monitor.ps1` / `mqtt-cam-monitor.ps1` | Subscribe to ACKs/events | default topic `skyfeeder/dev1/event/ack`.
| `mqtt-cam-control.ps1` | Unified CLI: `-Command status|wake|sleep|snapshot`. |

Confirm Mosquitto CLI is on PATH (`mosquitto_pub`, `mosquitto_sub`).

---

## 4. Validation & Artifact Checklist (A0.2 — completed)

Artifacts captured on 2025-10-10 (see REPORTS/):
- `mini_A0.2DS_boot_status.txt`
- `esp_A0.2DS_uart.log`
- `esp_A0.2DS_mqtt.log`
- `esp_A0.2DS_summary.md`

Reference command flow (retain for future regression runs):
```powershell
cd tools
.\cam-monitor.ps1                      # subscribe to acks
.\cam-wake.ps1                         # wake
Start-Sleep -Seconds 1
.\cam-snapshot.ps1                     # capture (after settle)
Start-Sleep -Seconds 5
.\cam-sleep.ps1                        # sleep
```

4. **Timing summary** (`wake` to ready, settle, total ) — `REPORTS/esp_A0.2DS_summary.md`.

Scripts to assist:
```powershell
cd tools
.\cam-monitor.ps1                      # subscribe to acks
.\cam-wake.ps1                         # wake
Start-Sleep -Seconds 1
.\cam-snapshot.ps1                     # capture (after settle)
Start-Sleep -Seconds 5
.\cam-sleep.ps1                        # sleep
```

---

## 5. Outstanding Questions / TODO

1. **Deep-sleep activation** — add Mini VOE deep-sleep call + ESP32 wake pulse (next sub-task inside A0.2/A0.3 overlap).
2. **Snapshot warm-up** — monitor in field that 800 ms remains sufficient; adjust if low-light requires longer.
3. **Status command meaning** — decide payload schema (currently just triggers Mini to emit standard status JSON).
4. **Power budget** — quantify current draw in sleep vs active (data needed before field deployment).
5. **Docs** — reports/legacy docs still mention `sf-mock01`; update when convenient.
6. **A1.1 prep** — design RTSP ingest -> HLS bridge (FFmpeg/Nginx), define validation checklist, and draft container layout before implementation.

---

## 6. Key Findings & Lessons Learned

| Date | Finding | Impact |
|------|---------|--------|
| 2025-10-10 | PowerShell JSON must be ASCII (UTF-16 BOM caused ArduinoJson `InvalidInput`). | Updated scripts to write temp ASCII (`mosquitto_pub -f`). |
| 2025-10-10 | A0.2 bench validation (wake -> snapshot -> sleep) | Verified pipeline with new scripts; artifacts recorded for regression. |
| 2025-10-10 | `doc["op"] | nullptr` can yield false null; need explicit type check. | AMB UART handler now validates variant type, eliminating `no_op` errors. |
| 2025-10-10 | Immediate snapshot post-wake yields black frame; camera needs warm-up. | Added 800 ms settle delay before capture. |
| 2025-10-10 | Ping heartbeat should stop in sleep to meet power goals. | Loop now suppresses pings when `camActive == false`. |

Keep appending to this table whenever we resolve tricky issues.

---

## 7. Working Agreement Recap

1. **Plan -> compare -> decide** for each major change. Note alternatives in chat.
2. **Self-validate** before asking user for physical verification.
3. **Artifacts** go under `REPORTS/` with agreed filenames.
4. **Architecture doc** (`ARCHITECTURE.md`) stays accurate.
5. If blocked, summarize attempts + logs + next options.
6. Use the other AI for peer review / double-checks when in doubt.

---

## 8. Quick Reference (commands)

```powershell
# Monitor events (acks by default)
.\tools\cam-monitor.ps1

# Issue commands
.\tools\cam-wake.ps1
.\tools\cam-snapshot.ps1
.\tools\cam-sleep.ps1
.\tools\cam-status.ps1

# Manual publish using JSON file
'{"op":"wake"}' | Out-File payload.json -Encoding ascii -NoNewline
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t skyfeeder/dev1/cmd/cam -f payload.json
Remove-Item payload.json
```

---

## 9. Next Steps (when continuing in a new chat)

1. Gather A0.2 artifacts with the updated firmware & scripts.
2. Verify sleep current (optional bench measurement).
3. Start on A0.3 (Wi-Fi provisioning) once DoD for A0.2 is satisfied.

Keep this file updated as we progress—especially the Key Findings and Outstanding TODO lists. This ensures a fresh chat can pick up the thread immediately.

















