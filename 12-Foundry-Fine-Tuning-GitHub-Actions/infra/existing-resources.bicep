param accountName string
param projectName string
param location string
param githubSubject string
param githubIdentityName string
param createBaselineDeployment bool
param createProject bool

var tags = {
  course: 'operationalize-ml-models'
  workload: 'medtriage-finetuning'
  managedBy: 'bicep'
}

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = if (createProject) {
  parent: account
  name: projectName
  // ARM removes this dependency when the baseline deployment is skipped.
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

resource existingProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' existing = if (!createProject) {
  parent: account
  name: projectName
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

resource githubFineTuningRoleForNewProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createProject) {
  name: guid(project.id, githubIdentity.id, 'FoundryUser')
  scope: project
  properties: {
    principalId: githubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')
  }
}

resource githubFineTuningRoleForExistingProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!createProject) {
  name: guid(existingProject.id, githubIdentity.id, 'FoundryUser')
  scope: existingProject
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
