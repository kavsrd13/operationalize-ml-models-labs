<#
.SYNOPSIS
    Delete the online endpoint and its deployments - this STOPS the hourly cost.
    The registered model (olist-freight-cost) is kept, so you can redeploy at any time.

.EXAMPLE
    .\scripts\delete-endpoint.ps1 -EndpointName freight-olistanna -ResourceGroup rg-olistanna-ml-dev -Workspace mlw-olistanna-dev
#>
param(
    [Parameter(Mandatory = $true)] [string]$EndpointName,
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev'
)

$ErrorActionPreference = 'Continue'
Write-Host "==> Deleting endpoint $EndpointName (takes a few minutes)" -ForegroundColor Cyan
az ml online-endpoint delete --name $EndpointName -g $ResourceGroup -w $Workspace --yes --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Delete failed - read the error above.' }
Write-Host '    [OK] Endpoint deleted. The model is still registered: redeploy with .\scripts\deploy-endpoint.ps1' -ForegroundColor Green
