$subscriptionId = ""
$resourceGroupName = ""
$storageAccountName = ""
$vmName = ""
$privateEndpointConnectionName = "$($storageAccountName)pec1"
$privateEndpointName = "$($storageAccountName)pe1"
$privateDnsZoneName = "privatelink.file.core.windows.net" # https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
$privateDnsVnetLinkName = ""
$privateDnsZoneGroupName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
$subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $nic.IpConfigurations[0].Subnet.Id
$tuples = $subnet.Id.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
$vnet = Get-AzVirtualNetwork -ResourceGroupName $tuples[3] -Name $tuples[7]

$privateEndpointConnection = New-AzPrivateLinkServiceConnection -Name $privateEndpointConnectionName -PrivateLinkServiceId $storageAccount.Id -GroupId "file"
New-AzPrivateEndpoint -ResourceGroupName $resourceGroupName -Name $privateEndpointName -Location $vm.Location -Subnet $subnet -PrivateLinkServiceConnection $privateEndpointConnection

$privateEndpointConnection = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $storageAccount.Id
$tuples = $privateEndpointConnection.PrivateEndpoint.Id.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
$privateEndpoint = Get-AzPrivateEndpoint -ResourceGroupName $tuples[3] -Name $tuples[7]

Get-AzPrivateLinkResource -PrivateLinkResourceId $storageAccount.Id
Get-AzPrivateLinkService -ResourceGroupName $resourceGroupName

$zone = Get-AzPrivateDnsZone -ResourceGroupName $resourceGroupName -Name $privateDnsZoneName
if ($null -eq $zone) {
    $zoneParameter = @{
        ResourceGroupName = $resourceGroupName
        Name = $privateDnsZoneName
    }
    $zone = New-AzPrivateDnsZone @zoneParameter
}

$link = Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $resourceGroupName -ZoneName $privateDnsZoneName
if ($null -eq $link) {
    $dnsVnetLinkParameter = @{
        ResourceGroupName = $resourceGroupName
        ZoneName = $privateDnsZoneName
        Name = $privateDnsVnetLinkName
        VirtualNetworkId = $vnet.Id
    }
    $link = New-AzPrivateDnsVirtualNetworkLink @dnsVnetLinkParameter
}

$zoneConfig = @{
    Name = $privateDnsZoneName
    PrivateDnsZoneId = $zone.ResourceId
}
$config = New-AzPrivateDnsZoneConfig @zoneConfig

$zoneGroupParameter = @{
    ResourceGroupName = $resourceGroupName
    PrivateEndpointName = $privateEndpoint.Name
    Name = $privateDnsZoneGroupName
    PrivateDnsZoneConfig = $config
}
New-AzPrivateDnsZoneGroup @zoneGroupParameter

$group = Get-AzPrivateDnsZoneGroup -ResourceGroupName $resourceGroupName -PrivateEndpointName $privateEndpoint.Name

Get-AzPrivateDnsRecordSet -ResourceGroupName $resourceGroupName -ZoneName $privateDnsZoneName

Remove-AzPrivateEndpointConnection -ResourceId $privateEndpointConnection.Id -Force
Remove-AzPrivateEndpoint -ResourceGroupName $privateEndpoint.ResourceGroupName -Name $privateEndpoint.Name -Force
Remove-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $link.ResourceGroupName -ZoneName $link.ZoneName -Name $link.Name
Remove-AzPrivateDnsZone -ResourceGroupName $resourceGroupName -Name $privateDnsZoneName
