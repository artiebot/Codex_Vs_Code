# OTA Diagnostic Script
# Run this to check current firmware version and validate OTA setup

param(
    [Parameter(Mandatory=$false)]
    [string]$MqttHost = "10.0.0.4",
    [Parameter(Mandatory=$false)]
    [string]$DeviceId = "dev1"
)

Write-Host "`n=== OTA DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Checking MQTT broker connectivity..." -ForegroundColor Yellow
$mqttTest = mosquitto_pub -h $MqttHost -t "test" -m "hello" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ MQTT broker reachable" -ForegroundColor Green
} else {
    Write-Host "   ✗ MQTT broker NOT reachable" -ForegroundColor Red
    Write-Host "   Error: $mqttTest" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Listening for device discovery (10 seconds)..." -ForegroundColor Yellow
Write-Host "   Topic: skyfeeder/$DeviceId/discovery" -ForegroundColor Gray

$discoveryFile = Join-Path $env:TEMP "discovery.json"
$timeout = 10
Start-Process mosquitto_sub -ArgumentList "-h",$MqttHost,"-t","skyfeeder/$DeviceId/discovery","-W",$timeout,"-C","1" -RedirectStandardOutput $discoveryFile -Wait -NoNewWindow

if (Test-Path $discoveryFile) {
    $discovery = Get-Content $discoveryFile -Raw
    if ($discovery) {
        Write-Host "   ✓ Discovery received" -ForegroundColor Green

        try {
            $json = $discovery | ConvertFrom-Json
            $fwVersion = $json.fw_version
            $step = $json.step

            Write-Host ""
            Write-Host "   Device ID:  $DeviceId" -ForegroundColor White
            Write-Host "   FW Version: $fwVersion" -ForegroundColor White
            Write-Host "   Step:       $step" -ForegroundColor White

            if ($step -ne "sf_step15D_ota_safe_staging") {
                Write-Host ""
                Write-Host "   ⚠ WARNING: Step is not 'sf_step15D_ota_safe_staging'" -ForegroundColor Yellow
            }

            Write-Host ""
            Write-Host "3. For OTA update to work:" -ForegroundColor Yellow
            Write-Host "   - New version MUST be > $fwVersion" -ForegroundColor White
            Write-Host "   - Use SemVer format (e.g., 1.5.0, 1.6.0, 2.0.0)" -ForegroundColor White

            $currentParts = $fwVersion -split '\.'
            if ($currentParts.Count -eq 3) {
                $major = [int]$currentParts[0]
                $minor = [int]$currentParts[1]
                $patch = [int]$currentParts[2]
                $nextMinor = "$major.$($minor + 1).0"
                $nextPatch = "$major.$minor.$($patch + 1)"

                Write-Host ""
                Write-Host "   Suggested versions for testing:" -ForegroundColor Green
                Write-Host "   - $nextPatch (patch bump)" -ForegroundColor White
                Write-Host "   - $nextMinor (minor bump)" -ForegroundColor White
            }

        } catch {
            Write-Host "   ⚠ Could not parse discovery JSON" -ForegroundColor Yellow
            Write-Host "   Raw: $discovery" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✗ No discovery received" -ForegroundColor Red
        Write-Host "   Device may be offline or not publishing discovery" -ForegroundColor Red
        exit 1
    }
    Remove-Item $discoveryFile
} else {
    Write-Host "   ✗ Discovery timeout" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "4. Checking .bin file..." -ForegroundColor Yellow
$binPath = "C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665\skyfeeder.ino.bin"
if (Test-Path $binPath) {
    $size = (Get-Item $binPath).Length
    $hash = (Get-FileHash -Path $binPath -Algorithm SHA256).Hash.ToLower()
    Write-Host "   ✓ Binary file found" -ForegroundColor Green
    Write-Host "   Path: $binPath" -ForegroundColor Gray
    Write-Host "   Size: $size bytes" -ForegroundColor White
    Write-Host "   SHA256: $hash" -ForegroundColor White
} else {
    Write-Host "   ✗ Binary file NOT found at: $binPath" -ForegroundColor Red
    Write-Host "   Compile firmware first in Arduino IDE" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan
Write-Host ""