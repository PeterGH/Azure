$subscriptionId = ""
$resourceGroupName = ""
$storageAccountName = ""
$vmName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
$subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $nic.IpConfigurations[0].Subnet.Id

$pec = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $storageAccount.Id

$tuples = $pec.PrivateEndpoint.Id.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
$privateEndpoint = Get-AzPrivateEndpoint -ResourceGroupName $tuples[3] -Name $tuples[7]

Get-AzPrivateLinkResource -PrivateLinkResourceId $storageAccount.Id
