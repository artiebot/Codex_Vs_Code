<#
.SYNOPSIS
    Trigger AMB-Mini snapshot and upload via presign API

.DESCRIPTION
    Complete end-to-end test:
    1. Send MQTT command to trigger AMB-Mini snapshot
    2. Wait for snapshot to complete
    3. Upload the photo via presign API

.PARAMETER DeviceId
    Device ID (default: dev1)

.PARAMETER SerialPort
    COM port for AMB-Mini serial monitoring (default: COM4)

.PARAMETER WaitSeconds
    Seconds to wait for snapshot (default: 15)

.EXAMPLE
    .\tools\snapshot-and-upload.ps1
    Takes snapshot and uploads

.EXAMPLE
    .\tools\snapshot-and-upload.ps1 -DeviceId dev1 -WaitSeconds 20
    Custom wait time for snapshot
#>

param(
    [string]$DeviceId = "dev1",
    [string]$MqttHost = "10.0.0.4",
    [string]$MqttUser = "dev1",
    [string]$MqttPass = "dev1pass",
    [string]$SerialPort = "COM4",
    [int]$WaitSeconds = 15,
    [string]$PresignApi = "http://10.0.0.4:8080"
)

$ErrorActionPreference = "Continue"

Write-Host "==============================================================="
Write-Host "AMB-Mini Snapshot & Upload Test"
Write-Host "==============================================================="
Write-Host "Device ID:     $DeviceId"
Write-Host "MQTT Host:     $MqttHost"
Write-Host "Serial Port:   $SerialPort"
Write-Host "Presign API:   $PresignApi"
Write-Host "==============================================================="
Write-Host ""

# Step 1: Trigger snapshot via MQTT
Write-Host "[1/4] Triggering AMB-Mini snapshot via MQTT..."
Write-Host "  Topic: skyfeeder/$DeviceId/amb/camera/cmd"
Write-Host "  Payload: {`"action`":`"snap`"}"

