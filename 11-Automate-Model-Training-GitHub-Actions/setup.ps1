# Run from a cloned repository after az login and gh auth login.
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$ResourceGroup,
    [string]$Workspace,
    [string]$Location,
    [string]$GitHubRepo,
    [string]$VmSize = 'Standard_E4ds_v4',
    [string]$OidcSubject,
    [switch]$PreviewOnly,
    [switch]$Yes
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
function Check([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed. Resolve the error above and rerun setup." }
}
function Ask([string]$value, [string]$label, [string]$default) {
    if ($value) { return $value }
    $answer = Read-Host "$label [$default]"
    if ($answer) { return $answer.Trim() }
    return $default
}
foreach ($tool in @('az', 'gh', 'python')) { Get-Command $tool -ErrorAction Stop | Out-Null }
$account = az account show -o json | ConvertFrom-Json
Check 'Azure sign-in (run az login)'
gh auth status
Check 'GitHub sign-in (run gh auth login)'
az account list --query '[].{Name:name,Subscription:id}' -o table
Check 'List subscriptions'
$SubscriptionId = Ask $SubscriptionId 'Subscription ID' $account.id
az account set --subscription $SubscriptionId
Check 'Select subscription'
$Location = Ask $Location 'Azure region with available CPU quota' 'eastus'
$ResourceGroup = Ask $ResourceGroup 'Resource group (use a dedicated course group)' 'rg-course-ml'
$Workspace = Ask $Workspace 'Azure ML workspace' 'mlw-course-ml'
$GitHubRepo = Ask $GitHubRepo 'Your GitHub repository (OWNER/REPO)' ''
if ($GitHubRepo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Use OWNER/REPO for GitHubRepo.' }
$repo = gh api "repos/$GitHubRepo" | ConvertFrom-Json
Check 'Read student repository'
if (-not $repo.permissions.admin) { throw 'Setup requires administrator access to your student repository.' }
if ($repo.default_branch -ne 'main') { throw 'Use main as the student repository default branch.' }
$GitHubRepo = $repo.full_name
if (-not $OidcSubject) {
    if ([datetime]$repo.created_at -ge [datetime]'2026-07-15') {
        $OidcSubject = "repo:$($repo.owner.login)@$($repo.owner.id)/$($repo.name)@$($repo.id):ref:refs/heads/main"
    } else { $OidcSubject = "repo:${GitHubRepo}:ref:refs/heads/main" }
}
az extension add --name ml --yes
Check 'Install Azure ML extension'
az bicep version
Check 'Bicep installation (run az bicep install if missing)'

# Keep the exact parameters for repeat deployments. This file contains IDs, not passwords.
$parameterValues = @{
    resourceGroupName = $ResourceGroup; workspaceName = $Workspace
    location = $Location; vmSize = $VmSize; githubSubject = $OidcSubject
}
$parameters = @{}
foreach ($key in $parameterValues.Keys) { $parameters[$key] = @{ value = $parameterValues[$key] } }
$parameterFile = Join-Path $PSScriptRoot '.lab11.parameters.json'
@{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = $parameters } |
    ConvertTo-Json -Depth 8 | Set-Content $parameterFile -Encoding utf8
$template = Join-Path $PSScriptRoot 'infra/main.bicep'
$deployment = "course-ml-$Location"
$deployArgs = @('--name', $deployment, '--location', $Location, '--template-file', $template, '--parameters', "@$parameterFile")
Write-Host "Preview: $SubscriptionId / $ResourceGroup / $Workspace / course-cpu / $GitHubRepo"
Write-Host 'Supporting resource names are derived consistently from the resource group. Training has 0-1 nodes.'
az deployment sub what-if @deployArgs
Check 'Bicep preview'
if ($PreviewOnly) { return }
if (-not $Yes -and (Read-Host 'Deploy the resources shown above? Type deploy') -ne 'deploy') { return }
az deployment sub create @deployArgs --output none
Check 'Bicep deployment'
$outputs = az deployment sub show --name $deployment --query properties.outputs -o json | ConvertFrom-Json
Check 'Read deployment outputs'
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --subscription $SubscriptionId --resource-group $ResourceGroup --workspace $Workspace --skip-install
Check 'Extract and register the versioned dataset'
$tenant = az account show --query tenantId -o tsv
Check 'Read tenant'
foreach ($item in @{
    AZURE_CLIENT_ID = $outputs.clientId.value
    AZURE_TENANT_ID = $tenant
    AZURE_SUBSCRIPTION_ID = $SubscriptionId
}.GetEnumerator()) {
    gh secret set $item.Key --body $item.Value --repo $GitHubRepo
    Check "Set $($item.Key)"
}
foreach ($item in @{
    AZURE_RESOURCE_GROUP = $ResourceGroup
    AZURE_ML_WORKSPACE = $Workspace
    AZURE_ML_COMPUTE = 'course-cpu'
    ENABLE_AZURE_TRAINING = 'true'
}.GetEnumerator()) {
    gh variable set $item.Key --body $item.Value --repo $GitHubRepo
    Check "Set $($item.Key)"
}
Write-Host "Ready. Edit Lab 11/jobs/train-job.yml, commit, and push to $GitHubRepo main."
Write-Host "Actions: https://github.com/$GitHubRepo/actions"
Write-Host "Studio: https://ml.azure.com/?wsid=$($outputs.workspaceId.value)"
Write-Host 'Keep the same resource group and workspace for subsequent exercises.'
