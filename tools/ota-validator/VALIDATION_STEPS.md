# Step 15D OTA Safe Staging - Complete Validation Guide

## What You Need On Your Side

### 1. **Compile Current Firmware (v1.4.0)**
- Ensure `skyfeeder/config.h` has `FW_VERSION "1.4.0"`
- Compile in Arduino IDE
- Flash to ESP32
- Note the `.bin` file location (usually in temp directory shown in Arduino IDE output)

### 2. **Start MQTT Monitoring**
Open a PowerShell terminal and run:
```powershell
mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/#" -v
```
Leave this running to see all MQTT traffic.

### 3. **Verify Device Online**
- Check serial monitor - should see "SETUP COMPLETE" and WiFi/MQTT connected
- Check MQTT subscriber - should see:
  - `skyfeeder/sf-mock01/status online`
  - `skyfeeder/sf-mock01/discovery {...}` with `"step":"sf_step15D_ota_safe_staging"`
  - `skyfeeder/sf-mock01/event/health/boot {...}` boot health event

**If discovery is missing:** Check serial debug output for "Discovery publish result". If it says "FAILED", there may be an MQTT buffer issue - try restarting the device.

---

## Test 1: Successful OTA Update (v1.4.0 → v1.5.0)

### Step 1: Compile v1.5.0 Firmware
1. Edit `skyfeeder/config.h` line 3: Change `"1.4.0"` to `"1.5.0"`
2. Compile in Arduino IDE (Sketch → Export Compiled Binary)
3. Note the `.bin` file location from the output

### Step 2: Get Firmware Info
Run the helper script:
```powershell
cd tools\ota-validator
.\validate-ota.ps1 -GenerateInfo -BinPath "C:\path\to\your\skyfeeder.ino.bin" -Version "1.5.0"
```
This will display the SHA-256 hash and file size you'll need.

### Step 3: Start HTTP Server
Copy the `.bin` file to a folder and serve it:
```powershell
# In the directory containing your .bin file:
python -m http.server 8000
```
The firmware will be available at `http://10.0.0.4:8000/skyfeeder.ino.bin`

### Step 4: Send OTA Command
**Option A:** Use the helper script:
```powershell
.\validate-ota.ps1 -SendCommand -BinPath "C:\path\to\your\skyfeeder.ino.bin" -Version "1.5.0"
```

**Option B:** Manual command (replace YOUR_SHA256 and YOUR_SIZE):
```powershell
mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/command/ota" -m '{\"url\":\"http://10.0.0.4:8000/skyfeeder.ino.bin\",\"version\":\"1.5.0\",\"sha256\":\"YOUR_SHA256_HERE\",\"size\":YOUR_SIZE_HERE}'
```

### Step 5: Monitor OTA Events
Watch your MQTT subscriber terminal. You should see this sequence:

```
skyfeeder/sf-mock01/event/ota {"status":"download_started","version":"1.5.0",...}
skyfeeder/sf-mock01/event/ota {"status":"download_ok","version":"1.5.0",...}
skyfeeder/sf-mock01/event/ota {"status":"verify_ok","version":"1.5.0",...}
skyfeeder/sf-mock01/event/ota {"status":"apply_pending","version":"1.5.0",...}
```

✅ **Expected:** All 4 events appear within ~10 seconds.

### Step 6: Reboot and Verify
1. **Press the reset button** on the ESP32
2. Watch serial monitor for boot sequence
3. Check MQTT subscriber for new discovery message
4. **Verify:** Discovery shows `"fw_version":"1.5.0"`

✅ **Success:** Device boots with v1.5.0 and publishes discovery!

---

## Test 2: Version Gating (Reject Same Version)

### Step 1: Send Same Version Again
Using the same v1.5.0 binary, send the OTA command again:
```powershell
.\validate-ota.ps1 -SendCommand -BinPath "C:\path\to\your\skyfeeder.ino.bin" -Version "1.5.0"
```

### Step 2: Verify Rejection
Watch MQTT subscriber. You should see:
```
skyfeeder/sf-mock01/event/ota {"status":"version_not_newer","current":"1.5.0","requested":"1.5.0",...}
```

✅ **Expected:** Immediate rejection with `version_not_newer` error.

