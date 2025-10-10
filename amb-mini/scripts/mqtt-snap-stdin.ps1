# Send snap command using stdin (avoids file path issues)
Write-Host "Sending snap command via MQTT..." -ForegroundColor Cyan
'{"action":"snap"}' | mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/sf-mock01/amb/camera/cmd" -l
Write-Host "Command sent. Check AMB serial monitor for response." -ForegroundColor Green
