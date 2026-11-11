// =====================================================================================
//  main.bicepparam  -  parameter values for main.bicep
// -------------------------------------------------------------------------------------
//  ".bicepparam" is the Bicep-native parameter file (type-checked against main.bicep
//  through the "using" line below - a typo in a parameter name fails at build time).
//
//  Each value can be overridden WITHOUT editing this file by setting an environment
//  variable. The deployment scripts and the GitHub Actions workflow do exactly that:
//
//      $env:AZURE_LOCATION = 'westeurope'      # PowerShell
//      export AZURE_LOCATION=westeurope        # bash
//
//  readEnvironmentVariable('NAME', 'default') -> uses the variable if set, else default.
//  Never put secrets in a parameter file.
// =====================================================================================

using './main.bicep'

// --- Identity of the environment ------------------------------------------------------
// projectName: 3-10 lowercase letters/numbers. Students sharing ONE subscription should
// each use a different value (e.g. 'olistanna'), because names are derived from it.
param projectName = readEnvironmentVariable('AML_PROJECT_NAME', 'olist')
param environmentName = readEnvironmentVariable('AML_ENVIRONMENT', 'dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')

// --- Who will use the workspace -----------------------------------------------------
// Empty = the person running the deployment. An instructor can set the object ID of a
// student here (az ad user show --id student@school.edu --query id -o tsv).
param dataScientistObjectId = readEnvironmentVariable('AML_USER_OBJECT_ID', '')
param dataScientistPrincipalType = 'User'

// --- Optional pieces ------------------------------------------------------------------
param createContainerRegistry = true
param deployComputeInstance = bool(readEnvironmentVariable('AML_DEPLOY_COMPUTE_INSTANCE', 'true'))

// --- Compute instance -----------------------------------------------------------------
// Standard_E4ds_v4 = 4 vCPU / 32 GB RAM. Cheaper option: Standard_E2ds_v4 (2 vCPU / 16 GB).
// Run scripts/00-check-prerequisites.ps1 to confirm the size has quota in your region.
param computeInstanceVmSize = readEnvironmentVariable('AML_COMPUTE_VM_SIZE', 'Standard_E4ds_v4')
param computeInstanceIdleShutdownMinutes = 30
param computeInstanceScheduledStopCron = '0 19 * * *'
param computeInstanceScheduleTimeZone = 'UTC'

// --- Tags -----------------------------------------------------------------------------
param tags = {
  course: 'operationalize-ml-models'
  dataset: 'olist-brazilian-ecommerce'
}
