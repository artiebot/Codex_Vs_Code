param(
    [string]$PortName,
    [int]$BaudRate = 115200,
    [int]$DurationSeconds = 10
)

try {
    $port = [System.IO.Ports.SerialPort]::new($PortName, $BaudRate)
    $port.ReadTimeout = 1000
    $port.Open()
    
    Write-Host "Monitoring $PortName for $DurationSeconds seconds..."
    
    $endTime = (Get-Date).AddSeconds($DurationSeconds)
    while ((Get-Date) -lt $endTime) {
        if ($port.BytesToRead -gt 0) {
            $data = $port.ReadExisting()
            Write-Host -NoNewline $data
        }
        Start-Sleep -Milliseconds 100
    }
    
    $port.Close()
} catch {
    Write-Error "Error accessing $PortName : $_"
}
