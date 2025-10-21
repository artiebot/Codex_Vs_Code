# SkyFeeder 24-Hour Soak Test Monitor
# Monitors device activity across MQTT, WebSocket, MinIO, and OTA for 24+ hours
# Usage: .\soak-test-24h.ps1 [-DeviceId dev1] [-Duration 24] [-OutputDir REPORTS\A1.4]

param(
    [string]$DeviceId = "dev1",
    [int]$DurationHours = 24,
    [string]$OutputDir = "REPORTS\A1.4\soak-test",
    [string]$MqttHost = "10.0.0.4",
    [string]$MqttUser = "dev1",
    [string]$MqttPass = "dev1pass",
    [string]$WsRelayUrl = "http://localhost:8081/v1/metrics",
    [string]$OtaServerUrl = "http://localhost:9180/v1/ota/status",
    [string]$MinioAlias = "local",
    [string]$PhotosBucket = "photos"
)

$ErrorActionPreference = "Continue"
$StartTime = Get-Date
$EndTime = $StartTime.AddHours($DurationHours)

Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "SkyFeeder 24-Hour Soak Test Monitor"
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "Device ID:       $DeviceId"
Write-Host "Duration:        $DurationHours hours"
Write-Host "Start Time:      $StartTime"
Write-Host "End Time:        $EndTime"
Write-Host "Output Dir:      $OutputDir"
Write-Host "MQTT Broker:     $MqttHost"
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host ""

# Create output directory
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[SETUP] Created output directory: $OutputDir"
}

# Initialize log files
$MqttLog = Join-Path $OutputDir "mqtt_events.jsonl"
$UploadLog = Join-Path $OutputDir "uploads.jsonl"
$WsMetricsLog = Join-Path $OutputDir "ws_metrics.jsonl"
$OtaHeartbeatsLog = Join-Path $OutputDir "ota_heartbeats.jsonl"
$SummaryLog = Join-Path $OutputDir "summary.log"
$ErrorLog = Join-Path $OutputDir "errors.log"

# Initialize summary counters
$Script:Counters = @{
    MqttMessages = 0
    Uploads = 0
    UploadSuccesses = 0
    UploadFailures = 0
    WsConnections = 0
    OtaHeartbeats = 0
    Errors = 0
    Snapshots = 0
    BootEvents = 0
}

function Write-Summary {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $Entry = "[$Timestamp] $Message"
    Add-Content -Path $SummaryLog -Value $Entry
    Write-Host $Entry
}

function Write-Error-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $Entry = "[$Timestamp] ERROR: $Message"
    Add-Content -Path $ErrorLog -Value $Entry
    Write-Host $Entry -ForegroundColor Red
    $Script:Counters.Errors++
}

# Start MQTT listener in background
Write-Summary "Starting MQTT listener..."
$MqttJob = Start-Job -ScriptBlock {
    param($Host, $User, $Pass, $Topic, $LogFile)
    mosquitto_sub -h $Host -u $User -P $Pass -t $Topic -v | ForEach-Object {
        $Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        $Entry = @{
            timestamp = $Timestamp
            raw = $_
        } | ConvertTo-Json -Compress
        Add-Content -Path $LogFile -Value $Entry
    }
} -ArgumentList $MqttHost, $MqttUser, $MqttPass, "skyfeeder/$DeviceId/#", $MqttLog

Write-Summary "MQTT listener started (Job ID: $($MqttJob.Id))"

# Monitoring loop
Write-Summary "Starting monitoring loop (checking every 60 seconds)..."
$CheckInterval = 60  # seconds
$LastUploadCount = 0
$LastWsMessageCount = 0

