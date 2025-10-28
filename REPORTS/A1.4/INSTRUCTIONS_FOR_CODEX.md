# Instructions for Codex: Implement AMB-Mini HTTP Upload

**Priority:** 🔴 **P0 - BLOCKING A1.4 VALIDATION**
**Estimated Effort:** 6-10 hours
**File to Edit:** `amb-mini/amb-mini.ino`

---

## Problem Summary

The AMB82-Mini camera firmware has a stubbed-out upload function that always returns `false`, causing **0% upload success** during A1.4 soak test (0 of 24+ photos uploaded).

**Current Code (line 444-454):**
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
  return false;  // ← ALWAYS FAILS - REPLACE THIS!
}
```

---

## Task: Implement Real HTTP Upload

### Required Flow
```
1. POST to presign API → get signed URL
2. PUT photo data to signed URL
3. Return true on success, false on failure
```

### Configuration Already Available
- `DEVICE_ID` = "dev1" (line 63)
- Presign API: `http://10.0.0.4:8080`
- WiFiClient: Already included and used for HTTP server

---

## Implementation Steps

### Step 1: Add HTTP Helper Function - Request Presigned URL

Add this function **before** `performUploadAttempt()`:

```cpp
// Request presigned URL from presign API
// Returns true and fills urlOut with signed URL on success
static bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen) {
  const char* PRESIGN_HOST = "10.0.0.4";
  const uint16_t PRESIGN_PORT = 8080;

  WiFiClient client;

  // Connect to presign API
  if (!client.connect(PRESIGN_HOST, PRESIGN_PORT)) {
    Serial.println("[http] Failed to connect to presign API");
    return false;
  }

  // Build JSON body: {"deviceId":"dev1","kind":"photos"}
  StaticJsonDocument<128> reqDoc;
  reqDoc["deviceId"] = DEVICE_ID;
  reqDoc["kind"] = kind;
  String body;
  serializeJson(reqDoc, body);

  // Send HTTP POST
  client.println("POST /v1/presign/put HTTP/1.1");
  client.print("Host: "); client.println(PRESIGN_HOST);
  client.println("Content-Type: application/json");
  client.print("Content-Length: "); client.println(body.length());
  client.println("Connection: close");
  client.println();
  client.print(body);

  // Read response headers (skip until blank line)
  unsigned long timeout = millis() + 5000;
  while (client.connected() && millis() < timeout) {
    String line = client.readStringUntil('\n');
    if (line == "\r") break; // End of headers
  }

  // Read JSON response body
  String responseBody;
  while (client.available()) {
    responseBody += (char)client.read();
  }
  client.stop();

  if (responseBody.length() == 0) {
    Serial.println("[http] Empty response from presign API");
    return false;
  }

  // Parse JSON: {"url":"http://...","method":"PUT",...}
  StaticJsonDocument<512> resDoc;
  DeserializationError error = deserializeJson(resDoc, responseBody);
  if (error) {
    Serial.print("[http] JSON parse error: ");
    Serial.println(error.c_str());
    return false;
  }

  const char* url = resDoc["url"];
  if (!url) {
    Serial.println("[http] No 'url' field in response");
    return false;
  }

  // Copy URL to output buffer
  strncpy(urlOut, url, maxLen - 1);
  urlOut[maxLen - 1] = '\0';

  Serial.print("[http] Got presigned URL: ");
  Serial.println(urlOut);
  return true;
}
```

### Step 2: Add HTTP Helper Function - Upload to Signed URL

Add this function **after** `requestPresignedUrl()`:

