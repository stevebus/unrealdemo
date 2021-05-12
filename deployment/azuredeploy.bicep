param projectName string
param userId string
param appRegId string
param utcValue string = utcNow()

var location = resourceGroup().location

var unique = substring(uniqueString(resourceGroup().id),0,2)
//var unique = ''

var iotHubName = '${projectName}hub${unique}'
var adtName = '${projectName}adt${unique}'
var signalrName = '${projectName}signalr${unique}'
var serverFarmName = '${projectName}farm${unique}'
var storageName = '${projectName}store${unique}'
var eventGridName = '${projectName}eg${unique}'
var funcAppName = '${projectName}funcapp${unique}'
var eventGridIngestName =  '${projectName}egingest${unique}'
var ingestFuncName = 'IoTHubIngest'
var signalrFuncName = 'broadcast'
var adtChangeLogTopicName='${projectName}adtchangelogtopic${unique}'
var funcPackageURI = 'https://github.com/stevebus/stuff/raw/main/unrealdemofuncs.zip'
var postDeployScriptURI = 'https://raw.githubusercontent.com/stevebus/stuff/main/post-deploy-script'

var identityName = '${projectName}-scriptidentity'
var rgRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var rgRoleDefinitionName = guid(identity.id, rgRoleDefinitionId, resourceGroup().id)
var ADTroleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'bcd981a7-7f74-457b-83e1-cceb9e632ffe')
var ADTroleDefinitionName = guid(identity.id, ADTroleDefinitionId, resourceGroup().id)
var ADTroleDefinitionAppName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', funcAppName), ADTroleDefinitionId, resourceGroup().id)
var ADTRoleDefinitionUserName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userId), ADTroleDefinitionId, resourceGroup().id)
var ADTRoleDefinitionAppRegName = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', appRegId), ADTroleDefinitionId, resourceGroup().id)

// create iot hub
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
    routing:{
      routes:[
        {
          name: 'default'
          source: 'DeviceMessages'
          condition: 'true'
          endpointNames: [
            'events'
          ]
          isEnabled: true
        }
      ]
    }
  }
  dependsOn:[
    ingestFunction //hackhack - make as much as possible 'dependon' the azure function app to deal w/ some timing issues
  ]
}

//create storage account (used by the azure function app)
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

// create ADT instance
resource adt 'Microsoft.DigitalTwins/digitalTwinsInstances@2020-03-01-preview' = {
  name: adtName
  location: location
  tags: {}
  properties: {}
  dependsOn: [
    identity
  ]
}

// create signalr instance
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

// create App Plan aka "server farm"
resource appserver 'Microsoft.Web/serverfarms@2019-08-01' = {
  name: serverFarmName
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'Dynamic'
    name: 'B1'
  }
}

// create Function app for hosting the IoTHub ingress and SignalR egress
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
          name: 'AzureSignalRConnectionString'
          value: 'Endpoint=https://${signalrName}.service.signalr.net;AccessKey=${listKeys(signalrName, providers('Microsoft.SignalRService', 'SignalR').apiVersions[0]).primaryKey};Version=1.0;'
        }
      ]
      alwaysOn:false
     cors:{
       supportCredentials: true
       allowedOrigins: [
         'http://localhost:3000'
         'https://functions.azure.com'
         'https://functions-staging.azure.com'
         'https://functions-next.azure.com'
       ]
     }
    }
    serverFarmId: appserver.id
    clientAffinityEnabled: false
     
  }
  dependsOn: [
    storage
    identity
    adt
    signalr
    appserver
  ]
}

// deploy the code for the two azure functionss (iot hub ingest and signalr)
//resource ingestFunction 'Microsoft.Web/sites/extensions@2015-08-01' = {
resource ingestFunction 'Microsoft.Web/sites/extensions@2020-12-01' = {
  name: '${funcApp.name}/MSDeploy'
  properties: {
  packageUri: '${funcPackageURI}'
  }
  dependsOn: [
    funcApp
  ]
}

