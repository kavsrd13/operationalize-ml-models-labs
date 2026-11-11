<#
.SYNOPSIS
    Shared settings and helper functions. Every script loads this file with:
        . "$PSScriptRoot\common.ps1"

.NOTES
    Works in Windows PowerShell 5.1 and PowerShell 7+ (Windows, macOS, Linux).
#>

$ErrorActionPreference = 'Stop'

# ----- Folder layout -------------------------------------------------------------------
$RepoRoot     = Split-Path -Parent $PSScriptRoot
$InfraDir     = Join-Path $RepoRoot 'infra'
$TemplateFile = Join-Path $InfraDir 'main.bicep'
$ParamFile    = Join-Path $InfraDir 'main.bicepparam'
$DataDir      = Join-Path $RepoRoot 'data'
$OutputsFile  = Join-Path $RepoRoot '.deployment-outputs.json'

# ----- Console output helpers ------------------------------------------------------------
function Write-Step([string]$Message) { Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Info([string]$Message) { Write-Host "    $Message" }
function Write-Ok([string]$Message)   { Write-Host "    [OK]   $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "    [WARN] $Message" -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host "    [FAIL] $Message" -ForegroundColor Red }

# ----- Azure CLI helpers -----------------------------------------------------------------
# PowerShell does NOT stop when a native program such as `az` fails - it only sets
# $LASTEXITCODE. Call this right after every important `az` command.
function Assert-AzSuccess([string]$What) {
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI step failed: $What (exit code $LASTEXITCODE). Read the error above."
    }
}

# Runs a script block containing an `az` command and returns $true if it succeeded.
# All output is hidden - use it for "does this resource exist?" checks.
function Test-AzCommand([scriptblock]$Command) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # stderr from az must not abort the check
    try { & $Command *> $null } finally { $ErrorActionPreference = $previous }
    return ($LASTEXITCODE -eq 0)
}

# Converts the text that `az ... -o json` prints into PowerShell objects.
function ConvertFrom-AzJson {
    param([Parameter(ValueFromPipeline = $true)] $InputObject)
    begin { $lines = @() }
    process { $lines += $InputObject }
    end {
        $text = ($lines -join "`n").Trim()
        # ForEach-Object unrolls JSON arrays into separate items (Windows PowerShell 5.1 keeps them bundled)
        if ($text) { $text | ConvertFrom-Json | ForEach-Object { $_ } }
    }
}

# ----- Naming convention -----------------------------------------------------------------
# These two names MUST match the naming rules in infra/main.bicep. The scripts need them
# before a deployment exists (for example to check for an existing compute instance).
function Get-ResourceGroupName([string]$ProjectName, [string]$EnvironmentName) {
    return "rg-$ProjectName-ml-$EnvironmentName"
}
function Get-WorkspaceName([string]$ProjectName, [string]$EnvironmentName) {
    return "mlw-$ProjectName-$EnvironmentName"
}
# A deployment's location cannot change, so the region is part of the deployment name.
function Get-DeploymentName([string]$ProjectName, [string]$EnvironmentName, [string]$Location) {
    return "aml-$ProjectName-$EnvironmentName-$Location"
}

# ----- Project name: asked from the user, used to name every resource ----------------------
$ProjectNamePattern = '^[a-z0-9]{3,10}$'

function Read-ProjectName {
    while ($true) {
        $value = (Read-Host 'Enter a name for your resources (3-10 lowercase letters or digits, e.g. olistanna)').Trim().ToLower()
        if ($value -match $ProjectNamePattern) { return $value }
        Write-Warn 'Use 3-10 lowercase letters or digits only (no spaces, hyphens or capitals).'
    }
}

function Test-ResourceGroupExists([string]$Name) {
    return ((az group exists --name $Name --only-show-errors) -eq 'true')
}

# Returns a project name whose resource group does NOT exist yet, so a deployment always
# creates NEW resources. Asks the user when no name was given. With -UpdateExisting an
# existing name is accepted (used to show that re-deploying changes nothing).
function Resolve-NewProjectName {
    param([string]$ProjectName, [string]$EnvironmentName, [switch]$UpdateExisting)
    $asked = -not $ProjectName
    if ($asked) { $ProjectName = Read-ProjectName }
    while ($true) {
        $rg = Get-ResourceGroupName $ProjectName $EnvironmentName
        if (-not (Test-ResourceGroupExists $rg)) {
            Write-Ok "Name '$ProjectName' is free - new resources will be created in $rg"
            return $ProjectName
        }
        if ($UpdateExisting) {
            Write-Info "Updating the EXISTING resources in $rg (-UpdateExisting)."
            return $ProjectName
        }
        if (-not $asked) {
            throw "Resource group $rg already exists. Choose a new -ProjectName to create new resources, or add -UpdateExisting to update the existing ones."
        }
        Write-Warn "$rg already exists. Choose another name to create NEW resources."
        $ProjectName = Read-ProjectName
    }
}

# Asks for the name if it was not passed (used by the scripts that do not create resources).
function Resolve-ProjectName([string]$ProjectName) {
    if ($ProjectName) { return $ProjectName }
    return Read-ProjectName
}

# main.bicepparam reads its values from these environment variables (readEnvironmentVariable).
function Set-BicepParameterEnvironment {
    param(
        [string]$ProjectName,
        [string]$EnvironmentName,
        [string]$Location,
        [string]$VmSize,
        [string]$DataScientistObjectId,
        [bool]$DeployComputeInstance = $true
    )
    $env:AML_PROJECT_NAME            = $ProjectName
    $env:AML_ENVIRONMENT             = $EnvironmentName
    $env:AZURE_LOCATION              = $Location
    $env:AML_COMPUTE_VM_SIZE         = $VmSize
    $env:AML_USER_OBJECT_ID          = $DataScientistObjectId
    $env:AML_DEPLOY_COMPUTE_INSTANCE = $DeployComputeInstance.ToString().ToLower()
}

# Reads the outputs saved by 02-deploy-infra.ps1.
function Get-DeploymentOutputs {
    if (-not (Test-Path $OutputsFile)) {
        throw "No deployment outputs found at $OutputsFile. Run scripts\02-deploy-infra.ps1 first."
    }
    return (Get-Content $OutputsFile -Raw | ConvertFrom-Json)
}
