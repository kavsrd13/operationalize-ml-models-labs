<#
.SYNOPSIS
    STEP 1 - Validate the Bicep templates WITHOUT creating anything.

.DESCRIPTION
    Infrastructure as code is tested in layers, from cheapest to most realistic:
      1. az bicep lint          - static analysis against best-practice rules (bicepconfig.json)
      2. az bicep build         - compiles Bicep to an ARM JSON template (syntax + type errors)
      3. az bicep build-params  - checks main.bicepparam against main.bicep
      4. az deployment sub validate - "preflight": Azure checks names, quotas, policies, RBAC
      5. az deployment sub what-if  - shows exactly what WOULD be created / changed / deleted

.EXAMPLE
    .\scripts\01-validate-infra.ps1 -ProjectName olist -EnvironmentName dev -Location eastus
#>
param(
    [ValidatePattern('^[a-z0-9]{3,10}$')]
    [string]$ProjectName = '',
    [ValidateSet('dev', 'test', 'prod')]
    [string]$EnvironmentName = 'dev',
    [string]$Location = 'eastus',
    [string]$VmSize = 'Standard_E4ds_v4',
    [string]$DataScientistObjectId = ''
)

. "$PSScriptRoot\common.ps1"

$ProjectName = Resolve-ProjectName $ProjectName
if (Test-ResourceGroupExists (Get-ResourceGroupName $ProjectName $EnvironmentName)) {
    Write-Warn "Resources named '$ProjectName' already exist - the preview shows changes to them."
} else {
    Write-Ok "Name '$ProjectName' is new - the preview shows what will be CREATED."
}

Set-BicepParameterEnvironment -ProjectName $ProjectName -EnvironmentName $EnvironmentName `
    -Location $Location -VmSize $VmSize -DataScientistObjectId $DataScientistObjectId
$deploymentName = Get-DeploymentName $ProjectName $EnvironmentName $Location

Write-Step '1. Lint (best-practice rules from infra/bicepconfig.json)'
az bicep lint --file $TemplateFile
Assert-AzSuccess 'az bicep lint'
Write-Ok 'Lint passed'

Write-Step '2. Build Bicep -> ARM JSON'
az bicep build --file $TemplateFile --stdout | Out-Null
Assert-AzSuccess 'az bicep build'
Write-Ok 'main.bicep compiles'

Write-Step '3. Build parameter file'
az bicep build-params --file $ParamFile --stdout | Out-Null
Assert-AzSuccess 'az bicep build-params'
Write-Ok 'main.bicepparam matches main.bicep'

Write-Step '4. Preflight validation in Azure (nothing is created)'
az deployment sub validate `
    --name $deploymentName `
    --location $Location `
    --parameters $ParamFile `
    --only-show-errors --output none
Assert-AzSuccess 'az deployment sub validate'
Write-Ok 'Azure accepted the template'

Write-Step '5. What-if: preview of the changes'
Write-Info 'Legend:  + Create   ~ Modify   - Delete   = No change   * Ignore'
az deployment sub what-if `
    --name $deploymentName `
    --location $Location `
    --parameters $ParamFile `
    --only-show-errors
Assert-AzSuccess 'az deployment sub what-if'

Write-Step 'Validation complete'
Write-Ok 'Next: .\scripts\02-deploy-infra.ps1'
