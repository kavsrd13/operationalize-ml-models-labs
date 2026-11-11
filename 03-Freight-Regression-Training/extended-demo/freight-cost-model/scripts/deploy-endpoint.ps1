<#
.SYNOPSIS
    Deploy olist-freight-cost to a managed online endpoint (a hosted REST API).

.DESCRIPTION
    1. Creates the endpoint (URL + key authentication) if it does not exist yet
    2. Creates the "blue" deployment: builds the environment image, starts the VM,
       loads the model, and sends 100% of traffic to it   (first run: ~15-20 minutes)
    3. Prints the scoring URL

    COST: the deployment VM is billed every hour until you run delete-endpoint.ps1.

.EXAMPLE
    .\scripts\deploy-endpoint.ps1 -EndpointName freight-olistanna -ResourceGroup rg-olistanna-ml-dev -Workspace mlw-olistanna-dev
#>
param(
    # Your own name: 3-32 characters, unique within the Azure region.
    [Parameter(Mandatory = $true)] [string]$EndpointName,
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev'
)

# az writes harmless notices to stderr; rely on $LASTEXITCODE instead of 'Stop'.
$ErrorActionPreference = 'Continue'
$deployDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'deploy'
$common = @('-g', $ResourceGroup, '-w', $Workspace, '--only-show-errors')

Write-Host "==> 1. Endpoint $EndpointName" -ForegroundColor Cyan
az ml online-endpoint show --name $EndpointName @common -o none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host '    Already exists - reusing it.'
} else {
    az ml online-endpoint create --file (Join-Path $deployDir 'endpoint.yml') --name $EndpointName @common -o none
    if ($LASTEXITCODE -ne 0) { throw 'Endpoint creation failed - read the error above.' }
    Write-Host '    [OK] Endpoint created' -ForegroundColor Green
}

Write-Host '==> 2. Deployment "blue" (image build + VM start: ~15-20 minutes the first time)' -ForegroundColor Cyan
az ml online-deployment create --file (Join-Path $deployDir 'deployment.yml') --endpoint-name $EndpointName `
    --all-traffic @common -o none
if ($LASTEXITCODE -ne 0) {
    Write-Host '    Deployment failed. Container logs:' -ForegroundColor Red
    az ml online-deployment get-logs --name blue --endpoint-name $EndpointName --lines 60 @common
    throw 'Deployment failed - see the logs above.'
}
Write-Host '    [OK] Deployment is live and receives 100% of traffic' -ForegroundColor Green

Write-Host '==> 3. Endpoint details' -ForegroundColor Cyan
$scoringUri = az ml online-endpoint show --name $EndpointName @common --query scoring_uri -o tsv
Write-Host "    Scoring URL : $scoringUri"
Write-Host "    Get the key : az ml online-endpoint get-credentials --name $EndpointName -g $ResourceGroup -w $Workspace"
Write-Host '    Test it     : .\scripts\test-endpoint.ps1'
