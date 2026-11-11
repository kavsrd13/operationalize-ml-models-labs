<#
.SYNOPSIS
    Runs the whole pipeline end to end: check -> validate -> deploy -> upload data -> verify.

.DESCRIPTION
    In class, run the numbered scripts ONE AT A TIME so you can see what each step does.
    Use this script once you understand the steps and just want the environment.

.EXAMPLE
    .\scripts\deploy-all.ps1
.EXAMPLE
    .\scripts\deploy-all.ps1 -ProjectName olistanna -Location westeurope -VmSize Standard_E2ds_v4
#>
param(
    [ValidatePattern('^[a-z0-9]{3,10}$')]
    [string]$ProjectName = '',
    [ValidateSet('dev', 'test', 'prod')]
    [string]$EnvironmentName = 'dev',
    [string]$Location = 'eastus',
    [string]$VmSize = 'Standard_E4ds_v4',
    [string]$DataScientistObjectId = '',
    [switch]$SkipComputeInstance,
    [switch]$SkipValidation,
    [switch]$UpdateExisting
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
$ProjectName = Resolve-NewProjectName -ProjectName $ProjectName -EnvironmentName $EnvironmentName -UpdateExisting:$UpdateExisting
$infraArgs = @{
    ProjectName           = $ProjectName
    EnvironmentName       = $EnvironmentName
    Location              = $Location
    VmSize                = $VmSize
    DataScientistObjectId = $DataScientistObjectId
}

& "$PSScriptRoot\00-check-prerequisites.ps1" -Location $Location -VmSize $VmSize
if ($LASTEXITCODE -ne 0) { throw 'Prerequisite check failed.' }

if (-not $SkipValidation) {
    & "$PSScriptRoot\01-validate-infra.ps1" @infraArgs
}

& "$PSScriptRoot\02-deploy-infra.ps1" @infraArgs -SkipComputeInstance:$SkipComputeInstance -UpdateExisting:$UpdateExisting
& "$PSScriptRoot\03-upload-data.ps1"
& "$PSScriptRoot\04-verify-deployment.ps1"
