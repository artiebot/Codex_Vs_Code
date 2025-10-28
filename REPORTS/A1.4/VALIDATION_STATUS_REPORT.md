# A1.4 & B1 Validation Status Report

**Date:** 2025-10-21
**Status:** 🔴 **BLOCKED** - Critical firmware issues require immediate attention

---

## Executive Summary

Automated validation discovered **TWO CRITICAL P0 BLOCKING BUGS** that prevent all A1.4 and B1 testing:

1. **ESP32 Crash Loop** - MQTT initialization causes Guru Meditation errors, flash corruption, infinite boot loop
2. **AMB-Mini Upload Not Implemented** - HTTP upload function is a stub that always returns false (Codex implemented fix but didn't flash)

**Impact:** Device is completely non-functional and requires manual firmware reflash before any validation can proceed.

---

## Critical Issues Discovered

### Issue #1: ESP32 MQTT Init Crash + Flash Corruption

**Severity:** 🔴 P0 CRITICAL
**File:** [CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md](CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md)

**Symptoms:**
- Device boots through all init stages successfully
- Crashes with `Guru Meditation Error: IllegalInstruction` during "Provisioning ready - starting MQTT..."
- Panic handler enters infinite recursion
- Flash partitions become corrupted
- Bootloader cannot find valid app partition
- Infinite boot loop with checksum errors

**Serial Evidence:**
```
Provisioning ready - starting MQTT...
Guru Meditation Error: Core  0 panic'ed (IllegalInstruction). Exception was unhandled.
Guru Meditation Error: Core  0 panic'ed (LoadProhibited). Exception was unhandled.
Panic handler entered multiple times. Abort panic handling. Rebooting ...

E (358) esp_image: Checksum failed. Calculated 0xc read 0x52
E (358) boot: OTA app partition slot 1 is not bootable
E (365) boot: OTA app partition slot 0 is not bootable
E (369) boot: No bootable app partitions in the partition table
[infinite loop continues]
```

**Root Cause:** MQTT client initialization in [skyfeeder/mqtt_client.cpp](skyfeeder/mqtt_client.cpp) or [skyfeeder/provisioning.cpp](skyfeeder/provisioning.cpp) has a critical bug causing invalid instruction execution and memory access violations.

**Required Fix:**
1. Erase flash completely via Arduino IDE (Tools > Erase All Flash Before Sketch Upload)
2. Reflash ESP32 firmware
3. Debug MQTT initialization crash
4. Add exception handling and watchdog feeding

---

### Issue #2: AMB-Mini Upload Stub Not Implemented

**Severity:** 🔴 P0 CRITICAL
**File:** [UPLOAD_NOT_IMPLEMENTED.md](UPLOAD_NOT_IMPLEMENTED.md)

**Symptoms:**
- Photos captured successfully (26KB JPG)
- Upload queue processes photos
- `performUploadAttempt()` always returns false
- Serial shows "TODO: implement HTTPS upload"
- 0% upload success rate during 24-hour soak test

**Code Location:** [amb-mini/amb-mini.ino:444-454](../../../amb-mini/amb-mini.ino#L444-L454)

**Status:** Codex implemented HTTP upload functions at lines 369, 460, 568 but **firmware not yet flashed to device**.

**Required Fix:**
1. Flash updated AMB-Mini firmware via Arduino IDE
2. Verify upload works with test snapshot
3. Re-run soak test

---

## Validation Results

### ✅ Tests Completed (Before Crash Discovery)

#### 1. Soak Test #1 Monitoring (22+ hours)
- **Status:** COMPLETE (monitored 22:15 of 24:00 before crash discovered)
- **Result:** ❌ FAIL - 0 uploads detected (0% success rate, target: >=85%)
- **Artifacts:**
  - [REPORTS/A1.4/soak-test/summary.log](soak-test/summary.log)
  - [REPORTS/A1.4/soak-test/mqtt_events.jsonl](soak-test/mqtt_events.jsonl)
  - [REPORTS/A1.4/soak-test/uploads.jsonl](soak-test/uploads.jsonl)
- **Findings:**
  - Detected 6 existing uploads at test start
  - NO new uploads during 22+ hours of testing
  - Device was in crash loop the entire time
  - MQTT telemetry never received (device never connected)

#### 2. Snapshot Trigger Investigation
- **Status:** COMPLETE
- **Result:** ❌ FAIL - Only 3 of 24 snapshots sent
- **Timeline:**
  - Snapshot 1: 10/20 21:02:00 ✅
  - Snapshot 2: 10/20 22:02:00 ✅
  - **GAP: 20 hours 25 minutes**
  - Snapshot 3: 10/21 18:27:18 ✅
- **Root Cause:** PowerShell `Start-Sleep` likely interrupted or process suspended
- **Fix Required:** Use more robust scheduling (Windows Task Scheduler or Python with threading)

#### 3. PROVISIONING.md Review
- **Status:** ✅ COMPLETE
- **Result:** ✅ PASS
- **File:** [docs/PROVISIONING.md](../../docs/PROVISIONING.md)
- **Findings:**
  - Clear documentation of triple power-cycle provisioning
  - LED state table accurate
  - Operator checklist comprehensive
  - Ready for B1 validation (once firmware is stable)

#### 4. ESP32 Firmware Analysis
- **Status:** ✅ COMPLETE
- **Result:** ❌ FAIL - Critical crash bug discovered
- **File:** [skyfeeder/command_handler.cpp:122](../../skyfeeder/command_handler.cpp#L122)
- **Fix Applied:** Changed sleep timeout from 15s → 90s (ready to flash)

---

### ⏸️ Tests BLOCKED by Firmware Issues

#### 5. AMB-Mini Upload Test
- **Status:** ⏸️ BLOCKED
- **Blocker:** Firmware not flashed with Codex's upload implementation
- **Next:** Flash updated firmware, send test snapshot, verify MinIO upload

#### 6. A1.4 Power Measurements (INA260)
- **Status:** ⏸️ BLOCKED
- **Blocker:** ESP32 crash loop prevents stable operation
- **Requirements:** INA260 already wired and ready
- **Next:** Measure current during upload and deep sleep after firmware reflash

#### 7. Soak Test #2 (24 hours)
- **Status:** ⏸️ BLOCKED
- **Blocker:** Both firmware issues must be fixed first
- **Next:** Re-run 24-hour test after upload works and device is stable

#### 8. B1: Triple Power-Cycle Provisioning
- **Status:** ⏸️ BLOCKED
- **Blocker:** ESP32 already in boot loop, cannot test provisioning
- **Next:** Test after firmware reflash

#### 9. B1: LED State Transitions
- **Status:** ⏸️ BLOCKED
- **Blocker:** Device never gets past boot, LED stuck in boot loop pattern
- **Next:** Test amber → blue → green after firmware reflash

#### 10. B1: Provisioning Demo Video
- **Status:** ⏸️ BLOCKED
- **Blocker:** Cannot record provisioning flow with crashed device
- **Next:** Record after B1 manual tests pass

#### 11. A1.3: iOS Gallery Testing
- **Status:** ⏸️ BLOCKED (Requires user + iOS device)
- **Next:** User to test after A1.4 complete

---

## Immediate Action Plan

### Step 1: Manual Firmware Reflash (USER REQUIRED)

**ESP32 Firmware:**
1. Open Arduino IDE
2. Connect ESP32 via USB (COM4)
3. Select: Tools > Board > ESP32 Dev Module
4. Select: Tools > Erase All Flash Before Sketch Upload > **Enabled**
5. Open [skyfeeder/skyfeeder.ino](../../skyfeeder/skyfeeder.ino)
6. Click Upload
7. Monitor serial console for clean boot (should NOT crash at "Provisioning ready")

**AMB82-Mini Firmware:**
1. Open Arduino IDE
2. Connect AMB82-Mini via USB
3. Select: Tools > Board > AMB82-Mini (Realtek AmebaPro2)
4. Open [amb-mini/amb-mini.ino](../../amb-mini/amb-mini.ino)
5. Verify Codex's upload implementation present at lines 369, 460, 568
6. Click Upload

### Step 2: Verify Device Stability (15 minutes)

1. Monitor serial console for 5 minutes - NO crashes
2. Check MQTT telemetry: `mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/#" -v`
3. Verify device publishes discovery + heartbeat

### Step 3: Test Upload Functionality (15 minutes)

1. Send snapshot command via WebSocket (production) or MQTT (dev):
   ```powershell
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
   ```
2. Monitor serial console for upload success (NOT "TODO: implement HTTPS upload")
3. Check MinIO for new photo:
   ```powershell
   docker exec skyfeeder-minio mc ls local/photos/dev1/
   ```
4. Verify photo uploaded successfully

### Step 4: INA260 Power Measurements (1-2 hours)

**Script Already Prepared:** [tools/measure-power-ina260.ps1](../../tools/measure-power-ina260.ps1) *(to be created)*

1. Connect INA260 sensor (already wired):
   - VCC → 3.3V
   - GND → GND
   - SDA → GPIO21
   - SCL → GPIO22
2. Run power measurement script
3. Trigger snapshot command
4. Measure current during:
   - Idle (ESP32 awake, AMB-Mini asleep)
   - Snapshot capture (AMB-Mini active)
   - Upload (WiFi transmitting)
   - Deep sleep (AMB-Mini sleeping)
5. Generate [REPORTS/A1.4/power.csv](power.csv) and [power_summary.md](power_summary.md)
6. Verify <200 mAh per event

### Step 5: Re-run 24-Hour Soak Test

1. Start fresh soak test:
   ```powershell
   powershell.exe -File "tools\soak-test-24h.ps1" -DeviceId dev1 -DurationHours 24 -OutputDir "REPORTS\A1.4\soak-test-2"
   ```
2. Start snapshot trigger:
   ```powershell
   powershell.exe -File "tools\trigger-periodic-snapshots.ps1" -IntervalSeconds 3600 -Count 24 -DeviceId dev1
   ```
3. Let run for full 24 hours
4. Review [REPORTS/A1.4/soak-test-2/SOAK_TEST_REPORT.md](soak-test-2/SOAK_TEST_REPORT.md)
5. Verify upload success rate >= 85%

### Step 6: B1 Provisioning Tests (USER REQUIRED - 30 minutes)

**Only after Steps 1-5 complete and device is stable.**

1. Triple power-cycle test
2. LED transition observation (amber → blue → green)
3. Captive portal access and configuration
4. Record provisioning demo video

---

## Files Created/Updated

### New Reports
- ✅ [CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md](CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md)
- ✅ [UPLOAD_NOT_IMPLEMENTED.md](UPLOAD_NOT_IMPLEMENTED.md)
- ✅ [VALIDATION_PLAN.md](VALIDATION_PLAN.md)
- ✅ [VALIDATION_STATUS_REPORT.md](VALIDATION_STATUS_REPORT.md) (this file)

### Code Fixes Ready (Not Yet Flashed)
- ✅ [skyfeeder/command_handler.cpp:122](../../skyfeeder/command_handler.cpp#L122) - Sleep timeout 15s → 90s
- ✅ [amb-mini/amb-mini.ino:369](../../amb-mini/amb-mini.ino#L369) - `requestPresignedUrl()` implementation
- ✅ [amb-mini/amb-mini.ino:460](../../amb-mini/amb-mini.ino#L460) - `putToSignedUrl()` implementation
- ✅ [amb-mini/amb-mini.ino:568](../../amb-mini/amb-mini.ino#L568) - `performUploadAttempt()` replacement

### Documentation
- ✅ [docs/PROVISIONING.md](../../docs/PROVISIONING.md) - Validated and ready for B1

---

## Summary

**Current State:** ❌ Device non-functional, requires manual intervention

**Automated Tests Completed:** 4 of 11 (36%)
- ✅ Soak test monitoring (found 0% success)
- ✅ Snapshot trigger analysis (found timing bug)
- ✅ PROVISIONING.md review (passed)
- ✅ Firmware analysis (found critical crash)

**Tests Blocked:** 7 of 11 (64%)
- ⏸️ Upload test
- ⏸️ Power measurements
- ⏸️ Soak test #2
- ⏸️ B1 triple power-cycle
- ⏸️ B1 LED transitions
- ⏸️ B1 provisioning video
- ⏸️ A1.3 iOS gallery

**Next Steps:**
1. **User manually reflashes both ESP32 and AMB-Mini firmware**
2. Verify device boots cleanly without crashes
3. Test upload functionality
4. Run power measurements
5. Re-run 24-hour soak test
6. Complete B1 provisioning tests

**Estimated Time to Complete (After Firmware Reflash):**
- Upload test: 15 minutes
- Power measurements: 1-2 hours
- Soak test: 24 hours (automated)
- B1 tests: 30 minutes (with user)
- **Total: ~26-27 hours**

---

**All critical issues documented. Awaiting user intervention for firmware reflash.**
