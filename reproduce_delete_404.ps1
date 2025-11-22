$baseUrl = "http://localhost:8080"
$deviceId = "dev1"
$filename = "test-delete-404.jpg"

$url = "$baseUrl/api/media/$filename" + "?deviceId=$deviceId"
Write-Host "Attempting DELETE $url"

try {
    Invoke-RestMethod -Uri $url -Method Delete -ErrorAction Stop
    Write-Host "DELETE succeeded"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "DELETE failed with status code: $statusCode"
    if ($statusCode -eq 404) {
        Write-Host "Still getting 404 Not Found."
    }
    else {
        Write-Host "Unexpected status code."
    }
}
