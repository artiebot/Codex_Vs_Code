#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor SkyFeeder camera ACK responses via MQTT

.DESCRIPTION
    Subscribes to skyfeeder/dev1/event/ack and displays formatted responses

.PARAMETER DeviceId
    Device ID (default: dev1)

.PARAMETER MqttHost
    MQTT broker host (default: 10.0.0.4)

.PARAMETER MqttUser
    MQTT username (default: dev1)

.PARAMETER MqttPass
    MQTT password (default: dev1pass)

.PARAMETER Topic
    Specific topic to monitor (default: event/ack)
    Options: event/ack, event/#, #

.EXAMPLE
    .\mqtt-cam-monitor.ps1
    Monitor ACK responses

.EXAMPLE
    .\mqtt-cam-monitor.ps1 -Topic "event/#"
    Monitor all events

.EXAMPLE
    .\mqtt-cam-monitor.ps1 -Topic "#"
    Monitor all topics for device
#>

param(
    [string]$DeviceId = "dev1",
    [string]$MqttHost = "10.0.0.4",
    [string]$MqttUser = "dev1",
    [string]$MqttPass = "dev1pass",
    [string]$Topic = "event/ack"
)

# Build full topic
$FullTopic = "skyfeeder/$DeviceId/$Topic"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  SkyFeeder MQTT Monitor" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Device   : $DeviceId" -ForegroundColor Yellow
Write-Host "Topic    : $FullTopic" -ForegroundColor Yellow
Write-Host "Broker   : $MqttHost" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Listening for messages... (Ctrl+C to stop)" -ForegroundColor Green
Write-Host ""

# Check if mosquitto_sub is available
$mosquittoSub = Get-Command mosquitto_sub -ErrorAction SilentlyContinue
if (-not $mosquittoSub) {
    Write-Host "ERROR: mosquitto_sub not found in PATH!" -ForegroundColor Red
    Write-Host "Install Mosquitto MQTT tools:" -ForegroundColor Yellow
    Write-Host "  https://mosquitto.org/download/" -ForegroundColor Yellow
    exit 1
}

# Subscribe to topic
try {
    & mosquitto_sub `
        -h $MqttHost `
        -u $MqttUser `
        -P $MqttPass `
        -t $FullTopic `
        -v
} catch {
    Write-Host "✗ Exception occurred!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
