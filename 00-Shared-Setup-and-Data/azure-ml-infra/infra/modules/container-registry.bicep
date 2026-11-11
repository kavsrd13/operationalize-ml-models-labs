// =====================================================================================
// MODULE: container-registry.bicep
// -------------------------------------------------------------------------------------
// Azure Container Registry (ACR) stores the Docker images that Azure ML builds for
// custom environments and for model deployments (managed online endpoints).
//
// ACR is OPTIONAL for an Azure ML workspace - if you do not attach one, Azure ML creates
// one automatically the first time it needs to build an image. We create it here so the
// whole environment is described in code (nothing is created "behind our back") and so
// it is deleted together with the resource group.
// =====================================================================================

@description('Globally unique registry name: 5-50 characters, letters and numbers only.')
@minLength(5)
@maxLength(50)
param name string

@description('Azure region for the registry.')
param location string

@description('Tags applied to the registry.')
param tags object

@description('Basic is the cheapest tier and is enough for teaching.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Basic'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    // The admin user is a shared username/password - a security anti-pattern.
    // Azure ML authenticates to ACR with the workspace's managed identity instead.
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
