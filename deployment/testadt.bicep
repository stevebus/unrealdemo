// create ADT instance
resource adt 'Microsoft.DigitalTwins/digitalTwinsInstances@2020-03-01-preview' = {
  name: 'testadt1'
  location: resourceGroup().location
  tags: {}
  properties: {}
  dependsOn: [
  ]
}

//output adtHostName string = adt.properties.hostName

output stuff object = {
  adtName: adt.name
  adtHostName: adt.properties.hostName
}
