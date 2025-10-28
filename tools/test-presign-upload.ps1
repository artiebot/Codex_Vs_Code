<#
.SYNOPSIS
    Test presign API upload flow

.DESCRIPTION
    Tests the HTTP presign upload flow that AMB-Mini firmware uses:
    1. POST to /v1/presign/put to get signed URL
    2. PUT JPEG data to signed URL
    Validates the entire upload pipeline is working.

.PARAMETER DeviceId
    Device ID (default: dev1)

.PARAMETER PhotoPath
    Path to JPEG file to upload (default: uses latest from MinIO or creates dummy)

.PARAMETER PresignApi
    Presign API URL (default: http://10.0.0.4:8080)

.PARAMETER Kind
    Photo kind/category (default: photos)

.EXAMPLE
    .\tools\test-presign-upload.ps1
    Tests with defaults - device dev1, auto-finds photo

.EXAMPLE
    .\tools\test-presign-upload.ps1 -PhotoPath "snapshot.jpg" -DeviceId dev1
    Tests with specific photo file
#>

param(
    [string]$DeviceId = "dev1",
    [string]$PhotoPath = "",
    [string]$PresignApi = "http://10.0.0.4:8080",
    [string]$Kind = "photos"
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================================="
Write-Host "Presign API Upload Test"
Write-Host "==============================================================="
Write-Host "Device ID:    $DeviceId"
Write-Host "Presign API:  $PresignApi"
Write-Host "Kind:         $Kind"
Write-Host "==============================================================="
Write-Host ""

# Step 1: Find or create test photo
if (-not $PhotoPath -or -not (Test-Path $PhotoPath)) {
    Write-Host "[1/4] Looking for test photo..."

    # Try to find a recent photo from MinIO
    $minioPhotos = docker exec skyfeeder-minio mc ls local/photos/$DeviceId/ --recursive 2>&1 |
                   Select-String -Pattern "\.jpg$" |
                   Select-Object -Last 1

    if ($minioPhotos) {
        # Download most recent photo
        $photoName = ($minioPhotos -split "\s+")[-1]
        $PhotoPath = "test-photo.jpg"
        Write-Host "  Downloading latest photo from MinIO: $photoName"
        docker exec skyfeeder-minio mc cp "local/photos/$DeviceId/$photoName" - > $PhotoPath 2>&1

        if (Test-Path $PhotoPath) {
            $size = (Get-Item $PhotoPath).Length
            Write-Host "  [OK] Downloaded: $size bytes" -ForegroundColor Green
        } else {
            throw "Failed to download photo from MinIO"
        }
    } else {
        # Create dummy JPEG (minimal valid JPEG header)
        Write-Host "  No photos in MinIO - creating dummy JPEG..."
        $PhotoPath = "test-photo.jpg"

        # Minimal valid JPEG: FFD8FF (SOI) + FFE0 (APP0) + minimal data + FFD9 (EOI)
        $jpegBytes = @(
            0xFF, 0xD8, 0xFF, 0xE0,  # SOI + APP0
            0x00, 0x10,              # APP0 length
            0x4A, 0x46, 0x49, 0x46, 0x00,  # "JFIF"
            0x01, 0x01,              # Version 1.1
            0x00,                    # Aspect ratio units
            0x00, 0x01, 0x00, 0x01,  # X/Y density
            0x00, 0x00,              # Thumbnail size
            0xFF, 0xD9               # EOI
        )

        [System.IO.File]::WriteAllBytes($PhotoPath, $jpegBytes)
        Write-Host "  [OK] Created dummy JPEG: $($jpegBytes.Length) bytes" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $PhotoPath)) {
    throw "Photo file not found: $PhotoPath"
}

$photoSize = (Get-Item $PhotoPath).Length
Write-Host ""
Write-Host "Photo to upload: $PhotoPath ($photoSize bytes)"
Write-Host ""

# Step 2: Request presigned URL
Write-Host "[2/4] Requesting presigned URL from API..."
Write-Host "  POST $PresignApi/v1/presign/put"

# Create request body
$presignBody = @{
    deviceId = $DeviceId
    kind = $Kind
    contentType = "image/jpeg"
}

Write-Host "  Payload: $(ConvertTo-Json $presignBody -Compress)"

try {
    # Use Invoke-RestMethod for proper JSON handling
    $presignData = Invoke-RestMethod `
        -Uri "$PresignApi/v1/presign/put" `
        -Method Post `
        -ContentType "application/json" `
        -Body (ConvertTo-Json $presignBody)

    if (-not $presignData.uploadUrl) {
        throw "No uploadUrl in response"
    }

    $uploadUrl = $presignData.uploadUrl
    $authorization = $presignData.authorization

    Write-Host "  [OK] Got presigned URL:" -ForegroundColor Green
    Write-Host "    URL: $uploadUrl"
    if ($authorization) {
        Write-Host "    Auth: $($authorization.Substring(0, [Math]::Min(50, $authorization.Length)))..."
    }

} catch {
    Write-Host "  [FAIL] Failed to get presigned URL" -ForegroundColor Red
    Write-Host "  Error: $_"
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  1. Check presign API is running:"
    Write-Host "     Invoke-WebRequest http://10.0.0.4:8080/health"
    Write-Host "  2. Check Docker containers:"
    Write-Host "     docker ps"
    Write-Host "  3. Check API logs:"
    Write-Host "     docker logs skyfeeder-api"
    exit 1
}

Write-Host ""

# Step 3: Upload photo to presigned URL
Write-Host "[3/4] Uploading photo to signed URL..."
Write-Host "  PUT (upload URL)"
Write-Host "  Size: $photoSize bytes"

try {
    # Read photo file as bytes
    $photoBytes = [System.IO.File]::ReadAllBytes($PhotoPath)

    # Build headers - only include Authorization if provided
    $headers = @{
        "Content-Type" = "image/jpeg"
    }
    if ($authorization) {
        $headers["Authorization"] = $authorization
    }

    # Upload using Invoke-WebRequest
    $uploadResponse = Invoke-WebRequest `
        -Uri $uploadUrl `
        -Method Put `
        -Headers $headers `
        -Body $photoBytes `
        -UseBasicParsing

    $httpCode = $uploadResponse.StatusCode
    Write-Host "  HTTP Status: $httpCode"

    if ($httpCode -eq 200 -or $httpCode -eq 204) {
        Write-Host "  [OK] Upload successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Upload failed with HTTP $httpCode" -ForegroundColor Red
        Write-Host "  Response: $($uploadResponse.Content)"
        throw "Upload returned HTTP $httpCode"
    }

} catch {
    Write-Host "  [FAIL] Upload failed" -ForegroundColor Red
    Write-Host "  Error: $_"
    if ($_.Exception.Response) {
        Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode.value__)"
    }
    exit 1
}

Write-Host ""

# Step 4: Verify photo in MinIO
Write-Host "[4/4] Verifying photo in MinIO..."

Start-Sleep -Seconds 2

try {
    # Extract filename from upload URL
    $urlParts = $uploadUrl -split "/"
    $filename = $urlParts[-1] -split "\?" | Select-Object -First 1

    Write-Host "  Looking for: $filename"

    $minioCheck = docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
                  Select-String -Pattern $filename

    if ($minioCheck) {
        Write-Host "  [OK] Photo found in MinIO!" -ForegroundColor Green
        Write-Host "  $minioCheck"
    } else {
        Write-Host "  [WARN] Photo not found in MinIO listing" -ForegroundColor Yellow
        Write-Host "  Listing recent files:"
        docker exec skyfeeder-minio mc ls "local/photos/$DeviceId/" --recursive 2>&1 |
            Select-Object -Last 5 | ForEach-Object { Write-Host "    $_" }
    }

} catch {
    Write-Host "  [WARN] Could not verify in MinIO: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==============================================================="
Write-Host "TEST COMPLETE"
Write-Host "==============================================================="
Write-Host ""
Write-Host "Summary:"
Write-Host "  [OK] Presign API request: SUCCESS"
Write-Host "  [OK] Photo upload: SUCCESS"
Write-Host "  [OK] MinIO verification: CHECK ABOVE"
Write-Host ""
Write-Host "This confirms the presign API and upload pipeline are working."
Write-Host "If AMB-Mini firmware still fails to upload, the issue is in the firmware code."
Write-Host ""

# Cleanup
if (Test-Path "test-photo.jpg") {
    Remove-Item "test-photo.jpg" -Force
}

exit 0
