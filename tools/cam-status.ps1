# Send camera status command
param()

$topic = "skyfeeder/dev1/cmd/cam"
$json  = @{ op = "status" } | ConvertTo-Json -Compress
$tmp   = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp -Value $json -Encoding ASCII -NoNewline

Write-Host "Sending status command..." -ForegroundColor Green
Write-Host "Topic: $topic" -ForegroundColor Yellow
Write-Host "Payload: $json" -ForegroundColor Yellow

mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t $topic -f $tmp
$exit = $LASTEXITCODE
Remove-Item $tmp -ErrorAction SilentlyContinue

if ($exit -eq 0) {
    Write-Host "Command sent successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to send command!" -ForegroundColor Red
}
