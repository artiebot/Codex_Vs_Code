# Codex Implementation Prompt - 2025-11-21

## System Overview

ESP32 + AMB82-Mini bird feeder camera system. ESP32 handles sensors (PIR, HX711 weight, INA260 power), AMB82 handles camera/video/uploads. Communication via UART JSON at 115200 baud.

---

## COMPLETED (Verify Only)

### 1. Upload Queue Size Fix ✓
- **File:** `amb-mini/amb-mini.ino` line 134
- **Status:** FIXED - `kUploadQueueSlots = 12` (was 4)
- **Action:** Verify this is in place, no further work needed

---

## REQUIRED IMPLEMENTATIONS

### 2. Video Recording (CRITICAL - NOT IMPLEMENTED)

**Problem:** `handleCaptureEvent()` in `amb-mini/amb-mini.ino` lines 1197-1205 only emits phase messages but does NOT record video.

**Current broken code:**
```cpp
// Lines 1197-1205 - BUG: No actual recording!
if (videoSec > 0) {
  emitEventPhase("video_start", trigger, 0, snapshotCount, videoSec, true);
  unsigned long videoEnd = millis() + static_cast<unsigned long>(videoSec) * 1000UL;
  while (millis() < videoEnd) {
    pumpMqtt();
    vTaskDelay(pdMS_TO_TICKS(50));  // Just waits - NO actual recording!
  }
  emitEventPhase("video_end", trigger, 0, snapshotCount, videoSec, true);
  // MISSING: No queueClipUpload() call!
}
```

**Required implementation:**
1. Record MJPEG/MP4 video from camera stream for `videoSec` seconds
2. Store frames in buffer/PSRAM
3. Call `queueClipUpload()` after recording completes
4. Video duration: 5 seconds

**Reference:** Look for existing `queueClipUpload()` function in amb-mini.ino and use it similarly to how `queueThumbnailUpload()` is used for photos.

---

### 3. New Capture Timing Behavior (MAJOR CHANGE)

**Current behavior:** Takes 10 photos rapidly (~200ms apart), then waits for video duration

**New required behavior:**

```
TIMELINE:
T+0s:   PIR triggers, weight >= 80g detected (bird lands)
T+0s:   Take Photo #1 immediately
T+5s:   Start 5-second video recording
T+10s:  Video ends, queue for upload
T+15s:  Take Photo #2 (if bird still present)
T+30s:  Take Photo #3 (if bird still present)
T+45s:  Take Photo #4 (if bird still present)
T+60s:  Take Photo #5 (if bird still present)
T+75s:  Take Photo #6 (if bird still present)
T+90s:  Take Photo #7 (if bird still present)
T+105s: Take Photo #8 (if bird still present)
T+120s: Take Photo #9 (if bird still present)
T+135s: Take Photo #10 (max) OR stop early if bird leaves
```

---

### 4. Bird Departure Detection (ESP32 Changes)

**File:** `skyfeeder/visit_service.cpp`

**Current code:** `evaluateSmallMotion()` (lines 65-89) fires a single capture and resets.

**New requirement:** Track bird presence throughout capture session:

1. Store initial bird weight when capture starts
2. Monitor for departure: `PIR LOW` AND `currentWeight < (baseline + birdWeight * 0.5)`
3. Send photo commands every 15 seconds while bird present
4. Send stop command when bird departs

**Add to VisitService class (visit_service.h):**
```cpp
private:
  bool capture_session_active_ = false;
  float bird_weight_g_ = 0;
  float capture_baseline_g_ = 0;
  unsigned long capture_start_ms_ = 0;
  unsigned long last_photo_ms_ = 0;
  uint8_t photo_count_ = 0;
```

**Modify visit_service.cpp loop():**
```cpp
// After existing code, add capture session management:
if (capture_session_active_) {
  unsigned long now = millis();
  float current = SF::weight.weightG();

  // Check for bird departure
  bool pir_low = !SF::motion.isTriggered();  // or appropriate method
  float bird_remaining = current - capture_baseline_g_;

  if (pir_low && bird_remaining < (bird_weight_g_ * 0.5f)) {
    // Bird left
    SF_captureStop(photo_count_);
    capture_session_active_ = false;
    Serial.println("[visit] Bird departed, capture stopped");
  } else if (photo_count_ < 10 && (now - last_photo_ms_ >= 15000)) {
    // Take next photo every 15 seconds
    photo_count_++;
    SF_capturePhoto(photo_count_);
    last_photo_ms_ = now;
  } else if (now - capture_start_ms_ >= 150000) {
    // Max duration (150s) reached
    SF_captureStop(photo_count_);
    capture_session_active_ = false;
    Serial.println("[visit] Max capture duration reached");
  }
}
```

