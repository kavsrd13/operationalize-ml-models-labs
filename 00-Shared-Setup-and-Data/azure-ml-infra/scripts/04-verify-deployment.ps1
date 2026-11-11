<#
.SYNOPSIS
    STEP 4 - Verify that everything was created correctly.

.DESCRIPTION
    Reads .deployment-outputs.json and inspects each piece with the Azure ML CLI v2:
    workspace, compute instance, datastores, data asset and role assignments.

.EXAMPLE
    .\scripts\04-verify-deployment.ps1
#>
param(
    [string]$DataAssetName = 'olist-ecommerce-raw'
)

. "$PSScriptRoot\common.ps1"

$outputs = Get-DeploymentOutputs
$rg = $outputs.resourceGroupName
$ws = $outputs.workspaceName
$common = @('--resource-group', $rg, '--workspace-name', $ws)

# ---------------------------------------------------------------------------------------
Write-Step "1. Workspace: $ws"
$workspace = az ml workspace show --name $ws --resource-group $rg -o json | ConvertFrom-AzJson
Assert-AzSuccess 'az ml workspace show'
Write-Ok "Location           : $($workspace.location)"
Write-Info "Storage account    : $(($workspace.storage_account -split '/')[-1])"
Write-Info "Key vault          : $(($workspace.key_vault -split '/')[-1])"
Write-Info "Container registry : $(($workspace.container_registry -split '/')[-1])"
Write-Info "MLflow tracking URI: $($workspace.mlflow_tracking_uri)"

# ---------------------------------------------------------------------------------------
Write-Step "2. Compute instance: $($outputs.computeInstanceName)"
if (Test-AzCommand { az ml compute show --name $outputs.computeInstanceName @common }) {
    $ci = az ml compute show --name $outputs.computeInstanceName @common -o json | ConvertFrom-AzJson
    Write-Ok "State: $($ci.state)   Size: $($ci.size)"
    Write-Info "Idle shutdown after: $($ci.idle_time_before_shutdown_minutes) minutes"
    Write-Info "Stop it when you are done:  az ml compute stop --name $($ci.name) --resource-group $rg --workspace-name $ws"
} else {
    Write-Warn 'Compute instance not found (deployed with -SkipComputeInstance?).'
}

# ---------------------------------------------------------------------------------------
Write-Step '3. Datastores (connections from the workspace to storage)'
az ml datastore list @common --query '[].{name:name, type:type, account:account_name, container:container_name, share:file_share_name}' -o table
Assert-AzSuccess 'az ml datastore list'

# ---------------------------------------------------------------------------------------
Write-Step "4. Data asset: $DataAssetName"
if (Test-AzCommand { az ml data list --name $DataAssetName @common }) {
    az ml data list --name $DataAssetName @common --query '[].{name:name, version:version, type:type, created:creation_context.created_at}' -o table
} else {
    Write-Warn "No data asset named $DataAssetName yet - run .\scripts\03-upload-data.ps1"
}

# ---------------------------------------------------------------------------------------
Write-Step '5. Role assignments for the data scientist'
$scopes = @(
    $workspace.id,
    (az storage account show --name $outputs.storageAccountName --resource-group $rg --query id -o tsv)
)
foreach ($scope in $scopes) {
    $roles = @(az role assignment list --assignee $outputs.dataScientistObjectId --scope $scope --query '[].roleDefinitionName' -o tsv)
    Write-Ok ("{0,-36} {1}" -f ($scope -split '/')[-1], ($roles -join ', '))
}

# ---------------------------------------------------------------------------------------
Write-Step 'Open Azure ML studio'
Write-Info $outputs.studioUrl
Write-Info 'In studio: Data -> olist-ecommerce-raw -> Explore,  Compute -> your instance -> JupyterLab'
Write-Warn 'Cost reminder: stop the compute instance when you are not using it, and run 99-cleanup.ps1 at the end of the course.'
