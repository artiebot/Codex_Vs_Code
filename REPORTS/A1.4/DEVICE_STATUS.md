# A1.4 Hardware Soak Test - Device Status Report

**Date:** 2025-10-20
**Tester:** Claude
**Duration:** Ongoing monitoring attempt

---

## Executive Summary

Attempted to initiate A1.4 24-hour hardware soak test, but device is currently **OFFLINE**.

- ❌ Device not responding to MQTT commands
- ❌ No WebSocket connections (0 clients)
- ❌ No OTA heartbeats recorded
- ❌ No recent uploads (last: 2025-10-20 02:31:30 UTC)
- ✅ Local stack services all running correctly
- ✅ 24-hour monitoring infrastructure created and ready

---

## Device Connectivity Assessment

### Test Date: 2025-10-20 19:03 - 19:08 PST

**Tests Performed:**

1. **COM Port Scan** (Serial/USB)
   - Scanned COM3-COM8
   - Result: ❌ No USB connection found
   - Note: Expected - user confirmed device not connected to PC

2. **MQTT Connectivity**
   - Broker: 10.0.0.4 (user: dev1, pass: dev1pass)
   - Commands sent:
     - `skyfeeder/dev1/amb/camera/cmd` → `{"action":"snap"}`
     - `skyfeeder/dev1/cmd/camera` → `{"op":"snapshot"}`
   - Result: ❌ No response from device
   - Monitoring duration: ~4 minutes

3. **WebSocket Relay**
   - Endpoint: http://localhost:8081/v1/metrics
   - Status: Running, but **0 clients connected**
   - Message count: 0
   - Result: ❌ Device not connected to WebSocket

4. **OTA Server**
   - Endpoint: http://localhost:9180/v1/ota/status
   - Result: ❌ No heartbeats recorded (empty array)

5. **MinIO Storage**
   - Bucket: local/photos/dev1/
   - Last upload: 2025-10-20T02:31:30Z (aeQwBT.jpg, 1.4MB)
   - Time since last upload: ~16.5 hours
   - Result: ❌ No new uploads during test

---

## Possible Device States

Based on diagnostic results, the device is likely in one of these states:

### 1. **Deep Sleep** (Most Likely)
- Device entered deep sleep after last upload (02:31:30 UTC)
- Waiting for wake trigger (motion detection, timer, etc.)
- Expected behavior for battery-powered operation
- **Action:** Trigger wake event or wait for scheduled wake

### 2. **Wi-Fi Disconnected**
- Device powered on but lost Wi-Fi connection
- Could be due to router reboot, AP roaming, or signal issues
- **Action:** Check Wi-Fi access point, wait for auto-reconnect

### 3. **Boot Loop / Crash**
- Device stuck in crash/reboot cycle
- Would need serial console to diagnose
- **Action:** Physical inspection with serial monitor

### 4. **Powered Off**
- Device completely powered down
- **Action:** Power cycle the device

---

## Local Stack Health (✅ All Services Running)

```
NAME                    STATUS              PORTS
skyfeeder-minio         Up About a minute   0.0.0.0:9200->9000/tcp
skyfeeder-ota-server    Up About a minute   0.0.0.0:9180->8090/tcp
skyfeeder-presign-api   Up About a minute   0.0.0.0:8080->8080/tcp
skyfeeder-ws-relay      Up About a minute   0.0.0.0:8081->8081/tcp
```

**All services operational and ready for device reconnection.**

---

## Previous Upload History (Evidence Device Was Working)

Last successful uploads from device `dev1`:

| Timestamp (UTC) | File | Size |
|-----------------|------|------|
| 2025-10-20 02:31:30 | 2025-10-20T02-31-27-074Z-aeQwBT.jpg | 1.4MB |
| 2025-10-20 02:31:21 | 2025-10-20T02-31-18-422Z-WKwBcL.jpg | 1.4MB |
| 2025-10-20 02:31:12 | 2025-10-20T02-31-09-624Z-W8oHe6.jpg | 1.4MB |
| 2025-10-20 02:30:47 | 2025-10-20T02-30-43-360Z-F2Erq9.jpg | 1.4MB |
| 2025-10-20 01:34:16 | 2025-10-20T01-33-51-047Z-QWc5dY.jpg | 1.4MB |

