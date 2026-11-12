targetScope = 'subscription'

@description('Resource group for this independent fine-tuning exercise.')
param resourceGroupName string

@description('Globally unique Azure AI Services account name. Use lowercase letters and digits only.')
@minLength(2)
@maxLength(64)
param accountName string

@description('Microsoft Foundry project used by the Azure AI Projects SDK.')
param projectName string = 'medtriage-project'

@description('Azure region for the Foundry resource and fine-tuning workload.')
param location string = 'eastus'

@description('Exact GitHub OIDC subject permitted to submit training from main.')
param githubSubject string

@description('Unique managed identity name for this student GitHub repository.')
param githubIdentityName string

@description('Create the baseline deployment. New resources always pass true; this parameter keeps setup inputs consistent.')
param createBaselineDeployment bool = true

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    course: 'operationalize-ml-models'
    workload: 'medtriage-finetuning'
    managedBy: 'bicep'
  }
}

module resources './resources.bicep' = {
  name: 'foundryFineTuningResources'
  scope: resourceGroup
  params: {
    accountName: accountName
    projectName: projectName
    location: location
    githubSubject: githubSubject
    githubIdentityName: githubIdentityName
    createBaselineDeployment: createBaselineDeployment
  }
}

output accountEndpoint string = resources.outputs.accountEndpoint
output projectEndpoint string = resources.outputs.projectEndpoint
output githubClientId string = resources.outputs.githubClientId
output accountResourceId string = resources.outputs.accountResourceId
