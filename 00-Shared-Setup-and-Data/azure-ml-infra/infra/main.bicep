// =====================================================================================
//  main.bicep  -  Azure Machine Learning environment for the Olist ML course
// -------------------------------------------------------------------------------------
//  This is the ENTRY POINT. It is deployed at SUBSCRIPTION scope so that it can create
//  the resource group itself, and then deploys every resource INTO that group by
//  calling small, single-purpose MODULES (see ./modules).
//
//      Subscription
//      └── Resource group  rg-<project>-ml-<env>
//          ├── Log Analytics workspace + Application Insights   (monitoring.bicep)
//          ├── Storage account                                  (storage-account.bicep)
//          ├── Key Vault                                        (key-vault.bicep)
//          ├── Container Registry (optional)                    (container-registry.bicep)
//          ├── Azure ML workspace                               (ml-workspace.bicep)
//          │   └── Compute instance (optional)                  (compute-instance.bicep)
//          └── Role assignments for the data scientist          (role-assignments.bicep)
//
//  The DATASET is uploaded afterwards by scripts/03-upload-data.ps1, because ARM/Bicep
//  runs inside Azure and cannot read files from your laptop.
//
//  Deploy:   az deployment sub create --location <region> --parameters infra/main.bicepparam
// =====================================================================================

targetScope = 'subscription'

// -------------------------------------------------------------------------------------
// PARAMETERS - the values that change between deployments.
// Defaults live in main.bicepparam; decorators (@...) validate input BEFORE deployment.
// -------------------------------------------------------------------------------------

@description('Short project name used in every resource name. Lowercase letters and numbers only.')
@minLength(3)
@maxLength(10)
param projectName string

@description('Environment name - lets you deploy dev / test / prod copies side by side.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Azure region for every resource, e.g. eastus, westeurope, centralindia.')
param location string

@description('Entra ID object ID of the data scientist who gets access and owns the compute instance. Empty = the identity running the deployment.')
param dataScientistObjectId string = ''

@description('Type of the dataScientistObjectId principal.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param dataScientistPrincipalType string = 'User'

@description('Create an Azure Container Registry and link it to the workspace.')
param createContainerRegistry bool = true

@description('Create the compute instance. Set to false when it already exists (it cannot be safely re-deployed).')
param deployComputeInstance bool = true

@description('VM size of the compute instance. Must be offered in the region AND have quota in your subscription.')
param computeInstanceVmSize string = 'Standard_E4ds_v4'

@description('Minutes of inactivity before the compute instance shuts itself down.')
@minValue(15)
@maxValue(4320)
param computeInstanceIdleShutdownMinutes int = 30

@description('Daily forced stop of the compute instance (NCronTab). Default 19:00.')
param computeInstanceScheduledStopCron string = '0 19 * * *'

@description('Windows time-zone name for the scheduled stop, e.g. "UTC" or "India Standard Time".')
param computeInstanceScheduleTimeZone string = 'UTC'

@description('Extra tags merged into the standard tags.')
param tags object = {}

// -------------------------------------------------------------------------------------
// VARIABLES - names are DERIVED from parameters so they are consistent and predictable.
// Naming follows the Microsoft Cloud Adoption Framework abbreviations (rg, st, kv, ...).
// -------------------------------------------------------------------------------------

var resourceGroupName = 'rg-${projectName}-ml-${environmentName}'

// uniqueString() returns a deterministic 13-character hash: the SAME inputs always give
// the SAME result, so re-deploying updates resources instead of creating new ones.
// Globally unique resources (storage, key vault, registry) need it to avoid name clashes.
var suffix = take(uniqueString(subscription().id, resourceGroupName, location), 6)

var names = {
  logAnalytics: 'log-${projectName}-${environmentName}'
  applicationInsights: 'appi-${projectName}-${environmentName}'
  storageAccount: take('st${projectName}${environmentName}${suffix}', 24)
  keyVault: take('kv-${projectName}-${environmentName}-${suffix}', 24)
  containerRegistry: 'cr${projectName}${environmentName}${suffix}'
  workspace: 'mlw-${projectName}-${environmentName}'
  // Compute instance names must be unique within the Azure REGION and cannot end in
  // "-<digits>", so the suffix is attached without a hyphen.
  computeInstance: take('ci-${projectName}-${environmentName}${suffix}', 24)
}

var allTags = union(
  {
    project: projectName
    environment: environmentName
    workload: 'machine-learning'
    managedBy: 'bicep'
  },
  tags
)

// deployer() returns the identity that is running THIS deployment (you, after az login).
var dataScientistId = empty(dataScientistObjectId) ? deployer().objectId : dataScientistObjectId

// -------------------------------------------------------------------------------------
// RESOURCES
// -------------------------------------------------------------------------------------

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: allTags
}

