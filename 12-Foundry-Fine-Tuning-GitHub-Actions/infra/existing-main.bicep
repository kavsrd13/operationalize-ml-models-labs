targetScope = 'subscription'

@description('Resource group containing the existing Azure AI Services or Azure OpenAI resource.')
param resourceGroupName string

@description('Name of the existing Azure AI Services or Azure OpenAI resource.')
param accountName string

@description('Region of the existing resource. The managed identity is created in the same region.')
param location string

@description('Exact GitHub OIDC subject permitted to submit training from main.')
param githubSubject string

@description('Unique managed identity name for this student GitHub repository.')
param githubIdentityName string

@description('Create medtriage-base only when it is not already present.')
param createBaselineDeployment bool = true

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: resourceGroupName
}

module resources './existing-resources.bicep' = {
  name: 'existingFoundryFineTuningResources'
  scope: resourceGroup
  params: {
    accountName: accountName
    location: location
    githubSubject: githubSubject
    githubIdentityName: githubIdentityName
    createBaselineDeployment: createBaselineDeployment
  }
}

output accountEndpoint string = resources.outputs.accountEndpoint
output githubClientId string = resources.outputs.githubClientId
output accountResourceId string = resources.outputs.accountResourceId
