<#
.SYNOPSIS
    Submit the delivery-time pipeline (prep + train) to Azure ML and wait until it finishes.

.EXAMPLE
    .\scripts\submit-pipeline.ps1 -ResourceGroup rg-olist-ml-dev -Workspace mlw-olist-dev
#>
param(
    [string]$ResourceGroup = 'rg-olist-ml-dev',
    [string]$Workspace = 'mlw-olist-dev'
)

# az writes harmless notices to stderr; rely on $LASTEXITCODE instead of 'Stop'.
$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pipelineFile = Join-Path $projectRoot 'pipelines\delivery-time-pipeline.yml'
$common = @('-g', $ResourceGroup, '-w', $Workspace, '--only-show-errors')

Write-Host "==> Submitting $pipelineFile" -ForegroundColor Cyan
$job = az ml job create --file $pipelineFile @common `
        --query '{name:name, studio:services.Studio.endpoint}' -o json | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $job) { throw 'Pipeline submission failed - read the error above.' }
Write-Host "    Pipeline : $($job.name)"
Write-Host "    Studio   : $($job.studio)"
# Remember the job so register-model.ps1 can find it without copy-pasting the random name.
Set-Content -Path (Join-Path $projectRoot '.last-pipeline-job') -Value $job.name -Encoding ascii

Write-Host '==> Waiting for the pipeline (prep, then train). Status is checked every 30 s.' -ForegroundColor Cyan
$finalStates = 'Completed', 'Failed', 'Canceled', 'NotResponding'
do {
    Start-Sleep -Seconds 30
    $status = az ml job show --name $job.name @common --query status -o tsv
    $steps = az ml job list --parent-job-name $job.name @common --query '[].[display_name, status]' -o tsv
    Write-Host ("    {0}  pipeline: {1}  |  {2}" -f (Get-Date -Format 'HH:mm:ss'), $status, (($steps | ForEach-Object { $_ -replace "`t", ': ' }) -join '  |  '))
} while ($finalStates -notcontains $status)

if ($status -eq 'Completed') {
    Write-Host "==> Pipeline $($job.name) completed" -ForegroundColor Green
    Write-Host "    Next: check the metrics in studio, then run .\scripts\register-model.ps1 -ResourceGroup $ResourceGroup -Workspace $Workspace"
} else {
    Write-Host "==> Pipeline $($job.name) finished with status: $status" -ForegroundColor Red
    Write-Host '    Open the studio link, click the failed step, and read Outputs + logs > user_logs/std_log.txt'
    exit 1
}
