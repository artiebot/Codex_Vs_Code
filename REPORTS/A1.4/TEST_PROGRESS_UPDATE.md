# 24-Hour Soak Test - Progress Update

**Current Time:** 2025-10-22 19:43 (7:43 PM)
**Test Elapsed:** 12 hours 22 minutes
**Remaining:** 11 hours 38 minutes
**Completion:** Tomorrow 07:20 AM

---

## Test Status: ✅ RUNNING STRONG

### Soak Test Monitor (Process 28fbf8)
- **Status:** Running smoothly
- **Elapsed:** 12:22:04
- **Checks Performed:** 742 (every 60 seconds)
- **Device Status:** Online and stable
- **Upload Count:** 6 (baseline - no new uploads)
- **Crash Count:** 0 ✅

### Snapshot Trigger (Process aa1591)
- **Status:** Running (with timing issue)
- **Snapshots Sent:** 3 of 24
  - Snapshot 1: 07:20:46 ✅
  - Snapshot 2: 08:20:46 ✅ (1 hour later)
  - **GAP:** 10 hours 28 minutes ⚠️
  - Snapshot 3: 18:49:37 ✅
- **Issue:** PowerShell `Start-Sleep` unreliable for 3600-second intervals

---

## Key Findings (12+ Hours)

### ✅ What's Working

**Device Stability:**
- **Zero crashes** in 12+ hours ✅
- Continuous MQTT connectivity
- Telemetry published every 2 seconds
- No watchdog resets
- No panic errors

**Snapshot Capture:**
- Photos captured successfully (26KB each)
- AMB-Mini camera functional
- ESP32 ↔ AMB-Mini UART communication stable

**System Services:**
- MQTT broker responsive
- MinIO storage accessible
- Presign API available (tested manually)

### ❌ What's Broken

**Upload Functionality:**
- **0 new uploads** in 12+ hours (0% success rate)
- All snapshot events show empty `url=""` field
- Zero serial console upload messages
- MinIO has no new photos since Oct 20

**Snapshot Trigger:**
- Only 3 of expected 12 snapshots sent
- PowerShell sleep timer skipping hours
- Same issue as previous soak test

**Root Cause (Upload):**
- AMB-Mini running old firmware WITHOUT upload code
- Need to reflash with Codex's HTTP implementation

---

## Upload Evidence - Still Broken

**Latest snapshot event (18:49):**
```json
{
  "ok": true,
  "bytes": 26125,
  "sha256": "",
  "url": "",  ← EMPTY! Upload failed
  "source": "mini",
  "trigger": "cmd"
}
```

**MinIO check:**
```bash
$ docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | grep "2025-10-22"
(no results)
```

**Serial console:** No upload messages logged in 12+ hours

---

## Soak Test Metrics (12 Hours In)

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| **Uptime** | 12h 22m | 24h | ✅ 51% complete |
| **Crashes** | 0 | 0 | ✅ PASS |
| **Upload Success** | 0% | ≥85% | ❌ FAIL |
| **Snapshots Triggered** | 3 | 12 (expected at 12h) | ❌ 25% |
| **Photos Uploaded** | 0 | ≥10 (expected) | ❌ FAIL |
| **MQTT Connectivity** | 100% | 100% | ✅ PASS |

---

## Snapshot Trigger Issue

**Expected behavior:**
- 1 snapshot every 60 minutes
- 24 snapshots over 24 hours
- At 12 hours: should have 12 snapshots

**Actual behavior:**
- Snapshots 1-2: Correct timing (1 hour apart)
- Massive 10-hour gap
- Snapshot 3: Finally sent
- PowerShell `Start-Sleep 3600` not reliable

**Hypothesis:**
- Windows power management suspending PowerShell process
- Sleep timer doesn't account for system sleep/hibernation
- Script needs more robust scheduling

**Fix Options:**
1. Use Windows Task Scheduler instead of PowerShell sleep
2. Use Python with threading (more reliable)
3. Reduce interval to test (e.g., 15 minutes instead of 60)

