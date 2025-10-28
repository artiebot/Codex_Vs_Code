# Manual Firmware Flash Instructions

**Date:** 2025-10-21
**Required Before:** A1.4 validation can proceed

---

## Overview

Both firmwares need to be flashed:

1. **AMB82-Mini:** Contains Codex's HTTP upload implementation (lines 369, 460, 568)
2. **ESP32:** Contains 90-second sleep timeout fix (line 122)

**Total Time:** ~10-15 minutes

---

## Prerequisites

- Arduino IDE 2.x installed
- ESP32 board support installed
- Realtek AMB board support installed
- Both devices connected via USB:
  - ESP32 on COM4
  - AMB82-Mini on COM port (TBD - check Arduino IDE)

---

## Part 1: Flash AMB82-Mini (HTTP Upload Fix)

### Step 1: Open AMB-Mini Sketch

1. Launch Arduino IDE
2. File → Open → Navigate to:
   ```
   D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\amb-mini\amb-mini.ino
   ```
3. Click Open

### Step 2: Verify Upload Code Present

**CRITICAL:** Verify these lines exist in the open sketch:

- **Line 369:** `static bool requestPresignedUrl(const char* kind, char* urlOut, size_t maxLen)`
- **Line 460:** `static bool putToSignedUrl(const char* url, const uint8_t* data, size_t len)`
- **Line 568:** `static bool performUploadAttempt(const UploadSlot& slot, unsigned long& elapsedMs)`

If you don't see proper implementations (just "TODO: implement HTTPS upload"), the code hasn't been updated. Ask Codex to implement it again.

### Step 3: Configure Board

1. Tools → Board → Realtek Ameba Boards → **RTL8735B(M)**
2. Tools → Port → Select the AMB82-Mini COM port
3. Tools → Upload Speed → 115200

### Step 4: Compile and Flash

1. Click ✓ (Verify) to compile
   - Wait for "Done compiling"
   - Check console for errors
2. Click → (Upload) to flash
   - Wait for "Done uploading"
   - AMB-Mini will reboot automatically

### Step 5: Verify Flash Success

Monitor serial output (Tools → Serial Monitor, 115200 baud):
```
Should see:
- Boot messages
- WiFi connection
- UART link with ESP32
```

---

## Part 2: Flash ESP32 (90s Sleep Timeout)

### Step 1: Open ESP32 Sketch

1. File → Open → Navigate to:
   ```
   D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\skyfeeder\skyfeeder.ino
   ```
2. Click Open

### Step 2: Verify Sleep Timeout Fix

**CRITICAL:** Check [skyfeeder/command_handler.cpp:122](../../skyfeeder/command_handler.cpp#L122)

Should read:
```cpp
constexpr unsigned long kMiniIdleSleepMs = 90000;  // 90s to allow upload retries
```

If it says `15000`, change it to `90000`.

### Step 3: Configure Board

1. Tools → Board → ESP32 Arduino → **ESP32 Dev Module**
2. Tools → Port → **COM4**
3. Tools → Upload Speed → 115200
4. Tools → Erase All Flash Before Sketch Upload → **Enabled** (IMPORTANT!)

### Step 4: Compile and Flash

1. Click ✓ (Verify) to compile
   - Wait for "Done compiling"
   - Compilation takes ~1-2 minutes
2. Click → (Upload) to flash
   - Wait for "Connecting..."
   - May need to press BOOT button on ESP32
   - Progress bar will show upload
   - Wait for "Done uploading"

### Step 5: Verify Flash Success

Monitor serial output (Tools → Serial Monitor, 115200 baud):

**Expected Output:**
```
=== SKYFEEDER BOOT DEBUG ===
setup() reached!
Free heap: 250936
...
Provisioning initialized!
Provisioning ready - starting MQTT...
MQTT initialized!
=== SETUP COMPLETE ===
WiFi connected: YES
MQTT connected: YES
```

**CRITICAL:** Device should NOT crash after "Provisioning ready - starting MQTT...". If it crashes here, there's still a firmware bug.

---

## Part 3: Verification Test

### Test Upload Functionality

1. Keep both devices connected and serial monitors open
2. Send snapshot command via MQTT:
   ```powershell
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
   ```

3. **Watch AMB-Mini serial output** for:
   ```
   [upload] Starting upload: kind=photo bytes=26125
   [http] Requesting presigned URL...
   [http] Got signed URL: http://10.0.0.4:9200/photos/...
   [http] Uploading 26125 bytes...
   [http] Upload complete: 200 OK
   [upload] SUCCESS
   ```

4. **Watch MQTT output** for:
   ```json
   skyfeeder/dev1/event/camera/snapshot {
     "ok":true,
     "bytes":26125,
     "sha256":"<hash>",
     "url":"http://10.0.0.4:9200/photos/dev1/...",
     "source":"mini",
     "trigger":"cmd"
   }
   ```

   **CRITICAL:** `url` field should NO LONGER be empty!

5. **Verify in MinIO:**
   ```powershell
   docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | Sort-Object -Descending | Select-Object -First 1
   ```

   Should show a new photo uploaded within the last minute.

---

## Success Criteria

- ✅ AMB-Mini compiles and uploads without errors
- ✅ ESP32 compiles and uploads without errors
- ✅ ESP32 boots cleanly (no MQTT init crash)
- ✅ Test snapshot command succeeds
- ✅ AMB-Mini serial shows HTTP upload flow (not "TODO")
- ✅ MQTT event shows populated `url` field
- ✅ Photo appears in MinIO within 60 seconds

---

## If Errors Occur

### Compilation Errors

**AMB-Mini:**
- Check that `ArduinoJson` and `PubSubClient` libraries are installed
- Tools → Manage Libraries → Search and install

**ESP32:**
- Check that all header files are present
- Verify board support package is up to date

### Upload Errors

**"Upload Error: Connecting..."**
- Press and hold BOOT button on ESP32 during upload
- Release after "Connecting..." appears

**"Port COM4 busy"**
- Close any serial monitors or other programs using the port
- Disconnect/reconnect USB cable

### Runtime Errors

**ESP32 crashes after "starting MQTT..."**
- This is the MQTT init bug - see [CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md](CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md)
- May need debugging of MQTT initialization code

**AMB-Mini still shows "TODO: implement HTTPS upload"**
- Codex's code wasn't saved or wasn't in the sketch
- Re-implement or ask Codex to provide the code again

**Upload fails with presign API error**
- Check presign API is running: `curl http://10.0.0.4:8080/health`
- Check MinIO is running: `docker ps | grep minio`

---

## After Successful Flash

Proceed to:
1. ✅ [Test single snapshot upload](VALIDATION_PLAN.md#test-upload-functionality)
2. ✅ [Run INA260 power measurements](VALIDATION_PLAN.md#a14-power-measurements)
3. ✅ [Start 24-hour soak test #2](VALIDATION_PLAN.md#re-run-24-hour-soak-test)

**Estimated time for post-flash validation:** ~26-27 hours (mostly automated soak test)

---

**These instructions assume Arduino IDE is already configured. If not, refer to project setup docs.**
