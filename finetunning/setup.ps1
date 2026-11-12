[CmdletBinding()]
param(
    [string]$SubscriptionId = '2df30ff1-915d-4d35-974a-3d3155aaa413',
    [string]$ResourceGroup = 'rg-medtriage-finetuning',
    [string]$AccountName = '',
    [string]$Location = 'eastus',
    [ValidateSet('New', 'Existing')]
    [string]$ResourceMode,
    [string]$GitHubRepo = 'kavsrd13/operationalize-ml-models-labs',
    [switch]$PreviewOnly,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

function Assert-LastExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed. Resolve the preceding error and rerun setup." }
}

function Select-ExistingFoundryAccount {
    $accounts = @(az cognitiveservices account list --subscription $SubscriptionId -o json | ConvertFrom-Json |
        Where-Object { $_.kind -in @('AIServices', 'OpenAI') } |
        Sort-Object resourceGroup, name)
    Assert-LastExitCode 'List existing Azure AI resources'
    if ($accounts.Count -eq 0) {
        throw "No Azure AI Services or Azure OpenAI resources were found in subscription $SubscriptionId. Rerun and choose New."
    }

    Write-Host ''
    Write-Host 'Available Azure AI resources:'
    for ($index = 0; $index -lt $accounts.Count; $index++) {
        $candidate = $accounts[$index]
        Write-Host ("  [{0}] {1} | {2} | {3} | {4}" -f ($index + 1), $candidate.name, $candidate.resourceGroup, $candidate.location, $candidate.kind)
    }
    do {
        $selectionText = Read-Host "Select a resource [1-$($accounts.Count)]"
        $selection = 0
        $validSelection = [int]::TryParse($selectionText, [ref]$selection) -and $selection -ge 1 -and $selection -le $accounts.Count
        if (-not $validSelection) { Write-Warning 'Enter one of the displayed numbers.' }
    } until ($validSelection)
    return $accounts[$selection - 1]
}

foreach ($tool in @('az', 'gh')) { Get-Command $tool -ErrorAction Stop | Out-Null }
az account set --subscription $SubscriptionId
Assert-LastExitCode 'Select the Pay-As-You-Go subscription'
$account = az account show -o json | ConvertFrom-Json
if ($account.id -ne $SubscriptionId) { throw "Azure CLI did not select $SubscriptionId." }
gh auth status
Assert-LastExitCode 'GitHub sign-in'
$repo = gh api "repos/$GitHubRepo" | ConvertFrom-Json
Assert-LastExitCode 'Read GitHub repository'
if (-not $repo.permissions.admin) { throw 'Administrator access to the GitHub repository is required to set Actions secrets and variables.' }
if ($repo.default_branch -ne 'main') { throw 'The automation expects main as the default branch.' }

if (-not $ResourceMode) {
    Write-Host ''
    Write-Host 'Choose the Azure resource strategy:'
    Write-Host '  [1] Use an existing Azure AI Services / Azure OpenAI resource'
    Write-Host '  [2] Create a new dedicated Azure AI Services resource'
    do {
        $modeSelection = Read-Host 'Select [1-2]'
        if ($modeSelection -notin @('1', '2')) { Write-Warning 'Enter 1 or 2.' }
    } until ($modeSelection -in @('1', '2'))
    $ResourceMode = if ($modeSelection -eq '1') { 'Existing' } else { 'New' }
}

