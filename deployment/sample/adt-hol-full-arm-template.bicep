@description('Location for all resources.')
param location string = resourceGroup().location
param utcValue string = utcNow()

@description('User ID deploying the environment: az ad user show --id jdoe@contoso.com --query objectId -o tsv ')
param userid string = 'paste the output of: az ad user show --id jdoe@contoso.com --query objectId -o tsv'

var prefix = 'a${substring(uniqueString(resourceGroup().id), 0, 6)}'
var iotHub = {
  name: '${prefix}iothub'
  id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Devices/IotHubs/${prefix}iothub'
}
var eventHub = {
  name: '${prefix}eventhub'
  namespaces: '${prefix}eventhubnamespaces'
  namespacesExternalId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.EventHub/namespaces/${prefix}eventhubnamespaces'
}
var digitaltwins = {
  name: '${prefix}digtwins'
}
var storage = {
  name: '${prefix}storage'
}
var tsi = {
  name: '${prefix}tsi'
  sourceName: '${prefix}tsies'
}
var eventGrid = {
  name: '${prefix}EventGrid'
}
var serverfarm = {
  name: '${prefix}sf'
}
var functionapp = {
  name: '${prefix}DTFunctions'
  zipurl: 'https://github.com/Azure-Samples/digital-twins-samples/blob/master/HandsOnLab/TwinInputFunction/twinfunction.zip?raw=true'
}
var tsifunctionapp = {
  name: '${prefix}TSIFunctions'
  zipurl: 'https://github.com/Teodelas/digital-twins-samples/blob/master/HandsOnLab/TSIFunction/tsifunction.zip?raw=true'
}
var roleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
var ADTroleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'bcd981a7-7f74-457b-83e1-cceb9e632ffe')
var ADTroleDefinitionName_var = guid(identityName.id, ADTroleDefinitionId, resourceGroup().id)
var ADTroleDefinitionWeb_var = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', functionapp.name), ADTroleDefinitionId, resourceGroup().id)
var roleDefinitionName_var = guid(identityName.id, roleDefinitionId, resourceGroup().id)
var ADTRoleDefinitionUser_var = guid(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userid), roleDefinitionId, resourceGroup().id)
var identityName_var = '${prefix}scriptidentity'
var DTFunctionWebDeploy = '${prefix}DTFunctionsWebDeploy'
var TwinsEventHubName = 'twins-event-hub'
var TSIEventHubName = 'tsi-event-hub'
var TwinsEHAuthRule = 'Twins-Auth-Rule'
var TSIEHAuthRule = 'TSI-Auth-Rule'

resource iotHub_name 'Microsoft.Devices/IotHubs@2020-03-01' = {
  name: iotHub.name
  location: location
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: 2
      }
    }
    cloudToDevice: {
      defaultTtlAsIso8601: 'PT1H'
      maxDeliveryCount: 10
      feedback: {
        ttlAsIso8601: 'PT1H'
        lockDurationAsIso8601: 'PT60S'
        maxDeliveryCount: 10
      }
    }
    messagingEndpoints: {
      fileNotifications: {
        ttlAsIso8601: 'PT1H'
        lockDurationAsIso8601: 'PT1M'
        maxDeliveryCount: 10
      }
    }
  }
  sku: {
    name: 'S1'
    capacity: 1
  }
}

resource storage_name 'Microsoft.Storage/storageAccounts@2018-02-01' = {
  name: storage.name
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: false
  }
}

resource digitaltwins_name 'Microsoft.DigitalTwins/digitalTwinsInstances@2020-03-01-preview' = {
  name: digitaltwins.name
  location: resourceGroup().location
  tags: {}
  sku: {
    name: 'S1'
  }
  properties: {}
  dependsOn: [
    identityName
  ]
}

resource functionapp_name 'Microsoft.Web/sites@2019-08-01' = {
  name: functionapp.name
  kind: 'functionapp'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    name: functionapp.name
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.name, '2019-06-01').keys[0].value}'
        }
        {
          name: 'ADT_SERVICE_URL'
          value: 'https://${digitaltwins_name.properties.hostName}'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: true
        }
      ]
    }
    serverFarmId: serverfarm_name.id
    clientAffinityEnabled: false
  }
  dependsOn: [
    storage_name
    identityName
  ]
}

