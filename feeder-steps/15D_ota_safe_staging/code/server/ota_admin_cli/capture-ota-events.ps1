param(
  [string]$DeviceId="sf-mock01",
  [string]$Broker="10.0.0.4",
  [string]$User="dev1",
  [string]$Pass="dev1pass"
)
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$out = "ota_events_${DeviceId}_$stamp.log"
Write-Host "Capturing OTA events for $DeviceId → $out  (Ctrl+C to stop)" -ForegroundColor Cyan
$topic = "skyfeeder/$DeviceId/event/ota"
$psi = "mosquitto_sub -h $Broker -u $User -P $Pass -t `"$topic`" -v"
cmd /c $psi | Tee-Object -FilePath $out
