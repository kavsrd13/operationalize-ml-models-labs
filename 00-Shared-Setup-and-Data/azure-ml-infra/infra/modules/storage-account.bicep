// =====================================================================================
// MODULE: storage-account.bicep
// -------------------------------------------------------------------------------------
// The workspace's DEFAULT storage account. Azure ML uses it for:
//   * workspaceblobstore  (blob container) - datasets, job outputs, model files
//   * workspacefilestore  (file share)     - notebooks and code you create in studio
//
// Microsoft requirements for the default storage account:
//   * kind = StorageV2 (general-purpose v2), Standard SKU (Premium is not supported)
//   * Hierarchical namespace (Data Lake Gen2) must be DISABLED for the default account
//   * Shared-key access must stay ENABLED when you use compute instances and the default
//     ("AccessKey") datastore authentication mode used in this course
// =====================================================================================

@description('Globally unique name: 3-24 characters, lowercase letters and numbers only.')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region for the storage account.')
param location string

@description('Tags applied to the storage account.')
param tags object

@description('Replication: LRS = 3 copies in one datacenter (cheapest, fine for teaching).')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param skuName string = 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: 'Hot'
    isHnsEnabled: false // Azure ML default storage cannot be a Data Lake Gen2 account
    allowSharedKeyAccess: true // required by compute instances + AccessKey datastores
    allowBlobPublicAccess: false // no anonymous (public) access to any container
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled' // a private-network setup is a later, advanced module
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      keySource: 'Microsoft.Storage' // Microsoft-managed encryption keys
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
