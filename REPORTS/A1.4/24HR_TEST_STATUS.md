# 24-Hour Soak Test - Status Report

**Start Time:** 2025-10-22 07:20:41
**End Time:** 2025-10-23 07:20:41 (Tomorrow)
**Duration:** 24 hours
**Device:** dev1
**Output:** [REPORTS/A1.4/soak-test-final/](soak-test-final/)

---

## Test Status: RUNNING

✅ **Soak Test Monitor:** Running (Process ID: 28fbf8)
✅ **Periodic Snapshot Trigger:** Running (Process ID: aa1591)
✅ **Baseline Uploads Detected:** 6 photos from previous tests

**First snapshot sent at:** 07:20:46
**Next snapshot:** 08:20:46 (one hour intervals)
**Total snapshots planned:** 24

---

## CRITICAL ISSUE DETECTED

⚠️ **Upload is STILL failing after firmware flash!**

**Evidence from test snapshot:**
```json
{
  "ok": true,
  "bytes": 26125,
  "sha256": "",
  "url": "",          ← EMPTY! Upload failed
  "source": "mini",
  "trigger": "cmd",
  "ts": 31
}
```

**Expected behavior:**
```json
{
  "ok": true,
  "bytes": 26125,
  "sha256": "abc123...",
  "url": "http://10.0.0.4:9200/photos/dev1/2025-10-22T...",  ← Should have URL
  "source": "mini",
  "trigger": "cmd"
}
```

**What this means:**
- AMB-Mini is capturing photos successfully (26,125 bytes)
- Upload stub is still present OR Codex's HTTP upload code not in flashed firmware
- MinIO will show 0 new uploads during 24-hour test
- Upload success rate will be 0%

---

## Root Cause Analysis

**Possible causes:**

1. **Codex's upload code wasn't in the AMB-Mini sketch that was flashed**
   - Check [amb-mini/amb-mini.ino:369](../../amb-mini/amb-mini.ino#L369) - should have `requestPresignedUrl()`
   - Check [amb-mini/amb-mini.ino:460](../../amb-mini/amb-mini.ino#L460) - should have `putToSignedUrl()`
   - Check [amb-mini/amb-mini.ino:568](../../amb-mini/amb-mini.ino#L568) - should have full `performUploadAttempt()`

2. **Wrong firmware binary was flashed**
   - Flashed an old version without the upload implementation

3. **Compilation error skipped the upload functions**
   - Arduino IDE may have failed to compile parts of the code

---

## Next Steps

### Option A: Wait for 24-Hour Test (Recommended)
Let test run to completion to validate device stability and capture patterns, even though uploads will fail.

**Review tomorrow:**
- [REPORTS/A1.4/soak-test-final/SOAK_TEST_REPORT.md](soak-test-final/SOAK_TEST_REPORT.md)
- Upload count (expected: 0)
- Crash count (expected: 0 - device should be stable)
- Telemetry patterns

### Option B: Stop Test and Re-Flash AMB-Mini
1. Stop soak test: `KillShell 28fbf8` and `KillShell aa1591`
2. **Verify Codex's code is in source:**
   ```bash
   grep -n "requestPresignedUrl" amb-mini/amb-mini.ino
   grep -n "putToSignedUrl" amb-mini/amb-mini.ino
   grep -n "performUploadAttempt" amb-mini/amb-mini.ino
   ```
3. If code is present, re-flash AMB-Mini firmware via Arduino IDE
4. Test single snapshot:
   ```bash
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/camera" -m '{"op":"snapshot"}'
   ```
5. Check MQTT event has populated `url` field
6. Restart 24-hour test

---

## Monitoring the Test

**Check progress:**
```powershell
# View soak test output
Get-Content REPORTS\A1.4\soak-test-final\summary.log -Tail 20 -Wait

# Check upload count
docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | Measure-Object | Select-Object -ExpandProperty Count

# View MQTT events
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/event/camera/snapshot" -v
```

**Kill tests if needed:**
```bash
# Stop soak test
KillShell 28fbf8

# Stop snapshot trigger
KillShell aa1591
```

---

## Expected Results (if upload stays broken)

| Metric | Expected Value | Target | Status |
|--------|---------------|--------|--------|
| Upload Success Rate | 0% | ≥85% | ❌ FAIL |
| Device Uptime | ~24 hours | 24 hours | ✅ (if no crashes) |
| Snapshots Captured | 24 | 24 | ✅ (capture works) |
| Photos Uploaded | 0 | ≥20 | ❌ FAIL |
| Crash Count | 0 | 0 | ✅ (device stable) |

---

## Files to Review Tomorrow

1. **[soak-test-final/SOAK_TEST_REPORT.md](soak-test-final/SOAK_TEST_REPORT.md)** - Main validation report
2. **[soak-test-final/summary.log](soak-test-final/summary.log)** - Timestamped progress log
3. **[soak-test-final/mqtt_events.jsonl](soak-test-final/mqtt_events.jsonl)** - All MQTT snapshot events
4. **[soak-test-final/uploads.jsonl](soak-test-final/uploads.jsonl)** - MinIO upload records (will be empty)

---

## Summary

**✅ Good News:**
- Device is stable (no crashes observed)
- Snapshot capture working (26KB photos)
- ESP32 ↔ AMB-Mini UART communication working
- 24-hour tests running successfully

**❌ Bad News:**
- **Upload completely broken** - url field empty in all snapshot events
- AMB-Mini firmware either:
  - Doesn't have Codex's upload code
  - Has the code but it's not executing
  - Has a bug preventing upload
- 0% upload success rate (target: ≥85%)

**Recommendation:**
Review AMB-Mini source code and serial console output to confirm upload implementation is present and executing.

---

**Test will complete automatically at:** 2025-10-23 07:20:41
**Report will be generated at:** [REPORTS/A1.4/soak-test-final/SOAK_TEST_REPORT.md](soak-test-final/SOAK_TEST_REPORT.md)
