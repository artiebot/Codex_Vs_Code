# CRITICAL: HTTP Upload Not Implemented in AMB-Mini Firmware

**Status:** 🔴 **BLOCKING** - Core functionality missing
**Discovered:** 2025-10-21 during A1.4 soak test troubleshooting
**Severity:** P0 - Zero uploads possible, blocks all validation

## Summary

The AMB82-Mini camera module firmware has a **stubbed-out upload function** that always returns false. Photos are captured successfully but never uploaded to MinIO/S3, resulting in 0% upload success rate during the 24-hour soak test.

## Root Cause

**File:** [amb-mini/amb-mini.ino:444-454](amb-mini/amb-mini.ino#L444-L454)

```cpp
static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs) {
  unsigned long start = millis();
  Serial.print("[upload] TODO: implement HTTPS upload for kind=");
  Serial.print(slot.kind);
  Serial.print(" bytes=");
  Serial.println(slot.length);
  // Placeholder—replace with HTTPS PUT to Cloudflare R2.
  vTaskDelay(pdMS_TO_TICKS(10));
  elapsedMs = millis() - start;
  return false;  // ← ALWAYS FAILS - NO IMPLEMENTATION!
}
```

**This is a TODO placeholder** with no actual HTTP client code.

## Evidence

### Serial Console Output
```
[mini] << {"mini":"upload","upload":"thumb","status":"pending",...}
[mini] << {"mini":"upload","upload":"thumb","status":"start",...}
[mini] << {"mini":"upload","upload":"thumb","status":"retry","eta_ms":60000...}
[mini] >> {"op":"sleep_deep"}  ← ESP32 sends sleep before retry completes
```

### Soak Test Results
- **Duration:** 21+ hours
- **Photos Captured:** 24+ (via snapshot commands)
- **Uploads Successful:** 0
- **Success Rate:** 0% (target: >= 85%)
- **Last Upload:** 10/20 02:31 (before test, manually triggered)

### Upload Queue Behavior
1. ✅ Photo captured successfully (26KB)
2. ✅ Queued in upload slot with SHA-256 hash
3. ❌ `performUploadAttempt()` called → always returns `false`
4. ⏱️ Retry scheduled for 60 seconds later
5. 💤 ESP32 sends `sleep_deep` after 15 seconds (NOW FIXED: changed to 90s)
6. 🔄 Loop repeats forever - **no uploads ever succeed**

## Architecture Analysis

### Current Design (Missing Implementation)
```
┌─────────────┐  capture   ┌──────────────┐  UART   ┌─────────┐
│  AMB82-Mini │───────────>│ Upload Queue │────────>│  ESP32  │
│   Camera    │  26KB JPG  │ (in memory)  │ status  │         │
└─────────────┘            └──────────────┘         └─────────┘
                                   │
                                   │ TODO: HTTP upload
                                   ▼
                           ┌──────────────┐
                           │ Presign API  │
                           │ (10.0.0.4)   │
                           └──────────────┘
                                   │ signed URL
                                   ▼
                           ┌──────────────┐
                           │    MinIO     │
                           │  (photos/)   │
                           └──────────────┘
```

### Expected Upload Flow
1. Mini captures photo → stored in memory
2. Mini GETs `/v1/discovery/dev1` from presign API
3. Mini POSTs to `/v1/presign/put` with `{"deviceId":"dev1","kind":"photos"}`
4. Presign API returns:
   ```json
   {
     "url": "http://10.0.0.4:8080/fput/<jwt-token>",
     "method": "PUT",
     "headers": {"Content-Type": "image/jpeg"}
   }
   ```
5. Mini PUTs 26KB photo data to signed URL
6. MinIO stores photo at `photos/dev1/2025-10-21T...jpg`
7. Mini reports success via UART telemetry

**Currently stops at step 2 - no HTTP client implementation!**

## Implementation Requirements

### 1. Add Configuration (Hardcoded for Now)
```cpp
// Near top of amb-mini.ino
constexpr char PRESIGN_API_HOST[] = "10.0.0.4";
constexpr uint16_t PRESIGN_API_PORT = 8080;
constexpr char DEVICE_ID[] = "dev1";  // Should come from ESP32 eventually
```

### 2. Implement HTTP Helper Functions
```cpp
// Parse discovery response for presign_base
bool fetchDiscovery(char* presignBaseOut, size_t maxLen);

// POST to /v1/presign/put, parse response for upload URL
bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen);

// PUT binary data to signed URL
bool putToSignedUrl(const char* url, const uint8_t* data, size_t len);
```

### 3. Replace `performUploadAttempt()` Stub
```cpp
static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs) {
  unsigned long start = millis();

  // Step 1: Get presigned URL
  char signedUrl[512];
  if (!requestPresignedUrl(slot.kind, signedUrl, sizeof(signedUrl))) {
    Serial.println("[upload] ERROR: Failed to get presigned URL");
    elapsedMs = millis() - start;
    return false;
  }

  // Step 2: PUT photo data
  if (!putToSignedUrl(signedUrl, slot.data, slot.length)) {
    Serial.println("[upload] ERROR: Failed to PUT data");
    elapsedMs = millis() - start;
    return false;
  }

  Serial.println("[upload] SUCCESS");
  elapsedMs = millis() - start;
  return true;
}
```

### 4. HTTP Client Implementation Notes

**WiFiClient already available** - Mini uses it for HTTP server functionality.

**Example POST to presign API:**
```cpp
bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen) {
  WiFiClient client;

  if (!client.connect(PRESIGN_API_HOST, PRESIGN_API_PORT)) {
    Serial.println("[http] Connect failed");
    return false;
  }

  // Build JSON body
  StaticJsonDocument<128> doc;
  doc["deviceId"] = DEVICE_ID;
  doc["kind"] = kind;
  String body;
  serializeJson(doc, body);

  // Send HTTP POST
  client.println("POST /v1/presign/put HTTP/1.1");
  client.print("Host: "); client.println(PRESIGN_API_HOST);
  client.println("Content-Type: application/json");
  client.print("Content-Length: "); client.println(body.length());
  client.println("Connection: close");
  client.println();
  client.print(body);

  // Read response (parse JSON for "url" field)
  // ... HTTP response parsing code ...

  client.stop();
  return true;
}
```

**Example PUT to signed URL:**
```cpp
bool putToSignedUrl(const char* url, const uint8_t* data, size_t len) {
  // Parse URL to extract host, port, path
  // ... URL parsing ...

  WiFiClient client;
  if (!client.connect(host, port)) return false;

  client.print("PUT ");
  client.print(path);
  client.println(" HTTP/1.1");
  client.print("Host: ");
  client.println(host);
  client.println("Content-Type: image/jpeg");
  client.print("Content-Length: ");
  client.println(len);
  client.println("Connection: close");
  client.println();

  // Write binary data
  client.write(data, len);

  // Read response (expect 204 No Content)
  // ... response parsing ...

  client.stop();
  return true;
}
```

## Related Fixes Applied

### ✅ ESP32 Sleep Timeout Fixed
**File:** [skyfeeder/command_handler.cpp:122](skyfeeder/command_handler.cpp#L122)

**Before:**
```cpp
constexpr unsigned long kMiniIdleSleepMs = 15000;  // 15 seconds
```

**After:**
```cpp
constexpr unsigned long kMiniIdleSleepMs = 90000;  // 90s to allow upload retries
```

**Rationale:** Mini needs 60+ seconds for retry backoff. ESP32 was sending `sleep_deep` after only 15 seconds, interrupting uploads mid-flight.

## Testing Plan

### Unit Tests
1. **Discovery Fetch**
   - Call `curl http://10.0.0.4:8080/v1/discovery/dev1`
   - Verify Mini can parse `presign_base` field

2. **Presign Request**
   - POST `{"deviceId":"dev1","kind":"photos"}` to `/v1/presign/put`
   - Verify Mini receives signed URL

3. **PUT Upload**
   - PUT 26KB test photo to signed URL
   - Verify MinIO shows file: `docker exec skyfeeder-minio mc ls local/photos/dev1/`

### Integration Test
1. Flash updated Mini firmware
2. Flash updated ESP32 firmware (with 90s timeout)
3. Send snapshot command via MQTT
4. Monitor serial console for upload success
5. Verify photo appears in MinIO within 10 seconds

### Soak Test
- Re-run 24-hour soak test
- Target: >= 85% upload success rate
- Expected: ~24 snapshots (1/hour) = 20+ successful uploads

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **HTTP parsing bugs** | Uploads fail with new errors | Add extensive serial logging for debugging |
| **Memory leaks** | Mini crashes after N uploads | Monitor heap usage, ensure proper `client.stop()` |
| **Network errors** | Intermittent failures | Implement exponential backoff (already exists in queue) |
| **URL parsing complexity** | Signed URLs may have complex formats | Test with actual presign API responses |
| **Blocking I/O** | Mini freezes during upload | Use timeouts on all socket operations |

## Dependencies

- **WiFiClient** - Already available in AMB82 SDK
- **ArduinoJson** - Already included for serialization
- **Presign API** - Running at `http://10.0.0.4:8080` ✅
- **MinIO** - Running at `http://10.0.0.4:9200` ✅

## Estimated Effort

- **HTTP client helpers:** 2-3 hours
- **Upload implementation:** 2-3 hours
- **Testing + debugging:** 2-4 hours
- **Total:** 6-10 hours

## Alternative: ESP32 Handles Uploads

**Trade-off:** Send 26KB photo over UART to ESP32, ESP32 does HTTP upload.

**Pros:**
- ESP32 has better HTTP libraries (ESP-IDF)
- Easier debugging with serial console

**Cons:**
- UART transfer adds latency (26KB at 115200 baud = ~2.2 seconds)
- More complex protocol (chunking, flow control)
- Violates separation of concerns (Mini handles camera, ESP32 handles connectivity)

**Recommendation:** Implement HTTP upload in Mini firmware (as originally designed).

## Next Steps

1. ✅ Document issue in this report
2. ⏳ Implement HTTP client functions in Mini firmware
3. ⏳ Test with manual snapshot command
4. ⏳ Re-run 24-hour soak test
5. ⏳ Validate A1.4 upload success rate >= 85%

---

**This is the root cause of 0% upload success during A1.4 soak test.**
