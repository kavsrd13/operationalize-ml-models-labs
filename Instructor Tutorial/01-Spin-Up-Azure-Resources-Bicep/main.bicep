targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Lowercase letters and numbers only. Used as naming prefix.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'diabdemo01'

var suffix = toLower(uniqueString(resourceGroup().id, namePrefix))
var storageAccountName = take('${namePrefix}${suffix}', 24)
var keyVaultName = take('${namePrefix}-${take(suffix, 10)}-kv', 24)
var appInsightsName = '${namePrefix}-appi-${take(suffix, 6)}'
var acrName = take('${namePrefix}${suffix}acr', 50)
var workspaceName = take('${namePrefix}mlw${suffix}', 32)

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: workspaceName
    keyVault: keyVault.id
    applicationInsights: appInsights.id
    storageAccount: storage.id
    containerRegistry: acr.id
    publicNetworkAccess: 'Enabled'
  }
}

output workspaceName string = workspace.name
output workspaceId string = workspace.id
output storageAccountName string = storage.name
output keyVaultName string = keyVault.name
output containerRegistryName string = acr.name
output applicationInsightsName string = appInsights.name