**Note:** These uploads were from A1.4 fault injection testing.

---

## Monitoring Infrastructure Created

Created comprehensive 24-hour soak test monitoring script:

### Script: `tools/soak-test-24h.ps1`

**Features:**
- ✅ Background MQTT listener (all topics under `skyfeeder/dev1/#`)
- ✅ MinIO upload tracking (checks every 60 seconds)
- ✅ WebSocket metrics monitoring (connections, message counts)
- ✅ OTA heartbeat tracking
- ✅ Success rate calculation (target: >= 85%)
- ✅ JSONL event logs for all telemetry streams
- ✅ Real-time console output with elapsed/remaining time
- ✅ Automatic report generation after 24 hours

**Outputs:**
- `mqtt_events.jsonl` - All MQTT events with timestamps
- `uploads.jsonl` - Upload events detected via MinIO
- `ws_metrics.jsonl` - WebSocket relay metrics over time
- `ota_heartbeats.jsonl` - OTA heartbeat events
- `summary.log` - Human-readable summary log
- `errors.log` - Error log
- `SOAK_TEST_REPORT.md` - Final test report with pass/fail

**Usage:**
```powershell
# Run 24-hour test
.\tools\soak-test-24h.ps1 -DeviceId dev1 -DurationHours 24

# Run shorter test (1 hour)
.\tools\soak-test-24h.ps1 -DeviceId dev1 -DurationHours 1

# Custom output directory
.\tools\soak-test-24h.ps1 -OutputDir REPORTS\A1.4\soak-test-run2
```

---

## Recommendations

### Immediate Actions Required

1. **⚠️ Physical Device Inspection**
   - Check power LED status (on/blinking/off?)
   - Verify power supply connected
   - Check Wi-Fi router for device connectivity
   - If possible, connect to serial console for logs

2. **⚠️ Trigger Device Wake**
   - Option A: Trigger motion sensor (if enabled)
   - Option B: Power cycle the device
   - Option C: Wait for scheduled wake timer (if configured)

3. **⚠️ Verify Wi-Fi Configuration**
   - Confirm Wi-Fi SSID/password correct
   - Check if AP is reachable from device location
   - Verify MQTT broker accessible at 10.0.0.4

### When Device Comes Online

1. **Start 24-hour soak test:**
   ```powershell
   cd d:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code
   .\tools\soak-test-24h.ps1 -DeviceId dev1 -DurationHours 24
   ```

2. **Optionally trigger periodic snapshots** (every hour):
   ```powershell
   # Every hour for 24 hours
   for ($i=0; $i -lt 24; $i++) {
       mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass `
           -t "skyfeeder/dev1/cmd/camera" `
           -m '{"op":"snapshot"}'
       Start-Sleep -Seconds 3600
   }
   ```

3. **Monitor real-time logs:**
   ```powershell
   # Watch MQTT events
   mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/#" -v

   # Watch uploads
   docker exec skyfeeder-minio mc ls local/photos/dev1/ --recursive | tail -10
   ```

---

## Next Steps

1. ✅ **Monitoring infrastructure complete** - Script ready to run when device online
2. ⏳ **Waiting for device to come online** - Physical inspection needed
3. ⏳ **24-hour soak test pending** - Will run when device reconnects
4. ⏳ **Power measurements pending** - Requires INA260 sensor or bench supply

---

## Files Created

1. ✅ `tools/soak-test-24h.ps1` - 24-hour monitoring script
2. ✅ `REPORTS/A1.4/DEVICE_STATUS.md` - This document
3. ✅ Background MQTT listener running (capturing all events)

---

**Status:** READY FOR TESTING - Device needs to come online

**Next Action:** Physical device inspection and wake trigger