**Modify evaluateSmallMotion() to start capture session:**
```cpp
void VisitService::evaluateSmallMotion(unsigned long now, float currentWeight) {
  // ... existing validation code ...

  // Start capture session
  capture_session_active_ = true;
  capture_baseline_g_ = small_event_baseline_;
  bird_weight_g_ = currentWeight - capture_baseline_g_;
  capture_start_ms_ = now;
  last_photo_ms_ = now;
  photo_count_ = 1;

  // Send capture_start (takes first photo + schedules video at T+5s)
  if (SF_captureStart("pir", bird_weight_g_)) {
    last_small_event_ms_ = now;
  } else {
    capture_session_active_ = false;
  }
}
```

---

### 5. New Command Functions (ESP32 - command_handler.cpp)

**Add new functions to command_handler.cpp:**

```cpp
bool SF_captureStart(const char* trigger, float weight_g) {
  StaticJsonDocument<128> doc;
  doc["op"] = "capture_start";
  doc["trigger"] = trigger;
  doc["weight_g"] = weight_g;

  String json;
  serializeJson(doc, json);
  Mini.println(json);
  Serial.print("[cmd] TX: ");
  Serial.println(json);
  return pumpMiniWhileWaiting(5000);
}

bool SF_capturePhoto(uint8_t index) {
  StaticJsonDocument<128> doc;
  doc["op"] = "capture_photo";
  doc["index"] = index;

  String json;
  serializeJson(doc, json);
  Mini.println(json);
  Serial.print("[cmd] TX: ");
  Serial.println(json);
  return true;  // Don't wait - fire and forget
}

bool SF_captureStop(uint8_t total_photos) {
  StaticJsonDocument<128> doc;
  doc["op"] = "capture_stop";
  doc["total_photos"] = total_photos;

  String json;
  serializeJson(doc, json);
  Mini.println(json);
  Serial.print("[cmd] TX: ");
  Serial.println(json);
  return true;
}
```

**Add declarations to command_handler.h:**
```cpp
bool SF_captureStart(const char* trigger, float weight_g);
bool SF_capturePhoto(uint8_t index);
bool SF_captureStop(uint8_t total_photos);
```

---

### 6. AMB82 Command Handlers (amb-mini.ino)

**Add to `processSerialLine()` around line 1224:**

```cpp
if (strcmp(op, "capture_start") == 0) {
  handleCaptureStart(doc);
  return;
}
if (strcmp(op, "capture_photo") == 0) {
  handleCapturePhoto(doc);
  return;
}
if (strcmp(op, "capture_stop") == 0) {
  handleCaptureStop(doc);
  return;
}
```

**Add state variables (near line 130):**
```cpp
// Capture session state
volatile bool gCaptureSessionActive = false;
volatile unsigned long gCaptureStartMs = 0;
volatile bool gVideoRecorded = false;
volatile uint8_t gPhotoCount = 0;
const char* gCaptureTrigger = "cmd";
```

**Implement handlers:**

```cpp
void handleCaptureStart(const JsonDocument& doc) {
  const char* trigger = doc["trigger"] | "cmd";
  float weight = doc["weight_g"] | 0.0f;

  gCaptureSessionActive = true;
  gCaptureStartMs = millis();
  gVideoRecorded = false;
  gPhotoCount = 1;
  gCaptureTrigger = trigger;

  ensureCamera();
  emitEventPhase("start", trigger, 0, 10, 5, true);

  // Take first photo immediately
  bool ok = captureStill();
  if (ok && lockFrameBuffer(pdMS_TO_TICKS(100))) {
    queueThumbnailUpload(lastFrame, lastFrameLen, trigger);
    unlockFrameBuffer();
  }
  emitEventPhase("snapshot", trigger, 1, 10, 0, ok);

  Serial.printf("[capture] Session started, weight=%.1fg\n", weight);
}

void handleCapturePhoto(const JsonDocument& doc) {
  uint8_t index = doc["index"] | 1;

  // Check if we should record video (at T+5s, before Photo #2)
  if (!gVideoRecorded && gCaptureSessionActive &&
      (millis() - gCaptureStartMs >= 5000)) {
    emitEventPhase("video_start", gCaptureTrigger, 0, 10, 5, true);

    // TODO: Implement actual video recording here
    // recordVideo(5);  // 5 seconds
    // queueClipUpload(...);

    // For now, just wait (placeholder)
    unsigned long videoEnd = millis() + 5000UL;
    while (millis() < videoEnd) {
      pumpMqtt();
      vTaskDelay(pdMS_TO_TICKS(50));
    }

    emitEventPhase("video_end", gCaptureTrigger, 0, 10, 5, true);
    gVideoRecorded = true;
  }

  // Take photo
  bool ok = captureStill();
  if (ok && lockFrameBuffer(pdMS_TO_TICKS(100))) {
    queueThumbnailUpload(lastFrame, lastFrameLen, gCaptureTrigger);
    unlockFrameBuffer();
  }
  emitEventPhase("snapshot", gCaptureTrigger, index, 10, 0, ok);
  gPhotoCount = index;
}

void handleCaptureStop(const JsonDocument& doc) {
  uint8_t totalPhotos = doc["total_photos"] | gPhotoCount;

  // Record video if not done yet
  if (!gVideoRecorded && gCaptureSessionActive) {
    emitEventPhase("video_start", gCaptureTrigger, 0, totalPhotos, 5, true);
    // TODO: Actual video recording
    unsigned long videoEnd = millis() + 5000UL;
    while (millis() < videoEnd) {
      pumpMqtt();
      vTaskDelay(pdMS_TO_TICKS(50));
    }
    emitEventPhase("video_end", gCaptureTrigger, 0, totalPhotos, 5, true);
  }

  gCaptureSessionActive = false;
  emitEventPhase("done", gCaptureTrigger, 0, totalPhotos, 5, true);
  Serial.printf("[capture] Session ended, %d photos\n", totalPhotos);
}
```