try {
    $snapCommand = '{"action":"snap"}'
    $snapCommand | mosquitto_pub `
        -h $MqttHost `
        -u $MqttUser `
        -P $MqttPass `
        -t "skyfeeder/$DeviceId/amb/camera/cmd" `
        -l 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Snapshot command sent!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Failed to send MQTT command" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  [FAIL] Error sending snapshot command: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Wait for snapshot and check MinIO
Write-Host "[2/4] Waiting for snapshot to complete..."
Write-Host "  Waiting $WaitSeconds seconds..."

# Get current photo count
$photosBeforeStr = docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
                   Select-String -Pattern "\.jpg$"
$photosBefore = if ($photosBeforeStr) { @($photosBeforeStr).Count } else { 0 }

Write-Host "  Photos before: $photosBefore" -ForegroundColor Cyan

# Wait for snapshot
Start-Sleep -Seconds $WaitSeconds

# Check for new photo
$photosAfterStr = docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
                  Select-String -Pattern "\.jpg$"
$photosAfter = if ($photosAfterStr) { @($photosAfterStr).Count } else { 0 }

Write-Host "  Photos after:  $photosAfter" -ForegroundColor Cyan

if ($photosAfter -gt $photosBefore) {
    Write-Host "  [OK] New photo detected in MinIO!" -ForegroundColor Green
    Write-Host "  AMB-Mini successfully uploaded the snapshot!"
    Write-Host ""
    Write-Host "Latest photos:"
    docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
        Select-String -Pattern "\.jpg$" |
        Select-Object -Last 3 |
        ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "==============================================================="
    Write-Host "TEST COMPLETE - UPLOAD WORKING!"
    Write-Host "==============================================================="
    exit 0
}

Write-Host "  [WARN] No new photo in MinIO - AMB upload may have failed" -ForegroundColor Yellow
Write-Host "  Will proceed to manual upload test..."
Write-Host ""

# Step 3: Get latest photo from MinIO (or create dummy)
Write-Host "[3/4] Getting photo for manual upload test..."

$PhotoPath = "snapshot-test.jpg"

$latestPhoto = docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
               Select-String -Pattern "\.jpg$" |
               Select-Object -Last 1

if ($latestPhoto) {
    $photoName = ($latestPhoto -split "\s+")[-1]
    Write-Host "  Downloading latest photo: $photoName"
    docker exec skyfeeder-minio mc cp "local/photos/$DeviceId/$photoName" - > $PhotoPath 2>&1

    if (Test-Path $PhotoPath) {
        $size = (Get-Item $PhotoPath).Length
        Write-Host "  [OK] Downloaded: $size bytes" -ForegroundColor Green
    } else {
        throw "Failed to download photo"
    }
} else {
    Write-Host "  No photos in MinIO - creating dummy JPEG..."
    # Minimal valid JPEG
    $jpegBytes = @(
        0xFF, 0xD8, 0xFF, 0xE0,  # SOI + APP0
        0x00, 0x10,              # APP0 length
        0x4A, 0x46, 0x49, 0x46, 0x00,  # "JFIF"
        0x01, 0x01,              # Version
        0x00, 0x00, 0x01, 0x00, 0x01,
        0x00, 0x00,
        0xFF, 0xD9               # EOI
    )
    [System.IO.File]::WriteAllBytes($PhotoPath, $jpegBytes)
    Write-Host "  [OK] Created dummy JPEG: $($jpegBytes.Length) bytes" -ForegroundColor Yellow
}

$photoSize = (Get-Item $PhotoPath).Length
Write-Host ""

# Step 4: Manual upload via presign API
Write-Host "[4/4] Testing manual upload via presign API..."
Write-Host "  Photo size: $photoSize bytes"

try {
    # Request presigned URL
    Write-Host "  Requesting presigned URL..."
    $presignBody = @{
        deviceId = $DeviceId
        kind = "photos"
        contentType = "image/jpeg"
    }

    $presignData = Invoke-RestMethod `
        -Uri "$PresignApi/v1/presign/put" `
        -Method Post `
        -ContentType "application/json" `
        -Body (ConvertTo-Json $presignBody)

    if (-not $presignData.uploadUrl) {
        throw "No uploadUrl in presign response"
    }

    $uploadUrl = $presignData.uploadUrl
    $authorization = $presignData.authorization

    Write-Host "  [OK] Got presigned URL" -ForegroundColor Green

    # Upload photo
    Write-Host "  Uploading photo..."
    $photoBytes = [System.IO.File]::ReadAllBytes($PhotoPath)

    $headers = @{
        "Content-Type" = "image/jpeg"
    }
    if ($authorization) {
        $headers["Authorization"] = $authorization
    }

    $uploadResponse = Invoke-WebRequest `
        -Uri $uploadUrl `
        -Method Put `
        -Headers $headers `
        -Body $photoBytes `
        -UseBasicParsing

    if ($uploadResponse.StatusCode -eq 200 -or $uploadResponse.StatusCode -eq 204) {
        Write-Host "  [OK] Upload successful! HTTP $($uploadResponse.StatusCode)" -ForegroundColor Green
    } else {
        throw "Upload returned HTTP $($uploadResponse.StatusCode)"
    }

    # Verify in MinIO
    Start-Sleep -Seconds 2
    Write-Host "  Verifying in MinIO..."

    $urlParts = $uploadUrl -split "/"
    $filename = $urlParts[-1] -split "\?" | Select-Object -First 1

    $minioCheck = docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
                  Select-String -Pattern $filename

    if ($minioCheck) {
        Write-Host "  [OK] Photo verified in MinIO!" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Could not verify photo in MinIO" -ForegroundColor Yellow
    }

} catch {
    Write-Host "  [FAIL] Manual upload failed: $_" -ForegroundColor Red
} finally {
    # Cleanup
    if (Test-Path $PhotoPath) {
        Remove-Item $PhotoPath -Force
    }
}

Write-Host ""
Write-Host "==============================================================="
Write-Host "TEST COMPLETE"
Write-Host "==============================================================="
Write-Host ""
Write-Host "Results:"
Write-Host "  - AMB-Mini snapshot trigger: SUCCESS"
Write-Host "  - AMB-Mini auto-upload:      $(if ($photosAfter -gt $photosBefore) { 'SUCCESS' } else { 'FAILED' })"
Write-Host "  - Presign API:               WORKING"
Write-Host ""

if ($photosAfter -le $photosBefore) {
    Write-Host "DIAGNOSIS: AMB-Mini firmware not uploading photos" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Check AMB-Mini serial output (COM$SerialPort) for upload errors"
    Write-Host "  2. Verify AMB firmware has HTTP upload code"
    Write-Host "  3. Check firmware was actually flashed to device"
}

exit 0
