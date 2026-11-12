targetScope = 'subscription'

@description('Resource group containing the existing Azure AI Services or Azure OpenAI resource.')
param resourceGroupName string

@description('Name of the existing Azure AI Services or Azure OpenAI resource.')
param accountName string

@description('Existing or newly created Microsoft Foundry project used by the SDK.')
param projectName string

@description('Region of the existing resource. The managed identity is created in the same region.')
param location string

@description('Exact GitHub OIDC subject permitted to submit training from main.')
param githubSubject string

@description('Unique managed identity name for this student GitHub repository.')
param githubIdentityName string

@description('Create medtriage-base only when it is not already present.')
param createBaselineDeployment bool = true

@description('Create the project only when the selected account has no suitable project.')
param createProject bool = false

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: resourceGroupName
}

module resources './existing-resources.bicep' = {
  name: 'existingFoundryFineTuningResources'
  scope: resourceGroup
  params: {
    accountName: accountName
    projectName: projectName
    location: location
    githubSubject: githubSubject
    githubIdentityName: githubIdentityName
    createBaselineDeployment: createBaselineDeployment
    createProject: createProject
  }
}

output accountEndpoint string = resources.outputs.accountEndpoint
output projectEndpoint string = resources.outputs.projectEndpoint
output githubClientId string = resources.outputs.githubClientId
output accountResourceId string = resources.outputs.accountResourceId
