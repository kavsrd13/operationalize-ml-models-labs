<#
.SYNOPSIS
    Submit the freight-cost training job to Azure ML and follow its logs until it finishes.

.EXAMPLE
    .\scripts\submit-training.ps1
.EXAMPLE
    # Try other hyperparameters without editing the YAML:
    .\scripts\submit-training.ps1 -LearningRate 0.1 -MaxIter 300
#>
param(
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev',
    [double]$LearningRate = 0.05,
    [int]$MaxIter = 600
)

# The Azure ML CLI writes harmless notices to stderr ("This is an experimental class...").
# Windows PowerShell 5.1 turns redirected stderr into errors, so we do not use 'Stop' here
# and check $LASTEXITCODE after each az command instead.
$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$jobFile = Join-Path $projectRoot 'jobs\train-job.yml'

Write-Host "==> Submitting $jobFile" -ForegroundColor Cyan
$job = az ml job create --file $jobFile -g $ResourceGroup -w $Workspace `
        --set inputs.learning_rate=$LearningRate inputs.max_iter=$MaxIter `
        --query '{name:name, studio:services.Studio.endpoint}' -o json --only-show-errors | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Job submission failed - read the error above.' }
Write-Host "    Job    : $($job.name)"
Write-Host "    Studio : $($job.studio)"
# Remember the job so register-model.ps1 can find it without copy-pasting the random name.
Set-Content -Path (Join-Path $projectRoot '.last-training-job') -Value $job.name -Encoding ascii

Write-Host '==> Streaming logs (Ctrl+C stops watching; the job keeps running)' -ForegroundColor Cyan
az ml job stream --name $job.name -g $ResourceGroup -w $Workspace --only-show-errors

# The log stream can disconnect early, so wait for a final status explicitly.
$finalStates = 'Completed', 'Failed', 'Canceled', 'NotResponding'
do {
    $status = az ml job show --name $job.name -g $ResourceGroup -w $Workspace --query status -o tsv --only-show-errors
    if ($finalStates -notcontains $status) { Write-Host "    status: $status - checking again in 20 s"; Start-Sleep -Seconds 20 }
} while ($finalStates -notcontains $status)

if ($status -eq 'Completed') {
    Write-Host "==> Job $($job.name) completed" -ForegroundColor Green
    Write-Host "    Next: check the metrics in studio, then run .\scripts\register-model.ps1 -ResourceGroup $ResourceGroup -Workspace $Workspace"
} else {
    Write-Host "==> Job $($job.name) finished with status: $status" -ForegroundColor Red
    exit 1
}
