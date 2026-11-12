<#
.SYNOPSIS
    STEP 3 - Upload the Olist CSV files and register them as a versioned Azure ML data asset.

.DESCRIPTION
    Why is this a script and not part of Bicep?
    Bicep/ARM deployments run INSIDE Azure, so they cannot read files on your laptop.
    Infrastructure (the "control plane") is created with Bicep; data (the "data plane")
    is pushed with the Azure ML CLI v2:

      1. Copy ONLY the 9 Olist CSVs into data/olist-raw  (the source folder has other files)
      2. az ml data create --file data/olist-data-asset.yml
           -> uploads the folder to the workspace's default datastore (workspaceblobstore)
           -> registers the data asset  olist-ecommerce-raw:<version>

.EXAMPLE
    .\scripts\03-upload-data.ps1
.EXAMPLE
    # New data later? Register a new version - existing versions are immutable.
    .\scripts\03-upload-data.ps1 -DataVersion 2
#>
param(
    # Default: the dataset extracted by the shared bootstrap script.
    [string]$SourceFolder = '',
    [string]$DataAssetName = 'olist-ecommerce-raw',
    [string]$DataVersion = '1'
)

. "$PSScriptRoot\common.ps1"

if (-not $SourceFolder) {
    $setupRoot = Split-Path -Parent $RepoRoot
    $collectionRoot = Split-Path -Parent $setupRoot
    $SourceFolder = Join-Path $collectionRoot 'datasets\olist\Ecommerce Dataset'
    if (-not (Test-Path $SourceFolder)) {
        throw "Olist data not found at $SourceFolder. Run the shared bootstrap script first or pass -SourceFolder <path>."
    }
}

$outputs       = Get-DeploymentOutputs
$resourceGroup = $outputs.resourceGroupName
$workspaceName = $outputs.workspaceName
$stagingDir    = Join-Path $DataDir 'olist-raw'
$assetFile     = Join-Path $DataDir 'olist-data-asset.yml'

# The 9 files that make up the Olist dataset.
$olistFiles = @(
    'olist_customers_dataset.csv'
    'olist_geolocation_dataset.csv'
    'olist_order_items_dataset.csv'
    'olist_order_payments_dataset.csv'
    'olist_order_reviews_dataset.csv'
    'olist_orders_dataset.csv'
    'olist_products_dataset.csv'
    'olist_sellers_dataset.csv'
    'product_category_name_translation.csv'
)

# ---------------------------------------------------------------------------------------
Write-Step "1. Staging the Olist files from: $SourceFolder"
if (-not (Test-Path $SourceFolder)) { throw "Source folder not found: $SourceFolder (use -SourceFolder)" }
$missing = $olistFiles | Where-Object { -not (Test-Path (Join-Path $SourceFolder $_)) }
if ($missing) { throw "Missing file(s) in ${SourceFolder}: $($missing -join ', ')" }

if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
New-Item -ItemType Directory -Path $stagingDir | Out-Null
$totalBytes = 0
foreach ($file in $olistFiles) {
    $item = Copy-Item -Path (Join-Path $SourceFolder $file) -Destination $stagingDir -PassThru
    $totalBytes += $item.Length
    Write-Info ("{0,-40} {1,8:N1} MB" -f $file, ($item.Length / 1MB))
}
Write-Ok ("{0} files, {1:N1} MB staged in {2}" -f $olistFiles.Count, ($totalBytes / 1MB), $stagingDir)

# ---------------------------------------------------------------------------------------
Write-Step "2. Checking whether $DataAssetName version $DataVersion already exists"
if (Test-AzCommand { az ml data show --name $DataAssetName --version $DataVersion --resource-group $resourceGroup --workspace-name $workspaceName }) {
    Write-Warn "$DataAssetName version $DataVersion already exists - data asset versions are immutable."
    Write-Info "Nothing uploaded. To register new data use:  .\scripts\03-upload-data.ps1 -DataVersion <next>"
    exit 0
}
Write-Ok 'Version is free'

# ---------------------------------------------------------------------------------------
Write-Step "3. Uploading and registering $DataAssetName version $DataVersion"
Write-Info "Workspace: $workspaceName   (resource group: $resourceGroup)"
# The upload prints an informational warning ("Your file exceeds 100 MB ...") on stderr.
# When output is redirected, Windows PowerShell 5.1 turns stderr lines into errors, so
# relax the error preference for this one call and rely on the exit code instead.
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    az ml data create `
        --file $assetFile `
        --name $DataAssetName `
        --version $DataVersion `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --only-show-errors --output none
} finally {
    $ErrorActionPreference = $previousPreference
}
Assert-AzSuccess 'az ml data create'

$asset = az ml data show --name $DataAssetName --version $DataVersion `
            --resource-group $resourceGroup --workspace-name $workspaceName -o json | ConvertFrom-AzJson
Write-Ok "Registered $($asset.name):$($asset.version)"
Write-Info "Stored at : $($asset.path)"
Write-Info "Use it in a job / notebook as:  azureml:$($DataAssetName):$DataVersion"
Write-Ok 'Next: .\scripts\04-verify-deployment.ps1'
