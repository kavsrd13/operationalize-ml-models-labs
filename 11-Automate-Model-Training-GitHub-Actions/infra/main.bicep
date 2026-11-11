targetScope = 'subscription'

param resourceGroupName string
param workspaceName string
param location string
param vmSize string = 'Standard_E4ds_v4'
param githubSubject string

resource group 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: { course: 'operationalize-ml-models'
    managedBy: 'bicep' }
}

module resources './resources.bicep' = {
  scope: group
  params: {
    workspaceName: workspaceName
    location: location
    vmSize: vmSize
    githubSubject: githubSubject
  }
}
output clientId string = resources.outputs.clientId
output workspaceId string = resources.outputs.workspaceId
output identityName string = resources.outputs.identityName
