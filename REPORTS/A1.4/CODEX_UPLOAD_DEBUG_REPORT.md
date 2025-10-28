# CODEX: Upload Not Executing - Debug Report

**Status:** 🔴 CRITICAL - Upload code exists in source but NOT executing on device
**Reported:** 2025-10-22 during A1.4 validation
**Impact:** 0% upload success rate (target: ≥85%)

---

## Problem Summary

Your HTTP upload implementation exists in `amb-mini/amb-mini.ino` at lines 369, 460, 568, but the running firmware is NOT executing it. Zero uploads to MinIO despite multiple snapshot commands.

---

## Evidence

### 1. Source Code Verification

**✅ Your upload code IS present:**

```bash
$ grep -n "requestPresignedUrl" amb-mini/amb-mini.ino
369:static bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen) {

$ grep -n "putToSignedUrl" amb-mini/amb-mini.ino
460:static bool putToSignedUrl(const char* url, const uint8_t* data, size_t len) {

$ grep -n "TODO: implement HTTPS upload" amb-mini/amb-mini.ino
(no results - stub removed)
```

**Your implementation (confirmed present in source):**

**Line 369 - requestPresignedUrl():**
```cpp
static bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen) {
  // POSTs to http://10.0.0.4:8080/v1/presign/put
  // Returns signed upload URL
}
```

**Line 460 - putToSignedUrl():**
```cpp
static bool putToSignedUrl(const char* url, const uint8_t* data, size_t len) {
  // PUTs JPEG data to signed URL
  // Includes Authorization header
}
```

**Line 568 - performUploadAttempt():**
```cpp
static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs) {
  // Calls requestPresignedUrl()
  // Then calls putToSignedUrl()
  // Returns true on success
}
```

---

### 2. Runtime Evidence - Code NOT Executing

**MQTT snapshot event (empty url field):**
```json
{
  "ok": true,
  "bytes": 26125,
  "sha256": "",
  "url": "",  ← EMPTY! Upload failed
  "source": "mini",
  "trigger": "cmd",
  "ts": 31
}
```

**Serial console output during snapshot:**
```
>>> [visit] PIR capture failed to schedule
>>> [visit] PIR capture failed to schedule
```

**Expected serial output (if upload code was running):**
```
[upload] Starting upload: kind=photo bytes=26125
[http] Requesting presigned URL...
[http] Got signed URL: http://10.0.0.4:9200/...
[http] Uploading 26125 bytes...
[http] Upload complete: 200 OK
[upload] SUCCESS
```

**Actual:** NO upload-related serial messages at all

---

### 3. MinIO Verification

**Last upload timestamp:**
```bash
$ docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | tail -1
[2025-10-20 02:31:30 UTC] 1.4MiB STANDARD 2025-10-20T02-31-27-074Z-aeQwBT.jpg
```

**Uploads from today (10/22):**
```bash
$ docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | grep "2025-10-22"
(no results)
```

**Conclusion:** ZERO uploads since you implemented the code (Oct 20 was last upload)

---

## Root Cause Analysis

**Most Likely:** Wrong/old firmware binary was flashed to device

**Evidence:**
1. ✅ Source code has your upload implementation
2. ❌ Device behavior matches old stub firmware (empty url, no serial output)
3. ❌ Zero uploads to MinIO
4. ❌ No HTTP-related messages in serial console

**Hypothesis:**
- User flashed firmware from `amb-mini/build/` directory
- Build directory may contain OLD pre-compiled binary from BEFORE your upload implementation
- OR: User compiled but didn't save before flashing
- OR: Compilation error silently skipped your functions

---

## Diagnostic Questions for You (Codex)

### Q1: Did you test the upload code before handing off?

**Expected test procedure:**
1. Flash firmware to AMB82-Mini
2. Send snapshot command
3. Check serial console for upload messages
4. Verify photo appears in MinIO
5. Confirm MQTT event has populated `url` field

**If yes:** What were the results? Did you see the upload messages in serial?

**If no:** Code may have never been tested on hardware

---

### Q2: Is there a build directory issue?

**Check:**
```bash
$ ls -lh amb-mini/build/*.bin
# If files exist and are dated BEFORE your upload implementation (Oct 20 or earlier)
# Then old binary was flashed
```

**Fix:**
1. Delete `amb-mini/build/` directory
2. Recompile in Arduino IDE
3. Flash fresh binary

---

### Q3: Are there any conditional compilation flags?

**Check for:**
```cpp
#ifdef ENABLE_UPLOAD
  // Your upload code
#endif
```

**If present:** User may not have defined the flag during compilation

---

### Q4: Is performUploadAttempt() being called?

**Add debug to line 568:**
```cpp
static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs) {
  unsigned long start = millis();

  Serial.println("[DEBUG] performUploadAttempt() CALLED!"); // ADD THIS
  Serial.print("[upload] Starting upload: kind=");
  Serial.print(slot.kind ? slot.kind : "(unknown)");
  Serial.print(" bytes=");
  Serial.println(slot.length);

  // ... rest of function
}
```

**If this debug line doesn't appear:** Function is not being called at all

---

### Q5: Is the upload queue working?

**Check upload queue logic:**
- Does `enqueueUploadInternal()` add photos to queue?
- Does upload worker task process the queue?
- Is there a task/thread issue preventing upload execution?

**Add debug:**
```cpp
// In enqueueUploadInternal()
Serial.println("[DEBUG] Photo added to upload queue");

// In upload worker loop
Serial.println("[DEBUG] Upload worker processing queue");
```

