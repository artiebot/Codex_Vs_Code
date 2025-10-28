# Step 15D OTA Safe Staging Validation Script
# This script helps validate the complete OTA workflow

param(
    [Parameter(Mandatory=$false)]
    [string]$BinPath,
    [Parameter(Mandatory=$false)]
    [string]$Version,
    [Parameter(Mandatory=$false)]
    [switch]$GenerateInfo,
    [Parameter(Mandatory=$false)]
    [switch]$SendCommand,
    [Parameter(Mandatory=$false)]
    [string]$DeviceId = "dev1",
    [Parameter(Mandatory=$false)]
    [string]$MqttHost = "localhost",
    [Parameter(Mandatory=$false)]
    [string]$MqttUsername = "dev1",
    [Parameter(Mandatory=$false)]
    [string]$MqttPassword = "dev1pass",
    [Parameter(Mandatory=$false)]
    [int]$MqttPort = 1883,
    [Parameter(Mandatory=$false)]
    [string]$HttpHost = "localhost",
    [Parameter(Mandatory=$false)]
    [int]$HttpPort = 9180,
    [Parameter(Mandatory=$false)]
    [string]$HttpPath = "/fw",
    [Parameter(Mandatory=$false)]
    [string]$FirmwareUrl,
    [Parameter(Mandatory=$false)]
    [bool]$Staged = $true,
    [Parameter(Mandatory=$false)]
    [bool]$Force = $false
)

function Get-FileHash256 {
    param([string]$Path)
    $hash = Get-FileHash -Path $Path -Algorithm SHA256
    return $hash.Hash.ToLower()
}

function Get-FileSize {
    param([string]$Path)
    return (Get-Item $Path).Length
}

function Show-Banner {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Step 15D OTA Validation Helper" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Show-FirmwareInfo {
    param([string]$Path, [string]$Ver)

    if (-not (Test-Path $Path)) {
        Write-Host "ERROR: Binary file not found: $Path" -ForegroundColor Red
        return $null
    }

    $sha256 = Get-FileHash256 -Path $Path
    $size = Get-FileSize -Path $Path

    Write-Host "Firmware Information:" -ForegroundColor Green
    Write-Host "  Version: $Ver" -ForegroundColor White
    Write-Host "  Path:    $Path" -ForegroundColor White
    Write-Host "  Size:    $size bytes" -ForegroundColor White
    Write-Host "  SHA256:  $sha256" -ForegroundColor White
    Write-Host ""

    return @{
        version = $Ver
        path = $Path
        size = $size
        sha256 = $sha256
    }
}

function Join-HttpPath {
    param([string]$Host, [int]$Port, [string]$PathFragment)
    $normalized = $PathFragment
    if (-not $normalized.StartsWith("/")) {
        $normalized = "/" + $normalized
    }
    return "http://$Host`:$Port$normalized"
}

function Send-OtaCommand {
    param($FirmwareInfo)

    $urlToSend = $FirmwareUrl
    if (-not $urlToSend) {
        $relative = "/skyfeeder.ino.bin"
        if ($FirmwareInfo -and $FirmwareInfo.ContainsKey("relative")) {
            $relative = $FirmwareInfo.relative
        } elseif ($HttpPath) {
            $relative = (Join-Path -Path $HttpPath -ChildPath "skyfeeder.ino.bin")
            $relative = $relative -replace "\\", "/"
        }
        $urlToSend = Join-HttpPath -Host $HttpHost -Port $HttpPort -PathFragment $relative
    }

    # Create JSON payload
    $payload = @{
        url = $urlToSend
        version = $FirmwareInfo.version
        sha256 = $FirmwareInfo.sha256
        size = $FirmwareInfo.size
        staged = $Staged
    }
    if ($Force) {
        $payload.force = $true
    }

    $payloadJson = $payload | ConvertTo-Json -Compress

    Write-Host "Sending OTA command..." -ForegroundColor Yellow
    Write-Host "Topic: skyfeeder/$DeviceId/cmd/ota" -ForegroundColor Gray
    Write-Host "Payload: $payloadJson" -ForegroundColor Gray
    Write-Host ""

    # Send command
    Write-Host ("Executing: mosquitto_pub -h {0} -p {1} -t skyfeeder/{2}/cmd/ota -u <user> -P <pass> -m <payload>" -f $MqttHost, $MqttPort, $DeviceId) -ForegroundColor Gray
    & mosquitto_pub -h $MqttHost -p $MqttPort -u $MqttUsername -P $MqttPassword -t ("skyfeeder/{0}/cmd/ota" -f $DeviceId) -m $payloadJson

    Write-Host "`nOTA command sent!" -ForegroundColor Green
    Write-Host "Monitor events with:" -ForegroundColor Yellow
    Write-Host "  mosquitto_sub -h $MqttHost -t `"skyfeeder/$DeviceId/event/ota`" -v" -ForegroundColor White
}

# Main execution
Show-Banner

if ($GenerateInfo -and $BinPath -and $Version) {
    Show-FirmwareInfo -Path $BinPath -Ver $Version
}
elseif ($SendCommand -and $BinPath -and $Version) {
    $info = Show-FirmwareInfo -Path $BinPath -Ver $Version
    if ($info) {
        Send-OtaCommand -FirmwareInfo $info
    }
}
else {
    Write-Host "Usage Examples:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Generate firmware info:" -ForegroundColor White
    Write-Host '   .\validate-ota.ps1 -GenerateInfo -BinPath "C:\path\to\firmware.bin" -Version "1.5.0"' -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Send OTA command:" -ForegroundColor White
    Write-Host '   .\validate-ota.ps1 -SendCommand -BinPath "C:\path\to\firmware.bin" -Version "1.5.0"' -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Monitor MQTT events:" -ForegroundColor White
    Write-Host "   mosquitto_sub -h $MqttHost -t `"skyfeeder/$DeviceId/#`" -v" -ForegroundColor Gray
    Write-Host ""
}
