# CRITICAL BUG: Snapshot Command Causes Fatal ESP32 Crash

**Severity:** 🔴 **BLOCKER** - Prevents hardware validation
**Date Found:** 2025-10-20 19:49 PST
**Firmware Version:** 1.4.2 (OTA firmware B)
**Tester:** Claude

---

## Executive Summary

The ESP32 firmware **crashes immediately** when processing a snapshot command via MQTT. The crash is **100% reproducible** and causes a reboot loop, making the device unusable for camera operations.

**Impact:**
- ❌ Cannot perform 24-hour soak test (requires snapshot uploads)
- ❌ Cannot validate upload reliability
- ❌ Cannot validate camera subsystem
- ❌ Blocks A1.4 hardware validation completely

---

## Reproduction Steps

1. Provision ESP32 with Wi-Fi and MQTT credentials
2. Wait for device to connect and publish discovery
3. Send MQTT command:
   ```bash
   mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
       -t "skyfeeder/dev1/cmd/camera" \
       -m '{"op":"snapshot","token":"test1"}'
   ```
4. **Result:** Device crashes within 1-2 seconds

---

## Serial Console Output (Crash Dump)

```
19:49:19.047 -> Guru Meditation Error: Core  0 panic'ed (IllegalInstruction). Exception was unhandled.
19:49:19.048 -> Memory dump at 0x40183b7c: 20aa20ff 00000000 00000000
19:49:19.048 -> Core  0����ister dump:Guru Meditation Error: Core  0 panic'ed (LoadProhibited). Exception was unhandled.
19:49:19.080 ->
19:49:19.080 -> Core  0����ister dump:Panic handler entered multiple times. Abort panic handling. Rebooting ...
19:49:19.080 -> Panic handler entered multiple times. Abort panic handling. Rebooting ...
```

---

## MQTT Event Sequence

```
1. skyfeeder/dev1/status online
2. skyfeeder/dev1/discovery {"device_id":"dev1","fw_version":"1.4.2",...}
3. skyfeeder/dev1/status offline
4. skyfeeder/dev1/cmd/camera {"op":"snapshot","token":"test1"}  ← Command received
5. [CRASH - Device reboots]
6. skyfeeder/dev1/status offline
7. skyfeeder/dev1/discovery {"device_id":"dev1","fw_version":"1.4.2",...}  ← Reboot
```

**Time between command and reboot:** ~1-2 seconds

---

## Error Analysis

### Primary Error: IllegalInstruction
```
Guru Meditation Error: Core 0 panic'ed (IllegalInstruction)
Memory dump at 0x40183b7c: 20aa20ff 00000000 00000000
```

**Meaning:** CPU tried to execute invalid/corrupted instruction
**Possible Causes:**
- Corrupted function pointer
- Stack overflow overwrote code
- Jump to invalid memory address
- Compiler optimization bug

### Secondary Error: LoadProhibited
```
Guru Meditation Error: Core 0 panic'ed (LoadProhibited)
```

**Meaning:** Attempted to read from invalid memory address
**Possible Causes:**
- Null pointer dereference
- Accessing freed memory
- Stack overflow
- Buffer overflow

### Tertiary Error: Panic Handler Crash
```
Panic handler entered multiple times. Abort panic handling. Rebooting ...
```

**Meaning:** The crash handler itself crashed (extremely bad)
**Cause:** Memory corruption is so severe that even error handling code is corrupted

---

## Likely Root Causes

### 1. **Stack Overflow** (Most Likely)
The snapshot command likely triggers:
- AMB82-Mini wake sequence (UART communication)
- Camera initialization
- Deep call stack (wake → ready → settle → capture)

If stack size is insufficient, it corrupts adjacent memory, causing:
1. Illegal instruction (code overwritten)
2. Load prohibited (pointers corrupted)
3. Panic handler crash (handler stack corrupted)

**File to check:** `skyfeeder/command_handler.cpp:509-633` (handleCamera function)

### 2. **Null Pointer in Camera Code**
The AMB82-Mini might not be connected/responding, causing:
- Null pointer dereference in `mini_link.cpp`
- Unhandled error in `runSnapshotSequence()` or `ensureMiniReady()`

**Files to check:**
- `skyfeeder/mini_link.cpp` - UART communication with AMB
- `skyfeeder/command_handler.cpp:556-560` - runSnapshotSequence()

### 3. **Buffer Overflow in UART/JSON Handling**
Parsing the snapshot command or UART responses might overflow a buffer:
- JSON deserialization buffer too small
- UART receive buffer overflow
- String operations without bounds checking

**Files to check:**
- `skyfeeder/command_handler.cpp:509-514` - JSON deserialization
- `skyfeeder/mini_link.cpp` - UART buffer handling

---

## Device Configuration When Crash Occurred

**Firmware:** 1.4.2 (OTA firmware B from A0.4 validation)
**Device ID:** dev1
**Camera State:** `"camera_state":""` (empty - camera not initialized)
**Camera Settled:** `"camera_settled":false`
**Services Running:** weight, motion, visit, led, camera, logs, ota, health

**Note:** Camera not settled/initialized might be causing the crash.

---

## Workarounds Attempted

