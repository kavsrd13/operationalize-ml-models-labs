// =====================================================================================
// MODULE: ml-workspace.bicep
// -------------------------------------------------------------------------------------
// The AZURE MACHINE LEARNING WORKSPACE is the top-level resource for ML work. It keeps
// track of everything you do: data assets, experiments/jobs, models, environments,
// endpoints and compute. It does not store data itself - it links to:
//
//     Storage account        -> data, job outputs, notebooks          (required)
//     Key Vault              -> secrets                               (required)
//     Application Insights   -> monitoring of jobs and endpoints      (required)
//     Container Registry     -> Docker images for environments        (optional)
//
// IMPORTANT: storageAccount and keyVault CANNOT be changed after the workspace exists.
// =====================================================================================

@description('Workspace name: 3-33 characters, letters, numbers, hyphens and underscores.')
@minLength(3)
@maxLength(33)
param name string

@description('Azure region for the workspace.')
param location string

@description('Tags applied to the workspace.')
param tags object

@description('Display name shown in Azure ML studio.')
param friendlyName string

@description('Description shown in Azure ML studio.')
param workspaceDescription string

@description('Resource ID of the default storage account.')
param storageAccountId string

@description('Resource ID of the key vault.')
param keyVaultId string

@description('Resource ID of the Application Insights component.')
param applicationInsightsId string

@description('Resource ID of the container registry. Empty = Azure ML creates one when it first needs it.')
param containerRegistryId string = ''

resource workspace 'Microsoft.MachineLearningServices/workspaces@2026-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Default' // a classic ML workspace (not an AI Foundry hub/project)
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    // A managed identity lets the workspace reach storage / key vault / registry
    // WITHOUT any passwords. Azure assigns it the roles it needs automatically.
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: friendlyName
    description: workspaceDescription

    // --- Linked (dependent) resources -------------------------------------------------
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: applicationInsightsId
    containerRegistry: empty(containerRegistryId) ? null : containerRegistryId

    // --- Security / networking -------------------------------------------------------
    publicNetworkAccess: 'Enabled' // private endpoints + managed VNet come in a later module
    hbiWorkspace: false // "high business impact" adds extra encryption; creation-time only
    v1LegacyMode: false // use the v2 APIs only (CLI v2 / Python SDK v2)

    // How the built-in datastores (workspaceblobstore / workspacefilestore) authenticate
    // to storage: 'AccessKey' (account key kept in Key Vault) or 'Identity' (Entra ID).
    systemDatastoresAuthMode: 'AccessKey'
  }
}

output id string = workspace.id
output name string = workspace.name
output principalId string = workspace.identity.principalId
@description('Immutable GUID of the workspace; the default blob container is azureml-blobstore-<workspaceId>.')
output workspaceId string = workspace.properties.workspaceId
@description('MLflow tracking URI - used in later modules to log experiments.')
output mlflowTrackingUri string = workspace.properties.mlFlowTrackingUri
