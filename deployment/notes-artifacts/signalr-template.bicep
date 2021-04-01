@description('The globally unique name of the SignalR resource to create.')
param name string = uniqueString(resourceGroup().id)

@description('Location for the SignalR resource.')
param location string = resourceGroup().location

@allowed([
  'Free_F1'
  'Standard_S1'
])
@description('The pricing tier of the SignalR resource.')
param pricingTier string = 'Standard_S1'

@allowed([
  1
  2
  5
  10
  20
  50
  100
])
@description('The number of SignalR Unit.')
param capacity int = 1

@allowed([
  'Default'
  'Serverless'
  'Classic'
])
@description('Visit https://github.com/Azure/azure-signalr/blob/dev/docs/faq.md#service-mode to understand SignalR Service Mode.')
param serviceMode string = 'Default'

@allowed([
  'true'
  'false'
])
param enableConnectivityLogs string = 'true'

@allowed([
  'true'
  'false'
])
param enableMessagingLogs string = 'true'

@description('Set the list of origins that should be allowed to make cross-origin calls.')
param allowedOrigins array = [
  'https://foo.com'
  'https://bar.com'
]

resource name_resource 'Microsoft.SignalRService/SignalR@2020-07-01-preview' = {
  name: name
  location: location
  sku: {
    capacity: capacity
    name: pricingTier
  }
  kind: 'SignalR'
  properties: {
    hostNamePrefix: name
    features: [
      {
        flag: 'ServiceMode'
        value: serviceMode
      }
      {
        flag: 'EnableConnectivityLogs'
        value: enableConnectivityLogs
      }
      {
        flag: 'EnableMessagingLogs'
        value: enableMessagingLogs
      }
    ]
    cors: {
      allowedOrigins: allowedOrigins
    }
    networkACLs: {
      defaultAction: 'Deny'
      publicNetwork: {
        allow: [
          'ClientConnection'
        ]
      }
      privateEndpoints: [
        {
          name: 'mySignalRService.1fa229cd-bf3f-47f0-8c49-afb36723997e'
          allow: [
            'ServerConnection'
          ]
        }
      ]
    }
    upstream: {
      templates: [
        {
          categoryPattern: '*'
          eventPattern: 'connect,disconnect'
          hubPattern: '*'
          urlTemplate: 'https://example.com/chat/api/connect'
        }
      ]
    }
  }
}