// event grid topic that iot hub posts telemetry messages to
resource eventGridIngestTopic 'Microsoft.EventGrid/systemTopics@2020-04-01-preview' = {
  name: eventGridIngestName
  location: location
  properties: {
    source: iot.id
    topicType: 'microsoft.devices.iothubs'
  }
  dependsOn: [
    iot
    ingestFunction
  ]
}

// event grid subscription for iot hub telemetry data (posts to iot hub ingestion function)
resource eventGrid_IoTHubIngest 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2020-04-01-preview' = {
  name: '${eventGridIngestTopic.name}/${ingestFuncName}'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${funcApp.id}/functions/${ingestFuncName}'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.Devices.DeviceTelemetry'
      ]
    }
  }
  dependsOn: [
    eventGridIngestTopic
    iot
    ingestFunction
  ]
}

// Event Grid topic for ADT twin change notifications
resource eventGridADTChangeLogTopic 'Microsoft.EventGrid/topics@2020-10-15-preview' = {
  name: adtChangeLogTopicName
  location: location
  sku: {
    name: 'Basic'
  }
  kind: 'Azure'
  identity: {
    type: 'None'
  }
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Enabled'
  }
  dependsOn:[
    ingestFunction
    iot  //hackhack - make this run as late as possible because of a tricky timing issue w/ the /broadcast function
    eventGrid_IoTHubIngest
    rgroledef
    adtroledef
    adtroledefapp
    ADTRoleDefinitionUser
    ADTRoleDefinitionAppReg
  ]
}

// EventGrid subscription for ADT twin changes (invokes function to post to signalr)
resource eventGrid_Signalr 'Microsoft.EventGrid/eventSubscriptions@2020-06-01' = {
  name: '${signalrFuncName}'
  scope: eventGridADTChangeLogTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${funcApp.id}/functions/${signalrFuncName}'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
  }
   dependsOn:[
     eventGridADTChangeLogTopic
   ]
}

// create user assigned managed identity for this script to run under
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}


// add RBAC "owner" role to resource group - for the script
resource rgroledef 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: rgRoleDefinitionName
  properties: {
    roleDefinitionId: rgRoleDefinitionId
    principalId: reference(identityName).principalId
    principalType: 'ServicePrincipal'
  }
}

// add "Digital Twins Data Owner" role to ADT instance for our deployment - for the script
resource adtroledef 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(identityName).principalId
    principalType: 'ServicePrincipal'
  }
}

// add "Digital Twins Data Owner" permissions to teh system identity of the Azure Functions
resource adtroledefapp 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionAppName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(funcApp.id, '2019-08-01', 'Full').identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [ 
    funcApp
  ]
}

// assign ADT data role owner permissions to the user
resource ADTRoleDefinitionUser 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTRoleDefinitionUserName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: userId
    principalType: 'User'
  }
}

// assign ADT data role owner permissions to the app registration
resource ADTRoleDefinitionAppReg 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTRoleDefinitionAppRegName
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: appRegId
    principalType: 'ServicePrincipal'
  }
}

// execute post deployment script
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
    arguments: '${adt.name} ${resourceGroup().name} ${adtChangeLogTopicName}'
    primaryScriptUri: '${postDeployScriptURI}'
    supportingScriptUris: []
    timeout: 'PT30M'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    rgroledef
    iot
    adt
    eventGridADTChangeLogTopic
  ]
}

//output scriptoutput object = reference('PostDeploymentscript').outputs
//output signalRconnstr string = 'Endpoint=https://${signalrName}.service.signalr.net;AccessKey=${listKeys(signalrName, providers('Microsoft.SignalRService', 'SignalR').apiVersions[0]).primaryKey};Version=1.0;'
//output iotHubName string = iotHubName
//output signalRnegotiate string = 'https://${funcApp.name}.azurewebsites.net/functions/negotiate'
//output adtHostName string = adt.properties.hostName

output importantInfo object = {
  iotHubName: iotHubName
  signalRNegotiatePath: 'https://${funcApp.name}.azurewebsites.net/api/negotiate'
  adtHostName: '${adt.properties.hostName}'
}

