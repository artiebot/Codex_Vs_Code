<#
.SYNOPSIS
    Measures power consumption during snapshot and upload using INA260 sensor

.DESCRIPTION
    Monitors MQTT telemetry for INA260 power readings while triggering snapshot commands.
    Measures current/power during idle, snapshot capture, upload, and sleep phases.
    Generates CSV data and summary report.

.PARAMETER DeviceId
    Device ID to monitor (e.g., "dev1")

.PARAMETER SnapshotCount
    Number of snapshots to capture for averaging (default: 5)

.PARAMETER OutputDir
    Directory for output files (default: REPORTS\A1.4)

.PARAMETER MqttBroker
    MQTT broker address (default: 10.0.0.4)

.EXAMPLE
    .\tools\measure-power-ina260.ps1 -DeviceId dev1 -SnapshotCount 5
#>

param(
    [string]$DeviceId = "dev1",
    [int]$SnapshotCount = 5,
    [string]$OutputDir = "REPORTS\A1.4",
    [string]$MqttBroker = "10.0.0.4"
)

$ErrorActionPreference = "Stop"

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$csvPath = Join-Path $OutputDir "power_measurements.csv"
$summaryPath = Join-Path $OutputDir "power_summary.md"
$rawPath = Join-Path $OutputDir "power_raw.jsonl"

Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "INA260 Power Measurement Tool"
Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "Device ID:       $DeviceId"
Write-Host "Snapshot Count:  $SnapshotCount"
Write-Host "Output Dir:      $OutputDir"
Write-Host "MQTT Broker:     $MqttBroker"
Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host ""

# Data collection arrays
$baseline = @()
$snapshots = @()
$rawEvents = @()

# CSV header
"timestamp,phase,bus_v,current_a,power_w,snapshot_bytes,upload_success" | Out-File $csvPath -Encoding UTF8

function Parse-PowerTelemetry {
    param([string]$payload)

    try {
        $json = $payload | ConvertFrom-Json
        if ($json.power.ok -eq $true) {
            return @{
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fff"
                bus_v = $json.power.bus_v
                current = $json.power.current
                power = $json.power.power
                ok = $true
            }
        }
    } catch {
        # Invalid JSON or missing power data
    }

    return $null
}

