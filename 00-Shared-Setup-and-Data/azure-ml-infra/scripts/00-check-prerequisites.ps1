<#
.SYNOPSIS
    STEP 0 - Check that your machine and Azure subscription are ready.

.DESCRIPTION
    Checks (and fixes, where it is safe to do so):
      1. Azure CLI is installed and recent enough
      2. Bicep CLI is available (installs it through Azure CLI if missing)
      3. You are logged in, and which subscription is active
      4. Azure ML CLI v2 extension ('ml') is installed (installs it if missing)
      5. Required resource providers are registered (registers missing ones)
      6. Your role on the subscription allows creating resources AND role assignments
      7. Azure ML vCPU quota for the compute-instance VM size in the chosen region

.EXAMPLE
    .\scripts\00-check-prerequisites.ps1 -Location eastus -VmSize Standard_E4ds_v4
#>
param(
    [string]$Location = 'eastus',
    [string]$VmSize = 'Standard_E4ds_v4'
)

. "$PSScriptRoot\common.ps1"
$problems = 0

# ---------------------------------------------------------------------------------------
Write-Step '1. Azure CLI'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Fail 'Azure CLI not found. Install it: winget install -e --id Microsoft.AzureCLI'
    Write-Info 'Docs: https://learn.microsoft.com/cli/azure/install-azure-cli'
    exit 1
}
$azVersion = [version]((az version -o json | ConvertFrom-AzJson).'azure-cli')
$minimumAz = [version]'2.61.0'   # .bicepparam deployments need 2.53+, deployment stacks 2.61+
if ($azVersion -lt $minimumAz) {
    Write-Fail "Azure CLI $azVersion is too old (need $minimumAz+). Run: az upgrade"
    $problems++
} else {
    Write-Ok "Azure CLI $azVersion"
}

# ---------------------------------------------------------------------------------------
Write-Step '2. Bicep CLI'
if (-not (Test-AzCommand { az bicep version })) {
    Write-Info 'Bicep not found - installing it through Azure CLI...'
    az bicep install
    Assert-AzSuccess 'az bicep install'
}
$bicepVersion = (az bicep version --only-show-errors) -join ' '
Write-Ok $bicepVersion
Write-Info "Tip: 'az bicep upgrade' keeps Bicep current (newer versions know newer API versions)."

# ---------------------------------------------------------------------------------------
Write-Step '3. Azure login'
if (-not (Test-AzCommand { az account show })) {
    Write-Fail "You are not logged in. Run 'az login' (and 'az account set -s <subscription>') then re-run."
    exit 1
}
$account = az account show -o json | ConvertFrom-AzJson
Write-Ok "Subscription : $($account.name) ($($account.id))"
Write-Ok "Signed in as : $($account.user.name) ($($account.user.type))"
Write-Info "Wrong subscription? Run: az account set --subscription <name-or-id>"

# ---------------------------------------------------------------------------------------
Write-Step "4. Azure ML CLI v2 extension ('ml')"
$extensions = @(az extension list -o json | ConvertFrom-AzJson)
if ($extensions | Where-Object { $_.name -eq 'azure-cli-ml' }) {
    Write-Warn "Removing the retired v1 extension 'azure-cli-ml' (it conflicts with v2)..."
    az extension remove --name azure-cli-ml
    Assert-AzSuccess 'az extension remove --name azure-cli-ml'
}
$mlExtension = $extensions | Where-Object { $_.name -eq 'ml' }
if (-not $mlExtension) {
    Write-Info "Installing the 'ml' extension..."
    az extension add --name ml --yes
    Assert-AzSuccess 'az extension add --name ml'
    $mlExtension = az extension show --name ml -o json | ConvertFrom-AzJson
}
Write-Ok "ml extension $($mlExtension.version)  (update with: az extension update --name ml)"

# ---------------------------------------------------------------------------------------
Write-Step '5. Resource providers'
# A resource provider is the Azure service that handles a resource type. Each one must be
# registered once per subscription before you can create that kind of resource.
$providers = @(
    'Microsoft.MachineLearningServices'   # Azure ML workspace + compute
    'Microsoft.Storage'                   # storage account
    'Microsoft.KeyVault'                  # key vault
    'Microsoft.ContainerRegistry'         # container registry
    'Microsoft.Insights'                  # Application Insights
    'Microsoft.OperationalInsights'       # Log Analytics
    'Microsoft.Notebooks'                 # required by compute instances
)
foreach ($ns in $providers) {
    $state = az provider show --namespace $ns --query registrationState -o tsv
    if ($state -ne 'Registered') {
        Write-Info "Registering $ns (can take a few minutes)..."
        az provider register --namespace $ns --wait
        Assert-AzSuccess "az provider register --namespace $ns"
    }
    Write-Ok $ns
}

