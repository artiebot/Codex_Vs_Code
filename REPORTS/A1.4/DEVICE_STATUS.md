# A1.4 Hardware Soak Test - Device Status Report

**Date:** 2025-10-20
**Tester:** Claude
**Status:** 🔴 **BLOCKED - Critical Firmware Bug**

---

## Executive Summary

Device successfully came online after provisioning, but **24-hour soak test is BLOCKED** by a critical firmware crash.

- ✅ Device connected to Wi-Fi and MQTT successfully
- ✅ Publishing discovery messages (firmware 1.4.2)
- ✅ Receiving MQTT commands
- 🔴 **CRITICAL:** Snapshot command causes immediate crash and reboot
- ❌ Cannot validate camera functionality
- ❌ Cannot run 24-hour soak test (requires uploads)
- ✅ Local stack services all running correctly

**See:** [CRITICAL_BUG_SNAPSHOT_CRASH.md](CRITICAL_BUG_SNAPSHOT_CRASH.md) for full crash analysis

---

## Timeline

### 19:03-19:08 PST - Initial Connectivity Assessment
- Device appeared offline (no MQTT/WS/OTA activity)
- Local stack confirmed healthy
- Created 24-hour monitoring infrastructure

### 19:25 PST - Provisioning Issue Discovered
User reported serial console showing:
```
Provisioning not ready - skipping MQTT
DEBUG: Provisioning not ready, waiting...
```

**Root Cause:** Firmware flash during A0.4 OTA validation cleared NVS storage (Wi-Fi/MQTT credentials)

### 19:28 PST - Device Provisioned and Online
- User provisioned device via captive portal
- Device connected successfully
- Published discovery: `{"device_id":"dev1","fw_version":"1.4.2",...}`
- Firmware version: 1.4.2 (OTA firmware B - correct!)

### 19:49 PST - **CRITICAL BUG DISCOVERED**
Sent snapshot command to test camera functionality:
```bash
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/camera" \
    -m '{"op":"snapshot","token":"test1"}'
```

**Result:** ESP32 crashed immediately with:
```
Guru Meditation Error: Core 0 panic'ed (IllegalInstruction)
Guru Meditation Error: Core 0 panic'ed (LoadProhibited)
Panic handler entered multiple times. Abort panic handling. Rebooting ...
```

Device entered crash/reboot loop. Crash is **100% reproducible**.

---

## Device Configuration

### Firmware
- **Version:** 1.4.2 (OTA firmware B from A0.4 validation)
- **Step:** sf_step15D_ota_safe_staging
- **Device ID:** dev1

### Services Running
weight, motion, visit, led, camera, logs, ota, health

### Camera Status (from discovery)
```json
"camera_state": "",
"camera_settled": false
```

**Note:** Camera not settled/initialized - likely contributing to crash

### Network Configuration
- **Wi-Fi SSID:** wififordays
- **MQTT Broker:** 10.0.0.4:1883
- **MQTT User:** dev1

---

## Crash Analysis

**See full analysis:** [CRITICAL_BUG_SNAPSHOT_CRASH.md](CRITICAL_BUG_SNAPSHOT_CRASH.md)

### Error Types
1. **IllegalInstruction** - Attempted to execute invalid code
2. **LoadProhibited** - Attempted to access invalid memory
3. **Panic Handler Crash** - Error handler itself crashed (severe memory corruption)

### Likely Root Causes
1. **Stack overflow** in camera/AMB wake sequence
2. **Null pointer dereference** if AMB82-Mini not connected/responding
3. **Buffer overflow** in JSON parsing or UART handling

### Files to Investigate
- `skyfeeder/command_handler.cpp:509-633` - handleCamera()
- `skyfeeder/mini_link.cpp` - UART communication with AMB
- `skyfeeder/skyfeeder.ino` - Task stack sizes

---

## MQTT Event Log (Crash Sequence)

```
2025-10-20 19:28:04 - skyfeeder/dev1/status online
2025-10-20 19:28:04 - skyfeeder/dev1/discovery {"device_id":"dev1","fw_version":"1.4.2",...}
2025-10-20 19:28:04 - skyfeeder/dev1/status offline
2025-10-20 19:49:03 - skyfeeder/dev1/cmd/camera {"op":"snapshot","token":"test1"}  ← CRASH
[Device reboots]
2025-10-20 19:49:19 - skyfeeder/dev1/status offline
2025-10-20 19:49:19 - skyfeeder/dev1/discovery {"device_id":"dev1","fw_version":"1.4.2",...}
```

**Time between command and reboot:** ~16 seconds (matches serial crash timestamp)

---

## Impact on Validation

### A1.4 - Hardware Soak Test: 🔴 **BLOCKED**
- Cannot send snapshot commands (immediate crash)
- Cannot generate upload traffic
- Cannot measure success rate over 24 hours
- Cannot validate retry logic with real device
- **Status:** Waiting for Codex to fix crash

### A1.3 - WebSocket Upload-Status: ⚠️ **Partially Complete**
- ✅ Simulation testing complete (8 events, reconnect handling)
- ❌ Real device testing blocked by crash
- ❌ iOS gallery testing blocked (no real photos)

### Future Phases: ⚠️ **At Risk**
- B1 - Provisioning polish (might work if no camera involved)
- A2 - Field pilot (**definitely blocked** - camera is core functionality)

---

## Monitoring Infrastructure Created

Despite the crash, all monitoring tools are ready:

