<#
.SYNOPSIS
    Call the freight-cost endpoint the way a real client would: HTTPS POST + key.

.EXAMPLE
    .\scripts\test-endpoint.ps1 -EndpointName freight-olistanna -ResourceGroup rg-olistanna-ml-dev -Workspace mlw-olistanna-dev
.EXAMPLE
    .\scripts\test-endpoint.ps1 -EndpointName freight-olistanna -RequestFile .\my-order.json
#>
param(
    [Parameter(Mandatory = $true)] [string]$EndpointName,
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev',
    [string]$RequestFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'deploy\sample-request.json')
)

$ErrorActionPreference = 'Continue'
$common = @('-g', $ResourceGroup, '-w', $Workspace, '--only-show-errors')

$scoringUri = az ml online-endpoint show --name $EndpointName @common --query scoring_uri -o tsv
$key = az ml online-endpoint get-credentials --name $EndpointName @common --query primaryKey -o tsv
if (-not $scoringUri -or -not $key) { throw "Could not read the URL or key of endpoint $EndpointName." }

Write-Host "==> POST $scoringUri" -ForegroundColor Cyan
$body = Get-Content $RequestFile -Raw
$response = Invoke-RestMethod -Method Post -Uri $scoringUri -Body $body -ContentType 'application/json' `
    -Headers @{ Authorization = "Bearer $key" }

$items = (ConvertFrom-Json $body).input_data
for ($i = 0; $i -lt $items.Count; $i++) {
    $item = $items[$i]
    "{0} -> {1}, {2,6} g, {3,5} km  =>  R`$ {4:N2}" -f $item.seller_state, $item.customer_state,
        $item.product_weight_g, $item.distance_km, $response.freight_value_brl[$i]
}
