# 24-Hour Automated Validation Test - RUNNING

**Start Time:** 2025-10-27 20:21:43
**End Time:** 2025-10-28 20:21:43 (Tomorrow)
**Status:** ✅ ALL TESTS RUNNING

---

## Tests Running

### 1. **24-Hour Soak Test** 🔄
**Purpose:** Monitor upload success rate, device crashes, MQTT connectivity
**Output:** `summary.log`, `uploads.jsonl`, `ws_metrics.jsonl`
**Window:** Minimized PowerShell window #1

**Check progress:**
```powershell
Get-Content 'REPORTS\A1.4\24h-final\summary.log' -Tail 20
```

---

### 2. **AMB-Mini Serial Logging** 📝
**Purpose:** Capture all AMB firmware output (upload messages, errors, status)
**Output:** `amb-serial.log`
**Window:** Minimized PowerShell window #2

**Check log:**
```powershell
Get-Content 'REPORTS\A1.4\24h-final\amb-serial.log' -Tail 50
```

**What to look for:**
- `[upload] SUCCESS` - Photo uploaded successfully
- `[upload] ERROR` - Upload failed
- `[http] Upload complete: 204` - HTTP success

---

### 3. **ESP32 Serial Logging** 📝
**Purpose:** Capture ESP32 firmware output (MQTT, crashes, PIR events)
**Output:** `esp32-serial.log`
**Window:** Minimized PowerShell window #3

**Check log:**
```powershell
Get-Content 'REPORTS\A1.4\24h-final\esp32-serial.log' -Tail 50
```

**What to look for:**
- `[visit] PIR capture` - Motion detected
- `[mini] event phase=done` - Snapshot completed
- **Any crash messages** - `a=8892.16` repeating, `Guru Meditation`, etc.

---

### 4. **Power Monitoring** ⚡
**Purpose:** Measure current/power consumption during snapshot events
**Output:** `power.csv`
**Window:** Minimized PowerShell window #4

**Check data:**
```powershell
Get-Content 'REPORTS\A1.4\24h-final\power.csv' -Tail 20
```

**Metrics:**
- Snapshot event power consumption
- Deep sleep current
- Peak current during upload

---

### 5. **Periodic Snapshot Trigger** 📸
**Purpose:** Trigger snapshots every 30 minutes to generate upload data
**How it works:** Sends MQTT command → ESP32 wakes AMB via GPIO → AMB captures → AMB uploads
**Interval:** 30 minutes (48 snapshots over 24 hours)
**Window:** Minimized PowerShell window #5

**Why needed:** AMB-Mini only wakes on PIR motion. Without this, AMB stays asleep and no uploads happen!

**MQTT command sent:**
```json
Topic: skyfeeder/dev1/cmd/camera
Payload: {"op":"snapshot"}
```

---

## Log Files Location

All logs are in: `D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code\REPORTS\A1.4\24h-final\`

| File | Purpose | Updated |
|------|---------|---------|
| `summary.log` | Soak test progress | Every 60s |
| `uploads.jsonl` | Upload events | On upload |
| `ws_metrics.jsonl` | WebSocket metrics | Every 60s |
| `amb-serial.log` | AMB serial output | Real-time |
| `esp32-serial.log` | ESP32 serial output | Real-time |
| `power.csv` | Power measurements | Every 10s |

---

## Quick Status Check

**Run this command to see current status:**
```powershell
cd 'D:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code'

Write-Host "Soak Test Status:" -ForegroundColor Cyan
Get-Content 'REPORTS\A1.4\24h-final\summary.log' -Tail 5

Write-Host "`nRecent AMB Messages:" -ForegroundColor Cyan
Get-Content 'REPORTS\A1.4\24h-final\amb-serial.log' -Tail 10 -ErrorAction SilentlyContinue

Write-Host "`nRecent ESP32 Messages:" -ForegroundColor Cyan
Get-Content 'REPORTS\A1.4\24h-final\esp32-serial.log' -Tail 10 -ErrorAction SilentlyContinue

Write-Host "`nPower Measurements:" -ForegroundColor Cyan
Get-Content 'REPORTS\A1.4\24h-final\power.csv' -Tail 5 -ErrorAction SilentlyContinue
```

---

## Important Notes

### ⚠️ **DO NOT:**
- Close the minimized PowerShell windows
- Close the master control window
- Unplug USB cables (ESP32 or AMB-Mini)
- Turn off computer / put in sleep mode
- Stop Docker containers

### ✅ **You CAN:**
- Minimize all windows
- Use the computer normally
- Check logs at any time
- Leave and come back tomorrow

---

## When Tests Complete (Tomorrow 8:21 PM)

### **Final Reports Generated:**

1. **Soak Test Summary** - Upload success rate, crash count
2. **Serial Logs** - Complete 24h output from both devices
3. **Power Report** - Average/peak power consumption
4. **Upload Log** - All upload attempts with success/failure

### **Validation Criteria:**

| Metric | Target | File |
|--------|--------|------|
| Upload Success Rate | ≥90% | `summary.log` |
| Device Crashes | 0 | `esp32-serial.log` |
| Power Per Event | <200mAh | `power.csv` |
| Device Uptime | 24h | `summary.log` |

---

## Troubleshooting

### **If tests stop:**

1. **Check if windows are still open:**
   ```powershell
   Get-Process powershell | Where-Object {$_.MainWindowTitle -like "*soak*"}
   ```

2. **Restart tests:**
   ```powershell
   .\REPORTS\A1.4\24h-final\start-all-tests.ps1
   ```

3. **Check for errors:**
   ```powershell
   Get-Content 'REPORTS\A1.4\24h-final\summary.log' -Tail 50
   ```

---

## Contact

**Tests started by:** Claude
**Date:** 2025-10-27 20:21:43
**Expected completion:** 2025-10-28 20:21:43

**Status:** ✅ Running smoothly - check back tomorrow!

---

## Quick Commands Reference

```powershell
# Check soak test progress
Get-Content 'REPORTS\A1.4\24h-final\summary.log' -Tail 20

# Watch AMB serial output live
Get-Content 'REPORTS\A1.4\24h-final\amb-serial.log' -Wait -Tail 20

# Watch ESP32 serial output live
Get-Content 'REPORTS\A1.4\24h-final\esp32-serial.log' -Wait -Tail 20

# Check upload success count
Get-Content 'REPORTS\A1.4\24h-final\uploads.jsonl' | Measure-Object

# View power data
Import-Csv 'REPORTS\A1.4\24h-final\power.csv' | Select-Object -Last 10
```

---

**All systems running! See you tomorrow for results!** 🚀