### 1. tools/soak-test-24h.ps1
24-hour monitoring script that tracks:
- MQTT events (background listener)
- MinIO uploads (60s polling)
- WebSocket metrics
- OTA heartbeats
- Success rate calculation (>= 85% target)
- Automatic report generation

**Usage (when crash is fixed):**
```powershell
.\tools\soak-test-24h.ps1 -DeviceId dev1 -DurationHours 24
```

### 2. tools/trigger-periodic-snapshots.ps1
Sends snapshot commands at intervals:
- Default: 1 snapshot/hour for 24 hours
- Configurable interval and count

**Usage (when crash is fixed):**
```powershell
.\tools\trigger-periodic-snapshots.ps1 -IntervalSeconds 3600 -Count 24
```

### 3. Manual Monitoring Commands
```powershell
# Monitor MQTT real-time
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/#" -v

# Check uploads
docker exec skyfeeder-minio mc ls local/photos/dev1/

# Check WebSocket
curl http://localhost:8081/v1/metrics | jq .

# Check OTA heartbeats
curl http://localhost:9180/v1/ota/status | jq .
```

---

## Local Stack Health ✅

All services running correctly:

```
NAME                    STATUS              PORTS
skyfeeder-minio         Up                  0.0.0.0:9200->9000/tcp
skyfeeder-ota-server    Up                  0.0.0.0:9180->8090/tcp
skyfeeder-presign-api   Up                  0.0.0.0:8080->8080/tcp
skyfeeder-ws-relay      Up                  0.0.0.0:8081->8081/tcp
```

Infrastructure is ready for testing as soon as firmware is fixed.

---

## Recommended Actions for Codex

### Priority 1: Fix the Crash
1. Add null pointer checks for AMB82-Mini communication
2. Increase task stack size (likely stack overflow)
3. Add error handling for UART failures
4. Enable core dumps for offline crash analysis

### Priority 2: Add Safety Features
1. Add watchdog timer to detect hangs
2. Add crash telemetry (report via MQTT before reboot)
3. Add memory stats logging (heap, stack usage)
4. Add hardware presence detection (is AMB actually connected?)

### Priority 3: Test Before Next Validation
1. Test snapshot command on real hardware
2. Verify AMB82-Mini is connected and responding
3. Add serial debug logging for camera sequence
4. Test with memory leak detection enabled

**Full recommendations:** See [CRITICAL_BUG_SNAPSHOT_CRASH.md](CRITICAL_BUG_SNAPSHOT_CRASH.md)

---

## Alternative Commands to Test (Safe)

While snapshot command crashes, these might work:

### LED Command (Should be safe)
```bash
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/led" \
    -m '{"state":"on","r":255,"g":0,"b":0}'
```

### Logs Command (Should be safe)
```bash
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/logs" \
    -m '{"count":10}'
```

### ⚠️ DO NOT USE (Crashes)
```bash
# CRASHES IMMEDIATELY
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass \
    -t "skyfeeder/dev1/cmd/camera" \
    -m '{"op":"snapshot"}'
```

---

## Next Steps

### For Codex:
1. Review [CRITICAL_BUG_SNAPSHOT_CRASH.md](CRITICAL_BUG_SNAPSHOT_CRASH.md)
2. Fix the snapshot crash bug
3. Test fix with real hardware (ESP32 + AMB82-Mini)
4. Provide updated firmware for validation

### For Validation (When Fixed):
1. Flash fixed firmware
2. Run 24-hour soak test:
   ```powershell
   .\tools\soak-test-24h.ps1 -DeviceId dev1 -DurationHours 24
   ```
3. Optionally trigger periodic snapshots:
   ```powershell
   .\tools\trigger-periodic-snapshots.ps1
   ```
4. Review generated report: `REPORTS/A1.4/soak-test/SOAK_TEST_REPORT.md`

---

## Artifacts

### Created
1. ✅ `tools/soak-test-24h.ps1` - 24-hour monitoring script
2. ✅ `tools/trigger-periodic-snapshots.ps1` - Periodic snapshot trigger
3. ✅ `REPORTS/A1.4/DEVICE_STATUS.md` - This document
4. ✅ `REPORTS/A1.4/CRITICAL_BUG_SNAPSHOT_CRASH.md` - Detailed crash analysis

### Expected (After Fix)
5. ⏳ `REPORTS/A1.4/soak-test/mqtt_events.jsonl` - MQTT event log
6. ⏳ `REPORTS/A1.4/soak-test/uploads.jsonl` - Upload tracking
7. ⏳ `REPORTS/A1.4/soak-test/SOAK_TEST_REPORT.md` - Final test report
8. ⏳ `REPORTS/A1.4/power.csv` - Power measurements (requires INA260)

---

## Conclusion

**Device Status:** 🟡 **ONLINE but UNUSABLE**
- ✅ Network connectivity working
- ✅ MQTT pub/sub working
- ✅ Discovery publishing correctly
- 🔴 Camera functionality crashes immediately
- 🔴 Cannot perform soak test until crash is fixed

**Blocker:** Snapshot command causes fatal crash (IllegalInstruction + LoadProhibited)

**Action Required:** Codex must fix crash before hardware validation can proceed

**Validation Status:** WAITING FOR BUG FIX

---

**Last Updated:** 2025-10-20 19:50 PST
**Status:** 🔴 **BLOCKED**
**Next Action:** Codex to fix snapshot crash