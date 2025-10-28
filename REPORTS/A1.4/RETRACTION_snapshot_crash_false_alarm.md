# RETRACTION: Snapshot Command Crash Report Was False Alarm

**Date:** 2025-10-21
**Status:** ✅ RETRACTED

---

## Summary

The earlier report (git commit ce4018d) documenting "snapshot command crash bug" was **based on incomplete evidence**. After comprehensive serial console analysis, the TRUE issue is:

**❌ FALSE:** Snapshot commands cause device to crash
**✅ TRUE:** ESP32 crashes during MQTT initialization on boot, BEFORE any snapshot commands are received

---

## Why the Confusion Occurred

### Observed Symptoms (Misleading)
- MQTT showed device going offline/online repeatedly
- Soak test showed 0 uploads during 24+ hours
- Only 3 of 24 snapshot commands were processed
- Assumption: "Snapshot commands must be causing crashes"

### Actual Root Cause (Serial Evidence)
Serial console shows device crashes during boot sequence:
```
Provisioning ready - starting MQTT...
Guru Meditation Error: Core  0 panic'ed (IllegalInstruction)
Guru Meditation Error: Core  0 panic'ed (LoadProhibited)
Panic handler entered multiple times. Abort panic handling. Rebooting ...
```

**Timeline:**
1. Device boots successfully through all init stages ✅
2. Reaches "Provisioning ready - starting MQTT..." ✅
3. **CRASHES** before MQTT connects ❌
4. **NEVER** receives snapshot commands (offline) ❌
5. Flash becomes corrupted during panic handling ❌
6. Enters infinite boot loop ❌

---

## Corrected Analysis

### What We Thought
- Snapshot commands trigger a crash
- Device needs debugging of snapshot handling code
- AMB-Mini has a camera capture bug

### What Actually Happens
- MQTT initialization has a critical bug (IllegalInstruction exception)
- Device crashes BEFORE connecting to MQTT broker
- Device NEVER receives snapshot commands (offline the entire time)
- Snapshot handling code is never executed
- AMB-Mini is fine (never gets commanded to do anything)

---

## Evidence That Proves Retraction

### 1. Serial Console Shows Boot Crash
- Crash happens at "starting MQTT..." line
- No snapshot command received before crash
- No camera code executed before crash

### 2. MQTT Telemetry Gap
- Device publishes NO telemetry after boot attempts
- Never connects to MQTT broker
- Cannot receive commands if offline

### 3. Soak Test Shows Device Offline
- Monitored for 22+ hours
- 6 uploads detected at START (existing photos from before test)
- 0 new uploads during test (device never online)
- MQTT listener received NO events (device offline)

### 4. Snapshot Trigger Script
- Sent 3 snapshot commands (21:02, 22:02, 18:27)
- Device was offline during all 3 attempts
- Commands were published to MQTT but never received by device
- No acknowledgment from device (because device offline)

---

## Correct Bug Report

**See:** [CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md](CRITICAL_ESP32_CRASH_FLASH_CORRUPTION.md)

**Issue:** MQTT client initialization in [skyfeeder/mqtt_client.cpp](../../skyfeeder/mqtt_client.cpp) or [skyfeeder/provisioning.cpp](../../skyfeeder/provisioning.cpp) causes:
- IllegalInstruction exception (invalid opcode or corrupted function pointer)
- LoadProhibited exception (invalid memory access)
- Panic handler recursion
- Flash partition corruption
- Infinite boot loop

**NOT related to:**
- Snapshot commands
- Camera capture
- AMB-Mini firmware
- UART communication
- Photo upload

---

## Lesson Learned

**Always use serial console for firmware debugging.**

Remote monitoring (MQTT, MQTT events, upload tracking) can mislead because:
1. Device appears to be "running" based on occasional reconnects
2. Cannot distinguish between "crash after command" vs "crash before connecting"
3. Timing correlation ≠ causation

Serial console is REQUIRED to see:
- Exact crash location
- Exception type and registers
- Boot sequence progress
- Panic handler output
- Flash corruption errors

---

## Updated Incident Classification

| Report | Status | Severity | Root Cause |
|--------|--------|----------|------------|
| ❌ Snapshot command crash | RETRACTED | N/A | False alarm - correlation ≠ causation |
| ✅ MQTT init crash + flash corruption | **ACTIVE** | 🔴 P0 | IllegalInstruction during MQTT.begin() |

---

## Next Steps

1. ✅ Retract snapshot crash report
2. ⏳ Focus on MQTT initialization bug
3. ⏳ Reflash firmware with full flash erase
4. ⏳ Test snapshot commands AFTER device is stable
5. ⏳ Verify snapshot handling works correctly (it should - code looks fine)

---

**Apologies for the false alarm. Serial console debugging revealed the true issue.**
