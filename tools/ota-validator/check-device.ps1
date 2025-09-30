# Simple device status checker
$MqttHost = "10.0.0.4"
$DeviceId = "dev1"

Write-Host "Listening for discovery message from device..." -ForegroundColor Yellow
Write-Host "Waiting 10 seconds..." -ForegroundColor Gray
Write-Host ""

$discoveryFile = Join-Path $env:TEMP "discovery_check.json"
if (Test-Path $discoveryFile) { Remove-Item $discoveryFile }

Start-Process mosquitto_sub -ArgumentList "-h $MqttHost -t skyfeeder/$DeviceId/discovery -W 10 -C 1" -RedirectStandardOutput $discoveryFile -Wait -NoNewWindow

if (Test-Path $discoveryFile) {
    $discovery = Get-Content $discoveryFile -Raw
    if ($discovery -and $discovery.Length -gt 10) {
        Write-Host "Discovery received!" -ForegroundColor Green
        Write-Host ""

        try {
            $json = $discovery | ConvertFrom-Json

            Write-Host "Device ID:   $DeviceId" -ForegroundColor White
            Write-Host "FW Version:  $($json.fw_version)" -ForegroundColor Cyan
            Write-Host "Step:        $($json.step)" -ForegroundColor White
            Write-Host ""

            Write-Host "For OTA to work, new version must be HIGHER than: $($json.fw_version)" -ForegroundColor Yellow
            Write-Host ""

            # Parse version
            if ($json.fw_version -match '(\d+)\.(\d+)\.(\d+)') {
                $major = [int]$matches[1]
                $minor = [int]$matches[2]
                $patch = [int]$matches[3]

                Write-Host "Suggested test versions:" -ForegroundColor Green
                Write-Host "  - $major.$minor.$($patch + 1)  (patch bump)" -ForegroundColor White
                Write-Host "  - $major.$($minor + 1).0  (minor bump)" -ForegroundColor White
            }

        } catch {
            Write-Host "Could not parse JSON" -ForegroundColor Red
            Write-Host $discovery -ForegroundColor Gray
        }

        Remove-Item $discoveryFile
    } else {
        Write-Host "No discovery message received" -ForegroundColor Red
        Write-Host "Check that device is powered on and connected" -ForegroundColor Yellow
    }
} else {
    Write-Host "Timeout - no discovery received" -ForegroundColor Red
}