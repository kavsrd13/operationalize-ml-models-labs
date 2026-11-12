[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ModelName = "diabetes-sklearn-model",

    [Parameter(Mandatory = $false)]
    [string]$ModelVersion = "latest",

    [Parameter(Mandatory = $false)]
    [string]$EndpointName = "diabetes-endpoint-demo-001"
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

az account set --subscription $subscriptionId | Out-Null

$endpointTemplate = Get-Content (Join-Path $PSScriptRoot "endpoint.yml") -Raw
$deploymentTemplate = Get-Content (Join-Path $PSScriptRoot "deployment.yml") -Raw

$resolvedEndpointYaml = $endpointTemplate.Replace("endpoint-name-placeholder", $EndpointName)
$resolvedDeploymentYaml = $deploymentTemplate.Replace("endpoint-name-placeholder", $EndpointName)
$resolvedDeploymentYaml = $resolvedDeploymentYaml.Replace("model-name-placeholder", $ModelName)

$endpointResolvedPath = Join-Path $PSScriptRoot "endpoint.resolved.yml"
$deploymentResolvedPath = Join-Path $PSScriptRoot "deployment.resolved.yml"

$resolvedEndpointYaml | Set-Content -Path $endpointResolvedPath -Encoding UTF8
$resolvedDeploymentYaml | Set-Content -Path $deploymentResolvedPath -Encoding UTF8

Write-Host "Creating or updating endpoint '$EndpointName'..."
az ml online-endpoint create `
    --file $endpointResolvedPath `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --set name=$EndpointName `
    --output none

Write-Host "Creating deployment 'blue'..."
az ml online-deployment create `
    --file $deploymentResolvedPath `
    --name blue `
    --endpoint-name $EndpointName `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --set model.path="azureml:$ModelName@$ModelVersion" `
    --all-traffic `
    --output none

Write-Host "Invoking endpoint with sample request..."
$requestFile = Join-Path $PSScriptRoot "sample-request.json"
az ml online-endpoint invoke `
    --name $EndpointName `
    --deployment-name blue `
    --request-file $requestFile `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName

$scoringUri = az ml online-endpoint show `
    --name $EndpointName `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --query scoring_uri `
    -o tsv

Write-Host ""
Write-Host "Step 4 complete."
Write-Host "Endpoint: $EndpointName"
Write-Host "Scoring URI: $scoringUri"
