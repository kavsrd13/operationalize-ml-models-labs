param accountName string
param projectName string
param location string
param githubSubject string
param githubIdentityName string
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
    allowProjectManagement: true
    customSubDomainName: accountName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: account
  name: projectName
  // Both child writes update the same account; wait for the baseline deployment.
  dependsOn: [baselineDeployment]
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: projectName
    description: 'Microsoft Foundry project for the MedTriage fine-tuning exercise'
  }
}

resource baselineDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = if (createBaselineDeployment) {
  parent: account
  name: 'medtriage-base'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    raiPolicyName: 'Microsoft.DefaultV2'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
  }
}

resource githubIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: githubIdentityName
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
  name: guid(project.id, githubIdentity.id, 'FoundryUser')
  scope: project
  properties: {
    principalId: githubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')
  }
}

output accountEndpoint string = account.properties.endpoint
output projectEndpoint string = 'https://${accountName}.services.ai.azure.com/api/projects/${projectName}'
output accountResourceId string = account.id
output githubClientId string = githubIdentity.properties.clientId