resource functionapp_name_MSDeploy 'Microsoft.Web/sites/extensions@2015-08-01' = {
  name: '${functionapp.name}/MSDeploy'
  location: resourceGroup().location
  tags: {
    displayName: DTFunctionWebDeploy
  }
  properties: {
    packageUri: functionapp.zipurl
    dbType: 'None'
    connectionString: ''
  }
  dependsOn: [
    functionapp_name
  ]
}

resource serverfarm_name 'Microsoft.Web/serverfarms@2019-08-01' = {
  name: serverfarm.name
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'Dynamic'
    name: 'B1'
  }
}

resource eventGrid_name 'Microsoft.EventGrid/systemTopics@2020-04-01-preview' = {
  name: eventGrid.name
  location: resourceGroup().location
  properties: {
    source: iotHub_name.id
    topicType: 'microsoft.devices.iothubs'
  }
}

resource eventGrid_name_sendtoFunction 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2020-04-01-preview' = {
  name: '${eventGrid.name}/sendtoFunction'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionapp_name.id}/functions/TwinsFunction'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Devices.DeviceTelemetry'
      ]
    }
  }
  dependsOn: [
    eventGrid_name

    iotHub_name
    functionapp_name_MSDeploy
  ]
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

resource ADTroleDefinitionName 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionName_var
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(identityName_var).principalId
    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}

resource ADTroleDefinitionWeb 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTroleDefinitionWeb_var
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: reference(functionapp_name.id, '2019-08-01', 'Full').identity.principalId
    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    identityName
  ]
}

resource ADTRoleDefinitionUser 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: ADTRoleDefinitionUser_var
  properties: {
    roleDefinitionId: ADTroleDefinitionId
    principalId: userid
    scope: resourceGroup().id
    principalType: 'User'
  }
}

resource eventHub_namespaces 'Microsoft.EventHub/namespaces@2018-01-01-preview' = {
  name: eventHub.namespaces
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    zoneRedundant: false
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    kafkaEnabled: true
  }
}

resource eventHub_namespaces_RootManageSharedAccessKey 'Microsoft.EventHub/namespaces/AuthorizationRules@2017-04-01' = {
  name: '${eventHub.namespaces}/RootManageSharedAccessKey'
  location: resourceGroup().location
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
  dependsOn: [
    eventHub_namespaces
  ]
}

resource eventHub_namespaces_TSIEventHubName 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventHub.namespaces}/${TSIEventHubName}'
  location: resourceGroup().location
  properties: {
    messageRetentionInDays: 7
    partitionCount: 4
    status: 'Active'
  }
  dependsOn: [
    eventHub_namespaces
  ]
}

resource eventHub_namespaces_TwinsEventHubName 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventHub.namespaces}/${TwinsEventHubName}'
  location: resourceGroup().location
  properties: {
    messageRetentionInDays: 7
    partitionCount: 4
    status: 'Active'
  }
  dependsOn: [
    eventHub_namespaces
  ]
}

resource eventHub_namespaces_TSIEventHubName_TSIEHAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2017-04-01' = {
  name: '${eventHub.namespaces}/${TSIEventHubName}/${TSIEHAuthRule}'
  location: resourceGroup().location
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
  dependsOn: [
    eventHub_namespaces_TSIEventHubName
    eventHub_namespaces
  ]
}

resource eventHub_namespaces_TwinsEventHubName_TwinsEHAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2017-04-01' = {
  name: '${eventHub.namespaces}/${TwinsEventHubName}/${TwinsEHAuthRule}'
  location: resourceGroup().location
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
  dependsOn: [
    eventHub_namespaces_TwinsEventHubName
    eventHub_namespaces
  ]
}

resource eventHub_namespaces_TSIEventHubName_tsi_preview 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2017-04-01' = {
  name: '${eventHub.namespaces}/${TSIEventHubName}/tsi-preview'
  location: resourceGroup().location
  properties: {}
  dependsOn: [
    eventHub_namespaces_TSIEventHubName
    eventHub_namespaces
  ]
}

