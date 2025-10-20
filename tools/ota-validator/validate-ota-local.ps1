# A0.4 OTA Local Stack Validation Script
# Updated version with localhost support for local development stack

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
    [string]$MqttHost = "10.0.0.4",
    [Parameter(Mandatory=$false)]
    [string]$HttpHost = "localhost",
    [Parameter(Mandatory=$false)]
    [string]$HttpPort = "9180",
    [Parameter(Mandatory=$false)]
    [string]$DeviceId = "dev1"
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
    Write-Host "  A0.4 OTA Local Stack Validator" -ForegroundColor Cyan
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

function Send-OtaCommand {
    param($FirmwareInfo)

    $url = "http://${HttpHost}:${HttpPort}/fw/$($FirmwareInfo.version)/skyfeeder.bin"

    # Create JSON payload
    $payload = @{
        url = $url
        version = $FirmwareInfo.version
        sha256 = $FirmwareInfo.sha256
        size = $FirmwareInfo.size
        staged = $true
    } | ConvertTo-Json -Compress

    # Escape for mosquitto_pub
    $escapedPayload = $payload -replace '"', '\"'

    Write-Host "Sending OTA command..." -ForegroundColor Yellow
    Write-Host "Topic: skyfeeder/$DeviceId/command/ota" -ForegroundColor Gray
    Write-Host "Payload: $payload" -ForegroundColor Gray
    Write-Host ""

    # Send command
    $cmd = "mosquitto_pub -h $MqttHost -t `"skyfeeder/$DeviceId/command/ota`" -m `"$escapedPayload`""
    Write-Host "Executing: $cmd" -ForegroundColor Gray
    Invoke-Expression $cmd

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
    Write-Host '   .\validate-ota-local.ps1 -GenerateInfo -BinPath "C:\path\to\firmware.bin" -Version "1.5.0"' -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Send OTA command (defaults to localhost:9180):" -ForegroundColor White
    Write-Host '   .\validate-ota-local.ps1 -SendCommand -BinPath "C:\path\to\firmware.bin" -Version "1.5.0"' -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Override MQTT host:" -ForegroundColor White
    Write-Host '   .\validate-ota-local.ps1 -SendCommand -BinPath "..." -Version "1.5.0" -MqttHost "192.168.1.100"' -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Monitor MQTT events:" -ForegroundColor White
    Write-Host "   mosquitto_sub -h $MqttHost -t `"skyfeeder/$DeviceId/#`" -v" -ForegroundColor Gray
    Write-Host ""
}
