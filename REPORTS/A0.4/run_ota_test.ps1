# A0.4 OTA Test Automation Script
# This script helps execute the OTA test steps

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("upgrade", "verify", "rollback", "final")]
    [string]$Step = "upgrade"
)

$MqttHost = "localhost"
$MqttPort = 1883
$MqttUser = "dev1"
$MqttPass = "dev1pass"
$DeviceId = "dev1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  A0.4 OTA Test - Step: $Step" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

switch ($Step) {
    "upgrade" {
        Write-Host "Starting A→B OTA Upgrade Test (1.4.0 → 1.4.2)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This will:" -ForegroundColor White
        Write-Host "  1. Start MQTT event capture" -ForegroundColor Gray
        Write-Host "  2. Send OTA command to device" -ForegroundColor Gray
        Write-Host "  3. Monitor upgrade progress" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press ENTER when device is ready (running v1.4.0, connected to MQTT)..." -ForegroundColor Yellow
        Read-Host

        Write-Host "`nStarting MQTT capture..." -ForegroundColor Green
        Write-Host "  Topic: skyfeeder/$DeviceId/event/ota" -ForegroundColor Gray
        Write-Host "  Output: REPORTS/A0.4/ota_runA_events.log" -ForegroundColor Gray
        Write-Host ""

        # Start MQTT capture in background
        $mqttJob = Start-Job -ScriptBlock {
            param($h, $p, $u, $pw, $d)
            mosquitto_sub -h $h -p $p -u $u -P $pw -t "skyfeeder/$d/event/ota" -v
        } -ArgumentList $MqttHost, $MqttPort, $MqttUser, $MqttPass, $DeviceId

        Start-Sleep -Seconds 2

        Write-Host "Sending OTA command..." -ForegroundColor Green
        Write-Host "  Payload: REPORTS/A0.4/ota_payload.json" -ForegroundColor Gray
        Write-Host ""

        mosquitto_pub -h $MqttHost -p $MqttPort -u $MqttUser -P $MqttPass `
            -t "skyfeeder/$DeviceId/cmd/ota" -f REPORTS/A0.4/ota_payload.json

        Write-Host "`nOTA command sent!" -ForegroundColor Green
        Write-Host "Monitoring MQTT events for 120 seconds..." -ForegroundColor Yellow
        Write-Host "Watch for:" -ForegroundColor White
        Write-Host "  - download_started" -ForegroundColor Gray
        Write-Host "  - download_ok" -ForegroundColor Gray
        Write-Host "  - verify_ok" -ForegroundColor Gray
        Write-Host "  - apply_pending" -ForegroundColor Gray
        Write-Host "  - [Device reboots]" -ForegroundColor Gray
        Write-Host "  - applied (after reboot)" -ForegroundColor Gray
        Write-Host ""

        # Wait for 2 minutes to capture upgrade
        for ($i = 120; $i -gt 0; $i--) {
            Write-Host "`rTime remaining: $i seconds..." -NoNewline -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
        Write-Host ""

        Write-Host "`nStopping MQTT capture..." -ForegroundColor Yellow
        Stop-Job -Job $mqttJob
        $events = Receive-Job -Job $mqttJob
        Remove-Job -Job $mqttJob

        $events | Out-File -FilePath REPORTS/A0.4/ota_runA_events.log -Encoding ASCII

        Write-Host "MQTT events saved to REPORTS/A0.4/ota_runA_events.log" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next step: Run with -Step verify" -ForegroundColor Yellow
    }

    "verify" {
        Write-Host "Verifying OTA Upgrade Success" -ForegroundColor Yellow
        Write-Host ""

        Write-Host "Fetching OTA status..." -ForegroundColor Green
        curl http://localhost:9180/v1/ota/status | jq . > REPORTS/A0.4/ota_status_after_b.json

        Write-Host "Fetching discovery payload..." -ForegroundColor Green
        curl http://localhost:8080/v1/discovery/dev1 | jq . > REPORTS/A0.4/discovery_after_b.json

        Write-Host ""
        Write-Host "Device Status:" -ForegroundColor Cyan
        $status = Get-Content REPORTS/A0.4/ota_status_after_b.json | ConvertFrom-Json
        $device = $status | Where-Object { $_.deviceId -eq $DeviceId }

        if ($device) {
            Write-Host "  Device ID:   $($device.deviceId)" -ForegroundColor White
            Write-Host "  Version:     $($device.version)" -ForegroundColor White
            Write-Host "  Boot Count:  $($device.bootCount)" -ForegroundColor White
            Write-Host "  Status:      $($device.status)" -ForegroundColor White
            Write-Host ""

            if ($device.version -eq "1.4.2" -and $device.bootCount -eq 1) {
                Write-Host "✅ UPGRADE SUCCESSFUL!" -ForegroundColor Green
                Write-Host ""
                Write-Host "Next step: Run with -Step rollback" -ForegroundColor Yellow
            } else {
                Write-Host "⚠️  UPGRADE MAY HAVE FAILED" -ForegroundColor Red
                Write-Host "  Expected: version=1.4.2, bootCount=1" -ForegroundColor Yellow
                Write-Host "  Got:      version=$($device.version), bootCount=$($device.bootCount)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ Device not found in OTA status" -ForegroundColor Red
        }
    }

    "rollback" {
        Write-Host "Starting Rollback Test (Bad OTA)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This will send an OTA with incorrect SHA256 to trigger error handling" -ForegroundColor White
        Write-Host ""
        Write-Host "Press ENTER to continue..." -ForegroundColor Yellow
        Read-Host

        Write-Host "`nCreating bad OTA payload..." -ForegroundColor Green
        @'
{"url":"http://localhost:9180/fw/1.4.2/skyfeeder.ino.bin","version":"1.4.3","size":1226432,"sha256":"0000000000000000000000000000000000000000000000000000000000000000","staged":true}
'@ | Set-Content REPORTS/A0.4/ota_payload_bad.json -Encoding ASCII

        Write-Host "Starting MQTT capture..." -ForegroundColor Green

        # Start MQTT capture in background
        $mqttJob = Start-Job -ScriptBlock {
            param($h, $p, $u, $pw, $d)
            mosquitto_sub -h $h -p $p -u $u -P $pw -t "skyfeeder/$d/event/ota" -v
        } -ArgumentList $MqttHost, $MqttPort, $MqttUser, $MqttPass, $DeviceId

        Start-Sleep -Seconds 2

        Write-Host "Sending bad OTA command..." -ForegroundColor Green
        mosquitto_pub -h $MqttHost -p $MqttPort -u $MqttUser -P $MqttPass `
            -t "skyfeeder/$DeviceId/cmd/ota" -f REPORTS/A0.4/ota_payload_bad.json

        Write-Host "`nMonitoring for error event (60 seconds)..." -ForegroundColor Yellow
        Write-Host "Expected: sha256_mismatch error" -ForegroundColor Gray
        Write-Host ""

        for ($i = 60; $i -gt 0; $i--) {
            Write-Host "`rTime remaining: $i seconds..." -NoNewline -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
        Write-Host ""

        Write-Host "`nStopping MQTT capture..." -ForegroundColor Yellow
        Stop-Job -Job $mqttJob
        $events = Receive-Job -Job $mqttJob
        Remove-Job -Job $mqttJob

        $events | Out-File -FilePath REPORTS/A0.4/ota_runB_rollback.log -Encoding ASCII

        Write-Host "MQTT events saved to REPORTS/A0.4/ota_runB_rollback.log" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next step: Run with -Step final" -ForegroundColor Yellow
    }

    "final" {
        Write-Host "Capturing Final Status" -ForegroundColor Yellow
        Write-Host ""

        Write-Host "Fetching final OTA status..." -ForegroundColor Green
        curl http://localhost:9180/v1/ota/status | jq . > REPORTS/A0.4/ota_status_final.json

        Write-Host "Fetching final discovery..." -ForegroundColor Green
        curl http://localhost:8080/v1/discovery/dev1 | jq . > REPORTS/A0.4/discovery_final.json

        Write-Host "Fetching WebSocket metrics..." -ForegroundColor Green
        curl http://localhost:8081/v1/metrics | jq . > REPORTS/A0.4/ws_metrics_after.json

        Write-Host ""
        Write-Host "✅ A0.4 Validation Artifacts Complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Generated Files:" -ForegroundColor Cyan
        Write-Host "  - REPORTS/A0.4/ota_runA_events.log" -ForegroundColor Gray
        Write-Host "  - REPORTS/A0.4/ota_status_after_b.json" -ForegroundColor Gray
        Write-Host "  - REPORTS/A0.4/discovery_after_b.json" -ForegroundColor Gray
        Write-Host "  - REPORTS/A0.4/ota_runB_rollback.log" -ForegroundColor Gray
        Write-Host "  - REPORTS/A0.4/ota_status_final.json" -ForegroundColor Gray
        Write-Host "  - REPORTS/A0.4/discovery_final.json" -ForegroundColor Gray
        Write-Host "  - REPORTS/A0.4/ws_metrics_after.json" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Review the logs and create REPORTS/A0.4/test_results.md summary" -ForegroundColor Yellow
    }
}

Write-Host ""