try {
    while ((Get-Date) -lt $EndTime) {
        $Now = Get-Date
        $Elapsed = $Now - $StartTime
        $Remaining = $EndTime - $Now

        Write-Summary "CHECK: Elapsed $($Elapsed.ToString('hh\:mm\:ss')) / Remaining $($Remaining.ToString('hh\:mm\:ss'))"

        # Check MinIO for new uploads
        try {
            $MinioOutput = docker exec skyfeeder-minio mc ls $MinioAlias/$PhotosBucket/$DeviceId/ 2>&1
            if ($LASTEXITCODE -eq 0) {
                $UploadCount = ($MinioOutput | Where-Object { $_ -match '\d{4}-\d{2}-\d{2}.*\.jpg' } | Measure-Object).Count
                if ($UploadCount -gt $LastUploadCount) {
                    $NewUploads = $UploadCount - $LastUploadCount
                    $Script:Counters.Uploads += $NewUploads
                    $Script:Counters.UploadSuccesses += $NewUploads

                    $Entry = @{
                        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                        total = $UploadCount
                        new = $NewUploads
                    } | ConvertTo-Json -Compress
                    Add-Content -Path $UploadLog -Value $Entry
                    Write-Summary "NEW UPLOADS: +$NewUploads (total: $UploadCount)"
                }
                $LastUploadCount = $UploadCount
            }
        } catch {
            Write-Error-Log "MinIO check failed: $_"
        }

        # Check WebSocket metrics
        try {
            $WsMetrics = Invoke-RestMethod -Uri $WsRelayUrl -Method Get -ErrorAction Stop
            $Entry = @{
                timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                totalClients = $WsMetrics.totalClients
                messageCount = $WsMetrics.messageCount
                rooms = $WsMetrics.rooms.Count
            } | ConvertTo-Json -Compress
            Add-Content -Path $WsMetricsLog -Value $Entry

            if ($WsMetrics.totalClients -gt 0) {
                $Script:Counters.WsConnections++
                Write-Summary "WS: $($WsMetrics.totalClients) clients, $($WsMetrics.messageCount) messages"
            }

            if ($WsMetrics.messageCount -gt $LastWsMessageCount) {
                $NewMessages = $WsMetrics.messageCount - $LastWsMessageCount
                Write-Summary "WS: +$NewMessages new messages"
            }
            $LastWsMessageCount = $WsMetrics.messageCount
        } catch {
            Write-Error-Log "WebSocket metrics check failed: $_"
        }

        # Check OTA heartbeats
        try {
            $OtaStatus = Invoke-RestMethod -Uri $OtaServerUrl -Method Get -ErrorAction Stop
            if ($OtaStatus.Count -gt 0) {
                $Script:Counters.OtaHeartbeats = $OtaStatus.Count
                $Entry = @{
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    count = $OtaStatus.Count
                } | ConvertTo-Json -Compress
                Add-Content -Path $OtaHeartbeatsLog -Value $Entry
                Write-Summary "OTA: $($OtaStatus.Count) heartbeat(s)"
            }
        } catch {
            Write-Error-Log "OTA status check failed: $_"
        }

        # Check MQTT log for new events
        if (Test-Path $MqttLog) {
            $MqttEvents = Get-Content $MqttLog -Tail 100 -ErrorAction SilentlyContinue
            foreach ($Event in $MqttEvents) {
                try {
                    $EventObj = $Event | ConvertFrom-Json
                    if ($EventObj.raw -match 'event/camera/snapshot') {
                        $Script:Counters.Snapshots++
                    }
                    if ($EventObj.raw -match 'event/sys.*boot') {
                        $Script:Counters.BootEvents++
                    }
                } catch {
                    # Ignore JSON parse errors
                }
            }
            $Script:Counters.MqttMessages = ($MqttEvents | Measure-Object).Count
        }

        # Sleep until next check
        Start-Sleep -Seconds $CheckInterval
    }
} finally {
    # Cleanup
    Write-Summary "Test duration complete. Stopping monitors..."

    if ($MqttJob) {
        Stop-Job -Job $MqttJob -ErrorAction SilentlyContinue
        Remove-Job -Job $MqttJob -Force -ErrorAction SilentlyContinue
        Write-Summary "MQTT listener stopped"
    }

    # Generate final summary
    Write-Summary "═══════════════════════════════════════════════════════════"
    Write-Summary "24-HOUR SOAK TEST SUMMARY"
    Write-Summary "═══════════════════════════════════════════════════════════"
    Write-Summary "Duration:          $DurationHours hours"
    Write-Summary "MQTT Messages:     $($Script:Counters.MqttMessages)"
    Write-Summary "Total Uploads:     $($Script:Counters.Uploads)"
    Write-Summary "Upload Successes:  $($Script:Counters.UploadSuccesses)"
    Write-Summary "Upload Failures:   $($Script:Counters.UploadFailures)"
    Write-Summary "WS Connections:    $($Script:Counters.WsConnections)"
    Write-Summary "OTA Heartbeats:    $($Script:Counters.OtaHeartbeats)"
    Write-Summary "Snapshots:         $($Script:Counters.Snapshots)"
    Write-Summary "Boot Events:       $($Script:Counters.BootEvents)"
    Write-Summary "Errors:            $($Script:Counters.Errors)"
    Write-Summary "═══════════════════════════════════════════════════════════"

    if ($Script:Counters.Uploads -gt 0) {
        $SuccessRate = [math]::Round(($Script:Counters.UploadSuccesses / $Script:Counters.Uploads) * 100, 2)
        Write-Summary "SUCCESS RATE: $SuccessRate% ($($Script:Counters.UploadSuccesses)/$($Script:Counters.Uploads))"

        if ($SuccessRate -ge 85) {
            Write-Summary "✓ SUCCESS: Target success rate (>=85%) achieved!"
        } else {
            Write-Summary "✗ FAIL: Success rate below 85% target"
        }
    } else {
        Write-Summary "⚠ WARNING: No uploads detected during test period"
    }

    # Generate summary report
    $ReportPath = Join-Path $OutputDir "SOAK_TEST_REPORT.md"

    $TableHeader = '| Metric | Count |'
    $TableSeparator = '|--------|-------|'
    $TableRow1 = "| MQTT Messages | " + $Script:Counters.MqttMessages + " |"
    $TableRow2 = "| Total Uploads | " + $Script:Counters.Uploads + " |"
    $TableRow3 = "| Upload Successes | " + $Script:Counters.UploadSuccesses + " |"
    $TableRow4 = "| Upload Failures | " + $Script:Counters.UploadFailures + " |"
    $TableRow5 = "| WebSocket Connections | " + $Script:Counters.WsConnections + " |"
    $TableRow6 = "| OTA Heartbeats | " + $Script:Counters.OtaHeartbeats + " |"
    $TableRow7 = "| Snapshot Events | " + $Script:Counters.Snapshots + " |"
    $TableRow8 = "| Boot Events | " + $Script:Counters.BootEvents + " |"
    $TableRow9 = "| Errors | " + $Script:Counters.Errors + " |"

    if ($Script:Counters.Uploads -gt 0) {
        $SuccessRate = [math]::Round(($Script:Counters.UploadSuccesses / $Script:Counters.Uploads) * 100, 2)
        $SuccessRateText = "**$SuccessRate%** ($($Script:Counters.UploadSuccesses)/$($Script:Counters.Uploads) successful uploads)"
    } else {
        $SuccessRateText = "⚠️ **No uploads detected during test period**"
    }

    if ($Script:Counters.Uploads -gt 0 -and ($Script:Counters.UploadSuccesses / $Script:Counters.Uploads) -ge 0.85) {
        $TestStatus = "✅ **PASS** - Success rate >= 85% target"
    } elseif ($Script:Counters.Uploads -gt 0) {
        $TestStatus = "❌ **FAIL** - Success rate below 85% target"
    } else {
        $TestStatus = "⚠️ **INCOMPLETE** - Device did not come online during test period"
    }

    $ReportContent = @"
# SkyFeeder 24-Hour Soak Test Report

**Test Date:** $StartTime to $(Get-Date)
**Device ID:** $DeviceId
**Duration:** $DurationHours hours

## Summary Metrics

$TableHeader
$TableSeparator
$TableRow1
$TableRow2
$TableRow3
$TableRow4
$TableRow5
$TableRow6
$TableRow7
$TableRow8
$TableRow9

## Success Rate

$SuccessRateText

## Artifacts

- MQTT Events: ``$MqttLog``
- Uploads Log: ``$UploadLog``
- WebSocket Metrics: ``$WsMetricsLog``
- OTA Heartbeats: ``$OtaHeartbeatsLog``
- Summary Log: ``$SummaryLog``
- Error Log: ``$ErrorLog``

## Test Status

$TestStatus
"@

    $ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8

    Write-Summary "Report saved to: $ReportPath"
}