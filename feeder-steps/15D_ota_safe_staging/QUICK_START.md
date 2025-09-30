# Step 15D OTA - Quick Start Guide

## 🚀 Ready-to-Run Commands

Your firmware details:
- **Size**: 1,217,408 bytes
- **SHA256**: `3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102`

### 1. Start Web Server (Terminal 1)
```powershell
cd "D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\feeder-steps\15D_ota_safe_staging\builds"
python -m http.server 8080
# Note your IP address, replace YOUR_IP below
```

### 2. Monitor OTA Events (Terminal 2)
```powershell
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/event/ota" -v
```

### 3. Publish OTA Command (Terminal 3)

**Replace `YOUR_IP` with your actual IP address:**

```powershell
# Using PowerShell script (RECOMMENDED):
cd "D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\feeder-steps\15D_ota_safe_staging\code\server\ota_admin_cli"

.\ota-publish.ps1 -DeviceId "sf-mock01" -Version "1.3.0" -Url "http://YOUR_IP:8080/skyfeeder.ino.bin" -Size 1217408 -Sha256 "3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102" -Channel "beta" -Staged $true
```

**Or using direct MQTT:**
```powershell
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/cmd/ota" -m '{"version":"1.3.0","url":"http://YOUR_IP:8080/skyfeeder.ino.bin","size":1217408,"sha256":"3cfad1b3515b65b36272c6cec695e8abde4edada378062cd126cd5d3707d7102","channel":"beta","staged":true}'
```

### 4. Expected Sequence in Terminal 2:
```
✅ download_started - OTA begins
✅ download_ok - Download complete
✅ verify_ok - SHA-256 verified
✅ apply_pending - Staged for reboot
```

### 5. Monitor Reboot and Applied State:
```powershell
# Terminal 4 - Monitor all device events
mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/+/+" -v
```

After device reboots, look for:
```json
{"schema":"v1","state":"applied","version":"1.3.0"}
```

## 🔍 Find Your IP Address
```powershell
# Windows
ipconfig | findstr IPv4

# Get network adapter IP
(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi").IPAddress
```

## ✅ Success Indicators
- [ ] Web server serves firmware at `http://YOUR_IP:8080/skyfeeder.ino.bin`
- [ ] OTA download starts and completes
- [ ] SHA-256 verification passes
- [ ] Firmware stages successfully
- [ ] Device reboots and applies update
- [ ] Applied event published with version 1.3.0

## ❌ Troubleshooting
- **Download fails**: Check IP address, firewall, web server running
- **Verification fails**: SHA-256 mismatch, check file integrity
- **No MQTT events**: Device offline, wrong MQTT credentials
- **Staging fails**: Flash space, OTA partition issues