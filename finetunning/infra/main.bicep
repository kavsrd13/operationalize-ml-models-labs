targetScope = 'subscription'

@description('Resource group for this independent fine-tuning exercise.')
param resourceGroupName string

@description('Globally unique Azure AI Services account name. Use lowercase letters and digits only.')
@minLength(2)
@maxLength(64)
param accountName string

@description('Azure region for the Foundry resource and fine-tuning workload.')
param location string = 'eastus'

@description('Exact GitHub OIDC subject permitted to submit training from main.')
param githubSubject string

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
    location: location
    githubSubject: githubSubject
  }
}

output accountEndpoint string = resources.outputs.accountEndpoint
output githubClientId string = resources.outputs.githubClientId
output accountResourceId string = resources.outputs.accountResourceId
