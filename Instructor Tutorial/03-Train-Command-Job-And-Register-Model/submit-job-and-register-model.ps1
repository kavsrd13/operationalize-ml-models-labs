[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ModelName = "diabetes-sklearn-model",

    [Parameter(Mandatory = $false)]
    [string]$ModelVersion = (Get-Date -Format "yyyyMMddHHmmss")
)

$ErrorActionPreference = "Stop"

$envFile = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "tutorial.env"
if (-not (Test-Path $envFile)) {
    throw "Missing tutorial.env. Run step 1 first."
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
$jobFile = Join-Path $PSScriptRoot "job.yml"

az account set --subscription $subscriptionId | Out-Null

Write-Host "Submitting command job..."
$jobName = az ml job create `
    --file $jobFile `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --stream `
    --query name `
    -o tsv

if (-not $jobName) {
    throw "Job submission did not return a job name."
}

Write-Host "Job completed: $jobName"
Write-Host "Registering model '$ModelName' version '$ModelVersion'..."

$modelPath = "azureml://jobs/$jobName/outputs/trained_model/paths/"
az ml model create `
    --name $ModelName `
    --version $ModelVersion `
    --type mlflow_model `
    --path $modelPath `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --output none

Write-Host ""
Write-Host "Step 3 complete."
Write-Host "Registered model: ${ModelName}:${ModelVersion}"
