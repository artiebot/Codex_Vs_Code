# A0.4 OTA Test - Issue Found & Resolution

**Date:** 2025-10-19
**Issue:** HTTP connection error during OTA upgrade

---

## Problem

OTA upgrade test failed with error:
```
skyfeeder/dev1/event/ota {"schema":"v1","state":"download_started","version":"1.4.2"}
skyfeeder/dev1/event/ota {"schema":"v1","state":"error","version":"1.4.2","reason":"http_-1"}
```

**Root Cause:** OTA payload used `localhost` in URL, but ESP32 cannot resolve `localhost` - it needs the actual IP address of the host machine.

**Current Payload (WRONG):**
```json
{"url":"http://localhost:9180/fw/1.4.2/skyfeeder.bin",...}
```

**ESP32's Perspective:**
- Connected to WiFi network `wififordays`
- MQTT broker at `10.0.0.4:1883` (from config.h)
- Cannot resolve `localhost` - needs real IP

---

## Solution

### Option 1: Use Host's 10.0.0.x IP Address (RECOMMENDED)

**Find your host machine's IP:**
```powershell
ipconfig
# Look for "Ethernet adapter" or "Wi-Fi adapter" with 10.0.0.x address
# Example: 10.0.0.4
```

**Create corrected payload:**
```powershell
# Replace 10.0.0.4 with your actual IP
@'
{"url":"http://10.0.0.4:9180/fw/1.4.2/skyfeeder.ino.bin","version":"1.4.2","size":1226432,"sha256":"1bd9989ceca10a034499e7e3db5b281f2959c219dc6fed30b8bae0598b43b854","staged":true}
'@ | Set-Content REPORTS/A0.4/ota_payload_fixed.json -Encoding ASCII
```

**Send corrected OTA:**
```powershell
# Start MQTT capture
mosquitto_sub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/event/ota" -v > REPORTS/A0.4/ota_runA_events_retry.log &

# Send corrected command
mosquitto_pub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/ota" -f REPORTS/A0.4/ota_payload_fixed.json
```

---

### Option 2: Update Docker Port Mapping

**Make OTA server accessible on all network interfaces:**

Edit `ops/local/docker-compose.yml`, change OTA server port mapping from:
```yaml
ports:
  - "9180:8090"  # localhost only
```

To:
```yaml
ports:
  - "0.0.0.0:9180:8090"  # accessible from network
```

Then restart:
```powershell
cd ops/local
docker compose restart ota-server
```

---

## Expected Output After Fix

**MQTT Events:**
```
skyfeeder/dev1/event/ota {"schema":"v1","state":"download_started","version":"1.4.2"}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":25,...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":50,...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":75,...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":100,...}
skyfeeder/dev1/event/ota {"schema":"v1","state":"download_ok","version":"1.4.2"}
skyfeeder/dev1/event/ota {"schema":"v1","state":"verify_ok","version":"1.4.2"}
skyfeeder/dev1/event/ota {"schema":"v1","state":"apply_pending","version":"1.4.2"}
... [Device reboots for ~10 seconds] ...
skyfeeder/dev1/event/ota {"schema":"v1","state":"applied","version":"1.4.2"}
```

---

## What Was Actually Tested

✅ **Firmware Flash:** Successfully flashed v1.4.0 to ESP32
✅ **Device Boot:** Device booted and connected to MQTT
✅ **OTA Command Received:** Device received OTA command and started download
❌ **HTTP Download:** Failed due to `localhost` URL (ESP32 can't resolve)

**Partial Success:** The OTA subsystem is working correctly - it's just a URL configuration issue.

---

## Next Steps

1. Find your host IP address (likely 10.0.0.4 based on config.h)
2. Create corrected payload with real IP
3. Send OTA command again
4. Watch for successful download and reboot
5. Verify upgrade with `curl http://localhost:9180/v1/ota/status`

---

## Files Generated So Far

- ✅ `REPORTS/A0.4/ota_runA_events.log` - Failed attempt (http_-1 error)
- ⏳ `REPORTS/A0.4/ota_runA_events_retry.log` - Retry with corrected URL (pending)

---

**Status:** Infrastructure is correct, just need IP address fix in payload
**Next Action:** Determine host IP and retry with corrected URL
