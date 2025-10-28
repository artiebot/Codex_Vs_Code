# A1.4 Validation Execution Plan
**Date:** 2025-10-21
**Status:** IN PROGRESS

## Firmware Status

**AMB-Mini:** Codex implemented HTTP upload (lines 369, 460, 568)
**ESP32:** Sleep timeout already fixed (90s)

**Issue:** Cannot flash firmware automatically - no Arduino CLI/IDE access via command line.

## Workaround: Test If Already Flashed

Codex may have already flashed the updated firmware. Let me test:

### Test 1: Send Snapshot & Monitor Upload
- Send snapshot command via WebSocket or MQTT
- Monitor serial console for upload logs
- Check MinIO for new photo

**If upload succeeds:** Firmware already updated ✅
**If upload fails:** Need user to flash firmware manually

---

## Tests I Can Execute Now

### ✅ Automated Tests (No User Needed)

1. **Test Current Firmware Upload**
   - Send snapshot command
   - Monitor serial + MQTT
   - Check MinIO
   - **Time:** 5 minutes

2. **INA260 Power Measurements**
   - Monitor current during snapshot + upload
   - Measure deep sleep current
   - Generate power.csv and power_summary.md
   - **Time:** 30-60 minutes

3. **Review Soak Test #1 Results**
   - Wait for completion (~20:52)
   - Analyze SOAK_TEST_REPORT.md
   - **Time:** 10 minutes

4. **Start Soak Test #2**
   - Fresh 24-hour test
   - Monitor upload success rate
   - **Time:** 24 hours (automated)

5. **Fix Snapshot Trigger**
   - Debug why only 3/24 sent
   - Restart trigger script
   - **Time:** 30 minutes

6. **Review PROVISIONING.md**
   - Validate documentation
   - **Time:** 10 minutes

### ❌ Manual Tests (Need User Tomorrow)

7. **B1: Triple Power-Cycle**
   - Physically unplug/replug ESP32 3x quickly
   - Verify captive portal appears
   - **Time:** 5 minutes
   - **User:** Must physically access hardware

8. **B1: LED Transitions**
   - Watch LED: amber → blue → green
   - Wait 2 min for AUTO mode
   - **Time:** 3 minutes
   - **User:** Must observe LED strip

9. **B1: Provisioning Video**
   - Screen record provisioning flow
   - Save as provisioning_demo.mp4
   - **Time:** 10 minutes
   - **User:** Must record video

10. **A1.3: iOS Gallery**
    - Build LOCAL gallery app
    - Test Save to Photos
    - Verify badge counts
    - **Time:** 30 minutes
    - **User:** Requires iOS device

---

## Execution Order

### Tonight (Next 3 Hours)
1. ✅ Test snapshot upload (determine firmware status)
2. ✅ INA260 power measurements
3. ✅ Start soak test #2 (if upload works)
4. ✅ Review soak test #1 when completes
5. ✅ Review PROVISIONING.md

### Tomorrow Morning
6. ❌ B1 manual validations (with user)
7. ❌ A1.3 iOS validations (with user)
8. ✅ Review soak test #2 results (24h later)

---

## Status Tracking

| Test | Status | Result | Notes |
|------|--------|--------|-------|
| Test snapshot upload | ⏳ STARTING | TBD | Checking if firmware updated |
| INA260 power measure | ⏳ PENDING | TBD | After upload test |
| Soak test #1 review | ⏳ PENDING | TBD | Completes ~20:52 |
| Soak test #2 start | ⏳ PENDING | TBD | After upload test |
| PROVISIONING.md review | ⏳ PENDING | TBD | Quick review |
| B1 manual tests | ⏳ TOMORROW | TBD | Requires user |
| A1.3 iOS tests | ⏳ TOMORROW | TBD | Requires user |

---

## If Firmware NOT Updated

**Manual Flash Required:**
1. Open Arduino IDE
2. Load `amb-mini/amb-mini.ino`
3. Select board: AMB82-Mini (Realtek AmebaPro2)
4. Compile and upload
5. Repeat for `skyfeeder/skyfeeder.ino`
6. Then proceed with tests

**User can do this tomorrow if needed.**
