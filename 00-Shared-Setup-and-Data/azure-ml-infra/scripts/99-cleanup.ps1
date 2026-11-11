<#
.SYNOPSIS
    CLEANUP - Delete everything this course created, so nothing keeps costing money.

.DESCRIPTION
    Deleting the resource group is NOT enough on its own, because some Azure resources are
    "soft-deleted" and keep their names reserved:

      Resource                 Soft delete           What this script does
      -----------------------  --------------------  -------------------------------------
      Azure ML workspace       14 days               delete with --permanently-delete
      Log Analytics workspace  14 days               delete with --force
      Key Vault                7 days (our setting)  purge after the resource group is gone

    If you skip these steps, re-deploying with the same names can fail with errors such as
    "vault already exists in deleted state" or "workspace name is soft-deleted".

.EXAMPLE
    .\scripts\99-cleanup.ps1
.EXAMPLE
    .\scripts\99-cleanup.ps1 -ProjectName olistanna -EnvironmentName dev -Force
#>
param(
    [ValidatePattern('^[a-z0-9]{3,10}$')]
    [string]$ProjectName = '',
    [ValidateSet('dev', 'test', 'prod')]
    [string]$EnvironmentName = 'dev',
    [switch]$Force
)

. "$PSScriptRoot\common.ps1"

$ProjectName = Resolve-ProjectName $ProjectName

$rg = Get-ResourceGroupName $ProjectName $EnvironmentName

Write-Step "Cleanup of resource group: $rg"
if (-not (Test-AzCommand { az group show --name $rg })) {
    Write-Info "Resource group $rg does not exist - nothing to delete."
    exit 0
}

$location = az group show --name $rg --query location -o tsv
$resources = @(az resource list --resource-group $rg -o json | ConvertFrom-AzJson)
Write-Info 'The following resources will be PERMANENTLY deleted:'
$resources | ForEach-Object { Write-Info ("   {0,-45} {1}" -f $_.name, $_.type) }

if (-not $Force) {
    $answer = Read-Host "Type the resource group name ($rg) to confirm"
    if ($answer -ne $rg) { Write-Warn 'Confirmation did not match - nothing deleted.'; exit 1 }
}

$keyVaults     = @($resources | Where-Object { $_.type -eq 'Microsoft.KeyVault/vaults' } | ForEach-Object { $_.name })
$logWorkspaces = @($resources | Where-Object { $_.type -eq 'Microsoft.OperationalInsights/workspaces' } | ForEach-Object { $_.name })
$mlWorkspaces  = @($resources | Where-Object { $_.type -eq 'Microsoft.MachineLearningServices/workspaces' } | ForEach-Object { $_.name })

# ---------------------------------------------------------------------------------------
foreach ($ws in $mlWorkspaces) {
    Write-Step "1. Permanently deleting Azure ML workspace $ws (and its compute)"
    az ml workspace delete --name $ws --resource-group $rg --permanently-delete --yes --only-show-errors
    Assert-AzSuccess "az ml workspace delete $ws"
    Write-Ok "$ws deleted"
}

foreach ($law in $logWorkspaces) {
    Write-Step "2. Force-deleting Log Analytics workspace $law"
    az monitor log-analytics workspace delete --resource-group $rg --workspace-name $law --force --yes --only-show-errors
    Assert-AzSuccess "az monitor log-analytics workspace delete $law"
    Write-Ok "$law deleted"
}

Write-Step "3. Deleting resource group $rg (takes a few minutes)"
az group delete --name $rg --yes --only-show-errors
Assert-AzSuccess "az group delete $rg"
Write-Ok "$rg deleted"

foreach ($kv in $keyVaults) {
    Write-Step "4. Purging soft-deleted key vault $kv"
    az keyvault purge --name $kv --location $location --only-show-errors
    Assert-AzSuccess "az keyvault purge $kv"
    Write-Ok "$kv purged"
}

# ---------------------------------------------------------------------------------------
Write-Step '5. Removing local files created by the scripts'
foreach ($path in @($OutputsFile, (Join-Path $DataDir 'olist-raw'))) {
    if (Test-Path $path) { Remove-Item $path -Recurse -Force; Write-Ok "Removed $path" }
}

Write-Step 'Cleanup complete - no resources from this environment remain.'