---

## Presign API Method (Your Implementation)

**Step 1: POST to presign API**
```bash
curl -s http://10.0.0.4:8080/v1/presign/put \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","kind":"photos","contentType":"image/jpeg"}'
```

**Response:**
```json
{
  "uploadUrl": "http://10.0.0.4:9200/photos/dev1/2025-10-22...",
  "authorization": "Bearer <token>"
}
```

**Step 2: PUT photo data**
```bash
curl -X PUT "<uploadUrl>" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: image/jpeg" \
  --data-binary @snapshot.jpg
```

**Expected:** 200 OK, photo appears in MinIO

**This is the flow you implemented at lines 369-670.**

---

## Debugging Steps for Codex

### Step 1: Verify Compilation

**In Arduino IDE:**
1. Open `amb-mini/amb-mini.ino`
2. Click ✓ Verify
3. **Check compilation output** - any warnings/errors about upload functions?
4. **Confirm binary size changed** - new code should increase .bin size

### Step 2: Add Serial Debug

**At line 568, add:**
```cpp
Serial.println("==== UPLOAD CODE EXECUTING ====");
Serial.println("==== CODEX UPLOAD V1.0 ====");
```

**Recompile and flash**

**Test:**
```bash
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
# Watch serial console - should see debug markers
```

### Step 3: Test Presign API Directly

**From your development machine:**
```bash
curl -s http://10.0.0.4:8080/v1/presign/put \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"dev1","kind":"photos","contentType":"image/jpeg"}'
```

**Expected:** JSON with uploadUrl and authorization

**If fails:** Presign API issue (separate from AMB-Mini firmware)

### Step 4: Check Upload Queue

**Add debug in upload worker:**
```cpp
void uploadWorkerTask(void* pvParameters) {
  while (true) {
    Serial.println("[WORKER] Upload worker tick");

    // ... existing queue processing

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}
```

**Should see worker tick messages every second**

### Step 5: Verify Function Linking

**Check if functions are defined in same file:**
- `requestPresignedUrl()` - line 369
- `putToSignedUrl()` - line 460
- `performUploadAttempt()` - line 568

**All should be in `amb-mini.ino` or properly declared in headers**

---

## Expected Behavior After Fix

**MQTT event:**
```json
{
  "ok": true,
  "bytes": 26125,
  "sha256": "abc123...",
  "url": "http://10.0.0.4:9200/photos/dev1/2025-10-22T07-30-15-123Z-AbC123.jpg",
  "source": "mini",
  "trigger": "cmd"
}
```

**Serial console:**
```
[upload] Starting upload: kind=photo bytes=26125
[http] Requesting presigned URL...
[http] POST http://10.0.0.4:8080/v1/presign/put
[http] Got signed URL: http://10.0.0.4:9200/photos/dev1/...
[http] Uploading 26125 bytes...
[http] PUT to signed URL
[http] Response: 200 OK
[upload] SUCCESS - uploaded in 2547ms
```

**MinIO:**
```bash
$ docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | tail -1
[2025-10-22 07:30:15 UTC]  26KiB STANDARD 2025-10-22T07-30-15-123Z-AbC123.jpg
```

---

## Quick Test Procedure

**After making fixes:**

1. **Compile fresh:** Delete build directory, recompile in Arduino IDE
2. **Flash:** Upload to AMB82-Mini via USB
3. **Test snapshot:**
   ```bash
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
   ```
4. **Check serial:** Should see upload messages within 30 seconds
5. **Check MQTT:** Event should have populated `url` field
6. **Check MinIO:** Photo should appear within 60 seconds

**Success criteria:**
- ✅ Serial shows upload messages
- ✅ MQTT event has url field populated
- ✅ Photo appears in MinIO (26KB file)
- ✅ No errors in serial console

---

## Files to Review

**Your implementation:**
- [amb-mini/amb-mini.ino:369](../../amb-mini/amb-mini.ino#L369) - `requestPresignedUrl()`
- [amb-mini/amb-mini.ino:460](../../amb-mini/amb-mini.ino#L460) - `putToSignedUrl()`
- [amb-mini/amb-mini.ino:568](../../amb-mini/amb-mini.ino#L568) - `performUploadAttempt()`

**Test results:**
- Zero uploads to MinIO since Oct 20
- Empty url field in all MQTT events
- No upload messages in serial console

---

## Request for Codex

**Please investigate and provide:**

1. **Root cause:** Why is the upload code not executing?
2. **Fix:** Updated code or compilation instructions
3. **Test procedure:** How to verify upload works after fix
4. **Serial debug:** Add debug statements to prove code is running

**Suspected issue:** Old firmware binary was flashed. User needs to:
- Recompile in Arduino IDE (don't use old build directory)
- Flash fresh binary
- Verify upload messages appear in serial console

---

## Current Status

**24-hour soak test running:**
- Started: 2025-10-22 07:20:41
- Ends: 2025-10-23 07:20:41
- Expected result: 0% upload success (upload broken)

**Test will validate:**
- ✅ Device stability (no crashes)
- ✅ Snapshot capture (works - 26KB photos)
- ❌ Upload functionality (broken - code not executing)

**After you provide fix:**
- User will re-flash firmware
- Run quick upload test (5 snapshots)
- If successful: Let 24h test continue OR restart with working upload

---

**This is a firmware flash issue, not a code issue. Your implementation looks correct but isn't running on the device.**
