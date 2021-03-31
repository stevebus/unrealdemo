param projectName string = 'contoso'
param utcValue string = utcNow()


param location string = resourceGroup().location
param skuName string = 'S1'
param skuUnits int = 1
param d2cPartitions int = 4 // partitions used for the event stream

var unique = uniqueString(resourceGroup().id)

var iotHubName = '${projectName}Hub${unique}'

var identityName_var = '${projectName}scriptidentity'
var roleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var roleDefinitionName_var = guid(identityName.id, roleDefinitionId, resourceGroup().id)



resource iot 'microsoft.devices/iotHubs@2020-03-01' = {
  name: iotHubName
  location: location
  sku: {
    name: skuName
    capacity: skuUnits
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: d2cPartitions
      }
    }
  }
}

resource identityName 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName_var
  location: resourceGroup().location
}

resource roleDefinitionName 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: roleDefinitionName_var
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: reference(identityName_var).principalId
    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}

resource PostDeploymentscript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'PostDeploymentscript'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityName.id}': {}
    }
  }
    properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.15.0'
    arguments: '${iot.name}'

    environmentVariables: [
      {
        name: 'someSecret'
        secureValue: 'if this is really a secret, don\'t put it here... in plain text...'
      }
    ]
    primaryScriptUri: 'https://raw.githubusercontent.com/stevebus/stuff/main/armtestscript'
    supportingScriptUris: []
    timeout: 'PT30M'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    roleDefinitionName
    iot
  ]
}

output result object = reference('PostDeploymentscript').outputs
