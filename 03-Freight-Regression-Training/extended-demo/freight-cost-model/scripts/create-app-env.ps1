<#
.SYNOPSIS
    Create app\.env with the URL and key of YOUR endpoint, fetched live from Azure.

.DESCRIPTION
    The key is read with your own Azure login and written straight into app\.env.
    It is never printed on screen. app\.env is ignored by git - do not share it.

.EXAMPLE
    .\scripts\create-app-env.ps1 -EndpointName freight-olistanna -ResourceGroup rg-olistanna-ml-dev -Workspace mlw-olistanna-dev
#>
param(
    [Parameter(Mandatory = $true)] [string]$EndpointName,
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev'
)

$ErrorActionPreference = 'Continue'   # az writes harmless notices to stderr; check exit codes instead
$common = @('-g', $ResourceGroup, '-w', $Workspace, '--only-show-errors')

$url = az ml online-endpoint show --name $EndpointName @common --query scoring_uri -o tsv
if ($LASTEXITCODE -ne 0 -or -not $url) { throw "Endpoint '$EndpointName' not found in $Workspace. Did Step 'Deploy the endpoint' succeed?" }
$key = az ml online-endpoint get-credentials --name $EndpointName @common --query primaryKey -o tsv
if ($LASTEXITCODE -ne 0 -or -not $key) { throw 'Could not read the endpoint key. Check your Azure login and permissions.' }

$envFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'app\.env'
@(
    '# Created by scripts/create-app-env.ps1 - contains a SECRET key. Do not commit or share.'
    "FREIGHT_ENDPOINT_URL=$url"
    "FREIGHT_ENDPOINT_KEY=$key"
) | Set-Content -Path $envFile -Encoding ascii

Write-Host "[OK] Wrote $envFile" -ForegroundColor Green
Write-Host "     URL : $url"
Write-Host '     Key : (hidden - stored only in the .env file)'
