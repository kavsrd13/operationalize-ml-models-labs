[CmdletBinding()]
param(
    [string]$SubscriptionId = '2df30ff1-915d-4d35-974a-3d3155aaa413',
    [string]$ResourceGroup = 'rg-medtriage-finetuning',
    [string]$AccountName = '',
    [string]$Location = 'eastus',
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
if (-not $AccountName) { $AccountName = "medtriageft$((Get-Random -Minimum 100000 -Maximum 999999))" }
if ($AccountName -notmatch '^[a-z0-9]{2,64}$') { throw 'AccountName must contain only lowercase letters and digits.' }
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
$parameters | ConvertTo-Json -Depth 8 | Set-Content -Path $parameterFile -Encoding utf8
$template = Join-Path $PSScriptRoot 'infra/main.bicep'
$deploymentName = "medtriage-finetuning-$Location"
$deploymentArgs = @('--name', $deploymentName, '--location', $Location, '--template-file', $template, '--parameters', "@$parameterFile")
az bicep build --file $template --stdout | Out-Null
Assert-LastExitCode 'Compile Bicep'
az deployment sub what-if @deploymentArgs
Assert-LastExitCode 'Preview Foundry resources'
if ($PreviewOnly) { return }
if (-not $Yes -and (Read-Host 'Type deploy to create the Foundry resources shown above') -ne 'deploy') { return }
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
Write-Host 'The workflow remains disabled until a reviewer deliberately changes both training gates to true.'
