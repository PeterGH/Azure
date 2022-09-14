$subscriptionId = ""
$roleDefinitionName = ""
$resourceGroupName = ""
$vmName = ""
$userAssignedManagedIdentityName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$location = $resourceGroup.Location

Write-Host "Create user assigned managed identity"
New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName -Location $location
$umi = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName
Get-AzADServicePrincipal -ObjectId $umi.PrincipalId

Remove-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName

Write-Host "Get virtual machine system assigned managed identity"
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$servicePrincipal = Get-AzADServicePrincipal -ObjectId $vm.Identity.PrincipalId
Get-AzRoleAssignment -ObjectId $servicePrincipal.Id
$smi = Get-AzSystemAssignedIdentity -Scope $vm.Id