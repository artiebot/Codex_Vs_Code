#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick test script for camera commands

.DESCRIPTION
    Interactive menu to send camera commands and view responses

.EXAMPLE
    .\test-cam.ps1
    Shows interactive menu
#>

param(
    [string]$DeviceId = "dev1",
    [string]$MqttHost = "10.0.0.4",
    [string]$MqttUser = "dev1",
    [string]$MqttPass = "dev1pass"
)

$Topic = "skyfeeder/$DeviceId/cmd/cam"
$AckTopic = "skyfeeder/$DeviceId/event/ack"

function Send-Command {
    param([string]$Command)

    $Payload = "{`"op`":`"$Command`"}"

    Write-Host "`n→ Sending: $Command" -ForegroundColor Yellow
    Write-Host "  Payload: $Payload" -ForegroundColor Gray

    & mosquitto_pub -h $MqttHost -u $MqttUser -P $MqttPass -t $Topic -m $Payload 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Sent!" -ForegroundColor Green

        # Wait briefly for ACK
        Write-Host "  Waiting for ACK..." -ForegroundColor Cyan
        $ack = & mosquitto_sub -h $MqttHost -u $MqttUser -P $MqttPass -t $AckTopic -C 1 -W 2 2>&1

        if ($ack) {
            Write-Host "  ← ACK: $ack" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ No ACK received (timeout)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ Failed to send!" -ForegroundColor Red
    }
}

function Show-Menu {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "  SkyFeeder Camera Test Menu" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "Device: $DeviceId @ $MqttHost" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  1) Status   - Query camera status" -ForegroundColor Gray
    Write-Host "  2) Wake     - Wake up camera" -ForegroundColor Gray
    Write-Host "  3) Sleep    - Put camera to sleep" -ForegroundColor Gray
    Write-Host "  4) Snapshot - Capture snapshot" -ForegroundColor Gray
    Write-Host "  5) Monitor  - Listen for all events" -ForegroundColor Gray
    Write-Host "  Q) Quit" -ForegroundColor Gray
    Write-Host ""
}

# Check dependencies
$mosquittoPub = Get-Command mosquitto_pub -ErrorAction SilentlyContinue
$mosquittoSub = Get-Command mosquitto_sub -ErrorAction SilentlyContinue

if (-not $mosquittoPub -or -not $mosquittoSub) {
    Write-Host "ERROR: Mosquitto tools not found!" -ForegroundColor Red
    Write-Host "Install from: https://mosquitto.org/download/" -ForegroundColor Yellow
    exit 1
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Select option"

    switch ($choice.ToLower()) {
        "1" { Send-Command "status" }
        "2" { Send-Command "wake" }
        "3" { Send-Command "sleep" }
        "4" { Send-Command "snapshot" }
        "5" {
            Write-Host "`nListening for events (Ctrl+C to stop)..." -ForegroundColor Green
            & mosquitto_sub -h $MqttHost -u $MqttUser -P $MqttPass -t "skyfeeder/$DeviceId/#" -v
        }
        "q" {
            Write-Host "`nGoodbye!" -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "`n✗ Invalid choice!" -ForegroundColor Red
        }
    }
}
