# Test if MQTT messages are reaching the broker
# Run this in one PowerShell window, then run mqtt-snap.ps1 in another

Write-Host "=== MQTT Broker Monitor ===" -ForegroundColor Cyan
Write-Host "Listening to all AMB topics..." -ForegroundColor Yellow
Write-Host "In another window, run: .\mqtt-snap.ps1" -ForegroundColor Yellow
Write-Host ""

mosquitto_sub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/amb/#" -v
