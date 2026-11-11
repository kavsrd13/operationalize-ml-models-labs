<#
.SYNOPSIS
    Register the model trained by a completed job in the Azure ML model registry.

.DESCRIPTION
    The training job saves the model in MLflow format to ./outputs/model, which Azure ML
    uploads as the job artifact "outputs/model".
    Registering it gives it a NAME and an auto-incremented VERSION (olist-freight-cost:1, :2, ...),
    and links it to the job, the code and the data that produced it (lineage).
    Only register a model after you have checked its metrics.

    Without -JobName it uses the last job submitted by submit-training.ps1 (saved in
    .last-training-job), so you do not have to copy the random job name.

.EXAMPLE
    .\scripts\register-model.ps1 -ResourceGroup rg-olistanna-ml-dev -Workspace mlw-olistanna-dev
.EXAMPLE
    .\scripts\register-model.ps1 -JobName <job-name> -ResourceGroup rg-olistanna-ml-dev -Workspace mlw-olistanna-dev
#>
param(
    [string]$JobName = '',
    [string]$ModelName = 'olist-freight-cost',
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev'
)

# az writes harmless notices to stderr; rely on $LASTEXITCODE instead of 'Stop' (see submit-training.ps1).
$ErrorActionPreference = 'Continue'

if (-not $JobName) {
    $lastJobFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.last-training-job'
    if (-not (Test-Path $lastJobFile)) { throw 'No -JobName given and no .last-training-job file found. Run submit-training.ps1 first.' }
    $JobName = (Get-Content $lastJobFile -Raw).Trim()
    Write-Host "    Using the last submitted job: $JobName"
}

$status = az ml job show --name $JobName -g $ResourceGroup -w $Workspace --query status -o tsv --only-show-errors
if ($status -ne 'Completed') { throw "Job $JobName has status '$status' - only completed jobs can be registered." }

Write-Host "==> Registering $ModelName from job $JobName" -ForegroundColor Cyan
$model = az ml model create `
    --name $ModelName `
    --type mlflow_model `
    --path "azureml://jobs/$JobName/outputs/artifacts/paths/outputs/model/" `
    --description 'Predicts the freight cost (BRL) of an Olist order item. Histogram gradient boosting on a log target.' `
    --tags "training_job=$JobName" 'dataset=olist-ecommerce-raw:1' `
    -g $ResourceGroup -w $Workspace `
    --query '{name:name, version:version}' -o json --only-show-errors | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Model registration failed - read the error above.' }

Write-Host "    [OK] Registered $($model.name):$($model.version)" -ForegroundColor Green
Write-Host '    See it in studio: Models -> olist-freight-cost'
