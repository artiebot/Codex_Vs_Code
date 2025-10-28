# Commit staged WiFi credentials to Mini camera
# Usage: .\cam-wifi-commit.ps1 -Token "tok-001"

param(
    [string]$Token = "test-token-001"
)

$topic = "skyfeeder/dev1/cmd/cam"

# Build JSON with proper escaping
$jsonObj = @{
    op = "commit_wifi"
    token = $Token
} | ConvertTo-Json -Compress

Write-Host "Committing WiFi credentials..." -ForegroundColor Green
Write-Host "Token: $Token" -ForegroundColor Yellow
Write-Host "Topic: $topic" -ForegroundColor Yellow
Write-Host "Payload: $jsonObj" -ForegroundColor Cyan
Write-Host ""

# Write to temp ASCII file to preserve JSON quotes
$tempFile = "payload_wifi_commit.json"
$jsonObj | Out-File $tempFile -Encoding ascii -NoNewline

# Send via mosquitto_pub using -f to read from file
$result = mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t $topic -f $tempFile 2>&1

# Clean up temp file
Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -eq 0) {
    Write-Host "Command sent successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Monitor ACK with:" -ForegroundColor Cyan
    Write-Host "  .\cam-monitor.ps1" -ForegroundColor White
} else {
    Write-Host "Failed to send command!" -ForegroundColor Red
    Write-Host "Error: $result" -ForegroundColor Red
}
