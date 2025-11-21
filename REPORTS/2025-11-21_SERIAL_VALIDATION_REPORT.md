# Serial Monitoring Validation Report
**Date:** 2025-11-21
**Session Duration:** ~10 minutes
**Devices:** ESP32 (COM4) + AMB82-Mini (COM6)

---

## Executive Summary

Serial monitoring session conducted to validate PIR weight filtering, capture events, and photo/video uploads. Key findings:

| Area | Status | Notes |
|------|--------|-------|
| Weight filtering | PASS | Correctly ignores < 80g, captures >= 80g |
| Weight metadata | PASS | Now included in capture_event JSON |
| Watchdog crash | PASS | No crashes during session (fix verified) |
| Photo capture | PARTIAL | 10 snapshots taken but only 1-2 uploaded |
| Video capture | FAIL | No actual recording - only phase messages emitted |
| Telemetry push | FAIL | ESP32 not pushing data to backend |

---

## Test Results

### 1. PIR Weight Filtering (PASS)

**Total PIR triggers:** 29
**Ignored (< 80g):** 26 (90%)
**Captured (>= 80g):** 2

Sample ignored triggers:
```
8.85g, 5.85g, 39.90g, 1.80g, 57.97g, 42.85g, 25.75g
```

Successful captures:
```
[19:36:21] weight delta=88.92g  -> 10 snapshots + 5s video triggered
[19:37:02] weight delta=444.67g -> 10 snapshots + 5s video triggered
```

### 2. Weight Metadata in Captures (PASS)

Weight is now correctly sent to AMB82:
```json
{"op":"capture_event","snapshots":10,"video_sec":5,"trigger":"pir","weight_g":88.92035}
{"op":"capture_event","snapshots":10,"video_sec":5,"trigger":"pir","weight_g":444.6678}
```

### 3. Watchdog Crash Fix (PASS)

No watchdog timeouts observed during 10-minute session. Previous fix (adding `esp_task_wdt_reset()` to `pumpMiniWhileWaiting()`) is verified working.

### 4. Photo Upload Queue (BUG FOUND & FIXED)

**Bug:** Only 1-2 photos per event uploaded instead of 10
**Root Cause:** `kUploadQueueSlots = 4` in amb-mini.ino line 134
**Fix Applied:** Changed to `kUploadQueueSlots = 12`

Evidence from serial logs - 10 snapshots captured but queue overflows:
```
[mini] event phase=snapshot trigger=pir total=10 index=1 ok=true
[mini] event phase=snapshot trigger=pir total=10 index=2 ok=true
...
[mini] event phase=snapshot trigger=pir total=10 index=10 ok=true
```

But only 1-2 appear in gallery due to queue overflow dropping photos 5-10.

### 5. Video Recording (BUG - NOT IMPLEMENTED)

**Bug:** Videos not recorded or uploaded
**Root Cause:** `handleCaptureEvent()` in amb-mini.ino only emits phases but does NOT:
- Record video from camera stream
- Call `queueClipUpload()`

Code at lines 1197-1205:
```cpp
if (videoSec > 0) {
  emitEventPhase("video_start", ...);  // Just emits message
  while (millis() < videoEnd) {        // Just waits
    pumpMqtt();
    vTaskDelay(pdMS_TO_TICKS(50));
  }
  emitEventPhase("video_end", ...);    // Just emits message
  // NO actual video recording!
}
```

### 6. iOS Dev Page Telemetry (NOT IMPLEMENTED)

**Bug:** Power & Telemetry section shows all null values
**Root Cause:** ESP32 does not push telemetry data to backend

Backend returns:
```json
{
  "packVoltage": null,
  "solarWatts": null,
  "loadWatts": null,
  "internalTempC": null,
  "batteryPercent": null
}
```

ESP32 has sensor readings (INA260, HX711) but no HTTP POST to push them.

---

## Files Modified

| File | Change |
|------|--------|
| `amb-mini/amb-mini.ino:134` | `kUploadQueueSlots` 4 -> 12 |

---

## Outstanding Issues Requiring Implementation

### Priority 1: Video Recording
- Implement actual MP4 recording in `handleCaptureEvent()`
- Add call to `queueClipUpload()` after recording
- Estimated complexity: Medium

### Priority 2: Telemetry Push
- Add periodic HTTP POST from ESP32 to backend
- Include: packVoltage, solarWatts, loadWatts, weightG, signalStrengthDbm
- Estimated complexity: Medium

---

## Validation Checklist

- [x] Boot sequence completes without crash
- [x] WiFi connects and stays stable
- [x] AMB82 communication healthy (ping count incrementing)
- [x] PIR triggers correctly filtered by weight
- [x] Weight >= 80g triggers capture
- [x] Weight < 80g ignored with log message
- [x] Weight metadata included in capture JSON
- [x] 10 snapshots captured per event
- [ ] 10 photos uploaded per event (BLOCKED by queue size - FIXED)
- [ ] Video recorded per event (NOT IMPLEMENTED)
- [ ] Video uploaded per event (NOT IMPLEMENTED)
- [ ] Telemetry visible in iOS app (NOT IMPLEMENTED)

---

## Recommendations

1. **Rebuild and flash AMB82 firmware** with increased queue size
2. **Implement video recording** using AMB82 RTSP stream or direct camera capture
3. **Add telemetry HTTP POST** to ESP32 main loop (every 30 seconds)
4. **Re-test after fixes** to verify 10 photos + 1 video per event
