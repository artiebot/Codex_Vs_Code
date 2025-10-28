# A1.4 24-Hour Soak Test - Status

## Test Overview

**Status:** RUNNING
**Start Time:** 2025-10-20 20:52:08
**Expected End:** 2025-10-21 20:52:08
**Device ID:** dev1
**Target Success Rate:** >= 85%

## Running Processes

### 1. Soak Test Monitor (Process ID: 2bced8)
- **Command:** `tools\soak-test-24h.ps1`
- **Function:** Monitors device health and upload success rate
- **Output Directory:** `REPORTS\A1.4\soak-test\`
- **Check Interval:** 60 seconds
- **Monitoring:**
  - MQTT events on `skyfeeder/dev1/#`
  - MinIO photo uploads (60-second polling)
  - WebSocket connection metrics
  - OTA heartbeat status
  - Error tracking

**Initial Status (First 10 minutes):**
- 6 existing uploads detected in MinIO
- Monitoring active and stable

### 2. Periodic Snapshot Trigger (Process ID: 142d10)
- **Command:** `tools\trigger-periodic-snapshots.ps1`
- **Function:** Sends snapshot commands every hour
- **Interval:** 3600 seconds (1 hour)
- **Total Snapshots:** 24
- **First Snapshot:** 2025-10-20 21:02:00
- **Next Snapshot:** 2025-10-20 22:02:00

## How to Monitor Progress

### Check Current Status
```powershell
# View latest soak test output
Get-Content REPORTS\A1.4\soak-test\summary.log -Tail 20

# View MQTT events
Get-Content REPORTS\A1.4\soak-test\mqtt_events.jsonl -Tail 10

# View upload tracking
Get-Content REPORTS\A1.4\soak-test\uploads.jsonl -Tail 10
```

### Monitor Live (Windows)
```powershell
# Tail the summary log
Get-Content REPORTS\A1.4\soak-test\summary.log -Wait -Tail 20
```

### Check Process Status
The background processes will run automatically. If you need to check if they're still running, you can use Task Manager or PowerShell:
```powershell
Get-Process | Where-Object {$_.ProcessName -eq "powershell"}
```

## Expected Outputs

After 24 hours, the following files will be generated:

1. **SOAK_TEST_REPORT.md** - Comprehensive test report with:
   - Summary metrics (MQTT messages, uploads, errors)
   - Upload success rate percentage
   - Pass/Fail verdict (>= 85% target)
   - Links to all artifact logs

2. **mqtt_events.jsonl** - All MQTT messages during test period
3. **uploads.jsonl** - Upload tracking with timestamps
4. **ws_metrics.jsonl** - WebSocket connection metrics
5. **ota_heartbeats.jsonl** - OTA service heartbeat logs
6. **summary.log** - Human-readable progress log
7. **errors.log** - Any errors encountered

## What to Do Next

### When Test Completes (10/21 20:52:08)
1. Review `REPORTS\A1.4\soak-test\SOAK_TEST_REPORT.md`
2. Check if success rate >= 85%
3. If PASS: Mark A1.4 soak test as complete
4. If FAIL: Investigate errors.log and failed uploads

### If You Need to Stop Early
**WARNING:** Stopping early will result in INCOMPLETE test results.

If necessary, you can kill the processes:
```powershell
# Find PowerShell processes
Get-Process powershell

# Stop specific process by ID
Stop-Process -Id <process_id>
```

## Validation Checklist

- [x] Automated soak test monitor running
- [x] Periodic snapshot trigger active (24 snapshots scheduled)
- [ ] 24-hour test duration complete
- [ ] Upload success rate >= 85%
- [ ] No critical errors in error log
- [ ] Device remained online throughout test
- [ ] SOAK_TEST_REPORT.md generated
- [ ] Power consumption measurements (<200 mAh per event)

## Notes

- Device must remain powered and connected to Wi-Fi for full 24 hours
- MinIO, MQTT broker, and ws-relay services must remain online
- Do not reflash firmware during test period
- Serial console NOT required (test runs remotely)
