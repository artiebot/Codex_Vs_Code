#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Send camera control commands to SkyFeeder ESP32 via MQTT

.DESCRIPTION
    Sends JSON commands to skyfeeder/dev1/cmd/cam topic for Mini camera control

.PARAMETER Command
    Command to send: status, wake, sleep, snapshot

.PARAMETER DeviceId
    Device ID (default: dev1)

.PARAMETER MqttHost
    MQTT broker host (default: 10.0.0.4)

.PARAMETER MqttUser
    MQTT username (default: dev1)

.PARAMETER MqttPass
    MQTT password (default: dev1pass)

.EXAMPLE
    .\mqtt-cam-control.ps1 -Command status
    Send status request to camera

.EXAMPLE
    .\mqtt-cam-control.ps1 -Command wake
    Wake up the camera

.EXAMPLE
    .\mqtt-cam-control.ps1 -Command sleep
    Put camera to sleep

.EXAMPLE
    .\mqtt-cam-control.ps1 -Command snapshot
    Request snapshot capture
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("status", "wake", "sleep", "snapshot")]
    [string]$Command,

    [string]$DeviceId = "dev1",
    [string]$MqttHost = "10.0.0.4",
    [string]$MqttUser = "dev1",
    [string]$MqttPass = "dev1pass"
)

# Build topic
$Topic = "skyfeeder/$DeviceId/cmd/cam"

# Build JSON payload
$Payload = "{`"op`":`"$Command`"}"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  SkyFeeder Camera Control via MQTT" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Command  : $Command" -ForegroundColor Yellow
Write-Host "Topic    : $Topic" -ForegroundColor Yellow
Write-Host "Payload  : $Payload" -ForegroundColor Yellow
Write-Host "Broker   : $MqttHost" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if mosquitto_pub is available
$mosquittoPub = Get-Command mosquitto_pub -ErrorAction SilentlyContinue
if (-not $mosquittoPub) {
    Write-Host "ERROR: mosquitto_pub not found in PATH!" -ForegroundColor Red
    Write-Host "Install Mosquitto MQTT tools:" -ForegroundColor Yellow
    Write-Host "  https://mosquitto.org/download/" -ForegroundColor Yellow
    exit 1
}

# Send command
Write-Host "Sending command..." -ForegroundColor Green
try {
    $result = & mosquitto_pub `
        -h $MqttHost `
        -u $MqttUser `
        -P $MqttPass `
        -t $Topic `
        -m $Payload `
        2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Command sent successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "To monitor responses, run in another terminal:" -ForegroundColor Cyan
        Write-Host "  mosquitto_sub -h $MqttHost -u $MqttUser -P $MqttPass -t `"skyfeeder/$DeviceId/event/ack`" -v" -ForegroundColor White
    } else {
        Write-Host "✗ Failed to send command!" -ForegroundColor Red
        Write-Host "Error: $result" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Exception occurred!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
