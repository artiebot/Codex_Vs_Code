# A0.4 Manual Validation Steps

**Status:** COM4 is currently busy (likely Arduino IDE Serial Monitor is open)
**Action Required:** Close Serial Monitor, then execute these steps

---

## Step 1: Flash Firmware A (v1.4.0)

**Close Arduino IDE Serial Monitor first!**

```powershell
"C:\Users\ardav\AppData\Local\Programs\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe" upload --fqbn esp32:esp32:esp32da --port COM4 --input-dir skyfeeder/build_1.4.0 skyfeeder
```

**Expected:** Firmware upload completes successfully

---

## Step 2: Verify Device Boots (Optional)

Open Serial Monitor at 115200 baud, look for:
```
[boot] Starting SkyFeeder v1.4.0
[wifi] Connecting...
[mqtt] Connected
```

Close Serial Monitor before proceeding to OTA test!

---

## Step 3: Execute A→B OTA Upgrade Test

### Terminal 1: MQTT Event Capture
```powershell
mosquitto_sub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/event/ota" -v > REPORTS/A0.4/ota_runA_events.log
```

### Terminal 2: Serial Capture (Optional but Recommended)
Open Arduino IDE Serial Monitor or use:
```powershell
python -c "import serial; s=serial.Serial('COM4',115200); [print(s.readline().decode('utf-8',errors='ignore').strip()) for _ in iter(int, 1)]" > REPORTS/A0.4/serial_runA.log
```

### Terminal 3: Send OTA Command

**Wait 30 seconds** after boot, then:

```powershell
# Create OTA payload file
@'
{"url":"http://localhost:9180/fw/1.4.2/skyfeeder.ino.bin","version":"1.4.2","size":1226432,"sha256":"1bd9989ceca10a034499e7e3db5b281f2959c219dc6fed30b8bae0598b43b854","staged":true}
'@ | Set-Content REPORTS/A0.4/ota_payload.json -Encoding ASCII

# Send OTA command
mosquitto_pub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/ota" -f REPORTS/A0.4/ota_payload.json
```

**Expected MQTT Events:**
```
skyfeeder/dev1/event/ota {"schema":"v1","state":"download_started","version":"1.4.2"}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":25,"bytes":...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":50","bytes":...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":75","bytes":...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.2","progress":100","bytes":...}
skyfeeder/dev1/event/ota {"schema":"v1","state":"download_ok","version":"1.4.2"}
skyfeeder/dev1/event/ota {"schema":"v1","state":"verify_ok","version":"1.4.2"}
skyfeeder/dev1/event/ota {"schema":"v1","state":"apply_pending","version":"1.4.2"}
```

**Device will reboot after 5 seconds**

After reboot:
```
skyfeeder/dev1/event/ota {"schema":"v1","state":"applied","version":"1.4.2"}
```

**Wait 60 seconds for device to fully boot and send heartbeat**

---

## Step 4: Verify Upgrade Success

Stop MQTT capture (Ctrl+C in Terminal 1)

```powershell
curl http://localhost:9180/v1/ota/status | jq . > REPORTS/A0.4/ota_status_after_b.json
curl http://localhost:8080/v1/discovery/dev1 | jq . > REPORTS/A0.4/discovery_after_b.json

# Check version
cat REPORTS/A0.4/ota_status_after_b.json | jq '.[] | select(.deviceId=="dev1")'
```

**Expected Output:**
```json
{
  "deviceId": "dev1",
  "version": "1.4.2",
  "slot": null,
  "bootCount": 1,
  "status": "boot",
  "updatedTs": <timestamp>
}
```

**Success Criteria:**
- ✅ version = "1.4.2"
- ✅ bootCount = 1
- ✅ No rollback triggered

---

## Step 5: Rollback Test (Bad OTA)

### Terminal 1: Restart MQTT Event Capture
```powershell
mosquitto_sub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/event/ota" -v > REPORTS/A0.4/ota_runB_rollback.log
```

### Terminal 2: Restart Serial Capture (Optional)
```powershell
python -c "import serial; s=serial.Serial('COM4',115200); [print(s.readline().decode('utf-8',errors='ignore').strip()) for _ in iter(int, 1)]" > REPORTS/A0.4/serial_rollback.log
```

### Terminal 3: Send Bad OTA (Wrong SHA256)

