# Start all 24-hour automated tests
# Run this script and leave it running

$ErrorActionPreference = "Continue"

Write-Host "================================================================="
Write-Host "Starting 24-Hour Automated Validation Tests"
Write-Host "================================================================="
Write-Host "Start Time: $(Get-Date)"
Write-Host ""

# Create output directory
New-Item -ItemType Directory -Force -Path "REPORTS\A1.4\24h-final" | Out-Null

# Start soak test in new window
Write-Host "[1/4] Starting 24-hour soak test..." -ForegroundColor Cyan
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "cd 'd:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code'; .\tools\soak-test-24h.ps1 -Duration 24 -OutputDir 'REPORTS\A1.4\24h-final'" -WindowStyle Minimized

Start-Sleep -Seconds 2

# Start AMB serial logging in new window
Write-Host "[2/4] Starting AMB-Mini serial logging (COM4)..." -ForegroundColor Cyan
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "cd 'd:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code'; python -c `"import serial, datetime; ser = serial.Serial('COM4', 115200, timeout=1); f = open('REPORTS/A1.4/24h-final/amb-serial.log', 'a', buffering=1); print(f'[{datetime.datetime.now().isoformat()}] AMB Serial logging started'); [f.write(f'[{datetime.datetime.now().isoformat()}] {line}') or f.flush() for line in iter(lambda: ser.readline().decode('utf-8', errors='ignore'), '')]`"" -WindowStyle Minimized

Start-Sleep -Seconds 2

# Start ESP32 serial logging in new window
Write-Host "[3/4] Starting ESP32 serial logging (COM6)..." -ForegroundColor Cyan
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "cd 'd:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code'; python -c `"import serial, datetime; ser = serial.Serial('COM6', 115200, timeout=1); f = open('REPORTS/A1.4/24h-final/esp32-serial.log', 'a', buffering=1); print(f'[{datetime.datetime.now().isoformat()}] ESP32 Serial logging started'); [f.write(f'[{datetime.datetime.now().isoformat()}] {line}') or f.flush() for line in iter(lambda: ser.readline().decode('utf-8', errors='ignore'), '')]`"" -WindowStyle Minimized

Start-Sleep -Seconds 2

# Start power monitoring in new window
Write-Host "[4/4] Starting 24-hour power monitoring..." -ForegroundColor Cyan
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "cd 'd:\OneDrive\Etsy\Feeder-Project\SW\feeder-project\ESP32\Codex_Vs_Code'; .\tools\measure-power-ina260.ps1 -Duration 1440 -OutputFile 'REPORTS\A1.4\24h-final\power.csv'" -WindowStyle Minimized

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "================================================================="
Write-Host "All Tests Started Successfully!"
Write-Host "================================================================="
Write-Host ""
Write-Host "Running Tests:"
Write-Host "  1. Soak Test (24h)      -> REPORTS\A1.4\24h-final\summary.log"
Write-Host "  2. AMB Serial Log       -> REPORTS\A1.4\24h-final\amb-serial.log"
Write-Host "  3. ESP32 Serial Log     -> REPORTS\A1.4\24h-final\esp32-serial.log"
Write-Host "  4. Power Monitoring     -> REPORTS\A1.4\24h-final\power.csv"
Write-Host ""
Write-Host "Status:"
Write-Host "  - All tests running in minimized windows"
Write-Host "  - Tests will complete in 24 hours: $($(Get-Date).AddHours(24))"
Write-Host "  - Do NOT close this window or the minimized windows"
Write-Host "  - Logs are being written continuously"
Write-Host ""
Write-Host "To check progress:"
Write-Host "  Get-Content 'REPORTS\A1.4\24h-final\summary.log' -Tail 20"
Write-Host ""
Write-Host "================================================================="
Write-Host "Tests running. You can minimize this window but DO NOT close it."
Write-Host "================================================================="
Write-Host ""
Write-Host "Press Ctrl+C to stop all tests (not recommended)"
Write-Host ""

# Keep this window alive
while ($true) {
    Start-Sleep -Seconds 60
    $elapsed = (Get-Date) - (Get-Date).AddHours(-24)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Tests running... Check logs for progress" -ForegroundColor Gray
}
