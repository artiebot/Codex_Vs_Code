# Quick OTA Test Commands - v1.5.0

## Fixed Issues
✅ Increased MQTT buffer to 1024 bytes (fixes discovery publish failure)
✅ Changed device ID to "dev1" in config.h

## Step-by-Step Commands

### 1. Flash Current v1.4.0 Firmware First
```bash
# In Arduino IDE:
# 1. Change config.h line 3 to: #define FW_VERSION  "1.4.0"
# 2. Click "Upload" to flash to ESP32
# 3. Open Serial Monitor - verify discovery now publishes successfully
# 4. You should see device_id:"dev1" in discovery
```

### 2. Compile v1.5.0 for OTA
```bash
# In Arduino IDE:
# 1. Change config.h line 3 to: #define FW_VERSION  "1.5.0"
# 2. Sketch → Export Compiled Binary (or Ctrl+Alt+S)
# 3. Note the output path - look for a line like:
#    "Sketch uses XXXXX bytes... of program storage space"
#    The .bin file is in: C:\Users\<you>\AppData\Local\Temp\arduino\sketches\<hash>\
# 4. Copy the skyfeeder.ino.bin file to a known location
```

**Example:** Copy to your Desktop:
```powershell
copy "C:\Users\ardav\AppData\Local\Temp\arduino\sketches\<hash>\skyfeeder.ino.bin" "$env:USERPROFILE\Desktop\skyfeeder-v1.5.0.bin"
```

### 3. Get Firmware Info
```powershell
# Set the bin path to your Arduino sketch folder
$binPath = "C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665\skyfeeder.ino.bin"
$hash = (Get-FileHash -Path $binPath -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $binPath).Length

Write-Host "Version: 1.5.0"
Write-Host "Size: $size"
Write-Host "SHA256: $hash"
```

### 4. Start HTTP Server
```powershell
# Navigate to the sketch folder and start HTTP server
cd C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665
python -m http.server 8000
```

**Leave this terminal running!**

### 5. Start MQTT Monitor (New Terminal)
```powershell
mosquitto_sub -h 10.0.0.4 -t "skyfeeder/dev1/#" -v
```

**Leave this terminal running!**

### 6. Send OTA Command (New Terminal)
```powershell
# First, get the hash and size in this terminal:
$binPath = "C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665\skyfeeder.ino.bin"
$hash = (Get-FileHash -Path $binPath -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $binPath).Length

# Display the values
Write-Host "Sending OTA for version 1.5.0"
Write-Host "Size: $size"
Write-Host "SHA256: $hash"

# Send the OTA command (using PowerShell variables for automatic substitution)
mosquitto_pub -h 10.0.0.4 -t "skyfeeder/dev1/cmd/ota" -m "{`"url`":`"http://10.0.0.4:8000/skyfeeder.ino.bin`",`"version`":`"1.5.0`",`"sha256`":`"$hash`",`"size`":$size,`"staged`":true}"
```

### 7. Watch for OTA Events
In your MQTT monitor terminal, you should see:
```
skyfeeder/dev1/event/ota {"status":"download_started",...}
skyfeeder/dev1/event/ota {"status":"download_ok",...}
skyfeeder/dev1/event/ota {"status":"verify_ok",...}
skyfeeder/dev1/event/ota {"status":"apply_pending",...}
```

### 8. Reboot ESP32
Press the reset button on your ESP32.

### 9. Verify v1.5.0
Check MQTT monitor for discovery message. Should show:
```
skyfeeder/dev1/discovery {"device_id":"dev1","fw_version":"1.5.0",...}
```

✅ **Success!** Device updated from v1.4.0 to v1.5.0 via OTA!

---

## Test Version Gating (Same Command Again)

Send the exact same OTA command again. Should see:
```
skyfeeder/dev1/event/ota {"status":"version_not_newer","current":"1.5.0","requested":"1.5.0",...}
```

✅ **Success!** Version gating works!

---

## Quick Commands Template

```powershell
# Get firmware info and send OTA (all in one)
$binPath = "C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665\skyfeeder.ino.bin"
$hash = (Get-FileHash -Path $binPath -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $binPath).Length
Write-Host "SHA256: $hash"
Write-Host "Size: $size"

# Send OTA command
mosquitto_pub -h 10.0.0.4 -t "skyfeeder/dev1/cmd/ota" -m "{`"url`":`"http://10.0.0.4:8000/skyfeeder.ino.bin`",`"version`":`"1.5.0`",`"sha256`":`"$hash`",`"size`":$size,`"staged`":true}"
```