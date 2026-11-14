# Run from the root of your own GitHub template repository after az login and gh auth login.
$ErrorActionPreference = 'Stop'

function Check([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed. Read the error above and rerun setup." }
}
function Ask([string]$Label, [string]$Default = '') {
    $value = if ($Default) { Read-Host "$Label [$Default]" } else { Read-Host "$Label (required)" }
    if ($value) { return $value.Trim() }
    if ($Default) { return $Default }
    throw "$Label is required."
}

az account show --output none
Check 'Azure CLI sign-in (run az login if needed)'
gh auth status *> $null
Check 'GitHub CLI sign-in (run gh auth login if needed)'
Write-Host 'Azure and GitHub CLI sessions are ready.'

$origin = (git remote get-url origin).Trim()
Check 'Read origin remote'
$repository = $origin -replace '^https://github\.com/', '' -replace '^git@github\.com:', '' -replace '\.git$', ''
if ($repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'origin must point to your GitHub repository.' }
if ($repository -eq 'kavsrd13/operationalize-ml-models-labs') { throw 'Create your own repository with Use this template first.' }
$repoJson = gh api "repos/$repository"
Check 'Read your GitHub repository'
$repo = $repoJson | ConvertFrom-Json
if (-not $repo.permissions.admin) { throw 'You need admin access to your repository for OIDC setup.' }
if ($repo.default_branch -ne 'main') { throw 'Set main as your GitHub repository default branch.' }
Write-Host "GitHub repository: $($repo.full_name)"

$allJson = az account list --all -o json
Check 'List Azure subscriptions'
$subscriptions = @(($allJson | ConvertFrom-Json) | Where-Object { $_.state -eq 'Enabled' -and $_.name -ne 'N/A(tenant level account)' } | Sort-Object name)
if (-not $subscriptions.Count) { throw 'No enabled subscriptions are available.' }
do {
    Write-Host 'Available Azure subscriptions:'
    for ($i=0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "  [$($i+1)] $($subscriptions[$i].name) | $($subscriptions[$i].id)"
    }
    $answer = Read-Host "Enter a subscription number (1-$($subscriptions.Count))"
    $choice = 0
    $valid = [int]::TryParse($answer, [ref]$choice) -and $choice -ge 1 -and $choice -le $subscriptions.Count
    if (-not $valid) { Write-Warning 'Enter one of the numbers shown above.' }
} until ($valid)
$subscription = $subscriptions[$choice-1]
az account set --subscription $subscription.id
Check 'Select subscription'

Write-Host 'In Foundry, copy the account, project, and deployment names from your existing project.'
$group = Ask 'Resource group containing the Foundry account'
$accountName = Ask 'Foundry account name'
$projectName = Ask 'Foundry project name'
$modelName = Ask 'Existing model deployment name'
$projectId = "/subscriptions/$($subscription.id)/resourceGroups/$group/providers/Microsoft.CognitiveServices/accounts/$accountName/projects/$projectName"
$projectUrl = "https://management.azure.com${projectId}?api-version=2025-06-01"
az rest --method get --url $projectUrl --query id -o tsv | Out-Null
Check 'Verify Foundry project'
az cognitiveservices account deployment show -g $group -n $accountName --deployment-name $modelName --subscription $subscription.id --query name -o tsv | Out-Null
Check 'Verify model deployment'
$endpoint = "https://$accountName.services.ai.azure.com/api/projects/$projectName"

$identityName = "id-olist-analyst-gh-$($repo.id)"
$identityJson = az identity show -g $group -n $identityName --subscription $subscription.id -o json 2>$null
if ($LASTEXITCODE -ne 0) {
    $identityJson = az identity create -g $group -n $identityName --subscription $subscription.id -o json
    Check 'Create GitHub OIDC identity'
}
$identity = $identityJson | ConvertFrom-Json
if ([datetime]$repo.created_at -ge [datetime]'2026-07-15') {
    $subject = "repo:$($repo.owner.login)@$($repo.owner.id)/$($repo.name)@$($repo.id):ref:refs/heads/main"
} else {
    $subject = "repo:$($repo.full_name):ref:refs/heads/main"
}
$credentialName = 'github-main'
$existingCredential = az identity federated-credential show -g $group --identity-name $identityName -n $credentialName --subscription $subscription.id -o json 2>$null
if ($LASTEXITCODE -eq 0) {
    $credential = $existingCredential | ConvertFrom-Json
    if ($credential.subject -ne $subject) { throw "Existing OIDC credential uses a different repository. Remove $credentialName from $identityName and rerun." }
} else {
    az identity federated-credential create -g $group --identity-name $identityName -n $credentialName --subscription $subscription.id --issuer 'https://token.actions.githubusercontent.com' --subject $subject --audiences 'api://AzureADTokenExchange' -o none
    Check 'Configure GitHub OIDC'
}

$role = az role definition list --name 'Foundry User' --query '[0].name' -o tsv
Check 'Find Foundry User role'
if (-not $role) { $role = az role definition list --name 'Azure AI User' --query '[0].name' -o tsv; Check 'Find Azure AI User role' }
if (-not $role) { throw 'Foundry User / Azure AI User role was not found in this tenant.' }
$assigned = az role assignment list --assignee-object-id $identity.principalId --scope $projectId --role $role --query '[0].id' -o tsv
Check 'Check workflow identity role'
if (-not $assigned) {
    az role assignment create --assignee-object-id $identity.principalId --assignee-principal-type ServicePrincipal --role $role --scope $projectId -o none
    Check 'Assign Foundry User role'
}

gh secret set ANALYST_AZURE_CLIENT_ID --body $identity.clientId --repo $repo.full_name; Check 'Save client ID'
gh secret set ANALYST_AZURE_TENANT_ID --body $subscription.tenantId --repo $repo.full_name; Check 'Save tenant ID'
gh secret set ANALYST_AZURE_SUBSCRIPTION_ID --body $subscription.id --repo $repo.full_name; Check 'Save subscription ID'
gh variable set ANALYST_PROJECT_ENDPOINT --body $endpoint --repo $repo.full_name; Check 'Save project endpoint'
gh variable set ANALYST_MODEL_DEPLOYMENT --body $modelName --repo $repo.full_name; Check 'Save model deployment'
gh variable set ANALYST_AGENT_NAME --body 'olist-data-analyst' --repo $repo.full_name; Check 'Save agent name'

Write-Host "Ready. Project endpoint: $endpoint"
Write-Host 'Push an edit to Exercise 13 instructions/system.txt on main to register a new agent version.'