---

### 7. Telemetry Push (ESP32 → Backend)

**Problem:** iOS Dev page shows null values for Power & Telemetry

**Create `skyfeeder/telemetry_service.cpp`:**

```cpp
#include "telemetry_service.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "power_service.h"
#include "weight_service.h"
#include "config.h"

namespace SF {

static unsigned long lastPushMs = 0;
static const unsigned long PUSH_INTERVAL_MS = 30000;  // 30 seconds

void telemetryLoop() {
  if (WiFi.status() != WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastPushMs < PUSH_INTERVAL_MS) return;
  lastPushMs = now;

  StaticJsonDocument<256> doc;
  doc["packVoltage"] = power.voltage();
  doc["solarWatts"] = power.solarWatts();
  doc["loadWatts"] = power.loadWatts();
  doc["weightG"] = weight.weightG();
  doc["signalStrengthDbm"] = WiFi.RSSI();

  String json;
  serializeJson(doc, json);

  HTTPClient http;
  String url = String(API_BASE_URL) + "/api/telemetry/push?deviceId=" + DEVICE_ID;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  int code = http.POST(json);
  if (code == 200) {
    Serial.println("[telem] Push OK");
  } else {
    Serial.printf("[telem] Push failed: %d\n", code);
  }
  http.end();
}

}  // namespace SF
```

**Create `skyfeeder/telemetry_service.h`:**
```cpp
#pragma once
namespace SF {
  void telemetryLoop();
}
```

**Add to main loop in `skyfeeder.ino`:**
```cpp
#include "telemetry_service.h"

void loop() {
  // ... existing code ...
  SF::telemetryLoop();
}
```

**Backend endpoint:** Verify `/api/telemetry/push` exists in `ops/local/presign-api/src/index.js`. If not, implement:

```javascript
app.post('/api/telemetry/push', async (req, res) => {
  const { deviceId } = req.query;
  const telemetry = req.body;

  // Store in memory or database
  deviceTelemetry.set(deviceId, {
    ...telemetry,
    updatedAt: new Date().toISOString()
  });

  res.json({ ok: true });
});
```

---

## Files to Modify Summary

| Component | File | Changes |
|-----------|------|---------|
| AMB82 | `amb-mini/amb-mini.ino` | Add `handleCaptureStart`, `handleCapturePhoto`, `handleCaptureStop`, video recording |
| ESP32 | `skyfeeder/visit_service.cpp` | Add capture session state machine, bird departure detection |
| ESP32 | `skyfeeder/visit_service.h` | Add state variables |
| ESP32 | `skyfeeder/command_handler.cpp` | Add `SF_captureStart`, `SF_capturePhoto`, `SF_captureStop` |
| ESP32 | `skyfeeder/command_handler.h` | Add function declarations |
| ESP32 | `skyfeeder/telemetry_service.cpp` | New file - HTTP POST telemetry |
| ESP32 | `skyfeeder/telemetry_service.h` | New file - header |
| ESP32 | `skyfeeder/skyfeeder.ino` | Add telemetryLoop() call |
| Backend | `ops/local/presign-api/src/index.js` | Add /api/telemetry/push endpoint if missing |

---

## Validation Checklist

After implementation:

- [ ] `kUploadQueueSlots = 12` confirmed in amb-mini.ino:134
- [ ] ESP32 compiles: `arduino-cli compile --fqbn esp32:esp32:esp32 skyfeeder/skyfeeder.ino`
- [ ] AMB82 compiles: check correct FQBN for your board
- [ ] Photo #1 taken immediately on PIR trigger (weight >= 80g)
- [ ] Video recorded at T+5s (5-second duration)
- [ ] Video appears in MinIO `/skyfeeder/videos/dev1/`
- [ ] Photos taken every 15s while bird present
- [ ] Bird departure stops capture (PIR LOW + 50% weight drop)
- [ ] Max 10 photos per session
- [ ] iOS Dev page shows telemetry values (not null)
- [ ] No `[upload] queue full` messages in serial

---

## Reference Files

- `REPORTS/2025-11-21_SERIAL_VALIDATION_REPORT.md` - Evidence of issues
- `REPORTS/PLAYBOOK.md` - Session log
- `skyfeeder/config.h` - PIR_EVENT_MIN_WEIGHT_G and other constants
- `amb-mini/amb-mini.ino` lines 1164-1208 - Current handleCaptureEvent()
