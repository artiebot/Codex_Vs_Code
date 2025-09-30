# Send OTA Command Script
param(
    [Parameter(Mandatory=$false)]
    [string]$BinPath = "C:\Users\ardav\AppData\Local\arduino\sketches\82E768BFF89799EC32C72A4F61C84665\skyfeeder.ino.bin",
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.5.0",
    [Parameter(Mandatory=$false)]
    [string]$MqttHost = "10.0.0.4",
    [Parameter(Mandatory=$false)]
    [int]$HttpPort = 8080,
    [Parameter(Mandatory=$false)]
    [string]$DeviceId = "dev1"
)

# Get file info
$hash = (Get-FileHash -Path $BinPath -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $BinPath).Length

Write-Host "=== OTA Update ===" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "Size: $size bytes" -ForegroundColor White
Write-Host "SHA256: $hash" -ForegroundColor White
Write-Host ""

# Create JSON payload
$payload = @{
    url = "http://${MqttHost}:${HttpPort}/skyfeeder.ino.bin"
    version = $Version
    sha256 = $hash
    size = [int]$size
    staged = $true
} | ConvertTo-Json -Compress

# Save to temp file (UTF-8 without BOM)
$tempFile = Join-Path $env:TEMP "ota_payload.json"
[System.IO.File]::WriteAllText($tempFile, $payload, [System.Text.UTF8Encoding]::new($false))

Write-Host "Payload:" -ForegroundColor Yellow
Write-Host $payload -ForegroundColor Gray
Write-Host ""
Write-Host "Temp file: $tempFile" -ForegroundColor Gray

# Verify file contents
$verifyContent = Get-Content $tempFile -Raw
Write-Host "Verified payload from file:" -ForegroundColor Gray
Write-Host $verifyContent -ForegroundColor Gray
Write-Host ""

# Send via mosquitto_pub using file input
$topic = "skyfeeder/$DeviceId/cmd/ota"
Write-Host "Sending to topic: $topic" -ForegroundColor Yellow

mosquitto_pub -h $MqttHost -t $topic -f $tempFile

Write-Host ""
Write-Host "OTA command sent!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Check Serial Monitor for these debug lines:" -ForegroundColor Yellow
Write-Host "  - DEBUG: Received OTA payload" -ForegroundColor Gray
Write-Host "  - DEBUG: JSON parsed successfully OR JSON parse error" -ForegroundColor Gray
Write-Host ""
Write-Host "Monitor MQTT events: mosquitto_sub -h $MqttHost -t `"skyfeeder/$DeviceId/#`" -v" -ForegroundColor Yellow