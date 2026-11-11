// =====================================================================================
// MODULE: monitoring.bicep
// -------------------------------------------------------------------------------------
// Creates the observability layer used by the Azure Machine Learning workspace:
//   1. Log Analytics workspace  - the central store for logs and metrics.
//   2. Application Insights     - "workspace-based" telemetry for jobs and endpoints.
//
// Application Insights must point at a Log Analytics workspace ("workspace-based").
// Classic (stand-alone) Application Insights has been retired by Microsoft.
// =====================================================================================

@description('Name of the Log Analytics workspace.')
param logAnalyticsName string

@description('Name of the Application Insights component.')
param applicationInsightsName string

@description('Azure region for the resources.')
param location string

@description('Tags applied to every resource.')
param tags object

@description('How many days logs are kept. 30 days is included in the free tier of retention.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018' // pay-as-you-go pricing tier
    }
    retentionInDays: retentionInDays
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id // <- this is what makes it "workspace-based"
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output applicationInsightsId string = applicationInsights.id
output applicationInsightsName string = applicationInsights.name
