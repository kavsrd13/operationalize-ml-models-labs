<#
.SYNOPSIS
    STEP 2 - Deploy the Azure ML infrastructure with Bicep.

.DESCRIPTION
    Runs `az deployment sub create` with infra/main.bicep + infra/main.bicepparam, which
    creates the resource group, monitoring, storage, key vault, container registry,
    Azure ML workspace, role assignments and (optionally) the compute instance.

    The deployment is IDEMPOTENT: running it again updates resources to match the code
    instead of creating duplicates. The one exception is the compute instance, which Azure
    does not allow to be re-deployed safely - so if it already exists, this script skips it.

    The deployment outputs (resource names, studio URL, ...) are saved to
    .deployment-outputs.json so the next scripts can use them.

.EXAMPLE
    .\scripts\02-deploy-infra.ps1
.EXAMPLE
    .\scripts\02-deploy-infra.ps1 -ProjectName olistanna -Location westeurope -VmSize Standard_E2ds_v4
.EXAMPLE
    # Instructor creating an environment for a student:
    $id = az ad user show --id student@school.edu --query id -o tsv
    .\scripts\02-deploy-infra.ps1 -ProjectName olistst01 -DataScientistObjectId $id
#>
param(
    # Leave empty to be asked. Every resource name is built from this name.
    [ValidatePattern('^[a-z0-9]{3,10}$')]
    [string]$ProjectName = '',
    [ValidateSet('dev', 'test', 'prod')]
    [string]$EnvironmentName = 'dev',
    [string]$Location = 'eastus',
    [string]$VmSize = 'Standard_E4ds_v4',
    [string]$DataScientistObjectId = '',
    [switch]$SkipComputeInstance,
    # By default the script only creates NEW resources. Use this to update existing ones.
    [switch]$UpdateExisting
)

. "$PSScriptRoot\common.ps1"

$ProjectName = Resolve-NewProjectName -ProjectName $ProjectName -EnvironmentName $EnvironmentName -UpdateExisting:$UpdateExisting

$resourceGroup  = Get-ResourceGroupName $ProjectName $EnvironmentName
$workspaceName  = Get-WorkspaceName $ProjectName $EnvironmentName
$deploymentName = Get-DeploymentName $ProjectName $EnvironmentName $Location

# ---------------------------------------------------------------------------------------
Write-Step 'Checking for an existing compute instance'
$deployCompute = -not $SkipComputeInstance
if ($deployCompute -and (Test-AzCommand { az ml workspace show --name $workspaceName --resource-group $resourceGroup })) {
    $existing = @(az ml compute list --workspace-name $workspaceName --resource-group $resourceGroup `
                    --type ComputeInstance --query '[].name' -o tsv)
    if ($existing.Count -gt 0) {
        Write-Info "Found: $($existing -join ', ') - it will NOT be re-deployed (not supported by Azure)."
        Write-Info 'To change its VM size or settings: delete it in studio, then run this script again.'
        $deployCompute = $false
    }
}
if ($deployCompute) { Write-Info 'A new compute instance will be created (takes ~5-10 minutes).' }
elseif ($SkipComputeInstance) { Write-Info 'Skipped by -SkipComputeInstance.' }

Set-BicepParameterEnvironment -ProjectName $ProjectName -EnvironmentName $EnvironmentName `
    -Location $Location -VmSize $VmSize -DataScientistObjectId $DataScientistObjectId `
    -DeployComputeInstance $deployCompute

# ---------------------------------------------------------------------------------------
Write-Step "Deploying '$deploymentName' to subscription scope (region: $Location)"
Write-Info 'Typical duration: 3-5 minutes, plus 5-10 minutes for a new compute instance.'
Write-Info 'Watch progress: Azure portal > Subscriptions > Deployments, or the resource group > Deployments.'
$start = Get-Date
az deployment sub create `
    --name $deploymentName `
    --location $Location `
    --parameters $ParamFile `
    --only-show-errors --output none
Assert-AzSuccess 'az deployment sub create'
Write-Ok ("Deployment succeeded in {0:N1} minutes" -f ((Get-Date) - $start).TotalMinutes)

# ---------------------------------------------------------------------------------------
Write-Step 'Saving deployment outputs'
$rawOutputs = az deployment sub show --name $deploymentName --query properties.outputs -o json | ConvertFrom-AzJson
Assert-AzSuccess 'az deployment sub show'

# ARM returns outputs as { name: { type, value } } - keep just the values.
$outputs = [ordered]@{ deploymentName = $deploymentName }
foreach ($property in $rawOutputs.PSObject.Properties) { $outputs[$property.Name] = $property.Value.value }
$outputs | ConvertTo-Json | Set-Content -Path $OutputsFile -Encoding UTF8
Write-Ok "Saved to $OutputsFile"

Write-Step 'Deployed resources'
Write-Info "Resource group     : $($outputs.resourceGroupName)"
Write-Info "ML workspace       : $($outputs.workspaceName)"
Write-Info "Storage account    : $($outputs.storageAccountName)"
Write-Info "Key vault          : $($outputs.keyVaultName)"
Write-Info "Container registry : $($outputs.containerRegistryName)"
Write-Info "Compute instance   : $($outputs.computeInstanceName)"
Write-Info "Azure ML studio    : $($outputs.studioUrl)"
Write-Ok 'Next: .\scripts\03-upload-data.ps1'