function Wait-ForPowerReading {
    param([int]$timeoutSec = 10)

    $start = Get-Date
    Write-Host "[INFO] Waiting for INA260 power reading..."

    while (((Get-Date) - $start).TotalSeconds -lt $timeoutSec) {
        $line = mosquitto_sub -h $MqttBroker -u $DeviceId -P "${DeviceId}pass" `
            -t "skyfeeder/$DeviceId/telemetry" -C 1 2>&1

        if ($line -match "skyfeeder/$DeviceId/telemetry (.+)") {
            $payload = $Matches[1]
            $power = Parse-PowerTelemetry $payload
            if ($power) {
                Write-Host "  ✓ Bus: $($power.bus_v)V, Current: $($power.current)A, Power: $($power.power)W"
                return $power
            }
        }

        Start-Sleep -Milliseconds 500
    }

    Write-Host "  ✗ No valid power reading received"
    return $null
}

# Step 1: Collect baseline power readings
Write-Host ""
Write-Host "[1/4] Collecting baseline power readings (idle state)..."
Write-Host "      Waiting 30 seconds for device to settle..."
Start-Sleep -Seconds 30

for ($i = 1; $i -le 5; $i++) {
    Write-Host "  Baseline sample $i/5..."
    $power = Wait-ForPowerReading -timeoutSec 15

    if ($power) {
        $baseline += $power
        "$($power.timestamp),baseline,$($power.bus_v),$($power.current),$($power.power),0,false" |
            Out-File $csvPath -Append -Encoding UTF8
        $rawEvents += @{phase="baseline"; data=$power}
    } else {
        Write-Host "  ⚠ WARNING: Could not read baseline power" -ForegroundColor Yellow
    }

    Start-Sleep -Seconds 5
}

if ($baseline.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: INA260 sensor not responding!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  1. Check INA260 is wired correctly:"
    Write-Host "     - VCC → 3.3V"
    Write-Host "     - GND → GND"
    Write-Host "     - SDA → GPIO21 (I2C_SDA)"
    Write-Host "     - SCL → GPIO22 (I2C_SCL)"
    Write-Host "  2. Check firmware has INA260 support enabled"
    Write-Host "  3. Check MQTT telemetry includes 'power' field with ok=true"
    Write-Host "  4. Monitor serial console for INA260 init messages"
    Write-Host ""
    exit 1
}

$avgBaseline = ($baseline | Measure-Object -Property power -Average).Average
Write-Host ""
Write-Host "  ✓ Baseline power: $([math]::Round($avgBaseline, 3))W ($($baseline.Count) samples)" -ForegroundColor Green

# Step 2: Collect power during snapshot/upload cycles
Write-Host ""
Write-Host "[2/4] Measuring power during $SnapshotCount snapshot cycles..."

for ($cycle = 1; $cycle -le $SnapshotCount; $cycle++) {
    Write-Host ""
    Write-Host "  Snapshot Cycle $cycle/$SnapshotCount"
    Write-Host "  ──────────────────────────────────────"

    # Trigger snapshot
    Write-Host "  [1] Triggering snapshot command..."
    mosquitto_pub -h $MqttBroker -u $DeviceId -P "${DeviceId}pass" `
        -t "skyfeeder/$DeviceId/cmd/camera" `
        -m '{"op":"snapshot"}' 2>&1 | Out-Null

    # Wait for snapshot event
    Write-Host "  [2] Waiting for snapshot completion..."
    $snapshotEvent = $null
    $timeout = 30
    $elapsed = 0

    while ($elapsed -lt $timeout) {
        $line = mosquitto_sub -h $MqttBroker -u $DeviceId -P "${DeviceId}pass" `
            -t "skyfeeder/$DeviceId/event/camera/snapshot" -C 1 -W 2 2>&1

        if ($line -match '\{.+\}') {
            $snapshotEvent = $Matches[0] | ConvertFrom-Json
            break
        }

        $elapsed += 2
        Start-Sleep -Seconds 2
    }

    if (-not $snapshotEvent) {
        Write-Host "      ✗ Snapshot timeout" -ForegroundColor Yellow
        continue
    }

    $uploadSuccess = $snapshotEvent.url -and $snapshotEvent.url -ne ""
    Write-Host "      ✓ Captured: $($snapshotEvent.bytes) bytes, Upload: $uploadSuccess"

    # Collect power readings during upload phase
    Write-Host "  [3] Monitoring power during upload/processing (30s)..."
    $cyclePower = @()

    for ($sample = 1; $sample -le 6; $sample++) {
        $power = Wait-ForPowerReading -timeoutSec 10

        if ($power) {
            $cyclePower += $power
            "$($power.timestamp),snapshot_cycle_$cycle,$($power.bus_v),$($power.current),$($power.power),$($snapshotEvent.bytes),$uploadSuccess" |
                Out-File $csvPath -Append -Encoding UTF8
            $rawEvents += @{
                phase="snapshot_cycle_$cycle"
                data=$power
                snapshot_bytes=$snapshotEvent.bytes
                upload_success=$uploadSuccess
            }
        }

        Start-Sleep -Seconds 5
    }

    if ($cyclePower.Count -gt 0) {
        $avgCyclePower = ($cyclePower | Measure-Object -Property power -Average).Average
        $maxCyclePower = ($cyclePower | Measure-Object -Property power -Maximum).Maximum
        Write-Host "      Avg: $([math]::Round($avgCyclePower, 3))W, Peak: $([math]::Round($maxCyclePower, 3))W"

        $snapshots += @{
            cycle = $cycle
            avg_power = $avgCyclePower
            max_power = $maxCyclePower
            samples = $cyclePower
            upload_success = $uploadSuccess
        }
    }

    # Wait before next cycle
    if ($cycle -lt $SnapshotCount) {
        Write-Host "  [4] Cooling down (30s)..."
        Start-Sleep -Seconds 30
    }
}

# Step 3: Collect deep sleep power (if applicable)
Write-Host ""
Write-Host "[3/4] Measuring deep sleep power (if device enters sleep)..."
Write-Host "      Note: AMB-Mini should enter sleep after $([int](90)) seconds of idle"
Write-Host "      Monitoring for 2 minutes..."

$sleepPower = @()
for ($sample = 1; $sample -le 12; $sample++) {
    $power = Wait-ForPowerReading -timeoutSec 15

    if ($power) {
        $sleepPower += $power
        "$($power.timestamp),sleep,$($power.bus_v),$($power.current),$($power.power),0,false" |
            Out-File $csvPath -Append -Encoding UTF8
        $rawEvents += @{phase="sleep"; data=$power}
    }

    Start-Sleep -Seconds 10
}

# Step 4: Generate summary report
Write-Host ""
Write-Host "[4/4] Generating summary report..."

$avgSleep = if ($sleepPower.Count -gt 0) {
    ($sleepPower | Measure-Object -Property power -Average).Average
} else {
    0
}

$snapshotAvgPowers = $snapshots | ForEach-Object { $_.avg_power }
$snapshotMaxPowers = $snapshots | ForEach-Object { $_.max_power }

