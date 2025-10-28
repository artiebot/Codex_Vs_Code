# A1.4 & B1 Validation Status

**Last Updated:** 2025-10-28 07:19 AM
**Status:** ⏳ **IN PROGRESS** - 24-hour tests running

---

## 📊 Current Test Progress

### **24-Hour Automated Tests** ✅ RUNNING

**Started:** 2025-10-27 20:21:43
**Current:** 2025-10-28 07:19:00 (10h 57m elapsed)
**Remaining:** 13h 02m
**Completion:** 2025-10-28 20:21:43 (Tonight)

#### **Test Status:**

| Test | Status | Progress | Output |
|------|--------|----------|--------|
| Soak Monitor | ✅ Running | 10h 57m / 24h | `24h-final/summary.log` |
| AMB Serial Log | ✅ Running | 10h 57m / 24h | `24h-final/amb-serial.log` |
| ESP32 Serial Log | ✅ Running | 10h 57m / 24h | `24h-final/esp32-serial.log` |
| Power Monitor | ✅ Running | 10h 57m / 24h | `24h-final/power.csv` |
| Snapshot Trigger | ✅ Running | ~22/48 snapshots | Every 30 minutes |

#### **Upload Results So Far:**

- **Total Uploads:** 30 photos
- **Time Period:** 10h 57m
- **Rate:** ~2.7 uploads/hour
- **Expected Final:** ~55 uploads by end of test
- **Success Rate:** TBD (calculating at end of test)

**Target:** ≥90% upload success rate

---

## ✅ What's Complete

### **Upload Fix** ✅
- **Issue:** AMB HTTP timeout - response not reaching WiFiClient
- **Root Cause:** UNKNOWN (documented in bug report)
- **Workaround:** Something made it work (contentType + flush()?)
- **Status:** **WORKING** - 30 uploads confirmed in MinIO
- **Evidence:** Photos uploading successfully, HTTP 204 responses

### **Backend Infrastructure** ✅
- **Presign API:** Working (returns correct URLs)
- **MinIO Storage:** Working (photos persisting)
- **Docker Services:** Running stable
- **MQTT Broker:** Online and reliable
- **Network Configuration:** Fixed (10.0.0.4 instead of localhost)

### **Firmware Updates** ✅
- **AMB-Mini:** Re-flashed with latest code
- **ESP32:** Re-flashed (but has crash issue)
- **Upload Code:** Confirmed present in AMB firmware

---

## ⏳ In Progress

### **24-Hour Soak Test** ⏳
**Status:** 45% complete (10h 57m / 24h)

**Monitoring:**
- Upload success rate (target ≥90%)
- Device crashes (target: 0)
- MQTT connectivity
- Serial output from both devices

**Results Available:** Tonight at 8:21 PM

### **Power Measurements** ⏳
**Status:** Running via INA260 sensor

**Collecting:**
- Snapshot event power consumption
- Upload power consumption
- Deep sleep current
- Peak current measurements

**Target:** <200mAh per event
**Results Available:** Tonight at 8:21 PM

---

## 🚨 Known Issues

### **Issue 1: ESP32 Crash Loop**
**Severity:** P0 CRITICAL
**Report:** [CODEX_BUG_ESP32_CRASH_LOOP.md](CODEX_BUG_ESP32_CRASH_LOOP.md)

**Symptoms:**
- Repeating output: `a=8892.16`
- Occurs after Arduino IDE closes
- PIR still works but system unstable

**Workaround:** Hardware reset (unplug/replug USB)
**Status:** ⚠️ **UNRESOLVED** - Needs Codex investigation

**Impact on Current Test:**
- May see crashes during 24h test
- If crashes occur, workaround is documented
- Serial logs will capture crash data

---

### **Issue 2: Upload Timeout (RESOLVED)**
**Severity:** P0 CRITICAL (was blocking)
**Report:** [CODEX_BUG_UPLOAD_TIMEOUT.md](CODEX_BUG_UPLOAD_TIMEOUT.md)

**Symptoms:**
- AMB HTTP timeout after 5s
- Presign API responds but AMB doesn't receive
- 0% upload success

**Fix Applied:**
- Added `contentType` field to request
- Added `client.flush()` calls
- Fixed Docker PUBLIC_BASE URL

**Status:** ✅ **RESOLVED** - Uploads working!

---

## 📋 Validation Remaining

### **Automated (Will Complete Tonight)**

1. ✅ **24-Hour Soak Test**
   - Started: 2025-10-27 20:21
   - Ends: 2025-10-28 20:21
   - Review results tomorrow night

2. ✅ **Power Measurements**
   - Running alongside soak test
   - Results ready tomorrow night