```cpp
// Upload binary data to presigned URL
// Returns true on successful upload (HTTP 204)
static bool putToSignedUrl(const char* url, const uint8_t* data, size_t len) {
  // Parse URL: http://10.0.0.4:8080/fput/TOKEN
  // Extract host, port, path

  if (strncmp(url, "http://", 7) != 0) {
    Serial.println("[http] URL must start with http://");
    return false;
  }

  const char* hostStart = url + 7;
  const char* pathStart = strchr(hostStart, '/');
  if (!pathStart) {
    Serial.println("[http] Invalid URL format");
    return false;
  }

  // Extract host and port
  char host[64];
  size_t hostLen = pathStart - hostStart;
  if (hostLen >= sizeof(host)) hostLen = sizeof(host) - 1;
  strncpy(host, hostStart, hostLen);
  host[hostLen] = '\0';

  // Check for port in host (e.g., "10.0.0.4:8080")
  uint16_t port = 80;
  char* colon = strchr(host, ':');
  if (colon) {
    *colon = '\0';
    port = atoi(colon + 1);
  }

  String path = pathStart;  // Keep full path including query params

  Serial.print("[http] Uploading to ");
  Serial.print(host);
  Serial.print(":");
  Serial.print(port);
  Serial.print(path);
  Serial.print(" (");
  Serial.print(len);
  Serial.println(" bytes)");

  WiFiClient client;

  // Connect
  if (!client.connect(host, port)) {
    Serial.println("[http] Failed to connect to upload host");
    return false;
  }

  // Send HTTP PUT request
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

  // Write binary data in chunks
  const size_t CHUNK_SIZE = 1024;
  size_t written = 0;
  while (written < len) {
    size_t toWrite = min(CHUNK_SIZE, len - written);
    size_t actualWritten = client.write(data + written, toWrite);
    written += actualWritten;

    if (actualWritten != toWrite) {
      Serial.println("[http] Write error");
      client.stop();
      return false;
    }
  }

  Serial.print("[http] Wrote ");
  Serial.print(written);
  Serial.println(" bytes");

  // Read response status line
  unsigned long timeout = millis() + 5000;
  while (!client.available() && millis() < timeout) {
    delay(10);
  }

  String statusLine = client.readStringUntil('\n');
  client.stop();

  Serial.print("[http] Response: ");
  Serial.println(statusLine);

  // Check for success (HTTP 204 No Content or 200 OK)
  bool success = (statusLine.indexOf("204") > 0 || statusLine.indexOf("200") > 0);

  if (!success) {
    Serial.println("[http] Upload failed - unexpected status");
  }

  return success;
}
```

### Step 3: Replace `performUploadAttempt()` Stub

Replace the entire function (lines 444-454) with:

```cpp
static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs) {
  unsigned long start = millis();

  Serial.print("[upload] Starting upload: kind=");
  Serial.print(slot.kind);
  Serial.print(" bytes=");
  Serial.println(slot.length);

  // Step 1: Get presigned URL
  char signedUrl[512];
  if (!requestPresignedUrl(slot.kind, signedUrl, sizeof(signedUrl))) {
    Serial.println("[upload] ERROR: Failed to get presigned URL");
    elapsedMs = millis() - start;
    return false;
  }

  // Step 2: Upload photo data
  if (!putToSignedUrl(signedUrl, slot.data, slot.length)) {
    Serial.println("[upload] ERROR: Failed to PUT data");
    elapsedMs = millis() - start;
    return false;
  }

  Serial.println("[upload] ✓ SUCCESS");
  elapsedMs = millis() - start;
  return true;
}
```

---

## Testing Instructions

### 1. Build and Flash Mini Firmware
```bash
# Use Arduino IDE or platform tool to compile and flash
# Target: AMB82-Mini board
```

### 2. Flash Updated ESP32 Firmware (Sleep Timeout Already Fixed)
```bash
# ESP32 sleep timeout already increased to 90s
# File: skyfeeder/command_handler.cpp:122
# Just rebuild and flash skyfeeder.ino
```

### 3. Manual Test - Single Snapshot

