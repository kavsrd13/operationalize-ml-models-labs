param accountName string
param location string
param githubSubject string
param createBaselineDeployment bool = true

var tags = {
  course: 'operationalize-ml-models'
  workload: 'medtriage-finetuning'
  managedBy: 'bicep'
}

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

resource baselineDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = if (createBaselineDeployment) {
  parent: account
  name: 'medtriage-base'
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
  }
}

resource githubIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-medtriage-finetuning-github'
  location: location
  tags: tags
}

resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: githubIdentity
  name: 'github-main'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: githubSubject
  }
}

resource githubFineTuningRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(account.id, githubIdentity.id, 'CognitiveServicesOpenAIContributor')
  scope: account
  properties: {
    principalId: githubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
  }
}

output accountEndpoint string = account.properties.endpoint
output accountResourceId string = account.id
output githubClientId string = githubIdentity.properties.clientId