---

## Test 3: Downgrade Protection (Optional)

### Step 1: Try Older Version
Try sending the v1.4.0 OTA command (from your earlier compilation):
```powershell
.\validate-ota.ps1 -SendCommand -BinPath "C:\path\to\v1.4.0\skyfeeder.ino.bin" -Version "1.4.0"
```

### Step 2: Verify Rejection
Should see `version_not_newer` event again.

✅ **Expected:** Downgrades are blocked.

---

## Test 4: Automatic Rollback (Advanced - Optional)

This tests that bad firmware automatically rolls back.

### Step 1: Create Bad Firmware
1. Edit `skyfeeder/provisioning.cpp`
2. Comment out line 54 in `mqtt_client.cpp`: `// SF::provisioning.onMqttConnected(client);`
3. Change version to `"1.6.0"` in `config.h`
4. Compile

### Step 2: Send Bad Firmware
```powershell
.\validate-ota.ps1 -SendCommand -BinPath "C:\path\to\bad\skyfeeder.ino.bin" -Version "1.6.0"
```

### Step 3: Watch Rollback
1. Wait for `apply_pending` event
2. Press reset button
3. Watch serial monitor - device will boot with v1.6.0
4. **But:** Since discovery won't publish, boot health will fail
5. After 60 seconds, watchdog triggers reboot
6. Device rolls back to v1.5.0 automatically

### Step 4: Verify Rollback Event
Check MQTT for:
```
skyfeeder/sf-mock01/event/health/boot {"status":"bootloader_revert","fw_version":"1.5.0",...}
```

✅ **Expected:** Device automatically reverts to last known good firmware!

---

## Troubleshooting

### Discovery Not Publishing
1. Check serial monitor for "Discovery publish result: FAILED"
2. If failed, check MQTT buffer size (default should be 512 bytes)
3. Try restarting the device
4. Verify MQTT broker is reachable: `mosquitto_pub -h 10.0.0.4 -t test -m hello`

### OTA Command Ignored
1. Check serial monitor for "Received OTA payload"
2. If missing, verify topic: `skyfeeder/sf-mock01/command/ota`
3. Check device ID matches: `sf-mock01` (in config.h or NVS)
4. Verify JSON escaping (quotes must be escaped with `\"`)

### Download Fails
1. Check HTTP server is running: `curl http://10.0.0.4:8000/skyfeeder.ino.bin`
2. Verify IP address is correct (your computer's IPv4)
3. Check firewall isn't blocking port 8000
4. Ensure `.bin` file name matches URL exactly

### SHA-256 Mismatch
1. Verify you're using the correct `.bin` file
2. Regenerate hash: `Get-FileHash -Path "your.bin" -Algorithm SHA256`
3. Ensure hash is lowercase in JSON payload
4. Don't modify the `.bin` file after generating hash

---

## Summary of Success Criteria

✅ **Discovery:** Device publishes `"step":"sf_step15D_ota_safe_staging"` on boot
✅ **OTA Sequence:** All 4 events (download_started → download_ok → verify_ok → apply_pending)
✅ **Version Update:** Device boots with new version after reset
✅ **Version Gating:** Same/older versions rejected with `version_not_newer`
✅ **Rollback (Optional):** Bad firmware automatically reverts to last good version

---

## Quick Command Reference

```powershell
# Monitor all device events
mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/#" -v

# Monitor only OTA events
mosquitto_sub -h 10.0.0.4 -t "skyfeeder/sf-mock01/event/ota" -v

# Start HTTP server (in directory with .bin file)
python -m http.server 8000

# Get firmware info
.\validate-ota.ps1 -GenerateInfo -BinPath "path\to\firmware.bin" -Version "1.5.0"

# Send OTA command
.\validate-ota.ps1 -SendCommand -BinPath "path\to\firmware.bin" -Version "1.5.0"

# Manual OTA command (escape quotes properly)
mosquitto_pub -h 10.0.0.4 -t "skyfeeder/sf-mock01/command/ota" -m '{\"url\":\"http://10.0.0.4:8000/skyfeeder.ino.bin\",\"version\":\"1.5.0\",\"sha256\":\"abc123...\",\"size\":123456}'
```