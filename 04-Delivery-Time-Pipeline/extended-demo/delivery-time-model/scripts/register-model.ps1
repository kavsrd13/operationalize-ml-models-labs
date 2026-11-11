<#
.SYNOPSIS
    Register the model produced by a completed delivery-time pipeline.

.DESCRIPTION
    The pipeline's output "trained_model" is an MLflow model folder written by the train step.
    Registering gives it a name and version (olist-delivery-time:1, :2, ...) with lineage back
    to the pipeline, code and data. Without -JobName the last submitted pipeline is used.

.EXAMPLE
    .\scripts\register-model.ps1 -ResourceGroup rg-olist-ml-dev -Workspace mlw-olist-dev
#>
param(
    [string]$JobName = '',
    [string]$ModelName = 'olist-delivery-time',
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev'
)

$ErrorActionPreference = 'Continue'
$common = @('-g', $ResourceGroup, '-w', $Workspace, '--only-show-errors')

if (-not $JobName) {
    $lastJobFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.last-pipeline-job'
    if (-not (Test-Path $lastJobFile)) { throw 'No -JobName given and no .last-pipeline-job file found. Run submit-pipeline.ps1 first.' }
    $JobName = (Get-Content $lastJobFile -Raw).Trim()
    Write-Host "    Using the last submitted pipeline: $JobName"
}

$status = az ml job show --name $JobName @common --query status -o tsv
if ($status -ne 'Completed') { throw "Pipeline $JobName has status '$status' - only completed pipelines can be registered." }

Write-Host "==> Registering $ModelName from pipeline $JobName" -ForegroundColor Cyan
$model = az ml model create `
    --name $ModelName `
    --type mlflow_model `
    --path "azureml://jobs/$JobName/outputs/trained_model" `
    --description 'Predicts delivery time (days) of an Olist order at checkout. Gradient boosting, absolute-error loss.' `
    --tags "training_pipeline=$JobName" 'dataset=olist-ecommerce-raw:1' `
    @common --query '{name:name, version:version}' -o json | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $model) { throw 'Model registration failed - read the error above.' }

Write-Host "    [OK] Registered $($model.name):$($model.version)" -ForegroundColor Green
Write-Host '    See it in studio: Models -> olist-delivery-time'
