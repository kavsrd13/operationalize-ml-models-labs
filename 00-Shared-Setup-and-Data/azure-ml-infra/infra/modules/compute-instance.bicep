// =====================================================================================
// MODULE: compute-instance.bicep
// -------------------------------------------------------------------------------------
// A COMPUTE INSTANCE is a managed, cloud-based workstation for ONE data scientist.
// It comes with Jupyter, JupyterLab, VS Code (remote) and the Azure ML SDK pre-installed.
//
// Key facts students should remember:
//   * It is billed per hour WHILE RUNNING (disk + IP are billed even when stopped).
//   * "Idle shutdown" and a "scheduled stop" protect you from surprise bills.
//   * It is PERSONAL: only the assigned user can open Jupyter / terminals on it.
//   * The name must be unique in the whole Azure REGION (not just your workspace).
//   * VM size, SSH and idle-shutdown settings can only be set at CREATION time.
//     Re-deploying an existing compute instance is NOT safe, which is why the deploy
//     script skips this module when the instance already exists.
// =====================================================================================

@description('Name of the existing Azure ML workspace that will own the compute instance.')
param workspaceName string

@description('Compute instance name: 3-24 chars, starts with a letter, unique in the region.')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region - must be the same region as the workspace.')
param location string

@description('Tags applied to the compute instance.')
param tags object

@description('VM size. Check what your subscription can use with scripts/00-check-prerequisites.ps1.')
param vmSize string

@description('Entra ID object ID of the user who will own (and be the only user of) the compute instance.')
param assignedUserObjectId string

@description('Entra ID tenant ID of the assigned user.')
param assignedUserTenantId string

@description('Shut the VM down after this many idle minutes (15 minutes to 3 days).')
@minValue(15)
@maxValue(4320)
param idleShutdownMinutes int = 30

@description('Also stop the VM every day at a fixed time (safety net for forgotten instances).')
param enableScheduledStop bool = true

@description('NCronTab expression for the daily stop: minute hour day month weekday.')
param scheduledStopCron string = '0 19 * * *'

@description('Windows time-zone name used by the schedule, e.g. "UTC" or "India Standard Time".')
param scheduleTimeZone string = 'UTC'

@description('When the schedule becomes active. Azure requires a start time whenever a time zone is given. utcNow() may only be used as a parameter default.')
param scheduleStartTime string = utcNow('yyyy-MM-ddTHH:mm:ss')

// Reference the workspace created by ml-workspace.bicep. "existing" means: do not
// create it, just look it up so we can use it as the parent of the compute instance.
resource workspace 'Microsoft.MachineLearningServices/workspaces@2026-05-01' existing = {
  name: workspaceName
}

resource computeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2026-05-01' = {
  parent: workspace
  name: name
  location: location
  tags: tags
  properties: {
    computeType: 'ComputeInstance'
    description: 'Personal development workstation for the Olist ML course.'
    properties: {
      vmSize: vmSize

      // Personal compute instance: assigned to exactly one user.
      applicationSharingPolicy: 'Personal'
      computeInstanceAuthorizationType: 'personal'
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: assignedUserObjectId
          tenantId: assignedUserTenantId
        }
      }

      // --- Cost controls -------------------------------------------------------------
      // ISO-8601 duration, e.g. PT30M = 30 minutes.
      idleTimeBeforeShutdown: 'PT${idleShutdownMinutes}M'
      schedules: enableScheduledStop
        ? {
            computeStartStop: [
              {
                action: 'Stop'
                triggerType: 'Cron'
                status: 'Enabled'
                cron: {
                  expression: scheduledStopCron
                  startTime: scheduleStartTime
                  timeZone: scheduleTimeZone
                }
              }
            ]
          }
        : null

      // --- Access -----------------------------------------------------------------
      // We use Jupyter / VS Code through Azure ML studio, so SSH stays disabled.
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      enableNodePublicIp: true // needed when the workspace is not in a virtual network
    }
  }
}

output name string = computeInstance.name
output id string = computeInstance.id
