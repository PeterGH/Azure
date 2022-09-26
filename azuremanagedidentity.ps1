$subscriptionId = ""
$roleDefinitionName = ""
$resourceGroupName = ""
$vmName = ""
$userAssignedManagedIdentityName = ""
$storageAccountName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$location = $resourceGroup.Location

Write-Host "Create user assigned managed identity"
New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName -Location $location

$umi = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName
$umispn = Get-AzADServicePrincipal -ObjectId $umi.PrincipalId
$scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
New-AzRoleAssignment -ObjectId $umispn.Id -RoleDefinitionName $roleDefinitionName -Scope $scope

Get-AzRoleAssignment -ObjectId $umispn.Id

Remove-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedManagedIdentityName

Write-Host "Get virtual machine system assigned managed identity"
$servicePrincipal = Get-AzADServicePrincipal -ObjectId $vm.Identity.PrincipalId
Get-AzRoleAssignment -ObjectId $servicePrincipal.Id
$smi = Get-AzSystemAssignedIdentity -Scope $vm.Id