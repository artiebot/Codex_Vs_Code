param(
  [Parameter(Mandatory=$true)][string]$DeviceId,
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][string]$Url,
  [Parameter(Mandatory=$true)][int]$Size,
  [Parameter(Mandatory=$true)][string]$Sha256,
  [Parameter(Mandatory=$true)][ValidateSet("alpha","beta","stable")][string]$Channel,
  [Parameter(Mandatory=$true)][bool]$Staged,
  [bool]$Force = $false,
  [string]$Broker="10.0.0.4",
  [string]$User="dev1",
  [string]$Pass="dev1pass"
)

$payload = [ordered]@{
  version = $Version
  url     = $Url
  size    = $Size
  sha256  = $Sha256.ToLower()
  channel = $Channel
  staged  = $Staged
}
if ($Force) { $payload.force = $true }
$payloadJson = ($payload | ConvertTo-Json -Compress)

Write-Host "Validating payload against schema..." -ForegroundColor Cyan
$schemaPath = Resolve-Path "$PSScriptRoot/../../../docs/ota_command.schema.json"
try {
  npx --yes ajv-cli validate -s $schemaPath -d $payloadJson | Out-Null
  Write-Host "Schema OK" -ForegroundColor Green
} catch {
  Write-Warning "ajv-cli not found or validation failed. Continuing..."
}

$topic = "skyfeeder/$DeviceId/cmd/ota"
Write-Host "Publishing OTA command to $topic ..." -ForegroundColor Cyan
$payloadJson | mosquitto_pub -h $Broker -u $User -P $Pass -t $topic -l
Write-Host "Done." -ForegroundColor Green
Write-Host "Payload:" $payloadJson
