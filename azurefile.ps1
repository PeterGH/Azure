$subscriptionId = ""
$resourceGroupName = ""
$storageAccountName = ""
$fileShareName = ""
$umiClientId = ""
$vmName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

Write-Host "Enable service endpoint for storage in virtual network"
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
$subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $nic.IpConfigurations[0].Subnet.Id
$tuples = $subnet.Id.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
$vnet = Get-AzVirtualNetwork -ResourceGroupName $tuples[3] -Name $tuples[7]

Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet.Name -AddressPrefix $subnet.AddressPrefix[0] -ServiceEndpoint Microsoft.Storage
$vnet | Set-AzVirtualNetwork

Write-Host "Allow selected virtual network to access storage"
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $resourceGroupName -Name $storageAccountName -DefaultAction Deny
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $resourceGroupName -Name $storageAccountName
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
$subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $nic.IpConfigurations[0].Subnet.Id
Add-AzStorageAccountNetworkRule -ResourceGroupName $resourceGroupName -Name $storageAccountName -VirtualNetworkResourceId $subnet.Id
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $resourceGroupName -Name $storageAccountName

Write-Host "Remove selected virtual network from accessing storage"
Remove-AzStorageAccountNetworkRule -ResourceGroupName $resourceGroupName -Name $storageAccountName -VirtualNetworkResourceId $subnet.Id
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $resourceGroupName -Name $storageAccountName

Write-Host "Acquire token for ARM access using user assigned managed identity"
$response = Invoke-WebRequest -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=$umiClientId&resource=https://management.azure.com/" -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$armToken = $content.access_token

$headers = @{
Authorization = "Bearer $armToken"
}

Write-Host "Get storage account properties"
Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers

$subscriptionId = ""
$resourceGroupName = ""
$storageAccountName = ""
$fileShareName = ""
$fileName = ""

Write-Host "Acquire token for ARM access using system assigned managed identity"
$response = Invoke-WebRequest -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" -Headers @{Metadata="true"}
$response
$content = $response.Content | ConvertFrom-Json
$armToken = $content.access_token
$armToken

Write-Host "Acquire token for storage access using system assigned managed identity"
$response = Invoke-WebRequest -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/" -Headers @{Metadata="true"}
$response
$content = $response.Content | ConvertFrom-Json
$token = $content.access_token
$token

Write-Host "Create storage file share"
$headers = @{
Authorization = "Bearer $armToken"
}
$properties = @{
enabledProtocols = "SMB"
accessTier = "Hot"
}
$payload = @{
properties = $properties
}
$body = ConvertTo-Json -InputObject $payload
$response = Invoke-WebRequest -Method PUT -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response

Write-Host "Create file"
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
"x-ms-type" = "file"
"x-ms-content-length" = "4096"
}
$response = Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName" -Headers $headers
$response

Write-Host "Put file range"
$payload = [System.Text.Encoding]::Unicode.GetBytes("0123456789")
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
"x-ms-range" = "bytes=0-$($payload.Length - 1)"
"x-ms-write" = "update"
"Content-Length" = "$($payload.Length)"
}
$response = Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName`?comp=range" -Headers $headers -Body $payload
$response

Write-Host "Get file"
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
}
$response = Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName" -Headers $headers
$response

Write-Host "Get file properties"
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
}
$response = Invoke-WebRequest -Method HEAD -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName" -Headers $headers
$response

#$now = (Get-Date -AsUTC -UFormat "%a, %d %b %Y %T GMT")
#$now = (Get-Date -UFormat "%a, %d %b %Y %T GMT")
Write-Host "Set file properties"
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
"x-ms-file-creation-time" = "preserve"
"x-ms-file-last-write-time" = "preserve"
"x-ms-file-change-time" = "now"
}
$response = Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName`?comp=properties" -Headers $headers
$response

Write-Host "List file ranges"
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
}
$response = Invoke-WebRequest -Method GET -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName`?comp=rangelist" -Headers $headers
$response


Write-Host "Put file range from url"
$sourceUrl = ""
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
"x-ms-copy-source" = "$sourceUrl"
"x-ms-copy-source-authorization" = "Bearer $token"
"x-ms-write" = "update"
"x-ms-range" = "bytes=0-511"
"x-ms-source-range" = "bytes=0-511"
"Content-Length" = "512"
"x-ms-file-last-write-time" = "now"
}
$response = Invoke-WebRequest -Method PUT -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName`?comp=range" -Headers $headers
$response



