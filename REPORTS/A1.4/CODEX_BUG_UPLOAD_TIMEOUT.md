# CODEX BUG REPORT: AMB-Mini Upload Timeout - Unable to Upload Photos

**Date:** 2025-10-27
**Reporter:** User + Claude
**Severity:** **P0 CRITICAL** - Blocks A1.4 validation, 100% upload failure
**Status:** **UNRESOLVED** - Multiple attempted fixes failed

---

## Executive Summary

AMB-Mini HTTP uploads fail 100% of the time with "Presign API response timeout" after 5 seconds, despite the backend presign API responding successfully in 2-5ms. Multiple root cause attempts and fixes have been applied but the issue persists. **Production-blocking issue.**

---

## Symptoms

**Serial Output (AMB-Mini COM4):**
```
19:48:45.216 -> [upload] Starting upload: kind=thumb bytes=24387
19:48:45.252 -> [INFO] Connect to Server successfully!  ← TCP connects
19:48:50.254 -> [http] Presign API response timeout     ← Times out at 5s
19:48:50.254 -> [upload] ERROR: Failed to get presigned URL
19:48:50.287 -> {"mini":"upload","upload":"thumb","status":"retry",...}
```

**Backend Logs (Docker presign-api):**
```
[0mPOST /v1/presign/put [32m200[0m 2.111 ms - 738[0m  ← API responds OK
[0mPOST /v1/presign/put [32m200[0m 3.308 ms - 738[0m
[0mPOST /v1/presign/put [32m200[0m 4.009 ms - 738[0m
```

**Observed Behavior:**
- ✅ TCP connection succeeds (AMB → presign API)
- ✅ Presign API receives requests and responds HTTP 200 in 2-5ms
- ❌ AMB-Mini never receives the response
- ❌ AMB times out after 5 seconds
- ❌ **Upload success rate: 0%**

---

## Environment

**Hardware:**
- ESP32 DevKit (main controller)
- AMB82-Mini (Realtek AmebaPro2 camera module)
- Connected via UART (Serial3)
- PIR sensor for motion detection

**Software:**
- AMB-Mini firmware: [amb-mini/amb-mini.ino](../../amb-mini/amb-mini.ino)
- ESP32 firmware: [skyfeeder/skyfeeder.ino](../../skyfeeder/skyfeeder.ino)
- Presign API: Node.js Express server in Docker
- MinIO S3 storage: Docker container

**Network:**
- AMB-Mini IP: 10.0.0.197
- Presign API: 10.0.0.4:8080
- MinIO: 10.0.0.4:9200
- All on same local network

**Tooling:**
- Arduino IDE (for AMB82-Mini)
- PlatformIO/Arduino IDE (for ESP32)
- Docker Desktop (backend services)

---

## Reproduction Steps

### Step 1: Start Backend Services
```bash
cd ops/local
docker compose up -d
```

Verify services running:
```bash
docker ps
# Should show: skyfeeder-presign-api, skyfeeder-minio
```

### Step 2: Flash AMB-Mini Firmware
1. Open Arduino IDE
2. Open `amb-mini/amb-mini.ino`
3. Select Board: AMB82-MINI (RTL8735B)
4. Tools → Port → Select AMB COM port
5. Upload firmware

### Step 3: Flash ESP32 Firmware
1. Open `skyfeeder/skyfeeder.ino`
2. Select Board: ESP32 Dev Module
3. Upload firmware

### Step 4: Trigger Upload
**Method A:** PIR motion trigger
- Wave hand in front of PIR sensor
- Wait for AMB to wake and capture photo

