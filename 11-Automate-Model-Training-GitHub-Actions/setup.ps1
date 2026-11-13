# Run from a cloned repository after az login and gh auth login.
[CmdletBinding()]
param(
    [string]$ResourceGroup,
    [string]$Workspace,
    [string]$Location,
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

function Select-AzureSubscription {
    $subscriptionJson = az account list --all -o json
    Check 'List Azure subscriptions'
    $parsed = ConvertFrom-Json -InputObject ($subscriptionJson -join [Environment]::NewLine)
    $subscriptions = @(
        $parsed |
            Where-Object { $_.state -eq 'Enabled' -and $_.name -ne 'N/A(tenant level account)' } |
            Sort-Object name, id
    )
    if ($subscriptions.Count -eq 0) { throw 'No enabled Azure subscriptions are available.' }

    do {
        Write-Host ''
        Write-Host 'Available Azure subscriptions:'
        for ($index = 0; $index -lt $subscriptions.Count; $index++) {
            $candidate = $subscriptions[$index]
            Write-Host ("  [{0}] {1} | Subscription: {2} | Tenant: {3}" -f ($index + 1), $candidate.name, $candidate.id, $candidate.tenantId)
        }
        $selectionText = Read-Host "Enter the subscription number shown above (1-$($subscriptions.Count))"
        $selection = 0
        $valid = [int]::TryParse($selectionText, [ref]$selection) -and $selection -ge 1 -and $selection -le $subscriptions.Count
        if (-not $valid) { Write-Warning "Enter a number from 1 to $($subscriptions.Count)." }
    } until ($valid)
    return $subscriptions[$selection - 1]
}

function Get-GitHubRepositoryFromOrigin {
    $remoteUrl = git remote get-url origin
    Check 'Read the origin Git remote'
    $remoteUrl = $remoteUrl.Trim()
    $repository = $remoteUrl `
        -replace '^https://github\.com/', '' `
        -replace '^git@github\.com:', '' `
        -replace '^ssh://git@github\.com/', '' `
        -replace '\.git$', '' `
        -replace '/$', ''
    if ($repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "The origin remote must point to your GitHub student repository: $remoteUrl"
    }
    Write-Host "Detected GitHub repository from origin: $repository"
    return $repository
}

foreach ($tool in @('az', 'gh', 'git', 'python')) { Get-Command $tool -ErrorAction Stop | Out-Null }
Write-Host 'Checking existing Azure and GitHub CLI sign-ins...'
az account show --output none
Check 'Azure session (run az login if signed out)'
gh auth status *> $null
Check 'GitHub session (run gh auth login if signed out)'
Write-Host 'Existing Azure and GitHub CLI sessions are ready; no second login is needed.'

$GitHubRepo = Get-GitHubRepositoryFromOrigin
if ($GitHubRepo -eq 'kavsrd13/operationalize-ml-models-labs') {
    throw 'This is the course source repository. Create your own repository with Use this template, clone it, and run setup there.'
}
$repo = gh api "repos/$GitHubRepo" | ConvertFrom-Json
Check 'Read student repository'
if (-not $repo.permissions.admin) { throw 'Setup requires administrator access to your student repository.' }
if ($repo.default_branch -ne 'main') { throw 'Use main as the student repository default branch.' }
$GitHubRepo = $repo.full_name
$currentBranch = (git branch --show-current).Trim()
Check 'Read current Git branch'
if ($currentBranch -ne 'main') { throw "Switch to main before setup. Current branch: $currentBranch" }

$SubscriptionId = (Select-AzureSubscription).id
az account set --subscription $SubscriptionId
Check 'Select subscription'
$account = az account show -o json | ConvertFrom-Json
Check 'Read selected subscription'
if ($account.id -ne $SubscriptionId) { throw "Azure CLI did not select subscription $SubscriptionId." }

$Location = Ask $Location 'Azure region with available CPU quota' 'eastus'
$ResourceGroup = Ask $ResourceGroup 'Resource group (use a dedicated course group)' 'rg-course-ml'
$Workspace = Ask $Workspace 'Azure ML workspace' 'mlw-course-ml'
if (-not $OidcSubject) {
    if ([datetime]$repo.created_at -ge [datetime]'2026-07-15') {
        $OidcSubject = "repo:$($repo.owner.login)@$($repo.owner.id)/$($repo.name)@$($repo.id):ref:refs/heads/main"
    } else { $OidcSubject = "repo:${GitHubRepo}:ref:refs/heads/main" }
}

foreach ($provider in @(
    'Microsoft.Storage',
    'Microsoft.KeyVault',
    'Microsoft.OperationalInsights',
    'Microsoft.Insights',
    'Microsoft.MachineLearningServices',
    'Microsoft.ManagedIdentity'
)) {
    $state = az provider show --namespace $provider --query registrationState -o tsv
    Check "Check resource provider $provider"
    if ($state -ne 'Registered') {
        Write-Host "Registering $provider..."
        az provider register --namespace $provider --wait --output none
        Check "Register resource provider $provider"
    }
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
$deployment = ("course-ml-$ResourceGroup".ToLower() -replace '[^a-z0-9-]', '-')
if ($deployment.Length -gt 64) { $deployment = $deployment.Substring(0, 64) }
$deployArgs = @('--name', $deployment, '--location', $Location, '--template-file', $template, '--parameters', "@$parameterFile")
Write-Host ''
Write-Host 'Lab 11 configuration:'
Write-Host "  Subscription: $SubscriptionId"
Write-Host "  Region:       $Location"
Write-Host "  Resource group: $ResourceGroup"
Write-Host "  Workspace:      $Workspace"
Write-Host "  Compute cluster: course-cpu ($VmSize, 0-1 nodes)"
Write-Host '  Compute instance: none'
Write-Host '  Data asset after deployment: olist-ecommerce-raw:1'
Write-Host "  GitHub repository: $GitHubRepo"
Write-Host "  OIDC subject: $OidcSubject"
Write-Host 'Supporting resource names are derived consistently from the resource group.'
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
Write-Host "Ready. Edit 11-Automate-Model-Training-GitHub-Actions/jobs/train-job.yml, commit, and push to $GitHubRepo main."
Write-Host "Actions: https://github.com/$GitHubRepo/actions"
Write-Host "Studio: https://ml.azure.com/?wsid=$($outputs.workspaceId.value)"
Write-Host 'Created or verified:'
Write-Host "  Workspace: $($outputs.workspaceName.value)"
Write-Host "  Storage account: $($outputs.storageAccountName.value)"
Write-Host "  Key vault: $($outputs.keyVaultName.value)"
Write-Host "  Log Analytics: $($outputs.logAnalyticsName.value)"
Write-Host "  Application Insights: $($outputs.applicationInsightsName.value)"
Write-Host "  Compute cluster: $($outputs.computeClusterName.value)"
Write-Host "  GitHub identity: $($outputs.identityName.value)"
Write-Host '  Data asset: olist-ecommerce-raw:1'
Write-Host 'Keep the same resource group and workspace for subsequent exercises.'