```powershell
# Create bad OTA payload (intentionally wrong SHA)
@'
{"url":"http://localhost:9180/fw/1.4.2/skyfeeder.ino.bin","version":"1.4.3","size":1226432,"sha256":"0000000000000000000000000000000000000000000000000000000000000000","staged":true}
'@ | Set-Content REPORTS/A0.4/ota_payload_bad.json -Encoding ASCII

# Send bad OTA command
mosquitto_pub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/ota" -f REPORTS/A0.4/ota_payload_bad.json
```

**Expected MQTT Events:**
```
skyfeeder/dev1/event/ota {"schema":"v1","state":"download_started","version":"1.4.3"}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.4.3","progress":...}
...
skyfeeder/dev1/event/ota {"schema":"v1","state":"error","version":"1.4.3","reason":"sha256_mismatch"}
```

**Alternative: Force Downgrade to 1.4.0**

If bad OTA doesn't work, try force downgrade:

```powershell
# Build 1.4.0 binary metadata first
"C:\Users\ardav\AppData\Local\Programs\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe" compile --fqbn esp32:esp32:esp32da skyfeeder --output-dir skyfeeder/build_1.4.0

# Get SHA256
Get-FileHash -Algorithm SHA256 skyfeeder\build_1.4.0\skyfeeder.ino.bin

# Stage it
mkdir ops\local\ota-server\public\fw\1.4.0
copy skyfeeder\build_1.4.0\skyfeeder.ino.bin ops\local\ota-server\public\fw\1.4.0\skyfeeder.bin

# Create force downgrade payload
@'
{"url":"http://localhost:9180/fw/1.4.0/skyfeeder.bin","version":"1.4.0","size":<SIZE>,"sha256":"<SHA256>","staged":true,"force":true}
'@ | Set-Content REPORTS/A0.4/ota_payload_force.json -Encoding ASCII

# Send force downgrade
mosquitto_pub -h localhost -p 1883 -u dev1 -P dev1pass -t "skyfeeder/dev1/cmd/ota" -f REPORTS/A0.4/ota_payload_force.json
```

**Wait for device to downgrade and reboot**

---

## Step 6: Capture Final Status

Stop all captures (Ctrl+C)

```powershell
curl http://localhost:9180/v1/ota/status | jq . > REPORTS/A0.4/ota_status_final.json
curl http://localhost:8080/v1/discovery/dev1 | jq . > REPORTS/A0.4/discovery_final.json
curl http://localhost:8081/v1/metrics | jq . > REPORTS/A0.4/ws_metrics_after.json
```

---

## Step 7: Create Summary

```powershell
# Review captured logs
cat REPORTS/A0.4/ota_runA_events.log
cat REPORTS/A0.4/ota_runB_rollback.log
cat REPORTS/A0.4/ota_status_after_b.json
cat REPORTS/A0.4/ota_status_final.json
```

**Create REPORTS/A0.4/test_results.md** with:
- Download duration (from first download_started to download_ok)
- Reboot duration (from apply_pending to applied)
- Final versions (before/after/final)
- Success/failure status
- Any errors observed

---

## Verification Checklist

After all steps complete, verify these artifacts exist:

- [x] REPORTS/A0.4/ota_runA_events.log - MQTT events during A→B upgrade
- [x] REPORTS/A0.4/serial_runA.log - Serial output during A→B upgrade (optional)
- [x] REPORTS/A0.4/ota_status_after_b.json - Status after upgrade
- [x] REPORTS/A0.4/discovery_after_b.json - Discovery after upgrade
- [x] REPORTS/A0.4/ota_runB_rollback.log - MQTT events during rollback
- [x] REPORTS/A0.4/serial_rollback.log - Serial output during rollback (optional)
- [x] REPORTS/A0.4/ota_status_final.json - Final status
- [x] REPORTS/A0.4/test_results.md - Test summary

---

## Success Criteria

- ✅ A→B upgrade completes successfully (1.4.0 → 1.4.2)
- ✅ Device boots on first attempt after upgrade (bootCount = 1)
- ✅ Rollback mechanism works (either via bad OTA or force downgrade)
- ✅ MQTT events match expected sequence
- ✅ No crashes or infinite boot loops

---

**Generated:** 2025-10-19
**Status:** Ready for execution (close Serial Monitor first)
