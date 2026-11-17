targetScope = 'resourceGroup'

@description('Globally unique Foundry account and subdomain name.')
@minLength(2)
@maxLength(64)
param accountName string

param location string = resourceGroup().location
param projectName string = 'azure-pricing'
param modelDeploymentName string = 'gpt-5'

@description('Check current GPT-5 availability before deploying this pinned version.')
param modelVersion string = '2025-08-07'

@description('Capacity allocation units, not a guaranteed token rate. Requires regional model quota.')
@minValue(1)
param modelCapacity int = 50

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: account
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Azure pricing agent'
    description: 'Public retail pricing and explicit partial scenario estimates.'
  }
}

resource model 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: account
  name: modelDeploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5'
      version: modelVersion
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

output projectEndpoint string = 'https://${accountName}.services.ai.azure.com/api/projects/${projectName}'
output projectArmId string = project.id
output accountArmId string = account.id
output modelDeployment string = model.name
