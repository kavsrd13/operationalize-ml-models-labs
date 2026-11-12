# Run from a cloned student repository after az login and gh auth login.
[CmdletBinding()]
param(
    [string]$ResourceGroup,
    [string]$AccountName,
    [string]$Location,
    [string]$OidcSubject,
    [switch]$PreviewOnly
)

$ErrorActionPreference = 'Stop'

function Assert-LastExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed. Resolve the preceding error and rerun setup." }
}

function Ask([string]$Value, [string]$Label, [string]$Default) {
    if ($Value) { return $Value }
    if ($Default) {
        $answer = Read-Host "$Label. Press Enter to use '$Default', or type a different value"
    } else {
        $answer = Read-Host "$Label (required; example: owner/repository)"
    }
    if ($answer) { return $answer.Trim() }
    return $Default
}

function Get-GitHubRepositoryFromGit {
    $remotes = @(git remote)
    Assert-LastExitCode 'Read Git remotes'
    if ($remotes -notcontains 'origin') {
        throw "No 'origin' Git remote was found. Clone the GitHub repository or add its URL as origin, then rerun setup."
    }

    $remoteUrl = (git remote get-url origin).Trim()
    Assert-LastExitCode 'Read the origin Git remote'
    $repository = $remoteUrl `
        -replace '^https://github\.com/', '' `
        -replace '^git@github\.com:', '' `
        -replace '^ssh://git@github\.com/', '' `
        -replace '\.git$', '' `
        -replace '/$', ''
    if ($repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "The origin remote is not a supported GitHub URL: $remoteUrl"
    }
    Write-Host "Detected GitHub repository from origin: $repository"
    return $repository
}

function Select-AzureSubscription {
    $subscriptionJson = az account list --all -o json
    Assert-LastExitCode 'List Azure subscriptions'
    $parsedSubscriptions = ConvertFrom-Json -InputObject ($subscriptionJson -join [Environment]::NewLine)
    $subscriptions = @(
        foreach ($subscription in $parsedSubscriptions) {
            if ($subscription.state -eq 'Enabled' -and $subscription.name -ne 'N/A(tenant level account)') { $subscription }
        }
    )
    $subscriptions = @($subscriptions | Sort-Object name, id)
    if ($subscriptions.Count -eq 0) {
        throw 'No enabled Azure subscriptions are available to the signed-in user.'
    }

    do {
        Write-Host ''
        Write-Host 'Available Azure subscriptions:'
        for ($index = 0; $index -lt $subscriptions.Count; $index++) {
            $candidate = $subscriptions[$index]
            Write-Host ("  [{0}] {1} | Subscription: {2} | Tenant: {3}" -f ($index + 1), $candidate.name, $candidate.id, $candidate.tenantId)
        }
        $selectionText = Read-Host "Enter the subscription number shown above (1-$($subscriptions.Count))"
        $selection = 0
        $validSelection = [int]::TryParse($selectionText, [ref]$selection) -and $selection -ge 1 -and $selection -le $subscriptions.Count
        if (-not $validSelection) { Write-Warning "Invalid choice. Enter a number from 1 to $($subscriptions.Count)." }
    } until ($validSelection)
    return $subscriptions[$selection - 1]
}

function Select-ExistingFoundryAccount {
    $accountJson = az cognitiveservices account list --subscription $SubscriptionId -o json
    Assert-LastExitCode 'List existing Azure AI resources'
    $parsedAccounts = ConvertFrom-Json -InputObject ($accountJson -join [Environment]::NewLine)
    $accounts = @(
        foreach ($azureAccount in $parsedAccounts) {
            if ($azureAccount.kind -in @('AIServices', 'OpenAI')) { $azureAccount }
        }
    )
    $accounts = @($accounts | Sort-Object resourceGroup, name)
    if ($accounts.Count -eq 0) {
        throw "No Azure AI Services or Azure OpenAI resources were found in subscription $SubscriptionId. Rerun and choose New."
    }

    do {
        Write-Host ''
        Write-Host 'Available Azure AI resources:'
        for ($index = 0; $index -lt $accounts.Count; $index++) {
            $candidate = $accounts[$index]
            Write-Host ("  [{0}] {1} | Resource group: {2} | Region: {3} | Type: {4}" -f ($index + 1), $candidate.name, $candidate.resourceGroup, $candidate.location, $candidate.kind)
        }
        $selectionText = Read-Host "Enter the Azure AI resource number shown above (1-$($accounts.Count))"
        $selection = 0
        $validSelection = [int]::TryParse($selectionText, [ref]$selection) -and $selection -ge 1 -and $selection -le $accounts.Count
        if (-not $validSelection) { Write-Warning "Invalid choice. Enter a number from 1 to $($accounts.Count)." }
    } until ($validSelection)
    return $accounts[$selection - 1]
}

foreach ($tool in @('az', 'gh', 'git')) { Get-Command $tool -ErrorAction Stop | Out-Null }
az account show --output none
Assert-LastExitCode 'Azure sign-in (run az login first)'
gh auth status
Assert-LastExitCode 'GitHub sign-in (run gh auth login first)'

$selectedSubscription = Select-AzureSubscription
$SubscriptionId = $selectedSubscription.id
az account set --subscription $SubscriptionId
Assert-LastExitCode 'Select Azure subscription'
$account = az account show -o json | ConvertFrom-Json
if ($account.id -ne $SubscriptionId) { throw "Azure CLI did not select $SubscriptionId." }

$GitHubRepo = Get-GitHubRepositoryFromGit
$repo = gh api "repos/$GitHubRepo" | ConvertFrom-Json
Assert-LastExitCode 'Read GitHub repository'
if (-not $repo.permissions.admin) { throw 'Administrator access to the origin repository is required to set Actions secrets and variables.' }
if ($repo.default_branch -ne 'main') { throw 'The automation expects main as the default branch.' }
$GitHubRepo = $repo.full_name
$currentBranch = (git branch --show-current).Trim()
Assert-LastExitCode 'Read current Git branch'
if ($currentBranch -ne 'main') { throw "Switch to main before setup. Current branch: $currentBranch" }

$branchProtectionQuery = 'query($owner:String!,$name:String!){repository(owner:$owner,name:$name){branchProtectionRules(first:100){totalCount}}}'
$branchProtectionCount = gh api graphql `
    -f query=$branchProtectionQuery `
    -F "owner=$($repo.owner.login)" `
    -F "name=$($repo.name)" `
    --jq '.data.repository.branchProtectionRules.totalCount'
Assert-LastExitCode 'Read GitHub branch-protection rules'
if ([int]$branchProtectionCount -gt 0) {
    throw 'The main branch has a branch-protection rule. Remove it for this classroom repository before rerunning setup.'
}
$rulesetJson = gh api "repos/$GitHubRepo/rulesets"
Assert-LastExitCode 'Read GitHub repository rulesets'
$parsedRulesets = ConvertFrom-Json -InputObject ($rulesetJson -join [Environment]::NewLine)
$rulesets = @(foreach ($ruleset in $parsedRulesets) { $ruleset })
if ($rulesets.Count -gt 0) {
    throw 'This repository has one or more rulesets. Remove them for this classroom repository before rerunning setup.'
}
Write-Host 'GitHub push check: origin/main has no branch protection or repository rulesets.'

if (-not $OidcSubject) {
    if ([datetime]$repo.created_at -ge [datetime]'2026-07-15') {
        $OidcSubject = "repo:$($repo.owner.login)@$($repo.owner.id)/$($repo.name)@$($repo.id):ref:refs/heads/main"
    } else {
        $OidcSubject = "repo:${GitHubRepo}:ref:refs/heads/main"
    }
}
$identityName = "id-medtriage-ft-gh-$($repo.id)"

do {
    Write-Host ''
    Write-Host 'Choose what Exercise 12 should do:'
    Write-Host '  [1] Use an existing Azure AI Services / Azure OpenAI resource'
    Write-Host '  [2] Create a new dedicated Azure AI Services resource'
    Write-Host '  [3] Exit setup without deploying anything'
    $modeSelection = Read-Host 'Enter 1, 2, or 3'
    if ($modeSelection -notin @('1', '2', '3')) {
        Write-Warning 'Invalid choice. You must enter 1, 2, or 3.'
    }
} until ($modeSelection -in @('1', '2', '3'))

if ($modeSelection -eq '3') {
    Write-Host 'Setup cancelled. No Azure resources or GitHub settings were changed.'
    return
}
$ResourceMode = if ($modeSelection -eq '1') { 'Existing' } else { 'New' }

$createBaselineDeployment = $true
if ($ResourceMode -eq 'Existing') {
    if (($AccountName -and -not $ResourceGroup) -or ($ResourceGroup -and -not $AccountName)) {
        throw 'For noninteractive existing-resource setup, provide both ResourceGroup and AccountName.'
    }
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

    $deploymentJson = az cognitiveservices account deployment list --subscription $SubscriptionId --resource-group $ResourceGroup --name $AccountName -o json
    Assert-LastExitCode "List model deployments on $AccountName"
    $parsedDeployments = ConvertFrom-Json -InputObject ($deploymentJson -join [Environment]::NewLine)
    $deployments = @(foreach ($deployment in $parsedDeployments) { $deployment })
    $baseline = $deployments | Where-Object { $_.name -eq 'medtriage-base' } | Select-Object -First 1
    if ($baseline) {
        if ($baseline.properties.model.name -ne 'gpt-4.1-mini' -or $baseline.properties.model.version -ne '2025-04-14') {
            throw "The existing medtriage-base deployment uses $($baseline.properties.model.name) $($baseline.properties.model.version). Rename or remove it, or select another resource."
        }
        $createBaselineDeployment = $false
        Write-Host 'Reusing the compatible medtriage-base deployment already on the selected resource.'
    }
    $template = Join-Path $PSScriptRoot 'infra/existing-main.bicep'
} else {
    $ResourceGroup = Ask $ResourceGroup 'New resource-group name (letters, numbers and hyphens)' 'rg-medtriage-finetuning'
    $Location = Ask $Location 'Azure region name with confirmed fine-tuning quota, such as eastus' 'eastus'
    $generatedName = "medtriageft$((Get-Random -Minimum 100000 -Maximum 999999))"
    $AccountName = Ask $AccountName 'New globally unique Azure AI Services name (lowercase letters and numbers only)' $generatedName
    if ($AccountName -notmatch '^[a-z0-9]{2,64}$') { throw 'AccountName must contain only lowercase letters and digits.' }
    $template = Join-Path $PSScriptRoot 'infra/main.bicep'
}

Write-Host ''
Write-Host "Resource mode:  $ResourceMode"
Write-Host "Subscription:   $SubscriptionId"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Azure resource: $AccountName"
Write-Host "Location:       $Location"
Write-Host 'Base model:    gpt-4.1-mini (2025-04-14)'
Write-Host "GitHub repo:    $GitHubRepo"
Write-Host "OIDC subject:   $OidcSubject"

$parameterFile = Join-Path $PSScriptRoot '.parameters.json'
$parameters = @{
  '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
  contentVersion = '1.0.0.0'
  parameters = @{
    resourceGroupName = @{ value = $ResourceGroup }
    accountName = @{ value = $AccountName }
    location = @{ value = $Location }
    githubSubject = @{ value = $OidcSubject }
    githubIdentityName = @{ value = $identityName }
    createBaselineDeployment = @{ value = $createBaselineDeployment }
  }
}
$parameters | ConvertTo-Json -Depth 8 | Set-Content -Path $parameterFile -Encoding utf8
$deploymentName = "medtriage-finetuning-$($ResourceMode.ToLowerInvariant())-$Location"
$deploymentArgs = @('--name', $deploymentName, '--location', $Location, '--template-file', $template, '--parameters', "@$parameterFile")
az bicep build --file $template --stdout | Out-Null
Assert-LastExitCode 'Compile Bicep'
az deployment sub what-if @deploymentArgs
Assert-LastExitCode 'Preview Foundry resources'
if ($PreviewOnly) { return }
do {
    Write-Host ''
    Write-Host 'Choose what to do with the Bicep preview:'
    Write-Host '  [1] Deploy the resources shown above'
    Write-Host '  [2] Show the Bicep what-if preview again'
    Write-Host '  [3] Exit without deploying'
    $deploymentChoice = Read-Host 'Enter 1, 2, or 3'
    if ($deploymentChoice -eq '2') {
        az deployment sub what-if @deploymentArgs
        Assert-LastExitCode 'Repeat Bicep preview'
    } elseif ($deploymentChoice -notin @('1', '3')) {
        Write-Warning 'Invalid choice. You must enter 1, 2, or 3.'
    }
} until ($deploymentChoice -in @('1', '3'))
if ($deploymentChoice -eq '3') {
    Write-Host 'Setup cancelled. No Azure deployment or GitHub configuration was applied.'
    return
}
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
}.GetEnumerator()) {
  gh variable set $item.Key --body $item.Value --repo $GitHubRepo
  Assert-LastExitCode "Set GitHub variable $($item.Key)"
}
Write-Host "Provisioning complete. Foundry endpoint: $($outputs.accountEndpoint.value)"
Write-Host "Azure resource mode: $ResourceMode ($ResourceGroup/$AccountName)"
Write-Host "Actions: https://github.com/$GitHubRepo/actions"
Write-Host 'Automation is ready. A push that changes Exercise 12 data, config, or scripts will submit fine-tuning after validation.'