module monitoring 'modules/monitoring.bicep' = {
  scope: resourceGroup
  params: {
    logAnalyticsName: names.logAnalytics
    applicationInsightsName: names.applicationInsights
    location: location
    tags: allTags
  }
}

module storage 'modules/storage-account.bicep' = {
  scope: resourceGroup
  params: {
    name: names.storageAccount
    location: location
    tags: allTags
  }
}

module keyVault 'modules/key-vault.bicep' = {
  scope: resourceGroup
  params: {
    name: names.keyVault
    location: location
    tags: allTags
  }
}

// "if (...)" makes the module CONDITIONAL - it is only deployed when the flag is true.
module containerRegistry 'modules/container-registry.bicep' = if (createContainerRegistry) {
  scope: resourceGroup
  params: {
    name: names.containerRegistry
    location: location
    tags: allTags
  }
}

// Passing another module's OUTPUT as an input creates an implicit dependency:
// Bicep waits for storage, key vault, monitoring (and ACR) before creating the workspace.
module workspace 'modules/ml-workspace.bicep' = {
  scope: resourceGroup
  params: {
    name: names.workspace
    location: location
    tags: allTags
    friendlyName: 'Olist ML (${environmentName})'
    workspaceDescription: 'Azure ML workspace for the Olist e-commerce ML course - deployed with Bicep.'
    storageAccountId: storage.outputs.id
    keyVaultId: keyVault.outputs.id
    applicationInsightsId: monitoring.outputs.applicationInsightsId
    containerRegistryId: createContainerRegistry ? containerRegistry!.outputs.id : ''
  }
}

module dataScientistAccess 'modules/role-assignments.bicep' = {
  scope: resourceGroup
  params: {
    principalId: dataScientistId
    principalType: dataScientistPrincipalType
    workspaceName: workspace.outputs.name
    storageAccountName: storage.outputs.name
  }
}

module computeInstance 'modules/compute-instance.bicep' = if (deployComputeInstance) {
  scope: resourceGroup
  params: {
    workspaceName: workspace.outputs.name
    name: names.computeInstance
    location: location
    tags: allTags
    vmSize: computeInstanceVmSize
    assignedUserObjectId: dataScientistId
    assignedUserTenantId: tenant().tenantId
    idleShutdownMinutes: computeInstanceIdleShutdownMinutes
    scheduledStopCron: computeInstanceScheduledStopCron
    scheduleTimeZone: computeInstanceScheduleTimeZone
  }
}

// -------------------------------------------------------------------------------------
// OUTPUTS - read by the scripts (and by you) after deployment. Never output secrets.
// -------------------------------------------------------------------------------------

output resourceGroupName string = resourceGroup.name
output location string = location
output workspaceName string = workspace.outputs.name
output workspaceId string = workspace.outputs.workspaceId
output mlflowTrackingUri string = workspace.outputs.mlflowTrackingUri
output storageAccountName string = storage.outputs.name
output keyVaultName string = keyVault.outputs.name
output containerRegistryName string = createContainerRegistry ? containerRegistry!.outputs.name : ''
output logAnalyticsName string = names.logAnalytics
output computeInstanceName string = names.computeInstance
output computeInstanceDeployed bool = deployComputeInstance
output dataScientistObjectId string = dataScientistId
output studioUrl string = 'https://ml.azure.com/?wsid=${workspace.outputs.id}&tid=${tenant().tenantId}'