$createBaselineDeployment = $true
if ($ResourceMode -eq 'Existing') {
    if ($AccountName) {
        $selectedAccount = az cognitiveservices account show --subscription $SubscriptionId --resource-group $ResourceGroup --name $AccountName -o json | ConvertFrom-Json
        Assert-LastExitCode "Read existing Azure AI resource $AccountName"
        if ($selectedAccount.kind -notin @('AIServices', 'OpenAI')) {
            throw "$AccountName is not an Azure AI Services or Azure OpenAI resource."
        }
    } else {
        $selectedAccount = Select-ExistingFoundryAccount
    }
    $AccountName = $selectedAccount.name
    $ResourceGroup = $selectedAccount.resourceGroup
    $Location = $selectedAccount.location

    $deployments = @(az cognitiveservices account deployment list --subscription $SubscriptionId --resource-group $ResourceGroup --name $AccountName -o json | ConvertFrom-Json)
    Assert-LastExitCode "List model deployments on $AccountName"
    $baseline = $deployments | Where-Object { $_.name -eq 'medtriage-base' } | Select-Object -First 1
    if ($baseline) {
        if ($baseline.properties.model.name -ne 'gpt-4o-mini' -or $baseline.properties.model.version -ne '2024-07-18') {
            throw "The existing medtriage-base deployment uses $($baseline.properties.model.name) $($baseline.properties.model.version). Rename or remove it, or use a resource without that deployment name."
        }
        $createBaselineDeployment = $false
        Write-Host 'Reusing the compatible medtriage-base deployment already on the selected resource.'
    }
    $template = Join-Path $PSScriptRoot 'infra/existing-main.bicep'
} else {
    if (-not $AccountName) { $AccountName = "medtriageft$((Get-Random -Minimum 100000 -Maximum 999999))" }
    if ($AccountName -notmatch '^[a-z0-9]{2,64}$') { throw 'AccountName must contain only lowercase letters and digits.' }
    $template = Join-Path $PSScriptRoot 'infra/main.bicep'
}

Write-Host ''
Write-Host "Resource mode:  $ResourceMode"
Write-Host "Subscription:   $SubscriptionId"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Azure resource: $AccountName"
Write-Host "Location:       $Location"
$subject = "repo:$($repo.owner.login)@$($repo.owner.id)/$($repo.name)@$($repo.id):ref:refs/heads/main"
$parameterFile = Join-Path $PSScriptRoot '.parameters.json'
$parameters = @{
  '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
  contentVersion = '1.0.0.0'
  parameters = @{
    resourceGroupName = @{ value = $ResourceGroup }
    accountName = @{ value = $AccountName }
    location = @{ value = $Location }
    githubSubject = @{ value = $subject }
  }
}
$parameters.parameters.createBaselineDeployment = @{ value = $createBaselineDeployment }
$parameters | ConvertTo-Json -Depth 8 | Set-Content -Path $parameterFile -Encoding utf8
$deploymentName = "medtriage-finetuning-$($ResourceMode.ToLowerInvariant())-$Location"
$deploymentArgs = @('--name', $deploymentName, '--location', $Location, '--template-file', $template, '--parameters', "@$parameterFile")
az bicep build --file $template --stdout | Out-Null
Assert-LastExitCode 'Compile Bicep'
az deployment sub what-if @deploymentArgs
Assert-LastExitCode 'Preview Foundry resources'
if ($PreviewOnly) { return }
if (-not $Yes -and (Read-Host 'Type deploy to apply the resources shown above') -ne 'deploy') { return }
az deployment sub create @deploymentArgs --output none
Assert-LastExitCode 'Create Foundry resources'
$outputs = az deployment sub show --name $deploymentName --query properties.outputs -o json | ConvertFrom-Json
Assert-LastExitCode 'Read deployment outputs'
foreach ($item in @{
  MEDTRIAGE_AZURE_CLIENT_ID = $outputs.githubClientId.value
  MEDTRIAGE_AZURE_TENANT_ID = $account.tenantId
  MEDTRIAGE_AZURE_SUBSCRIPTION_ID = $SubscriptionId
}.GetEnumerator()) {
  gh secret set $item.Key --body $item.Value --repo $GitHubRepo
  Assert-LastExitCode "Set GitHub secret $($item.Key)"
}
foreach ($item in @{
  MEDTRIAGE_FOUNDRY_ENDPOINT = $outputs.accountEndpoint.value
  MEDTRIAGE_RESOURCE_GROUP = $ResourceGroup
  MEDTRIAGE_ACCOUNT_NAME = $AccountName
  ENABLE_MEDTRIAGE_FINETUNING = 'false'
  MEDTRIAGE_DATA_REVIEWED = 'false'
}.GetEnumerator()) {
  gh variable set $item.Key --body $item.Value --repo $GitHubRepo
  Assert-LastExitCode "Set GitHub variable $($item.Key)"
}
Write-Host "Provisioning complete. Foundry endpoint: $($outputs.accountEndpoint.value)"
Write-Host "Azure resource mode: $ResourceMode ($ResourceGroup/$AccountName)"
Write-Host 'The workflow remains disabled until a reviewer deliberately changes both training gates to true.'
