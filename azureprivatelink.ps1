$subscriptionId = ""
$resourceGroupName = ""
$storageAccountName = ""
$vmName = ""
$privateEndpointConnectionName = "$($storageAccountName)pec1"
$privateEndpointName = "$($storageAccountName)pe1"

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
$subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $nic.IpConfigurations[0].Subnet.Id

$privateEndpointConnection = New-AzPrivateLinkServiceConnection -Name $privateEndpointConnectionName -PrivateLinkServiceId $storageAccount.Id -GroupId "file"
New-AzPrivateEndpoint -ResourceGroupName $resourceGroupName -Name $privateEndpointName -Location $vm.Location -Subnet $subnet -PrivateLinkServiceConnection $privateEndpointConnection

$privateEndpointConnection = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $storageAccount.Id

$tuples = $privateEndpointConnection.PrivateEndpoint.Id.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
$privateEndpoint = Get-AzPrivateEndpoint -ResourceGroupName $tuples[3] -Name $tuples[7]

Get-AzPrivateLinkResource -PrivateLinkResourceId $storageAccount.Id
Get-AzPrivateLinkService -ResourceGroupName $resourceGroupName

Remove-AzPrivateEndpointConnection -ResourceId $privateEndpointConnection.Id -Force
Remove-AzPrivateEndpoint -ResourceGroupName $privateEndpoint.ResourceGroupName -Name $privateEndpoint.Name -Force
