# Complete OTA Test Steps

## Current Status
✅ Device: dev1
✅ Current FW: 1.4.0
✅ MQTT working
✅ Discovery publishing
✅ OTA command parsing working
❌ Need fresh v1.5.0 binary

## Step-by-Step Instructions

### 1. Compile v1.5.0 Binary

```
Arduino IDE:
1. Open skyfeeder/skyfeeder.ino
2. Edit skyfeeder/config.h line 3: Change to #define FW_VERSION "1.5.0"
3. Sketch → Verify/Compile (or click checkmark)
4. Wait for "Done compiling"
5. Note the sketch path in output (should be: C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665)
```

**IMPORTANT: Do NOT upload! We want v1.4.0 running on the device and v1.5.0 as the OTA binary.**

### 2. Start HTTP Server (Terminal 1)

```powershell
cd C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665
python -m http.server 8080
```

Leave this running.

### 3. Start MQTT Monitor (Terminal 2)

```powershell
mosquitto_sub -h 10.0.0.4 -t "skyfeeder/dev1/#" -v
```

Leave this running.

### 4. Send OTA Command (Terminal 3)

```powershell
cd D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\tools\ota-validator
.\send-ota.ps1 -HttpPort 8080
```

### 5. Expected Results

**Terminal 2 (MQTT) should show:**
```
skyfeeder/dev1/event/ota {"status":"download_started","version":"1.5.0",...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.5.0","progress":10,...}
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.5.0","progress":20,...}
...
skyfeeder/dev1/event/ota {"status":"downloading","version":"1.5.0","progress":100,...}
skyfeeder/dev1/event/ota {"status":"download_ok","version":"1.5.0",...}
skyfeeder/dev1/event/ota {"status":"verify_ok","version":"1.5.0",...}
skyfeeder/dev1/event/ota {"status":"apply_pending","version":"1.5.0",...}
```

**Terminal 1 (HTTP) should show:**
```
10.0.0.xxx - - [date] "GET /skyfeeder.ino.bin HTTP/1.1" 200 -
```

**Serial Monitor should show:**
```
DEBUG: Received OTA payload...
DEBUG: JSON parsed successfully
DEBUG: Calling OtaManager::processCommand...
DEBUG: processCommand result: SUCCESS
DEBUG: OTA command accepted!
OTA Download: 10%
OTA Download: 20%
...
OTA Download: 100%
```

### 6. Reboot ESP32

Press the reset button.

### 7. Verify Update

```powershell
.\check-device.ps1
```

Should show: **FW Version: 1.5.0**

---

## Troubleshooting

### Size Mismatch Error
- Binary changed after you got SHA-256
- Solution: Recompile v1.5.0 and run send-ota.ps1 again

### SHA-256 Mismatch Error
- Using old hash from previous compilation
- Solution: Recompile v1.5.0 and run send-ota.ps1 again

### Version Not Newer Error
- Device is already running 1.5.0
- Solution: Change config.h back to 1.4.0, upload to device, then try again

### HTTP Connection Reset
- Normal - happens when ESP32 finishes download
- Check MQTT events to see if download completed

### No Debug Output
- Wrong baud rate (should be 115200)
- Wrong COM port selected
- Device not rebooted after upload

---

## Quick Reference

**Check device status:**
```powershell
.\check-device.ps1
```

**Send OTA update:**
```powershell
.\send-ota.ps1 -HttpPort 8080
```

**Monitor all MQTT:**
```powershell
mosquitto_sub -h 10.0.0.4 -t "skyfeeder/dev1/#" -v
```

**Start HTTP server:**
```powershell
cd C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665
python -m http.server 8080
```