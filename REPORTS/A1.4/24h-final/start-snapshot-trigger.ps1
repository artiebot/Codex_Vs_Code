# Start Snapshot Trigger for 24h Test
# Triggers 48 snapshots (every 30 minutes for 24 hours)

Write-Host "Starting periodic snapshot trigger..." -ForegroundColor Cyan
Write-Host "  Interval: 30 minutes"
Write-Host "  Count: 48 snapshots"
Write-Host "  Duration: 24 hours"
Write-Host ""

Set-Location 'd:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code'

.\tools\trigger-periodic-snapshots.ps1 -IntervalSeconds 1800 -Count 48 -DeviceId dev1
