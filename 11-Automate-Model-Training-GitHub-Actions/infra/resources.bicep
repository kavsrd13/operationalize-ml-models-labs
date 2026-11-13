param workspaceName string
param location string
param vmSize string
param githubSubject string
var suffix = take(uniqueString(resourceGroup().id), 10)
var tags = { course: 'operationalize-ml-models'
    managedBy: 'bicep' }

module storage '../../00-Shared-Setup-and-Data/azure-ml-infra/infra/modules/storage-account.bicep' = {
  name: 'storage'
  params: { name: 'stcourse${suffix}'
    location: location
    tags: tags }
}
module vault '../../00-Shared-Setup-and-Data/azure-ml-infra/infra/modules/key-vault.bicep' = {
  name: 'vault'
  params: { name: 'kv-course-${suffix}'
    location: location
    tags: tags }
}
module monitoring '../../00-Shared-Setup-and-Data/azure-ml-infra/infra/modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: 'log-course-${suffix}'
    applicationInsightsName: 'appi-course-${suffix}'
    location: location
    tags: tags
  }
}
module workspace '../../00-Shared-Setup-and-Data/azure-ml-infra/infra/modules/ml-workspace.bicep' = {
  name: 'workspace'
  params: {
    name: workspaceName
    location: location
    tags: tags
    friendlyName: 'Course ML workspace'
    workspaceDescription: 'Reusable course workspace provisioned with Bicep.'
    storageAccountId: storage.outputs.id
    keyVaultId: vault.outputs.id
    applicationInsightsId: monitoring.outputs.applicationInsightsId
  }
}
resource aml 'Microsoft.MachineLearningServices/workspaces@2026-05-01' existing = {
  name: workspaceName
}
resource cluster 'Microsoft.MachineLearningServices/workspaces/computes@2026-05-01' = {
  parent: aml
  name: 'course-cpu'
  location: location
  dependsOn: [workspace]
  properties: {
    computeType: 'AmlCompute'
    properties: {
      vmSize: vmSize
      vmPriority: 'Dedicated'
      osType: 'Linux'
      remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 1
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
    }
  }
}
resource github 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-course-github'
  location: location
  tags: tags
}
resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: github
  name: 'github-main'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: githubSubject
    audiences: ['api://AzureADTokenExchange']
  }
}
resource trainingAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aml.id, github.id, 'AzureML-Data-Scientist')
  scope: aml
  dependsOn: [workspace]
  properties: {
    principalId: github.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f6c7c914-8db3-469d-8ca1-694a8f32e121')
  }
}
output clientId string = github.properties.clientId
output identityName string = github.name
output workspaceId string = aml.id
output workspaceName string = aml.name
output storageAccountName string = storage.outputs.name
output keyVaultName string = vault.outputs.name
output logAnalyticsName string = last(split(monitoring.outputs.logAnalyticsWorkspaceId, '/'))
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
output computeClusterName string = cluster.name