$avgSnapshotPower = if ($snapshotAvgPowers.Count -gt 0) {
    ($snapshotAvgPowers | Measure-Object -Average).Average
} else {
    0
}

$maxSnapshotPower = if ($snapshotMaxPowers.Count -gt 0) {
    ($snapshotMaxPowers | Measure-Object -Maximum).Maximum
} else {
    0
}

# Calculate energy per event (Wh)
# Assuming 60 seconds average duration per snapshot cycle
$duration_hours = 60.0 / 3600.0  # 60 seconds in hours
$energy_per_snapshot_wh = $avgSnapshotPower * $duration_hours
$energy_per_snapshot_mah = ($energy_per_snapshot_wh / 3.7) * 1000  # Assuming 3.7V battery

# Generate markdown summary
$summary = @"
# INA260 Power Measurement Summary

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Device:** $DeviceId
**Snapshot Cycles:** $SnapshotCount
**Successful Uploads:** $(($snapshots | Where-Object { $_.upload_success } | Measure-Object).Count) of $SnapshotCount

---

## Power Consumption Summary

| Phase | Avg Power (W) | Peak Power (W) | Samples |
|-------|---------------|----------------|---------|
| Baseline (Idle) | $([math]::Round($avgBaseline, 3)) | $([math]::Round(($baseline | Measure-Object -Property power -Maximum).Maximum, 3)) | $($baseline.Count) |
| Snapshot/Upload | $([math]::Round($avgSnapshotPower, 3)) | $([math]::Round($maxSnapshotPower, 3)) | $(($snapshotAvgPowers | Measure-Object).Count) |
| Deep Sleep | $([math]::Round($avgSleep, 3)) | $([math]::Round(($sleepPower | Measure-Object -Property power -Maximum).Maximum, 3)) | $($sleepPower.Count) |

---

## Energy per Snapshot Event

**Estimated Duration:** 60 seconds
**Average Power:** $([math]::Round($avgSnapshotPower, 3))W
**Energy Consumed:** $([math]::Round($energy_per_snapshot_wh, 4))Wh ($([math]::Round($energy_per_snapshot_mah, 1))mAh @ 3.7V)

**Target:** < 200mAh per event
**Status:** $(if ($energy_per_snapshot_mah -lt 200) { "✅ PASS" } else { "❌ FAIL" })

---

## Detailed Cycle Measurements

"@

foreach ($snap in $snapshots) {
    $summary += @"

### Cycle $($snap.cycle)
- Average Power: $([math]::Round($snap.avg_power, 3))W
- Peak Power: $([math]::Round($snap.max_power, 3))W
- Upload Success: $($snap.upload_success)
- Samples: $($snap.samples.Count)

"@
}

$summary += @"

---

## Raw Data Files

- **CSV Data:** [power_measurements.csv](power_measurements.csv)
- **Raw Events:** [power_raw.jsonl](power_raw.jsonl)

---

## Notes

- INA260 measures current on bus power rail
- Baseline includes ESP32 + AMB-Mini idle consumption
- Snapshot/Upload includes photo capture + WiFi transmission
- Deep sleep measurements may vary if device doesn't enter sleep mode
- Energy calculations assume average 60-second snapshot duration

---

**Validation Result:** $(if ($energy_per_snapshot_mah -lt 200) { "✅ A1.4 Power requirements MET" } else { "❌ A1.4 Power requirements NOT MET - needs optimization" })
"@

$summary | Out-File $summaryPath -Encoding UTF8

# Save raw events
$rawEvents | ConvertTo-Json -Depth 5 | Out-File $rawPath -Encoding UTF8

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host "POWER MEASUREMENT COMPLETE"
Write-Host "════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "Results:"
Write-Host "  Baseline Power:     $([math]::Round($avgBaseline, 3))W"
Write-Host "  Snapshot Avg Power: $([math]::Round($avgSnapshotPower, 3))W"
Write-Host "  Snapshot Peak Power: $([math]::Round($maxSnapshotPower, 3))W"
Write-Host "  Energy per Event:   $([math]::Round($energy_per_snapshot_mah, 1))mAh @ 3.7V"
Write-Host ""
Write-Host "  Target: < 200mAh per event"
Write-Host "  Status: $(if ($energy_per_snapshot_mah -lt 200) { "✅ PASS" } else { "❌ FAIL" })"
Write-Host ""
Write-Host "Output Files:"
Write-Host "  - $csvPath"
Write-Host "  - $summaryPath"
Write-Host "  - $rawPath"
Write-Host ""

if ($energy_per_snapshot_mah -lt 200) {
    exit 0
} else {
    Write-Host "WARNING: Power consumption exceeds target!" -ForegroundColor Yellow
    exit 1
}