resource tsi_name 'Microsoft.TimeSeriesInsights/environments@2020-05-15' = {
  name: tsi.name
  location: resourceGroup().location
  tags: {}
  sku: {
    name: 'L1'
    capacity: 1
  }
  kind: 'longterm'
  properties: {
    storageConfiguration: {
      accountName: storage.name
      managementKey: listKeys(storage_name.id, '2018-02-01').keys[0].value
    }
    timeSeriesIdProperties: [
      {
        name: '$dtId'
        type: 'string'
      }
    ]
    warmStoreConfiguration: {
      dataRetention: 'P7D'
    }
  }
}

resource tsi_name_HubInput 'Microsoft.TimeSeriesInsights/environments/eventsources@2020-05-15' = {
  name: '${tsi.name}/HubInput'
  location: resourceGroup().location
  kind: 'Microsoft.EventHub'
  properties: {
    serviceBusNamespace: eventHub.namespaces
    eventHubName: TSIEventHubName
    keyName: TSIEHAuthRule
    consumerGroupName: 'tsi-preview'
    timestampPropertyName: 'timestamp'
    eventSourceResourceId: eventHub_namespaces_TSIEventHubName.id
    provisioningState: 'Succeeded'
    sharedAccessKey: listKeys(resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules', eventHub.namespaces, TSIEventHubName, TSIEHAuthRule), '2017-04-01').primaryKey
  }
  dependsOn: [
    tsi_name
    resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules', eventHub.namespaces, TSIEventHubName, TSIEHAuthRule)
  ]
}

resource tsifunctionapp_name 'Microsoft.Web/sites@2019-08-01' = {
  name: tsifunctionapp.name
  kind: 'functionapp'
  location: location
  properties: {
    name: tsifunctionapp.name
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.name, '2019-06-01').keys[0].value}'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: true
        }
        {
          name: 'EventHubAppSetting-TSI'
          value: 'Endpoint=sb://${eventHub.namespaces}.servicebus.windows.net/;SharedAccessKeyName=${TSIEHAuthRule};SharedAccessKey=${listKeys(resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules', eventHub.namespaces, TSIEventHubName, TSIEHAuthRule), '2017-04-01').primaryKey};EntityPath=${TSIEventHubName}'
        }
        {
          name: 'EventHubAppSetting-Twins'
          value: 'Endpoint=sb://${eventHub.namespaces}.servicebus.windows.net/;SharedAccessKeyName=${TwinsEHAuthRule};SharedAccessKey=${listKeys(resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules', eventHub.namespaces, TwinsEventHubName, TwinsEHAuthRule), '2017-04-01').primaryKey};EntityPath=${TwinsEventHubName}'
        }
      ]
    }
    serverFarmId: serverfarm_name.id
    clientAffinityEnabled: false
  }
  dependsOn: [
    storage_name
  ]
}

resource tsifunctionapp_name_MSDeploy 'Microsoft.Web/sites/extensions@2015-08-01' = {
  name: '${tsifunctionapp.name}/MSDeploy'
  location: resourceGroup().location
  tags: {
    displayName: DTFunctionWebDeploy
  }
  properties: {
    packageUri: tsifunctionapp.zipurl
    dbType: 'None'
    connectionString: ''
  }
  dependsOn: [
    tsifunctionapp_name
  ]
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
    arguments: '${digitaltwins.name} ${resourceGroup().name} ${prefix} ${location} ${eventHub.namespaces} ${TwinsEventHubName} ${TwinsEHAuthRule} ${iotHub.name} ${tsi.name} ${userid}'
    environmentVariables: [
      {
        name: 'someSecret'
        secureValue: 'if this is really a secret, don\'t put it here... in plain text...'
      }
    ]
    primaryScriptUri: 'https://raw.githubusercontent.com/Teodelas/digital-twins-samples/master/HandsOnLab/deployment/arm-template-full-deployment-script.ps1'
    supportingScriptUris: []
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    roleDefinitionName
  ]
}

output result object = reference('PostDeploymentscript').outputs