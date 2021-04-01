param projectName string = 'contoso'
param userId string
param utcValue string = utcNow()

var location = resourceGroup().location

var unique = substring(uniqueString(resourceGroup().id),3)

var iotHubName = '${projectName}Hub${unique}'
var adtName = '${projectName}adt${unique}'
var signalrName = '${projectName}signalr${unique}'
var serverFarmName = '${projectName}farm${unique}'
var storageName = '${projectName}store${unique}'
var eventGridName = '${projectName}eg${unique}'
var funcAppName = '${projectName}funcapp${unique}'

var identityName = '${projectName}scriptidentity'
var rgRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var rgRoleDefinitionName = guid(identity.id, rgRoleDefinitionId, resourceGroup().id)
var ADTroleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'bcd981a7-7f74-457b-83e1-cceb9e632ffe')
var ADTroleDefinitionName = guid(identity.id, ADTroleDefinitionId, resourceGroup().id)
var ADTroleDefinitionAppName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', funcAppName), ADTroleDefinitionId, resourceGroup().id)


resource iot 'microsoft.devices/iotHubs@2020-03-01' = {
  name: iotHubName
  location: location
  sku: {
    name: 'S1'
    capacity: 1
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: 4
      }
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2018-02-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: false
  }
}

resource adt 'Microsoft.DigitalTwins/digitalTwinsInstances@2020-03-01-preview' = {
  name: adtName
  location: location
  tags: {}
//  sku: {
//    name: 'S1'
//  }
  properties: {}
  dependsOn: [
    identity
  ]
}

resource signalr 'Microsoft.SignalRService/signalR@2020-07-01-preview' = {
  name: signalrName
  location: location
  sku: {
    name: 'Standard_S1'
    capacity: 1
    tier:  'Standard'
  }
  properties: {
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    features: [
      {
        flag: 'ServiceMode'
        value: 'Serverless'
      }
    ]
  }
}

resource funcApp 'Microsoft.Web/sites@2019-08-01' = {
  name: funcAppName
  kind: 'functionapp'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageName};AccountKey=${listKeys(storageName, '2019-06-01').keys[0].value}'
        }
        {
          name: 'ADT_SERVICE_URL'
          value: 'https://${adt.properties.hostName}'
        }
        {
          name: 'SIGNALR_CONNECTION_STRING'
//          value: 'Endpoint=https://${signalrName}.service.signalr.net;AccessKey=${listKeys(signalrName, providers('Microsoft.SignalRService', 'SignalR').apiVersions[0]).keys[0].value};Version=1.0;'
          value: 'Endpoint=https://${signalrName}.service.signalr.net;AccessKey=${listKeys(signalrName, providers('Microsoft.SignalRService', 'SignalR').apiVersions[0]).primaryKey};Version=1.0;'
        }
        // {
        //   name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
        //   value: true
        // }
      ]
    }
    serverFarmId: appserver.id
    clientAffinityEnabled: false
  }
  dependsOn: [
    storage
    identity
  ]
}
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

// add RBAC role to resource group
resource rgroledef 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: rgRoleDefinitionName
  properties: {
    roleDefinitionId: rgRoleDefinitionId
    principalId: reference(identityName).principalId
//    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}

// add "Digital Twins Data Owner" role to ADT instance
resource adtroledef 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(identityName).principalId
//    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}

resource adtroledefapp 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionAppName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(funcApp.id, '2019-08-01', 'Full').identity.principalId
//    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
  dependsOn: [ 
    funcApp
  ]
}

resource appserver 'Microsoft.Web/serverfarms@2019-08-01' = {
  name: serverFarmName
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'Dynamic'
    name: 'B1'
  }
}

resource PostDeploymentscript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'PostDeploymentscript'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
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
    rgroledef
    iot
  ]
}

output result object = reference('PostDeploymentscript').outputs
