# Codex Audit Prompt - 2025-11-21

## Context

A Claude Code session performed serial monitoring and identified/fixed issues in the ESP32 + AMB82-Mini bird feeder system. This prompt requests Codex to audit the changes and fix any remaining issues.

---

## Session Summary

### Changes Made

1. **ESP32 Firmware (skyfeeder/)** - Previously committed:
   - Fixed watchdog crash by adding `esp_task_wdt_reset()` to `pumpMiniWhileWaiting()` in command_handler.cpp
   - Fixed inverted weight logic in visit_service.cpp (now ignores < 80g, captures >= 80g)
   - Added weight parameter threading through capture event chain
   - Renamed `PIR_EVENT_MAX_WEIGHT_DELTA_G` to `PIR_EVENT_MIN_WEIGHT_G` (80g default)

2. **AMB82 Firmware (amb-mini/)** - NEW change requiring commit:
   - **File:** `amb-mini/amb-mini.ino` line 134
   - **Change:** `kUploadQueueSlots` from 4 to 12
   - **Reason:** Queue was too small for 10 snapshots per event, causing photos 5-10 to be dropped

### Issues Still Requiring Implementation

1. **Video Recording Not Implemented** (CRITICAL)
   - Location: `amb-mini/amb-mini.ino` function `handleCaptureEvent()` lines 1197-1205
   - Problem: Code only emits phase messages but does NOT record or upload video
   - Required: Implement actual video recording using camera stream and call `queueClipUpload()`

2. **Telemetry Push Not Implemented** (MEDIUM)
   - Problem: ESP32 has sensor data (INA260 power, HX711 weight) but doesn't POST to backend
   - Required: Add periodic HTTP POST to `/api/telemetry/push` endpoint
   - iOS app Dev page shows null values for Power & Telemetry

---

## Audit Tasks for Codex

### Task 1: Verify Upload Queue Fix
- [ ] Confirm `kUploadQueueSlots = 12` in amb-mini.ino line 134
- [ ] Check if there are other queue-related constants that need adjustment
- [ ] Verify `kUploadMaxAttempts` is reasonable (currently 3)

### Task 2: Implement Video Recording
- [ ] Review AMB82 camera capabilities (RTSP stream available at rtsp://10.0.0.197:554/live)
- [ ] Implement video recording in `handleCaptureEvent()`:
  ```cpp
  // After snapshots loop, before emitEventPhase("done"...):
  if (videoSec > 0) {
    emitEventPhase("video_start", trigger, 0, snapshotCount, videoSec, true);
    // TODO: Record video for videoSec seconds
    // TODO: Call queueClipUpload(videoData, videoLen, trigger);
    emitEventPhase("video_end", trigger, 0, snapshotCount, videoSec, true);
  }
  ```
- [ ] Consider using MP4 encoding or raw H.264 stream capture
- [ ] Ensure video includes weight metadata if possible

### Task 3: Implement Telemetry Push
- [ ] Add telemetry HTTP POST to ESP32 (skyfeeder/):
  - Create new `telemetry_push.cpp` or add to existing service
  - Collect: INA260 readings (packVoltage, solarWatts, loadWatts), HX711 weight, WiFi RSSI
  - POST to `http://<backend>/api/telemetry/push` every 30 seconds
- [ ] Backend endpoint `/api/telemetry/push` may need implementation in presign-api

### Task 4: Code Quality Check
- [ ] Ensure all changes compile without warnings
- [ ] Check for memory leaks in upload queue (increased from 4 to 12 slots = more RAM usage)
- [ ] Verify weight_g field is correctly parsed by AMB82 and included in upload metadata

---

## Files to Review

| Component | File | Purpose |
|-----------|------|---------|
| AMB82 | `amb-mini/amb-mini.ino` | Upload queue, video recording |
| ESP32 | `skyfeeder/command_handler.cpp` | Capture event, watchdog fix |
| ESP32 | `skyfeeder/visit_service.cpp` | Weight filtering logic |
| ESP32 | `skyfeeder/config.h` | PIR_EVENT_MIN_WEIGHT_G constant |
| Backend | `ops/local/presign-api/src/index.js` | Telemetry endpoints |
| iOS | `mobile/ios-field-utility/SkyFeederUI/.../DevViewModel.swift` | Telemetry display |

---

## Validation After Fixes

1. **Compile both firmwares:**
   ```bash
   # ESP32
   arduino-cli compile --fqbn esp32:esp32:esp32 skyfeeder/skyfeeder.ino

   # AMB82
   arduino-cli compile --fqbn realtek-ambz2:ameba:... amb-mini/amb-mini.ino
   ```

2. **Flash and test:**
   - Trigger PIR with weight >= 80g
   - Verify 10 photos appear in gallery
   - Verify 1 video appears in gallery
   - Check iOS Dev page shows telemetry values

3. **Serial monitoring:**
   - Look for `[upload] queue full` messages (should NOT appear now)
   - Verify video upload telemetry messages

---

## Expected Outcome

After Codex completes this audit:
1. AMB82 firmware compiles with queue fix
2. Video recording implemented and tested
3. Telemetry push implemented (or documented as future work)
4. All changes committed and pushed

---

## Reference Documents

- `REPORTS/PLAYBOOK.md` - Session log
- `REPORTS/2025-11-21_SERIAL_VALIDATION_REPORT.md` - Full validation results
- Serial monitoring logs showing upload queue overflow evidence