❌ **None successful** - Any snapshot command immediately crashes the device

Commands tried:
1. `{"op":"snapshot"}` - CRASH
2. `{"op":"snapshot","token":"test1"}` - CRASH

---

## Impact on Validation Phases

### A1.4 - Hardware Soak Test: ❌ **BLOCKED**
Cannot run 24-hour soak test because:
- Snapshot commands crash the device
- Cannot generate upload traffic
- Cannot validate retry logic under real conditions
- Cannot measure success rate

### A1.3 - WebSocket Upload-Status: ⚠️ **Partially Validated**
- Simulation testing completed (fault injection, reconnect)
- Real device testing blocked by this crash

### Future Phases: ⚠️ **At Risk**
- B1 - Provisioning polish (might be affected if camera involved)
- A2 - Field pilot (definitely blocked - camera is core functionality)

---

## Recommended Next Steps for Codex

### Immediate Actions (Priority 1)

1. **Add Stack Size Debugging**
   - Print stack usage before/after snapshot command
   - Increase task stack size if needed (FreeRTOS)
   - Check for recursive calls

2. **Add Null Pointer Checks**
   - Verify AMB82-Mini is connected before snapshot
   - Add error handling for UART communication failures
   - Return error codes instead of crashing

3. **Review Buffer Sizes**
   - JSON deserialization buffer (currently 192 bytes in handleCamera)
   - UART receive buffers in mini_link.cpp
   - String operations in snapshot sequence

4. **Enable Core Dumps**
   - Save crash dump to flash for offline analysis
   - Include full register dump, backtrace, stack trace
   - See: https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/core_dump.html

### Investigation (Priority 2)

1. **Check if AMB82-Mini is actually connected**
   - Device shows `"camera_settled":false`
   - Might be missing hardware (AMB not connected?)
   - Add hardware presence detection

2. **Test with simpler commands**
   - Try LED command: `{"state":"on","r":255,"g":0,"b":0}`
   - Try calibrate command
   - See if crash is camera-specific or all commands

3. **Review Recent Code Changes**
   - Check git diff for skyfeeder/command_handler.cpp
   - Check git diff for skyfeeder/mini_link.cpp
   - Look for recent UART or camera changes

### Long-term Fixes (Priority 3)

1. **Add Watchdog Timer**
   - Detect infinite loops/hangs
   - Auto-reboot with error telemetry

2. **Add Memory Protection**
   - Enable MPU (Memory Protection Unit) if available
   - Detect stack overflows before corruption

3. **Add Telemetry**
   - Report crashes via MQTT before reboot
   - Track crash count, last crash reason
   - OTA heartbeat should include crash stats

---

## Validation Status

**Can Continue Without Fix:**
- ✅ OTA validation (A0.4) - Already complete
- ✅ Local stack validation (A1.1) - Already complete
- ✅ Discovery validation (A1.2) - Already complete
- ✅ WebSocket simulation testing (A1.3, A1.4) - Already complete

**Blocked Until Fix:**
- ❌ A1.4 hardware soak test - Requires snapshot uploads
- ❌ A1.3 iOS gallery testing - Requires real photos
- ❌ A2 field pilot - Camera is core functionality
- ❌ B1+ all camera-related features

---

## Files to Review

**High Priority:**
1. `skyfeeder/command_handler.cpp` (lines 509-633) - handleCamera(), runSnapshotSequence()
2. `skyfeeder/mini_link.cpp` - UART communication, ensureMiniReady()
3. `skyfeeder/mini_link.h` - Interface definitions

**Medium Priority:**
4. `skyfeeder/skyfeeder.ino` - Main loop, task stack sizes
5. `skyfeeder/config.h` - Buffer sizes, timeouts
6. `skyfeeder/provisioning.cpp` - Recent changes (modified per git status)

---

## Test Commands for Debugging

### Safe Commands (Should NOT Crash)
```bash
# LED command
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/led" \
    -m '{"state":"on","r":255,"g":0,"b":0}'

# Log command
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/logs" \
    -m '{"count":10}'
```

### Crash Commands (DO NOT USE until fixed)
```bash
# Snapshot command - CRASHES IMMEDIATELY
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/camera" \
    -m '{"op":"snapshot"}'
```

---

## Monitoring During Fix

When Codex provides a fix, validate with:

1. **Serial console monitoring** (catch crashes immediately)
2. **MQTT event logging** (see command/response flow)
3. **MinIO upload verification** (confirm photos actually upload)
4. **Memory stats logging** (heap, stack usage)

---

## Conclusion

**This is a CRITICAL blocker** for hardware validation. The snapshot command - the core functionality of the device - crashes immediately and reproducibly.

**Root cause appears to be:** Stack overflow or null pointer dereference in camera/AMB handling code.

**Codex needs to:**
1. Fix the crash (add null checks, increase stack, fix UART handling)
2. Add crash reporting telemetry
3. Test with real hardware before next validation

**Validation cannot proceed** until this is resolved.

---

**Bug Reported:** 2025-10-20 19:49 PST
**Reporter:** Claude (Hardware Validation)
**Status:** 🔴 **OPEN - BLOCKER**
**Assigned To:** Codex
**Priority:** **P0 - CRITICAL**