Write-Host "Get storage file share properties"
$headers = @{
Authorization = "Bearer $armToken"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?`$expand=stats&api-version=2021-09-01" -Headers $headers
$response

Write-Host "Update storage file share"
$headers = @{
Authorization = "Bearer $armToken"
}
$properties = @{
metadata = @{
    test1 = "value1"
}
}
$payload = @{
properties = $properties
}
$body = ConvertTo-Json -InputObject $payload
$response = Invoke-WebRequest -Method PATCH -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response

Write-Host "Create storage file share snapshot"
$headers = @{
Authorization = "Bearer $armToken"
}
$payload = @{
}
$body = ConvertTo-Json -InputObject $payload
$response = Invoke-WebRequest -Method PUT -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?`$expand=snapshots&api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response

$r = $response.Content | ConvertFrom-Json
$snapshotTime = $r.properties.snapshotTime

Write-Host "Get storage file share snapshot properties"
$headers = @{
"Authorization" = "Bearer $armToken"
"x-ms-snapshot" = "$snapshotTime"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?`$expand=stats&api-version=2021-09-01" -Headers $headers
$response

Write-Host "Acquire a lease to storage file share"
$headers = @{
Authorization = "Bearer $armToken"
}
$payload = @{
"action" = "Acquire"
"leaseDuration" = "60"
}
$body = ConvertTo-Json -InputObject $payload
$response = Invoke-WebRequest -Method POST -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName/lease?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response
$response.RawContent

$leaseId = ($response.Content | ConvertFrom-Json).leaseId
$leaseId

Start-Sleep -Seconds 5

Write-Host "Renew a lease to storage file share"
$headers = @{
Authorization = "Bearer $armToken"
}
$payload = @{
"action" = "Renew"
"leaseId" = $leaseId
}
$body = ConvertTo-Json -InputObject $payload
$response = Invoke-WebRequest -Method POST -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName/lease?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response
$response.RawContent

Write-Host "List storage file shares including snapshots and deleted"
$headers = @{
Authorization = "Bearer $armToken"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares?`$expand=deleted,snapshots&api-version=2021-09-01" -Headers $headers
$response

Write-Host "Get storage file share unique identifier"
$headers = @{
"Authorization" = "Bearer $armToken"
"x-ms-include-file-share-unique-identifier" = "true"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?`$expand=stats&api-version=2021-09-01" -Headers $headers
$response.RawContent
$uniqueId = $response.Headers["x-ms-file-share-unique-identifier"]
$uniqueId

Write-Host "Delete file"
$headers = @{
"Authorization" = "Bearer $token"
"x-ms-version" = "2021-10-04"
"x-ms-file-request-intent" = "backup"
}
$response = Invoke-WebRequest -Method DELETE -Uri "https://$storageAccountName.file.core.windows.net/$fileShareName/$fileName" -Headers $headers
$response

Write-Host "Delete storage file share"
$headers = @{
Authorization = "Bearer $armToken"
}
$response = Invoke-WebRequest -Method DELETE -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$fileShareName`?api-version=2021-09-01" -ContentType "application/json" -Headers $headers
$response

Write-Host "List storage deleted file shares"
$headers = @{
Authorization = "Bearer $armToken"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares?`$expand=deleted&api-version=2021-09-01" -Headers $headers
$response

$r = $response.Content | ConvertFrom-Json
$d = $r.value | Where-Object { $_.properties.deleted -eq $true }
$deletedShareName = $d[0].name
$deletedShareVersion = $d[0].properties.version
$restoredShareName = "$fileShareName"

Write-Host "Restore deleted storage file share"
$headers = @{
Authorization = "Bearer $armToken"
}
$payload = @{
"deletedShareName" = "$deletedShareName"
"deletedShareVersion" = "$deletedShareVersion"
}
$body = ConvertTo-Json -InputObject $payload
$response = Invoke-WebRequest -Method POST -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$restoredShareName/restore?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response
$response.RawContent

Write-Host "Get storage file service properties"
$headers = @{
Authorization = "Bearer $armToken"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default?api-version=2021-09-01" -Headers $headers
$response

Write-Host "List storage file services"
$headers = @{
Authorization = "Bearer $armToken"
}
$response = Invoke-WebRequest -Method GET -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices?api-version=2021-09-01" -Headers $headers
$response

Write-Host "Set storage file service properties"
$headers = @{
Authorization = "Bearer $armToken"
}
$payload = @{
    properties = @{
        protocolSettings = @{
            smb = @{
                "versions" = "SMB2.1;SMB3.0;SMB3.1.1"
                "authenticationMethods" = "NTLMv2;Kerberos"
                "kerberosTicketEncryption" = "RC4-HMAC;AES-256"
                "channelEncryption" = "AES-128-CCM;AES-128-GCM;AES-256-GCM"
            }
        }
    }
}
$body = ConvertTo-Json -InputObject $payload -Depth 4
$response = Invoke-WebRequest -Method PUT -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default?api-version=2021-09-01" -ContentType "application/json" -Headers $headers -Body $body
$response
