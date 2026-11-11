// =====================================================================================
// MODULE: role-assignments.bicep
// -------------------------------------------------------------------------------------
// Grants a person (the data scientist / student) the least-privilege roles they need to
// WORK in the environment - without making them Owner or Contributor of everything.
//
//   Scope              Role                                   Why
//   -----------------  -------------------------------------  -----------------------------------
//   ML workspace       AzureML Data Scientist                 run jobs, register data/models,
//                                                             start/stop their compute instance
//   Storage account    Storage Blob Data Contributor          read/write data with their own
//                                                             Entra identity (no account keys)
//   Storage account    Storage File Data Privileged           open notebooks stored on the
//                      Contributor                            workspace file share in studio
//
// Role definition IDs are the same in every Azure tenant. They come from:
// https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
//
// The role assignment NAME must be a GUID. guid(scope, principal, role) produces the
// same GUID every time, so re-deploying the template does not create duplicates.
// =====================================================================================

@description('Object ID of the user, group or service principal receiving the roles.')
param principalId string

@description('Type of the principal. Setting it avoids replication-delay errors right after creation.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'User'

@description('Name of the existing Azure ML workspace.')
param workspaceName string

@description('Name of the existing workspace storage account.')
param storageAccountName string

var roleIds = {
  azureMLDataScientist: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  storageFileDataPrivilegedContributor: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2026-05-01' existing = {
  name: workspaceName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

resource workspaceDataScientist 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspace.id, principalId, roleIds.azureMLDataScientist)
  scope: workspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.azureMLDataScientist)
    principalId: principalId
    principalType: principalType
    description: 'Lets the data scientist use the Azure ML workspace.'
  }
}

resource storageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, roleIds.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageBlobDataContributor)
    principalId: principalId
    principalType: principalType
    description: 'Lets the data scientist read/write blobs (datasets) with Entra ID.'
  }
}

resource storageFileDataPrivilegedContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, roleIds.storageFileDataPrivilegedContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.storageFileDataPrivilegedContributor)
    principalId: principalId
    principalType: principalType
    description: 'Lets the data scientist open notebooks stored on the workspace file share.'
  }
}
