# CRITICAL: ESP32 Watchdog Crash Boot Loop - Blocks All A1.4 Validation

**Status:** 🔴 **BLOCKING** - Device completely non-functional
**Discovered:** 2025-10-21 during 24-hour soak test
**Severity:** P0 - Complete system failure

## Summary

The ESP32 firmware (v1.4.2) enters an infinite boot loop within seconds of startup, repeatedly crashing with watchdog timeout resets. This makes the device completely non-functional and blocks all A1.4 validation including the 24-hour soak test.

## Evidence

### Serial Console Output (Continuous Loop)
```
18:28:36.977 -> rst:0x7 (TG0WDT_SYS_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
18:28:36.977 -> configsip: 0, SPIWP:0xee
18:28:37.022 -> csum err:0x49!=0xff
18:28:37.022 -> ets_main.c 384
18:28:37.289 -> rst:0x7 (TG0WDT_SYS_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
18:28:37.646 -> csum err:0x59!=0xff
18:28:37.646 -> ets_main.c 384
18:28:37.930 -> rst:0x7 (TG0WDT_SYS_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)
[repeats infinitely]
```

### Reset Code Meaning
- **rst:0x7** = `TG0WDT_SYS_RESET` - Timer Group 0 Watchdog timeout
- **csum err** = Flash read checksum mismatch
- **ets_main.c 384** = ESP32 bootloader failing to load app

### Soak Test Results (21+ Hours)
- **Test Duration:** 21h 30m of 24h
- **Uploads Detected:** 0 (target: 20+)
- **Success Rate:** 0% (target: >= 85%)
- **MQTT Reboots:** Multiple offline/online cycles observed
- **Last Successful Upload:** 10/20 02:31 (before test started)

## Root Causes (Suspected)

### 1. Watchdog Timeout
Device takes too long to initialize or loop() function blocking, triggering hardware watchdog.

**Possible Culprits:**
- MQTT client blocking operations
- HTTP client synchronous requests
- Serial/UART communication deadlocks
- Infinite loops in initialization code

### 2. Flash Corruption
Checksum errors suggest:
- Corrupted firmware flash during upload
- Hardware flash memory failure
- Power instability during flash write

### 3. Stack Overflow
Deep call chains or large local variables causing stack corruption.

## Impact

| System | Status | Notes |
|--------|--------|-------|
| **A1.4 Soak Test** | ❌ FAIL | Cannot run for 24 hours, 0 uploads detected |
| **Upload Success Rate** | ❌ 0% | Target: >= 85% |
| **Device Stability** | ❌ FAIL | Continuous crashes |
| **Power Measurements** | ⏸️ BLOCKED | Cannot measure if device non-functional |
| **B1 Provisioning** | ⏸️ BLOCKED | Cannot test LED states if crashing |
| **Field Deployment** | 🚫 BLOCKED | Device unusable |

## Timeline

| Time | Event |
|------|-------|
| 10/20 20:52 | Started 24-hour soak test |
| 10/20 21:02 | First snapshot triggered via MQTT |
| 10/20 21:03-22:45 | Device appeared to boot successfully (some MQTT telemetry) |
| 10/20 22:45-10/21 18:13 | Device offline (likely crashing repeatedly) |
| 10/21 18:13-18:20 | Brief online period, soak test still monitoring |
| 10/21 18:28 | **User reports continuous boot loop on serial console** |

## Attempted Workarounds

1. ❌ **Wait for firmware to stabilize** - Does not recover, infinite loop
2. ⏳ **Power cycle device** - Not yet attempted
3. ⏳ **Reflash firmware** - Not yet attempted
4. ⏳ **Erase NVS** - Not yet attempted

## Recommendations

### Immediate Actions (Codex)

1. **Enable Watchdog Debugging**
   - Add watchdog timer reset calls in main loop
   - Instrument initialization with serial debug points
   - Identify which subsystem is blocking

2. **Check for Blocking Code**
   - Review MQTT client usage (is it using blocking calls?)
   - Review HTTP client operations
   - Check Serial/UART read/write for deadlocks
   - Profile loop() execution time

3. **Verify Flash Integrity**
   - Check compiler optimization flags
   - Verify partition table alignment
   - Test on fresh ESP32 board to rule out hardware

4. **Add Crash Logging**
   - Implement ESP32 exception decoder
   - Store crash dumps in NVS
   - Report crash reason on next boot

### Testing Steps

1. **Reproduce Locally**
   ```
   - Flash firmware v1.4.2 to ESP32
   - Connect serial console (115200 baud)
   - Power on and observe boot sequence
   - Expected: Immediate watchdog crash loop
   ```

2. **Minimal Boot Test**
   ```cpp
   void setup() {
     Serial.begin(115200);
     Serial.println("MINIMAL BOOT TEST");
     // Comment out all subsystems one by one
   }

   void loop() {
     Serial.println("Loop alive");
     delay(1000);
   }
   ```

3. **Watchdog Feed Test**
   ```cpp
   #include <esp_task_wdt.h>

   void setup() {
     esp_task_wdt_init(30, true);  // 30 second watchdog
     esp_task_wdt_add(NULL);
   }

   void loop() {
     esp_task_wdt_reset();  // Feed watchdog
     // ... rest of code
   }
   ```

## Workaround for Validation

Since the ESP32 firmware is currently non-functional:

**Option 1:** Pause A1.4/B1 validation until firmware is stable
**Option 2:** Test only the AMB82-Mini camera module independently
**Option 3:** Rollback to last known stable firmware version

## Files Referenced

- `skyfeeder/skyfeeder.ino` - Main firmware entry point
- `skyfeeder/command_handler.cpp:122` - kMiniIdleSleepMs timeout
- `amb-mini/amb-mini.ino` - Camera module firmware
- `REPORTS/A1.4/soak-test/summary.log` - 21+ hour test log
- `REPORTS/A1.4/soak-test/uploads.jsonl` - Zero uploads recorded

## Next Steps

1. ✅ Document crash in this report
2. ⏳ Share with Codex for immediate fix
3. ⏳ Attempt power cycle + reflash to verify if recoverable
4. ⏳ Wait for firmware fix before continuing A1.4 validation
5. ⏳ Re-run 24-hour soak test with stable firmware

## Related Issues

- **Upload Timing Bug:** ESP32 sleeps AMB-Mini after 15s, but uploads need 60s → IRRELEVANT if device crashes immediately
- **MQTT De-Scope:** MQTT being phased out, but still used for legacy commands → May contribute to blocking
- **Snapshot Trigger Stopped:** Automated snapshots stopped after 2/24 → Expected if ESP32 offline

---

**This issue blocks all further validation work until resolved.**