**Option A: WebSocket (Production Method)**
```bash
# Install wscat if needed: npm install -g wscat

# Connect and send snapshot command
wscat -c "ws://10.0.0.4:8081?deviceId=dev1" \
  --execute '{"cmd":"snapshot"}'

# Monitor serial console for upload logs
# Expected output:
#   [upload] Starting upload: kind=thumb bytes=26125
#   [http] Got presigned URL: http://10.0.0.4:8080/fput/...
#   [http] Uploading to 10.0.0.4:8080/fput/... (26125 bytes)
#   [http] Wrote 26125 bytes
#   [http] Response: HTTP/1.1 204 No Content
#   [upload] ✓ SUCCESS

# Verify file in MinIO
docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive
# Should show new photo with current timestamp
```

**Option B: MQTT (Development/Testing Only - Being Deprecated)**
```bash
# For quick local testing only - DO NOT use in production
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
  -t "skyfeeder/dev1/cmd/camera" \
  -m '{"op":"snapshot"}'
```

**Note:** ESP32 firmware currently listens to both MQTT and WebSocket. MQTT is legacy and will be removed in future versions.

### 4. Re-run 24-Hour Soak Test
```bash
# Kill existing soak test
# Start fresh test
powershell -File tools\soak-test-24h.ps1 -DeviceId dev1 -DurationHours 24 -OutputDir REPORTS\A1.4\soak-test

# Start snapshot trigger (1 per hour)
# NOTE: This script uses MQTT for convenience - update to WebSocket for production
powershell -File tools\trigger-periodic-snapshots.ps1 -IntervalSeconds 3600 -Count 24 -DeviceId dev1

# After 24 hours, check report
cat REPORTS\A1.4\soak-test\SOAK_TEST_REPORT.md
# Expected: Success rate >= 85% (target: 20+ of 24 uploads)
```

**TODO for Production:** Replace MQTT trigger script with WebSocket-based command sender.

---

## Error Handling Notes

### Common Issues to Watch For

1. **Memory Leaks**
   - Ensure `client.stop()` called in all code paths
   - Monitor heap usage: `Serial.println(ESP.getFreeHeap())`

2. **Timeouts**
   - HTTP operations have 5-second timeouts built in
   - If network slow, may need to increase

3. **URL Parsing Edge Cases**
   - Presign API might return different URL formats
   - Test with actual responses from `/v1/presign/put`

4. **JSON Buffer Overflow**
   - `StaticJsonDocument<512>` may be too small for long URLs
   - Increase if needed: `StaticJsonDocument<1024>`

5. **WiFi Disconnects**
   - Upload will fail gracefully
   - Retry queue will automatically retry after backoff

---

## Success Criteria

✅ **Unit Test:** Single snapshot command → photo appears in MinIO within 10 seconds
✅ **Soak Test:** 24-hour test with >= 85% upload success rate
✅ **No Memory Leaks:** Device stable after 100+ uploads
✅ **Serial Logs:** Clear success/failure messages for debugging

---

## Related Fixes Already Applied

✅ **ESP32 Sleep Timeout:** Increased from 15s → 90s
   - File: `skyfeeder/command_handler.cpp:122`
   - Allows Mini to complete 60-second retry backoff

✅ **Soak Test Script:** PowerShell pipe parsing fixed
   - File: `tools/soak-test-24h.ps1`
   - Ready to run 24-hour test

---

## Questions?

- **Why not HTTPS?** Presign API currently returns `http://` URLs. Add TLS later.
- **Why not ESP32 upload?** Mini is designed to handle its own uploads independently.
- **What about R2/Cloudflare?** Same flow works - presign API will return R2 URLs when deployed.

---

## Validation Status After Fix

| Phase | Status | Notes |
|-------|--------|-------|
| **A1.4 Soak Test** | ⏳ Ready to re-run | After upload implementation |
| **A1.4 Upload Success** | 🎯 Target: >= 85% | Expected: ~20/24 snapshots |
| **B1 Provisioning** | ⏳ Manual testing | Triple power-cycle, LED, video |
| **A1.4 Power** | ⏳ Hardware hookup | INA260 sensor measurements |

---

**Once upload is implemented, A1.4 validation can complete successfully.**
