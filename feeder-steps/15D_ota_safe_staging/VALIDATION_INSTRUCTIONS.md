# Step 15D OTA Safe Staging - Detailed Validation Instructions

## Firmware Details
- **Binary Path**: `D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\feeder-steps\15D_ota_safe_staging\builds\skyfeeder.ino.bin`
- **Size**: 1,217,408 bytes
- **SHA256**: `3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102`
- **Version**: 1.2.0 → 1.3.0 (upgrade test)

## Prerequisites
1. **ESP32 Device**: Running Step 15D firmware, connected to WiFi
2. **MQTT Broker**: Accessible at `10.0.0.4` with credentials `dev1`/`dev1pass`
3. **Web Server**: HTTP server serving the firmware binary (setup in Step 1 below)
4. **Device ID**: `sf-mock01` (or adjust commands accordingly)

## Step 1: Setup Web Server for Firmware

### Option A: Simple Python HTTP Server
```powershell
# Navigate to the builds directory
cd "D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\feeder-steps\15D_ota_safe_staging\builds"

# Start Python HTTP server on port 8080
python -m http.server 8080
```

### Option B: Use Your Existing Web Server
Copy `skyfeeder.ino.bin` to your web server at `http://10.0.0.4/fw/` so it's accessible at:
`http://10.0.0.4/fw/skyfeeder.ino.bin`

## Step 2: Monitor MQTT Events (Terminal 1)

Open a new PowerShell terminal and run:
```powershell
# Monitor OTA events
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/event/ota" -v

# Expected sequence:
# skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"download_started","version":"1.3.0","url":"http://..."}
# skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"download_ok","version":"1.3.0","progress":100}
# skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"verify_ok","version":"1.3.0","sha256":"3cfad1b3..."}
# skyfeeder/sf-mock01/event/ota {"schema":"v1","state":"apply_pending","version":"1.3.0","staged":true}
```

## Step 3: Publish OTA Command

### Using the PowerShell Script:
```powershell
cd "D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\feeder-steps\15D_ota_safe_staging\code\server\ota_admin_cli"

# For local Python server (Option A):
.\ota-publish.ps1 -DeviceId "sf-mock01" -Version "1.3.0" -Url "http://YOUR_IP:8080/skyfeeder.ino.bin" -Size 1217408 -Sha256 "3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102" -Channel "beta" -Staged $true

# For existing web server (Option B):
.\ota-publish.ps1 -DeviceId "sf-mock01" -Version "1.3.0" -Url "http://10.0.0.4/fw/skyfeeder.ino.bin" -Size 1217408 -Sha256 "3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102" -Channel "beta" -Staged $true
```

### Using Direct MQTT Command:
```powershell
# Replace YOUR_IP with your actual IP address if using Python server
$payload = '{"version":"1.3.0","url":"http://YOUR_IP:8080/skyfeeder.ino.bin","size":1217408,"sha256":"3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102","channel":"beta","staged":true}'

mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/cmd/ota" -m $payload
```

## Step 4: Monitor Device Logs (Terminal 2)

```powershell
# Monitor device telemetry and logs
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/+/+" -v
```

## Step 5: Validate Download and Staging

Watch Terminal 1 for the expected sequence:
1. **`download_started`** - OTA download begins
2. **`download_ok`** - Firmware downloaded successfully
3. **`verify_ok`** - SHA-256 verification passed
4. **`apply_pending`** - Firmware staged, awaiting safe boot

## Step 6: Trigger Reboot for Staged Update

The update is staged but won't apply until reboot. You can:

### Option A: Wait for automatic reboot (if configured)
### Option B: Manual reboot command
```powershell
# Send reboot command (if implemented)
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/cmd/reboot" -m '{"immediate":true}'
```

### Option C: Physical reset
Press the reset button on the ESP32

## Step 7: Validate Applied State

After reboot, watch for:
```json
{"schema":"v1","state":"applied","version":"1.3.0","lastGoodFw":"1.2.0"}
```

## Step 8: Verify Discovery Update

```powershell
# Check device discovery shows correct step
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/discovery" -C 1 -v

# Should show: "step":"sf_step15D_ota_safe_staging"
```

## Step 9: Test Rollback (Optional)

To test the boot health watchdog:

1. Flash firmware with intentional crash/infinite loop
2. Device should auto-rollback after failed boots
3. Monitor for rollback event:
```json
{"schema":"v1","state":"rollback","fromVersion":"1.3.0","toVersion":"1.2.0","reason":"boot_health_timeout"}
```

## Troubleshooting

### Download Fails
- Verify web server is accessible
- Check firewall settings
- Ensure correct URL and file exists

### Verification Fails
- Double-check SHA-256 hash matches exactly
- Verify file wasn't corrupted during transfer

### No MQTT Events
- Check device is connected to WiFi
- Verify MQTT broker credentials
- Ensure device is running Step 15D firmware

### Staging Fails
- Check available flash space
- Verify OTA partition is configured correctly

## Success Criteria

✅ Download completes with progress events
✅ SHA-256 verification passes
✅ Firmware stages successfully
✅ Reboot applies the new firmware
✅ Device publishes "applied" event
✅ NVS persistence stores lastGoodFw
✅ Discovery advertises correct step identifier