### **Manual (Requires User)**

3. ⏸️ **B1 Provisioning Tests** (15 minutes)
   - Triple power-cycle test (factory reset)
   - LED transition observation (amber→blue→green)
   - Screen record provisioning flow
   - **When:** After soak test completes

4. ⏸️ **A1.3 iOS Gallery Tests** (30 minutes, optional)
   - Build LOCAL gallery app (Xcode)
   - Test video playback
   - Test "Save to Photos"
   - Verify badge counts
   - **When:** Optional - requires iOS device

---

## 📊 A1.4 Validation Criteria

| Requirement | Target | Current | Status |
|-------------|--------|---------|--------|
| **Upload Success Rate** | ≥90% | TBD (30 uploads so far) | ⏳ Testing |
| **Device Stability** | 24h no crashes | 11h so far | ⏳ Testing |
| **Power Per Event** | <200mAh | TBD | ⏳ Testing |
| **Soak Test Duration** | 24 hours | 11h / 24h | ⏳ Running |

**Can declare PASS/FAIL:** Tomorrow night at 8:21 PM

---

## 📁 Test Data Location

All logs and data in:
```
REPORTS\A1.4\24h-final\
```

**Files:**
- `summary.log` - Soak test progress (330 KB so far)
- `amb-serial.log` - AMB firmware output
- `esp32-serial.log` - ESP32 firmware output
- `power.csv` - Power measurements
- `uploads.jsonl` - Upload event log
- `ws_metrics.jsonl` - WebSocket metrics
- `README.md` - Instructions for checking status

---

## 🔄 Next Steps

### **Tonight (When Tests Complete - 8:21 PM)**

1. **Review Soak Test Results**
   ```powershell
   Get-Content 'REPORTS\A1.4\24h-final\summary.log'
   ```

2. **Calculate Upload Success Rate**
   ```powershell
   $success = (Get-Content 'REPORTS\A1.4\24h-final\amb-serial.log' |
               Select-String "\[upload\] SUCCESS").Count
   $rate = ($success / 48) * 100
   Write-Host "Upload Success Rate: $rate%"
   ```

3. **Check for Crashes**
   ```powershell
   Get-Content 'REPORTS\A1.4\24h-final\esp32-serial.log' |
       Select-String "crash|panic|Guru|a=8892"
   ```

4. **Review Power Data**
   ```powershell
   Import-Csv 'REPORTS\A1.4\24h-final\power.csv' |
       Measure-Object -Property current_mA -Average
   ```

5. **Declare A1.4 PASS or FAIL**
   - If upload rate ≥90% + 0 crashes → **PASS**
   - If upload rate <90% or crashes → **FAIL** (needs fixes)

### **After A1.4 Passes**

6. **B1 Provisioning Tests** (15 min manual)
7. **Optional: A1.3 iOS Gallery** (30 min manual)
8. **Complete A1.4 & B1 Validation**

---

## 🐛 Bug Reports for Codex

**If validation fails, hand these to Codex:**

1. [CODEX_BUG_ESP32_CRASH_LOOP.md](CODEX_BUG_ESP32_CRASH_LOOP.md)
   - ESP32 crash/boot loop issue
   - Repeating `a=8892.16` output
   - P0 CRITICAL - blocks production

2. [CODEX_BUG_UPLOAD_TIMEOUT.md](CODEX_BUG_UPLOAD_TIMEOUT.md)
   - AMB HTTP timeout issue (RESOLVED)
   - Historical reference for future debugging
   - Shows what was tried and what worked

---

## 📝 Notes

### **Why Tests Are Running**
- Started before user left (automated for 24h)
- All tests in minimized PowerShell windows
- Computer must stay on (no sleep mode)
- Serial logs capturing all output

### **What's Being Tested**
- Upload reliability over 24 hours
- Device stability (no crashes)
- Power consumption per event
- MQTT connectivity

### **Expected Outcome**
- Upload success rate ≥90%
- 0 device crashes
- Power <200mAh per event
- Complete A1.4 validation

---

## ✅ Summary

**Current Status:** Tests running successfully for 11 hours

**Progress:**
- ✅ Upload working (30 photos uploaded)
- ✅ Tests stable and running
- ✅ Backend infrastructure healthy
- ⏳ Waiting for 24h completion

**Next Milestone:** Tonight 8:21 PM - Review results and declare PASS/FAIL

**Remaining Work:**
- Review test results (tonight)
- B1 provisioning tests (15 min manual)
- Optional iOS gallery tests

---

**Last Status Check:** 2025-10-28 07:19 AM
**Test Completion:** 2025-10-28 20:21 PM (13h 2m remaining)

**All systems running! 🚀**
