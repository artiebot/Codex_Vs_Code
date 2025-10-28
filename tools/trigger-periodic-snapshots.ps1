# Trigger Periodic Snapshots for Soak Testing
# Sends snapshot commands to device at regular intervals
# Usage: .\trigger-periodic-snapshots.ps1 [-Interval 3600] [-Count 24] [-DeviceId dev1]

param(
    [int]$IntervalSeconds = 3600,  # 1 hour default
    [int]$Count = 24,               # 24 snapshots (24 hours at 1/hour)
    [string]$DeviceId = "dev1",
    [string]$MqttHost = "10.0.0.4",
    [string]$MqttUser = "dev1",
    [string]$MqttPass = "dev1pass"
)

$StartTime = Get-Date
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "SkyFeeder Periodic Snapshot Trigger"
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "Device ID:     $DeviceId"
Write-Host "Interval:      $IntervalSeconds seconds ($([math]::Round($IntervalSeconds/60, 1)) minutes)"
Write-Host "Total Count:   $Count"
Write-Host "Total Duration: $([math]::Round($IntervalSeconds * $Count / 3600, 1)) hours"
Write-Host "MQTT Broker:   $MqttHost"
Write-Host "Start Time:    $StartTime"
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host ""

$CommandTopic = "skyfeeder/$DeviceId/cmd/camera"
$Command = '{"op":"snapshot"}'

for ($i = 1; $i -le $Count; $i++) {
    $Now = Get-Date
    $Elapsed = $Now - $StartTime
    Write-Host "[$Now] Snapshot $i/$Count (Elapsed: $($Elapsed.ToString('hh\:mm\:ss')))"

    try {
        mosquitto_pub -h $MqttHost -u $MqttUser -P $MqttPass -t $CommandTopic -m $Command
        Write-Host "  ✓ Command sent to: $CommandTopic"
    } catch {
        Write-Host "  ✗ ERROR: Failed to send command: $_" -ForegroundColor Red
    }

    if ($i -lt $Count) {
        Write-Host "  Waiting $IntervalSeconds seconds until next snapshot..."
        Write-Host ""
        Start-Sleep -Seconds $IntervalSeconds
    }
}

$EndTime = Get-Date
$TotalDuration = $EndTime - $StartTime

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "Snapshot triggering complete!"
Write-Host "Total snapshots sent: $Count"
Write-Host "Total duration:       $($TotalDuration.ToString('hh\:mm\:ss'))"
Write-Host "End time:             $EndTime"
Write-Host "═══════════════════════════════════════════════════════════"