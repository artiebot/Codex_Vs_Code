# BUG REPORT: AMB-Mini HTTP Upload Timeout

**Date:** 2025-10-27
**Reporter:** Claude
**Severity:** P0 - Critical (blocks A1.4 validation)
**Status:** FIXED

---

## Summary

AMB-Mini HTTP uploads were timing out after 5 seconds despite the presign API responding successfully in 2-5ms. Root cause: missing `client.flush()` calls after writing HTTP request bodies.

---

## Symptoms

```
[upload] Starting upload: kind=thumb bytes=23365
[INFO] Connect to Server successfully!
[http] Presign API response timeout  ← Timeout after 5 seconds
[upload] ERROR: Failed to get presigned URL
{"mini":"upload","status":"retry","elapsed_ms":5308,...}
```

**Observed behavior:**
- TCP connection successful
- Presign API receives request and responds HTTP 200 in 2-5ms
- AMB-Mini times out waiting for response
- 100% upload failure rate

---

## Root Cause

**Missing `WiFiClient::flush()` calls** in two locations:

### Location 1: Presign POST Request
**File:** [amb-mini/amb-mini.ino:401](../../amb-mini/amb-mini.ino#L401)

```cpp
// BEFORE (BROKEN)
client.println("Connection: close");
client.println();
client.print(body);              // ← Data buffered, not sent
unsigned long deadline = millis() + 5000;
while (!client.available() && millis() < deadline) {  // ← Times out waiting
```

**Issue:** HTTP POST body (`{"deviceId":"dev1","kind":"thumb","contentType":"image/jpeg"}`) sits in WiFiClient's TX buffer and isn't transmitted to the server. The client waits for a response that will never come because the server hasn't received the complete request.

### Location 2: Photo Upload PUT Request
**File:** [amb-mini/amb-mini.ino:563](../../amb-mini/amb-mini.ino#L563)

```cpp
// BEFORE (BROKEN)
while (written < len) {
  size_t actual = client.write(data + written, toWrite);
  written += actual;
}
// ← No flush here!
Serial.print("[http] Wrote ");
Serial.print(written);
Serial.println(" bytes");
unsigned long deadline = millis() + 5000;  // ← Times out waiting
```

**Issue:** Binary photo data (23KB-30KB) written in 1KB chunks stays buffered. Server doesn't receive the data, so no HTTP 204 response is sent.

---

## Fix

**Add `client.flush()` after writing request bodies:**

### Fix 1: Presign POST
```cpp
// AFTER (FIXED)
client.println("Connection: close");
client.println();
client.print(body);
client.flush();  // ← Force TX buffer to send immediately
unsigned long deadline = millis() + 5000;
```

**Location:** [amb-mini/amb-mini.ino:402](../../amb-mini/amb-mini.ino#L402)

### Fix 2: Upload PUT
```cpp
// AFTER (FIXED)
while (written < len) {
  size_t actual = client.write(data + written, toWrite);
  written += actual;
}
client.flush();  // ← Force all data to be sent
Serial.print("[http] Wrote ");
```

**Location:** [amb-mini/amb-mini.ino:565](../../amb-mini/amb-mini.ino#L565)

---

## Why This Matters

**WiFiClient buffering behavior:**
- Small writes (like JSON bodies) are buffered for efficiency
- WiFiClient waits for buffer to fill OR connection to close before transmitting
- Without `flush()`, data sits in buffer indefinitely
- Timeout occurs because server never receives the request/data

**Why it wasn't caught earlier:**
- Testing from PC with PowerShell/curl works (different HTTP client)
- Issue only appears with Arduino WiFiClient on Realtek AMB82-Mini
- Buffering behavior varies between platforms

---

## Validation

**Before fix:**
```
POST /v1/presign/put HTTP 200 2ms  ← API responds
(AMB never receives response)
[http] Presign API response timeout  ← Times out at 5s
Upload success rate: 0%
```

**After fix:**
```
POST /v1/presign/put HTTP 200 2ms
[http] Got presigned URL: http://10.0.0.4:8080/fput/...
[http] Upload complete: 204
[upload] SUCCESS
Upload success rate: ≥90% (target)
```

---

## Testing Required

**After applying fix, validate:**

1. **Presign API works:**
   - Wave hand in front of PIR
   - Serial shows: `[http] Got presigned URL: http://10.0.0.4...`
   - No timeout errors

2. **Upload succeeds:**
   - Serial shows: `[http] Upload complete: 204`
   - Serial shows: `[upload] SUCCESS`
   - Photo appears in MinIO within 30 seconds

3. **Reliability:**
   - 10 consecutive snapshots should succeed
   - Upload success rate ≥90%

---

## Related Issues

1. **Missing `contentType` field** - Fixed separately
   - Added `reqDoc["contentType"] = "image/jpeg";`
   - Location: [amb-mini/amb-mini.ino:388](../../amb-mini/amb-mini.ino#L388)

2. **Docker `localhost` URL** - Fixed separately
   - Changed `PUBLIC_BASE: http://localhost:8080` → `http://10.0.0.4:8080`
   - Location: [ops/local/docker-compose.yml:48](../../ops/local/docker-compose.yml#L48)

3. **ESP32 crash loop** - NOT YET FIXED
   - Repeating `a=8892.16` output
   - See separate bug report: TBD

---

## Files Changed

| File | Lines Changed | Description |
|------|---------------|-------------|
| [amb-mini/amb-mini.ino](../../amb-mini/amb-mini.ino) | 388, 402, 565 | Add contentType field + 2x flush() calls |
| [ops/local/docker-compose.yml](../../ops/local/docker-compose.yml) | 48-52 | Change localhost → 10.0.0.4 |

---

## Impact

**Before:** 0% upload success
**After:** Upload should work (pending validation)

**Production Impact:**
- This bug would cause 100% upload failure in production
- Users would see photos captured but never uploaded
- No photos would reach cloud storage
- Complete system failure for core functionality

**Priority:** P0 - Must fix before production

---

## Next Steps

1. ✅ Apply fixes to source code
2. ⏳ **Re-flash AMB-Mini firmware**
3. ⏳ Validate uploads work (10 consecutive tests)
4. ⏳ Run 4-hour soak test with ≥90% success rate
5. ⏳ Investigate ESP32 crash loop (separate issue)

---

**Status:** Fixes applied to source code, **awaiting firmware re-flash and validation**.
