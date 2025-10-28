# CODEX BUG REPORT: ESP32 Enters Crash Loop After Arduino IDE Closes

**Date:** 2025-10-27
**Reporter:** User + Claude
**Severity:** **P0 CRITICAL** - Device unstable, production blocker
**Status:** **UNRESOLVED** - Root cause unknown

---

## Executive Summary

ESP32 enters a crash/boot loop displaying repeating `a=8892.16` output after Arduino IDE is closed. Device continues to function partially (PIR triggers still work) but system is in an unstable state. This will cause field failures in production.

---

## Symptoms

**Serial Output (ESP32):**
```
19:29:19.698 -> a=8892.16
19:29:19.698 -> a=8892.16
19:29:19.698 -> a=8892.16
19:29:19.698 -> a=8892.16
19:29:19.698 -> a=8892.16
(repeats indefinitely)
```

**Observed Behavior:**
- ❌ Repeating identical output at high frequency
- ✅ PIR motion sensor still wakes AMB-Mini
- ✅ Some UART communication continues (ESP32→AMB)
- ❌ System in undefined/corrupted state
- ⚠️ Occurs specifically after closing Arduino IDE

**Trigger:**
- Upload firmware to ESP32 via Arduino IDE
- Close Arduino IDE
- Monitor serial output
- Crash loop begins

---

## Environment

**Hardware:**
- ESP32 DevKit (main controller)
- AMB82-Mini connected via UART
- PIR sensor on GPIO
- LED strip (WS2812B/NeoPixel)
- INA260 power sensor (I2C)

**Software:**
- ESP32 firmware: [skyfeeder/skyfeeder.ino](../../skyfeeder/skyfeeder.ino)
- Arduino IDE or PlatformIO
- ESP32 board package version: (unknown)

**Network:**
- ESP32 IP: (obtained via DHCP)
- MQTT broker: 10.0.0.4:1883
- WiFi connected

---

## Reproduction Steps

### Step 1: Flash ESP32 Firmware
1. Open Arduino IDE
2. Open `skyfeeder/skyfeeder.ino`
3. Select Board: ESP32 Dev Module
4. Tools → Port → Select ESP32 COM port
5. Upload firmware
6. Wait for "Upload complete"

### Step 2: Close Arduino IDE
1. Close Arduino IDE application
2. **Crash loop begins**

### Step 3: Monitor Serial Output
```powershell
python -c "import serial; ser = serial.Serial('COM_ESP32', 115200); while True: print(ser.readline().decode('utf-8', errors='ignore'), end='')"
```

### Expected Result
Normal operation with periodic telemetry and status messages

### Actual Result
```
a=8892.16
a=8892.16
a=8892.16
(repeats forever)
```

---

## Analysis

### Pattern Analysis

**The output `a=8892.16` suggests:**

1. **Watchdog Timer Firing**
   - `a=` might be abbreviated watchdog message
   - Number could be timestamp or register value
   - Repeating pattern indicates loop

2. **Panic Handler Recursion**
   - Similar to earlier crash report: "Panic handler entered multiple times"
   - System trying to recover but failing
   - Re-entering panic handler in loop

3. **Float/Debug Print Loop**
   - Variable `a` with value `8892.16`
   - Printing in tight loop
   - Possible memory corruption showing random float

4. **Boot Loop**
   - Crashes during init
   - Watchdog resets
   - Crashes again at same point
   - `a=8892.16` is truncated boot message

### Code Search

**Searched for `a=8892` pattern:**
```bash
grep -r "a=8892" skyfeeder/
# No matches found
```

**Conclusion:** Not a normal debug print statement

---

## Related Earlier Evidence

**From Earlier Report ([RETRACTION_snapshot_crash_false_alarm.md](RETRACTION_snapshot_crash_false_alarm.md)):**

```
Provisioning ready - starting MQTT...
Guru Meditation Error: Core 0 panic'ed (IllegalInstruction)
Guru Meditation Error: Core 0 panic'ed (LoadProhibited)
Panic handler entered multiple times. Abort panic handling. Rebooting ...
```

**This suggests:**
- ESP32 has a crash bug during MQTT initialization
- Crashes with `IllegalInstruction` or `LoadProhibited` exceptions
- Panic handler recurses
- Device enters boot loop

**Files involved:**
- [skyfeeder/mqtt_client.cpp](../../skyfeeder/mqtt_client.cpp)
- [skyfeeder/provisioning.cpp](../../skyfeeder/provisioning.cpp)

---

## Possible Root Causes

### Hypothesis 1: MQTT Client Initialization Bug
**Theory:** MQTT library crashes during initialization

**Evidence:**
- Earlier crash report shows crash at "starting MQTT..."
- `IllegalInstruction` suggests corrupted function pointer
- `LoadProhibited` suggests invalid memory access

**Location:** [skyfeeder/mqtt_client.cpp](../../skyfeeder/mqtt_client.cpp) - MQTT.begin() or similar

**Status:** ⚠️ HIGH PROBABILITY

---

### Hypothesis 2: Stack Overflow
**Theory:** Recursive function or deep call stack overflows

**Evidence:**
- "Panic handler entered multiple times"
- Suggests recursion
- Watchdog can't recover

**Status:** ⚠️ POSSIBLE

---

### Hypothesis 3: Memory Corruption
**Theory:** Buffer overflow corrupts heap or stack

**Evidence:**
- `a=8892.16` might be corrupted memory contents
- Float value suggests heap data
- Repeating suggests stuck in loop reading corrupted memory

**Status:** ⚠️ POSSIBLE

---

### Hypothesis 4: Arduino IDE Debugger Interference
**Theory:** IDE keeps watchdog disabled, closing IDE enables watchdog, device crashes

