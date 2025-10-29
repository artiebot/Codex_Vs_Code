# Corner Cases & Coverage Analysis

## Device Uploader
- **Partial upload / connection drop**  
  - *Current handling:* PUT proxy buffers the entire body before writing to MinIO; if a stream error occurs, it returns `upload_failed` but leaves no retry metadata. 【F:ops/local/presign-api/src/index.js†L209-L245】  
  - *Risk:* Medium – large clips can exhaust RAM or fail mid-stream without backpressure.  
  - *Proposed guard:* Stream to MinIO in chunks with abort callbacks and cap `Content-Length` to protect memory.  
  - *Lightweight validation:* Upload a 50 MB file over throttled network and confirm memory stays bounded.
- **Duplicate event IDs**  
  - *Current handling:* Day index blindly appends a new random `id` for every entry, so duplicates remain. 【F:ops/local/presign-api/src/index.js†L145-L154】  
  - *Risk:* Low – gallery may show repeated cards, but storage remains consistent.  
  - *Proposed guard:* De-duplicate by relative key before pushing.  
  - *Lightweight validation:* Upload same file twice and verify index contains one entry.

## Discovery & MinIO Integration
- **Presigned URL expired**  
  - *Current handling:* Upload tokens expire after 15 min and `verifyUploadToken` returns 401, but device logs only show `invalid_token`. 【F:ops/local/presign-api/src/index.js†L61-L192】  
  - *Risk:* Medium – devices cannot distinguish expiry from auth failures.  
  - *Proposed guard:* Include structured error codes and retry hints in response.  
  - *Lightweight validation:* Sleep past expiry, retry PUT, and confirm firmware surfaces new code.
- **Bucket missing / lifecycle purge**  
  - *Current handling:* Reads catching `NoSuchKey` log warnings, but writes still target missing buckets and will throw. 【F:ops/local/presign-api/src/index.js†L125-L163】  
  - *Risk:* High – uploads fail silently if MinIO volumes are wiped.  
  - *Proposed guard:* Add startup health checks for bucket existence and fail `/healthz` when missing.  
  - *Lightweight validation:* Delete bucket, call `/healthz`, ensure alert.

## WebSocket Relay
- **Token replay / spoof**  
  - *Current handling:* Relay only checks signature and `deviceId`; no `aud`/`iss` validation. 【F:ops/local/ws-relay/src/index.js†L69-L118】  
  - *Risk:* High – anyone with the secret can impersonate any device.  
  - *Proposed guard:* Enforce JWT claims and bind token to connection metadata.  
  - *Lightweight validation:* Forge token for another device and confirm rejection.
- **Flooding / large payloads**  
  - *Current handling:* Broadcast loop forwards any JSON without size or rate limits. 【F:ops/local/ws-relay/src/index.js†L69-L158】  
  - *Risk:* High – malicious clients can DoS operator apps.  
  - *Proposed guard:* Impose payload caps and per-connection rate limiting.  
  - *Lightweight validation:* Send 256 KB payload, ensure server disconnects offender.

## OTA Flow
- **Channel-specific rollouts**  
  - *Current handling:* `queueEvent` ignores `channel`, so queued events after reboot lose rollout context. 【F:skyfeeder/ota_manager.cpp†L112-L151】  
  - *Risk:* Medium – phased rollouts lose audit trail.  
  - *Proposed guard:* Persist channel in `PendingEvent` and include it in `publishEvent`.  
  - *Lightweight validation:* Stage OTA, power cycle, verify `channel` persists.
- **Rollback threshold reset on restart**  
  - *Current handling:* OTA server stores heartbeat state in RAM with `OTA_MAX_BOOT_FAILS=3`; restart forgets boot counts. 【F:ops/local/ota-server/src/index.js†L39-L56】  
  - *Risk:* High – boot loops may never trigger rollback.  
  - *Proposed guard:* Persist heartbeat snapshots to disk and reload on boot.  
  - *Lightweight validation:* Record boot count, restart server, ensure count remains.

## Provisioning / AP
- **SSID collision / stale defaults**  
  - *Current handling:* Default SSID/password are hard-coded; no collision detection. 【F:skyfeeder/config.h†L6-L12】  
  - *Risk:* Medium – shipping with defaults invites takeover.  
  - *Proposed guard:* Force captive-portal provisioning and randomize SSID suffix.  
  - *Lightweight validation:* Boot without NVS, ensure portal demands new credentials.
- **Triple power-cycle timing drift**  
  - *Current handling:* Firmware constants exist but playbook notes validation pending. 【F:README_PLAYBOOK.md†L73-L86】  
  - *Risk:* Medium – operators may miss provisioning window.  
  - *Proposed guard:* Add serial hints and widen tolerance based on manual testing.  
  - *Lightweight validation:* Follow playbook steps and capture acceptable timing range.

## Dashboard / UI
- **CORS / mismatched broker URL**  
  - *Current handling:* Default WebSocket URL hard-coded to `ws://10.0.0.4:9001`; no runtime override. 【F:app/skyfeeder-app/src/config.ts†L1-L17】  
  - *Risk:* Medium – off-LAN builds silently fail to connect.  
  - *Proposed guard:* Drive URL from discovery payload or Expo env.  
  - *Lightweight validation:* Build with alternate `EXPO_PUBLIC_BROKER_WS_URL` and confirm connection.
- **Telemetry bursts**  
  - *Current handling:* UI keeps 24 samples per device with no throttle on message rate. 【F:app/skyfeeder-app/App.tsx†L148-L207】  
  - *Risk:* Low – high-frequency data could bog down rendering.  
  - *Proposed guard:* Debounce telemetry updates or downsample before storing.  
  - *Lightweight validation:* Publish telemetry at 5 Hz and observe frame rate.

## Sensors / Edge Cases
- **Visit baseline drift**  
  - *Current handling:* EMA constants lack floor/ceiling, so long absences can skew baseline. 【F:skyfeeder/config.h†L33-L42】  
  - *Risk:* Medium – first visit after refill may be missed.  
  - *Proposed guard:* Clamp baseline delta or reset after prolonged inactivity.  
  - *Lightweight validation:* Simulate drift in unit test and ensure detection recovers.
- **Power loss during OTA**  
  - *Current handling:* OTA manager depends on BootHealth/pending flags, but hardware soak validation still outstanding. 【F:skyfeeder/ota_manager.cpp†L343-L398】【F:README_PLAYBOOK.md†L57-L69】  
  - *Risk:* Medium – rollback path remains unverified without lab test.  
  - *Proposed guard:* Run forced power-cut test and capture MQTT events.  
  - *Lightweight validation:* Use lab power relay to interrupt OTA and confirm rollback.