# ---------------------------------------------------------------------------------------
Write-Step '6. Your permissions'
# The template creates ROLE ASSIGNMENTS, which needs more than Contributor:
# either Owner, or Contributor + (User Access Administrator | Role Based Access Control Administrator).
if ($account.user.type -eq 'user') {
    $myObjectId = az ad signed-in-user show --query id -o tsv
    $roles = @(az role assignment list --assignee $myObjectId --scope "/subscriptions/$($account.id)" `
                  --include-inherited --include-groups --query '[].roleDefinitionName' -o tsv)
    $canCreate = ($roles -contains 'Owner') -or ($roles -contains 'Contributor')
    $canAssign = ($roles -contains 'Owner') -or ($roles -contains 'User Access Administrator') -or
                 ($roles -contains 'Role Based Access Control Administrator')
    if ($canCreate -and $canAssign) {
        Write-Ok "Roles on subscription: $($roles -join ', ')"
    } else {
        Write-Warn "Roles found at subscription scope: $($roles -join ', ')"
        Write-Warn 'You may lack permission to create resources or role assignments. Ask for Owner on the subscription,'
        Write-Warn 'or Contributor + Role Based Access Control Administrator (roles granted on a management group also count).'
        $problems++
    }
    Write-Info "Your object ID: $myObjectId (the compute instance will be assigned to it)"
} else {
    Write-Info 'Signed in as a service principal - skipping the user role check.'
}

# ---------------------------------------------------------------------------------------
Write-Step "7. Azure ML quota for $VmSize in $Location"
# Quota = the maximum number of vCPUs of each VM family you may run in a region.
# Compute instances and compute clusters share this Azure ML quota.
$api = 'api-version=2026-05-01'
$base = "https://management.azure.com/subscriptions/$($account.id)/providers/Microsoft.MachineLearningServices/locations/$Location"
$sizes = az rest --method get --url "$base/vmSizes?$api" -o json | ConvertFrom-AzJson
Assert-AzSuccess "list VM sizes in $Location"
$size = $sizes.value | Where-Object { $_.name -eq $VmSize } | Select-Object -First 1

if (-not $size) {
    Write-Fail "$VmSize is not offered by Azure ML in $Location. Pick another size or region."
    $problems++
} elseif ($size.supportedComputeTypes -notcontains 'ComputeInstance') {
    Write-Fail "$VmSize cannot be used for a compute instance (supported: $($size.supportedComputeTypes -join ', '))."
    $problems++
} else {
    $usages = az rest --method get --url "$base/usages?$api" -o json | ConvertFrom-AzJson
    Assert-AzSuccess "list quota usage in $Location"
    $familyQuota = $usages.value | Where-Object {
        $_.name.value -eq $size.family -and $_.type -like '*vmFamily/dedicatedCores/usages'
    } | Select-Object -First 1
    $totalQuota = $usages.value | Where-Object { $_.name.value -eq 'TotalDedicatedCores' } | Select-Object -First 1

    $familyFree = $familyQuota.limit - $familyQuota.currentValue
    $totalFree  = $totalQuota.limit - $totalQuota.currentValue
    Write-Info ("{0}: {1} vCPU, {2} GB RAM, family {3}" -f $VmSize, $size.vCPUs, $size.memoryGB, $size.family)
    Write-Info ("Family quota  : {0} of {1} vCPUs used ({2} free)" -f $familyQuota.currentValue, $familyQuota.limit, $familyFree)
    Write-Info ("Regional total: {0} of {1} vCPUs used ({2} free)" -f $totalQuota.currentValue, $totalQuota.limit, $totalFree)

    if ($familyFree -ge $size.vCPUs -and $totalFree -ge $size.vCPUs) {
        Write-Ok "Enough quota for one $VmSize compute instance."
    } else {
        Write-Fail "Not enough quota for $VmSize. Choose a size from a family that has quota, or request more:"
        Write-Info 'Azure ML studio > Manage > Quota, or https://learn.microsoft.com/azure/machine-learning/how-to-manage-quotas'
        Write-Info 'Families with free quota here:'
        $usages.value | Where-Object { $_.type -like '*vmFamily/dedicatedCores/usages' -and ($_.limit - $_.currentValue) -gt 0 } |
            ForEach-Object { Write-Info ("   {0,-28} {1} free" -f $_.name.value, ($_.limit - $_.currentValue)) }
        $problems++
    }
}

# ---------------------------------------------------------------------------------------
Write-Step 'Summary'
if ($problems -eq 0) {
    Write-Ok 'Everything looks good. Next: .\scripts\01-validate-infra.ps1'
} else {
    Write-Fail "$problems problem(s) found - fix them before deploying."
    exit 1
}
