# Monitor camera ACK responses
$topic = "skyfeeder/dev1/event/ack"

Write-Host "Monitoring ACK responses..." -ForegroundColor Green
Write-Host "Topic: $topic" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop" -ForegroundColor Cyan
Write-Host ""

mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t $topic -v
