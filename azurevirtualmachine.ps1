$subscriptionId = ""
$resourceGroupName = ""
$vmName = ""
$vmSize = ""
$vnetName = ""
$vsubnetName = ""
$publicIpName = ""
$nsgName = ""
$nicName = ""
$userName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$location = $resourceGroup.Location

$subnet = New-AzVirtualNetworkSubnetConfig -Name $vsubnetName -AddressPrefix "10.0.0.0/24"
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $subnet
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName

$allowRdpRule = New-AzNetworkSecurityRuleConfig -Name "allowRDP" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName -SecurityRules $allowRdpRule
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsgName

New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName -AllocationMethod Dynamic -Location $location
$ip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName

New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $ip.Id -NetworkSecurityGroupId $nsg.Id
$nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName

$cred = Get-Credential -UserName $userName -Message "Create a user and password"
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $cred
Set-AzVMSourceImage -VM $vmConfig -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-11" -Skus "win11-21h2-ent" -Version "latest"
Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

Write-Host "Assign system managed identity to vm"
Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm -IdentityType SystemAssigned
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id

Write-Host "Get vm system assigned managed identity"
Get-AzSystemAssignedIdentity -Scope $vm.Id
$servicePrincipal = Get-AzADServicePrincipal -ObjectId $vm.Identity.PrincipalId
Get-AzRoleAssignment -ObjectId $servicePrincipal.Id

Remove-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force
Remove-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -Force
Remove-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName -Force
Remove-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsgName -Force
Remove-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName -Force

Get-AzVMImagePublisher -Location $location | Where-Object { $_.PublisherName -match "MicrosoftWindowsDesktop" }
Get-AzVMImageOffer -Location $location -PublisherName "MicrosoftWindowsServer" | Where-Object { $_.Offer -match "windows-11" }
Get-AzVMImageSku -Location $location -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-11"
$imageName = "MicrosoftWindowsDesktop:windows-11:win11-21h2-ent:latest"