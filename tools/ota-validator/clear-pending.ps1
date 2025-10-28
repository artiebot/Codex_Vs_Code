# Clear pending OTA state by sending force flag
# Use this if OTA is stuck with "pending_newer_or_equal" error

param(
    [Parameter(Mandatory=$false)]
    [string]$MqttHost = "10.0.0.4",
    [Parameter(Mandatory=$false)]
    [string]$DeviceId = "dev1"
)

Write-Host "This will attempt to clear stuck OTA state" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Reboot ESP32" -ForegroundColor Cyan
Write-Host "  - Press reset button on ESP32" -ForegroundColor White
Write-Host "  - If pending firmware is good, it will apply" -ForegroundColor White
Write-Host "  - If pending firmware is bad, it will rollback" -ForegroundColor White
Write-Host ""
Write-Host "Option 2: Send force command with newer version" -ForegroundColor Cyan
Write-Host "  - Bypasses version check" -ForegroundColor White
Write-Host "  - Use carefully!" -ForegroundColor Red
Write-Host ""

$response = Read-Host "Which option? (1/2/cancel)"

if ($response -eq "1") {
    Write-Host ""
    Write-Host "Please press the reset button on your ESP32 now" -ForegroundColor Yellow
    Write-Host "Then run check-device.ps1 to see the result" -ForegroundColor White
} elseif ($response -eq "2") {
    Write-Host ""
    Write-Host "Force flag not yet implemented" -ForegroundColor Red
    Write-Host "For now, use Option 1 (reboot)" -ForegroundColor Yellow
} else {
    Write-Host "Cancelled" -ForegroundColor Gray
}