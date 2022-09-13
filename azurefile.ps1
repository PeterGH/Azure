$subscriptionId = ""
$roleDefinitionName = ""

Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

$role = Get-AzRoleDefinition -Name $roleDefinitionName

if ($null -eq $role) {
    $role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
    $role.Id = $null
    $role.Name = $roleDefinitionName
    $role.Description = $roleDefinitionName
    $role.IsCustom = $true
    $role.Actions = @()
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