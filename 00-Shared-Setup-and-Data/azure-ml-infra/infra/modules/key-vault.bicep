// =====================================================================================
// MODULE: key-vault.bicep
// -------------------------------------------------------------------------------------
// Azure ML stores secrets here - for example datastore credentials and connection
// strings - so they never appear in code, notebooks or job definitions.
//
// Design choices for a TEACHING environment:
//   * Azure RBAC authorization (Microsoft's recommended permission model) instead of the
//     legacy "access policies". The workspace's managed identity is granted access by
//     Azure ML automatically when the workspace is created.
//   * Soft delete is ALWAYS on in Azure (it cannot be disabled). A deleted vault keeps its
//     name reserved for the retention period, so we use the minimum: 7 days.
//   * Purge protection is left OFF. Turning it on is irreversible and would stop the
//     cleanup script from purging the vault - in production you WOULD turn it on.
// =====================================================================================

@description('Globally unique name: 3-24 characters, letters, numbers and hyphens.')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region for the key vault.')
param location string

@description('Tags applied to the key vault.')
param tags object

@description('Days a deleted vault can be recovered (7-90). Can only be set at creation.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

resource keyVault 'Microsoft.KeyVault/vaults@2026-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output id string = keyVault.id
output name string = keyVault.name
