$subscriptionId = ""
$roleDefinitionName = ""
$resourceGroupName = ""
$vmName = ""
$storageAccountName = ""
$fileShareName = ""
$userAssignedManagedIdentityName = ""
$vmSize = ""
$vnetName = ""
$vsubnetName = ""
$publicIpName = ""
$nsgName = ""
$nicName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$location = $resourceGroup.Location

$subnet = New-AzVirtualNetworkSubnetConfig -Name $vsubnetName -AddressPrefix "10.0.0.0/24"
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName -Location $location -AddressPrefix "10.0.0.0/24" -Subnet $subnet
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName
Remove-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName

$ip = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName -AllocationMethod Dynamic -Location $location
$ip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName

$allowRdpRule = New-AzNetworkSecurityRuleConfig -Name "allowRDP" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName -SecurityRules $allowRdpRule
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsgName

$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $ip.Id -NetworkSecurityGroupId $nsg.Id
$nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName

Get-AzVMImagePublisher -Location $location | Where-Object { $_.PublisherName -match "MicrosoftWindowsDesktop" }
Get-AzVMImageOffer -Location $location -PublisherName "MicrosoftWindowsServer" | Where-Object { $_.Offer -match "windows-11" }
Get-AzVMImageSku -Location $location -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-11"
$imageName = "MicrosoftWindowsDesktop:windows-11:win11-21h2-ent:latest"

$cred = Get-Credential -UserName "testuser1"

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $cred
Set-AzVMSourceImage -VM $vmConfig -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-11" -Skus "win11-21h2-ent" -Version "latest"
Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig


$role = Get-AzRoleDefinition -Name $roleDefinitionName

if ($null -eq $role) {
    $role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
    $role.Id = $null
    $role.Name = $roleDefinitionName
    $role.Description = $roleDefinitionName
    $role.IsCustom = $true
    $role.Actions = @()
    $role.Actions += "Microsoft.Storage/storageAccounts/read"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/read"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/write"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/shares/action"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/shares/read"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/shares/write"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/shares/delete"
    $role.Actions += "Microsoft.Storage/storageAccounts/fileServices/shares/lease/action"
    $role.DataActions = @()
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/read"
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/write"
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/delete"
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/modifypermissions/action"
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/readFileBackupSemantics/action"
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/writeFileBackupSemantics/action"
    $role.DataActions += "Microsoft.Storage/storageAccounts/fileServices/takeOwnership/action"
    $role.AssignableScopes = @("/subscriptions/$subscriptionId")
    New-AzRoleDefinition -Role $role
} else {
    $role.Description = $roleDefinitionName
    $role.IsCustom = $true
    $role.Actions.Clear()
    $role.NotActions.Clear()
    $role.DataActions.Clear()
    $role.NotDataActions.Clear()
    $role.AssignableScopes.Clear()
    $role.Actions.Add("Microsoft.Storage/storageAccounts/read")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/read")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/write")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/shares/action")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/shares/read")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/shares/write")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/shares/delete")
    $role.Actions.Add("Microsoft.Storage/storageAccounts/fileServices/shares/lease/action")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/fileshares/files/read")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/fileshares/files/write")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/fileshares/files/delete")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/fileshares/files/modifypermissions/action")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/readFileBackupSemantics/action")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/writeFileBackupSemantics/action")
    $role.DataActions.Add("Microsoft.Storage/storageAccounts/fileServices/takeOwnership/action")
    $role.AssignableScopes.Add("/subscriptions/$subscriptionId")
    Set-AzRoleDefinition -Role $role
}

$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id

Write-Host "Get virtual machine system assigned managed identity"
$servicePrincipal = Get-AzADServicePrincipal -ObjectId $vm.Identity.PrincipalId
Get-AzRoleAssignment -ObjectId $servicePrincipal.Id
$smi = Get-AzSystemAssignedIdentity -Scope $vm.Id

Write-Host "Create user assigned managed identity"
New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName -Location $location
$umi = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName
Get-AzADServicePrincipal -ObjectId $umi.PrincipalId

Write-Host "Acquire token for ARM access"
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

Write-Host "Acquire token for storage access"
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
