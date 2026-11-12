[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DataAssetName = "diabetes-data",

    [Parameter(Mandatory = $false)]
    [string]$DataAssetVersion = "1",

    [Parameter(Mandatory = $false)]
    [string]$ComputeInstanceName = "ci-diabetes",

    [Parameter(Mandatory = $false)]
    [string]$ComputeClusterName = "cpu-cluster",

    [Parameter(Mandatory = $false)]
    [string]$ComputeSize = "STANDARD_DS3_V2"
)

$ErrorActionPreference = "Stop"

$envFile = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "tutorial.env"
if (-not (Test-Path $envFile)) {
    throw "Missing tutorial.env. Run step 1 first: 01-Spin-Up-Azure-Resources-Bicep/deploy.ps1"
}

$config = @{}
foreach ($line in Get-Content $envFile) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) { continue }
    $parts = $line.Split("=", 2)
    if ($parts.Count -eq 2) {
        $config[$parts[0].Trim()] = $parts[1].Trim()
    }
}

$subscriptionId = $config["AZURE_SUBSCRIPTION_ID"]
$resourceGroup = $config["AZURE_RESOURCE_GROUP"]
$workspaceName = $config["AZURE_WORKSPACE_NAME"]
$dataFile = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..")) "data\diabetes-data\diabetes.csv"

if (-not (Test-Path $dataFile)) {
    throw "Dataset file not found: $dataFile"
}

az account set --subscription $subscriptionId | Out-Null

Write-Host "Registering data asset '${DataAssetName}:${DataAssetVersion}'..."
az ml data create `
    --name $DataAssetName `
    --version $DataAssetVersion `
    --type uri_file `
    --path $dataFile `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --output none

Write-Host "Ensuring compute instance '$ComputeInstanceName' exists..."
az ml compute show `
    --name $ComputeInstanceName `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    az ml compute create `
        --name $ComputeInstanceName `
        --type ComputeInstance `
        --size $ComputeSize `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --output none
}

Write-Host "Ensuring compute cluster '$ComputeClusterName' exists..."
az ml compute show `
    --name $ComputeClusterName `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    az ml compute create `
        --name $ComputeClusterName `
        --type AmlCompute `
        --size $ComputeSize `
        --min-instances 0 `
        --max-instances 2 `
        --idle-time-before-scale-down 120 `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --output none
}

Write-Host ""
Write-Host "Step 2 complete."
Write-Host "Data asset: ${DataAssetName}:${DataAssetVersion}"
Write-Host "Compute instance: $ComputeInstanceName"
Write-Host "Compute cluster: $ComputeClusterName"
