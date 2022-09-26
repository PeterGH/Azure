$subscriptionId = ""
$resourceGroupName = ""
$storageAccountName = ""
$fileShareName = ""
$umiClientId = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

Write-Host "Acquire token for ARM access using user assigned managed identity"
$response = Invoke-WebRequest -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$umiClientId&resource=https://management.azure.com/" -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$armToken = $content.access_token

Write-Host "Acquire token for ARM access using system assigned managed identity"
$response = Invoke-WebRequest -Method GET -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$armToken = $content.access_token

$headers = @{
Authorization = "Bearer $armToken"
}

Write-Host "Get storage account properties"
Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers

Write-Host "Get storage file service properties"
Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers

Write-Host "List storage file shares"
Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers

Write-Host "Create storage file share"
$properties = @{
enabledProtocols = "SMB"
accessTier = "Hot"
}
$payload = @{
properties = $properties
}
$body = ConvertTo-Json -InputObject $payload
Invoke-WebRequest -Method PUT -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body

Write-Host "Get storage file share properties"
Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers

Write-Host "Acquire token for storage access using user assigned managed identity"
$response = Invoke-WebRequest -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$umiClientId&resource=https://storage.azure.com/" -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$token = $content.access_token

Write-Host "Acquire token for storage access using system assigned managed identity"
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/' -Method GET -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$token = $content.access_token

$version = "2021-10-04"
$auth = "Bearer $token"
$headers = @{ 
"Authorization" = $auth
"x-ms-version" = $version
}

Write-Host "Get storage file service properties"
Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/?restype=service&comp=properties" -Headers $headers

Write-Host "List storage file shares"
Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/?comp=list" -Headers $headers

$headers = @{
"Authorization" = $auth
"x-ms-version" = $version
"x-ms-file-request-intent" = "backup"
}

Write-Host "Create directory"
Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/dir1?restype=directory" -Headers $headers


$headers = @{
"Authorization" = $auth
"x-ms-version" = $version
"x-ms-file-request-intent" = "backup"
"x-ms-type" = "file"
"x-ms-content-length" = "4096"
}

Write-Host "Create file"
Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/file1" -Headers $headers

$payload = [System.Text.Encoding]::Unicode.GetBytes("0123456789")
$headers = @{ 
"Authorization" = $auth
"x-ms-version" = $version
"x-ms-file-request-intent" = "backup"
"x-ms-range" = "bytes=0-$($payload.Length - 1)"
"x-ms-write" = "update"
"Content-Length" = "$($payload.Length)"
}

Write-Host "Put file range"
Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/file1?comp=range" -Headers $headers -Body $payload

$headers = @{
"Authorization" = $auth
"x-ms-version" = $version
"x-ms-file-request-intent" = "backup"
}

Write-Host "List file range"
Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/file1?comp=rangelist" -Headers $headers

Write-Host "Get file"
Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/file1" -Headers $headers

Write-Host "List directories and files"
Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/?restype=directory&comp=list" -Headers $headers