**Method B:** MQTT command (doesn't wake AMB from deep sleep)
```powershell
.\amb-mini\scripts\mqtt-snap-stdin.ps1
```

### Step 5: Monitor Serial Output
```powershell
python -c "import serial; ser = serial.Serial('COM4', 115200); while True: print(ser.readline().decode('utf-8', errors='ignore'), end='')"
```

### Expected Result
```
[upload] Starting upload: kind=thumb bytes=24387
[http] Presign status: HTTP/1.1 200 OK
[http] Got presigned URL: http://10.0.0.4:8080/fput/...
[http] Uploading to 10.0.0.4:8080/fput/... (24387 bytes)
[http] Upload complete: 204
[upload] SUCCESS  ← Should see this
```

### Actual Result
```
[upload] Starting upload: kind=thumb bytes=24387
[INFO] Connect to Server successfully!
[http] Presign API response timeout  ← Times out instead
[upload] ERROR: Failed to get presigned URL
```

---

## Attempted Fixes (ALL FAILED)

### Fix 1: Add Missing `contentType` Field
**Issue:** Presign API was rejecting requests with HTTP 400 due to missing `contentType`

**Fix Applied:** [amb-mini/amb-mini.ino:388](../../amb-mini/amb-mini.ino#L388)
```cpp
reqDoc["deviceId"] = DEVICE_ID;
reqDoc["kind"] = kind;
reqDoc["contentType"] = "image/jpeg";  // ← Added
```

**Result:** ✅ Stopped JSON parse errors, but timeout persists

---

### Fix 2: Change `localhost` to `10.0.0.4`
**Issue:** Presign API was returning URLs with `http://localhost:8080` which AMB couldn't reach

**Fix Applied:** [ops/local/docker-compose.yml:48](../../ops/local/docker-compose.yml#L48)
```yaml
# BEFORE
PUBLIC_BASE: http://localhost:8080

# AFTER
PUBLIC_BASE: http://10.0.0.4:8080
```

**Validation:**
```bash
curl -X POST http://10.0.0.4:8080/v1/presign/put \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","kind":"thumb","contentType":"image/jpeg"}'

# Response now shows:
{"uploadUrl":"http://10.0.0.4:8080/fput/..."}  ← Correct IP
```

**Result:** ✅ API returns correct URL, but AMB still times out

---

### Fix 3: Add `client.flush()` Calls
**Issue:** WiFiClient buffering might prevent data from being sent

**Fix Applied:**
- [amb-mini/amb-mini.ino:402](../../amb-mini/amb-mini.ino#L402) - After presign POST
- [amb-mini/amb-mini.ino:565](../../amb-mini/amb-mini.ino#L565) - After photo PUT

```cpp
client.print(body);
client.flush();  // ← Added
```

**Result:** ❌ **STILL TIMES OUT** - No change in behavior

---

### Fix 4: Multiple Firmware Re-flashes
User re-flashed AMB-Mini firmware **3+ times** with incremental fixes applied. Issue persists after every re-flash.

---

## Evidence & Analysis

### Evidence 1: Backend API Works Perfectly
**Test from PC:**
```powershell
# Presign API responds in 65ms
Measure-Command { curl.exe -X POST http://10.0.0.4:8080/v1/presign/put ... }
# Result: 64.9573 ms
```

**API Logs:**
```
POST /v1/presign/put [32m200[0m 2.111 ms - 738
POST /v1/presign/put [32m200[0m 3.308 ms - 738
```

✅ **Conclusion:** Presign API works perfectly when tested from PC

---

### Evidence 2: TCP Connection Succeeds
AMB serial output:
```
[INFO] Connect to Server successfully!
```

AMB source code ([amb-mini/amb-mini.ino:380](../../amb-mini/amb-mini.ino#L380)):
```cpp
if (!client.connect(kPresignHost, kPresignPort)) {
  Serial.println("[http] Failed to connect to presign API");
  return false;
}
```

✅ **Conclusion:** TCP connection from AMB to API succeeds

---

### Evidence 3: API Receives Requests
Docker logs show HTTP 200 responses at the exact time AMB attempts upload.

API log timestamps match AMB serial timestamps within 100ms.

✅ **Conclusion:** Requests are reaching the server

---

### Evidence 4: AMB Never Receives Response
AMB code waits for response ([amb-mini/amb-mini.ino:404-410](../../amb-mini/amb-mini.ino#L404-L410)):
```cpp
unsigned long deadline = millis() + 5000;
while (!client.available() && millis() < deadline) {
  vTaskDelay(pdMS_TO_TICKS(10));
}
if (!client.available()) {
  Serial.println("[http] Presign API response timeout");  // ← Always hits this
  client.stop();
  return false;
}
```

`client.available()` returns 0 for entire 5-second timeout period.

❌ **Conclusion:** Response data never arrives in WiFiClient RX buffer

---

## Possible Root Causes (Hypothesis)

### Hypothesis 1: HTTP/1.1 Keep-Alive Issue
**Theory:** AMB sends `Connection: close` but API might be keeping connection alive

**Check:**
```cpp
// Line 399
client.println("Connection: close");
```

**Status:** ⚠️ Needs investigation - Express.js default behavior?

---

### Hypothesis 2: WiFiClient Buffer Size
**Theory:** Response is arriving but WiFiClient buffer is too small or misconfigured

**Status:** ⚠️ Needs investigation - check Realtek WiFiClient implementation

---

### Hypothesis 3: Network MTU/Fragmentation
**Theory:** Response packets are fragmented and WiFiClient can't reassemble

**Status:** ⚠️ Needs packet capture with Wireshark

---

### Hypothesis 4: Realtek WiFi Stack Bug
**Theory:** Bug in Realtek's WiFiClient implementation for request/response pattern

**Status:** ⚠️ Needs comparison with working HTTP client (ESP32 Arduino WiFiClient?)

---

### Hypothesis 5: Timing Issue
**Theory:** `client.available()` called too quickly before TCP stack receives data

**Status:** ⚠️ Try adding delay before checking availability?

---

## Workaround Attempts

### Workaround 1: Use ESP32 as HTTP Proxy
**Idea:** ESP32 fetches presigned URL, sends to AMB via UART

**Status:** Not attempted - would require significant architectural change

---

### Workaround 2: Direct MinIO Upload
**Idea:** Skip presign API, upload directly to MinIO with static credentials

**Status:** Not attempted - less secure, defeats presign purpose

---

## Impact

### Current Impact
- ✅ Device stability: No crashes (ran 24h soak test)
- ✅ Snapshot capture: AMB captures photos successfully
- ✅ MQTT telemetry: Device communicates with backend
- ❌ **Photo upload: 0% success rate**

### Production Impact
- **BLOCKS A1.4 validation** (requires ≥90% upload success)
- **BLOCKS production deployment** (core feature non-functional)
- Users would see device functioning but no photos uploaded
- Photos captured locally but never reach cloud storage

**Severity:** **P0 CRITICAL** - Complete failure of primary functionality

---

## Additional Related Issue: ESP32 Crash Loop

**Separate but also critical:**

ESP32 enters crash loop showing repeating output:
```
a=8892.16
a=8892.16
a=8892.16
```

**Symptoms:**
- Occurs after closing Arduino IDE
- PIR still wakes AMB (ESP32 continues functioning)
- Output suggests watchdog or panic handler recursion

**Impact:** Device unstable, may crash in production

**Status:** Needs separate investigation after upload issue resolved

---

## Files Involved

| File | Purpose | Status |
|------|---------|--------|
| [amb-mini/amb-mini.ino](../../amb-mini/amb-mini.ino) | AMB firmware with upload code | Modified 3x, issue persists |
| [ops/local/docker-compose.yml](../../ops/local/docker-compose.yml) | Presign API config | Fixed (localhost→IP) |
| [skyfeeder/skyfeeder.ino](../../skyfeeder/skyfeeder.ino) | ESP32 main firmware | Has crash issue |

---

## Test Environment Validation

**Presign API test (manual upload works):**
```bash
# Get signed URL
curl -X POST http://10.0.0.4:8080/v1/presign/put \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","kind":"photos","contentType":"image/jpeg"}'

# Response:
{
  "uploadUrl":"http://10.0.0.4:8080/fput/eyJ...",
  "headers":{"Authorization":"Bearer eyJ..."}
}

# Upload photo (using PowerShell)
Invoke-WebRequest -Uri $uploadUrl -Method Put \
  -Headers @{"Authorization"=$auth} -Body $photoBytes

# Result: HTTP 204 Success
```

✅ **Conclusion:** When tested from PC, entire upload pipeline works perfectly

---

## Next Steps for Codex

### Immediate Investigation Needed

1. **Packet Capture**
   - Use Wireshark to capture AMB→API traffic
   - Verify HTTP response actually transmitted
   - Check for TCP retransmissions or errors

2. **WiFiClient Debug**
   - Add debug logging to WiFiClient RX buffer
   - Check if data arrives but isn't available to application
   - Compare with ESP32 WiFiClient behavior (known working)

3. **API Response Format**
   - Verify Express.js response headers
   - Check Content-Length header matches body size
   - Ensure proper HTTP/1.1 response format

4. **Realtek SDK Investigation**
   - Check Realtek WiFiClient known issues
   - Test with different Realtek board SDK versions
   - Compare with Realtek sample HTTP client code

### Alternative Approaches

1. **Switch to ESP32 HTTP Proxy**
   - ESP32 fetches presigned URL (ESP32 WiFiClient works)
   - ESP32 sends URL to AMB via UART
   - AMB uses URL for upload

2. **Use Realtek HTTPClient Library**
   - Instead of raw WiFiClient
   - May have better buffering/parsing

3. **Implement Custom HTTP Parser**
   - Read raw TCP data
   - Parse HTTP response manually
   - Bypass WiFiClient response handling

---

## Validation Criteria

**Upload considered FIXED when:**

1. AMB serial shows:
   ```
   [upload] Starting upload: kind=thumb bytes=XXXXX
   [http] Got presigned URL: http://10.0.0.4:8080/fput/...
   [http] Upload complete: 204
   [upload] SUCCESS
   ```

2. Photos appear in MinIO within 30 seconds of capture

3. **Upload success rate ≥90%** over 10 consecutive tests

4. **4-hour soak test** shows consistent upload success

---

## Summary for Codex

**What works:**
- ✅ Backend API (presign + MinIO)
- ✅ TCP connectivity (AMB→API)
- ✅ Snapshot capture
- ✅ Device stability (24h no crashes)

**What's broken:**
- ❌ AMB WiFiClient never receives HTTP response
- ❌ Upload success rate: 0%
- ❌ ESP32 crash loop (separate issue)

**Attempted fixes (all failed):**
- Added contentType field
- Fixed localhost→IP address
- Added client.flush() calls
- Re-flashed firmware 3+ times

**Root cause:** Unknown - response data not reaching WiFiClient despite API responding correctly

**Priority:** **P0 CRITICAL** - Production blocker

---

**PLEASE INVESTIGATE AND FIX**

This issue has resisted multiple attempts at resolution. The problem appears to be at the WiFiClient or TCP stack level on the Realtek AMB82-Mini platform.

User is frustrated after multiple re-flash cycles. Need fresh eyes and deeper investigation.