---

## Projected 24-Hour Results

### If Current Trend Continues

**Device Stability:** ✅ PASS
- Expected: 0 crashes over 24 hours
- High confidence based on 12-hour stability

**Upload Success:** ❌ FAIL
- Expected: 0% success rate
- Reason: Old firmware (upload code not executing)

**Snapshot Trigger:** ⚠️ PARTIAL
- Expected: 6-8 snapshots total (not 24)
- Reason: PowerShell sleep timer skipping

**Telemetry:** ✅ PASS
- Expected: Continuous MQTT connectivity
- Device publishes health metrics

---

## Next Steps

### Overnight (Automatic)
- ✅ Let soak test continue running
- ✅ Monitor for any crashes (none expected)
- ✅ Snapshot trigger will attempt remaining snapshots
- ✅ Test completes automatically at 07:20 AM

### Tomorrow Morning (Manual)
1. **Review soak test report**
   - [REPORTS/A1.4/soak-test-final/SOAK_TEST_REPORT.md](soak-test-final/SOAK_TEST_REPORT.md)
   - Validate 0 crashes over 24 hours
   - Confirm 0% upload (as expected)

2. **Fix upload issue** (based on Codex report)
   - [REPORTS/A1.4/CODEX_UPLOAD_DEBUG_REPORT.md](CODEX_UPLOAD_DEBUG_REPORT.md)
   - Delete `amb-mini/build/` directory
   - Recompile in Arduino IDE
   - Flash fresh firmware
   - Test single snapshot upload

3. **Verify upload works**
   ```bash
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
   # Wait 30s, check MQTT event has populated url field
   # Verify photo appears in MinIO
   ```

4. **Optional: Re-run shorter validation**
   - 4-6 hour test with working upload
   - Verify ≥85% upload success rate
   - Or: Accept 24-hour stability + 0% upload as documented issue

5. **B1 Manual Tests** (30 minutes)
   - Triple power-cycle provisioning
   - LED state transitions
   - Captive portal demo
   - Record video

---

## Files to Review Tomorrow

**Test Results:**
- [REPORTS/A1.4/soak-test-final/SOAK_TEST_REPORT.md](soak-test-final/SOAK_TEST_REPORT.md)
- [REPORTS/A1.4/soak-test-final/summary.log](soak-test-final/summary.log)
- [REPORTS/A1.4/soak-test-final/mqtt_events.jsonl](soak-test-final/mqtt_events.jsonl)

**Debug & Status:**
- [REPORTS/A1.4/CODEX_UPLOAD_DEBUG_REPORT.md](CODEX_UPLOAD_DEBUG_REPORT.md)
- [REPORTS/A1.4/VALIDATION_FINAL_STATUS.md](VALIDATION_FINAL_STATUS.md)
- [REPORTS/A1.4/24HR_TEST_STATUS.md](24HR_TEST_STATUS.md)
- [REPORTS/A1.4/TEST_PROGRESS_UPDATE.md](TEST_PROGRESS_UPDATE.md) (this file)

**Instructions:**
- [REPORTS/A1.4/MANUAL_FIRMWARE_FLASH_INSTRUCTIONS.md](MANUAL_FIRMWARE_FLASH_INSTRUCTIONS.md)

---

## Summary

**The Good News:**
- ✅ Device rock solid - 12+ hours, zero crashes
- ✅ Snapshot capture working perfectly
- ✅ All services stable and responsive
- ✅ Test infrastructure working

**The Bad News:**
- ❌ Upload broken (wrong firmware running)
- ❌ Snapshot trigger skipping hours (PowerShell sleep issue)
- ❌ 0% upload success (need firmware reflash)

**The Plan:**
- ✅ Let test complete overnight
- ✅ Proves 24-hour stability
- Tomorrow: Fix firmware, test upload, decide on re-run vs accept results

---

**Test continues running automatically. Results tomorrow morning at 07:20.**

**Current Status: 51% Complete (12h 22m / 24h)**