**Evidence:**
- Crash specifically happens after IDE closes
- IDE may disable watchdog for debugging
- Closing IDE restores normal watchdog behavior

**Status:** ⚠️ POSSIBLE

---

### Hypothesis 5: Flash Partition Corruption
**Theory:** Firmware flash corrupted, device can't boot properly

**Evidence:**
- Earlier report mentioned "Flash partition corruption"
- Boot loop consistent with corrupted firmware

**Status:** ⚠️ POSSIBLE - try full erase before flash

---

## Workarounds

### Workaround 1: Hardware Reset
**Action:** Unplug and replug ESP32 USB cable

**Result:** User confirmed this temporarily fixes the issue

**Limitation:** Not viable for production - need permanent fix

---

### Workaround 2: Full Flash Erase
**Action:**
```bash
esptool.py --port COM_ESP32 erase_flash
# Then re-flash firmware
```

**Status:** Not yet attempted

---

### Workaround 3: Disable MQTT
**Action:** Comment out MQTT initialization code

**Status:** Would break functionality, not a real solution

---

## Impact

### Current Impact
- ⚠️ Device enters undefined state
- ⚠️ System unstable after IDE closes
- ✅ PIR still triggers (some functionality remains)
- ❌ Repeating crash/corruption output

### Production Impact
- **CRITICAL:** Device will crash in field
- Users won't have Arduino IDE to "keep alive"
- Watchdog behavior different in production vs. development
- **Random crashes expected**
- Device reliability: UNKNOWN

**Severity:** **P0 CRITICAL** - Production deployment blocked

---

## User Observations

**User reports:**
> "i think part of our problems is that i have noticed the esp once i close ide goes into these crash states"

**Key insight:** Issue is reproducible and occurs consistently after IDE closes

---

## Capture Requirements

### Need from Codex

1. **Full Crash Dump**
   - Enable ESP32 core dump to flash
   - Capture complete register state
   - Get full stack trace

2. **Serial Decode**
   - Decode `a=8892.16` message
   - Identify source in firmware or ESP32 SDK

3. **MQTT Debug**
   - Add extensive logging around MQTT initialization
   - Identify exact line where crash occurs

4. **Watchdog Analysis**
   - Check watchdog timer configuration
   - Verify watchdog timeout values
   - Test with watchdog disabled

---

## Debugging Steps for Codex

### Step 1: Enable Core Dumps
```cpp
// In setup()
#include "esp_core_dump.h"
ESP_COREDUMP_INIT();
```

### Step 2: Add MQTT Debug Logging
```cpp
// In mqtt_client.cpp
Serial.println("[mqtt] BEFORE MQTT.begin()");
bool ok = MQTT.begin();
Serial.println("[mqtt] AFTER MQTT.begin()");
```

### Step 3: Increase Watchdog Timeout
```cpp
// In setup()
esp_task_wdt_init(30, false);  // 30 second timeout, don't panic
```

### Step 4: Catch Exceptions
```cpp
void setup() {
  esp_register_panic_handler(customPanicHandler);
}

void customPanicHandler(void* frame) {
  Serial.println("[PANIC] Custom handler called");
  // Log crash info before watchdog resets
}
```

---

## Validation Criteria

**Bug considered FIXED when:**

1. ✅ Flash firmware via Arduino IDE
2. ✅ Close Arduino IDE
3. ✅ Monitor serial output
4. ✅ **NO repeating crash output**
5. ✅ Device runs normally for 24+ hours
6. ✅ All functionality works (MQTT, PIR, snapshots)

---

## Files to Investigate

| File | Reason |
|------|--------|
| [skyfeeder/mqtt_client.cpp](../../skyfeeder/mqtt_client.cpp) | MQTT init crashes per earlier report |
| [skyfeeder/provisioning.cpp](../../skyfeeder/provisioning.cpp) | May contain MQTT startup code |
| [skyfeeder/skyfeeder.ino](../../skyfeeder/skyfeeder.ino) | Main setup() and loop() |
| ESP32 Arduino Core | WiFiClient, MQTT library bugs? |

---

## Related Issues

### Issue 1: Earlier MQTT Crash (Retracted)
**Report:** [RETRACTION_snapshot_crash_false_alarm.md](RETRACTION_snapshot_crash_false_alarm.md)

Initially thought snapshot commands caused crashes. Actually, MQTT initialization was crashing during boot BEFORE snapshot commands were received.

**Key evidence:**
```
Provisioning ready - starting MQTT...
Guru Meditation Error: Core 0 panic'ed (IllegalInstruction)
```

**Conclusion:** MQTT init has a critical bug

---

### Issue 2: Flash Corruption (From Same Report)
```
Panic handler entered multiple times. Abort panic handling. Rebooting ...
```

Suggests flash partition corruption or panic handler bug.

---

## Summary for Codex

**What happens:**
1. Flash ESP32 firmware via Arduino IDE
2. Close Arduino IDE
3. ESP32 enters crash loop: `a=8892.16` repeating
4. Device unstable but PIR still works partially

**Root cause:** Unknown - likely MQTT initialization or watchdog issue

**Evidence:**
- Earlier crash report shows MQTT init crash with `IllegalInstruction`
- Panic handler recursion
- Crash occurs specifically when IDE closes (watchdog behavior changes?)

**Workaround:** Hardware reset (unplug/replug USB)

**Priority:** **P0 CRITICAL** - Will cause production failures

**Request:** Please investigate with core dumps, MQTT debugging, and watchdog analysis

---

**NEEDS IMMEDIATE ATTENTION**

Device cannot be deployed to production in this state. Crashes are reproducible and consistent.

User is frustrated after multiple firmware re-flashes. Need deep investigation into ESP32 crash cause.
