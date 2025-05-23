param vmName string
param location string
param eventHubNamespace string
param eventHubName string

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

resource extension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: 'VMWatch'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.ManagedServices'
    type: 'ApplicationHealthWindows'
    typeHandlerVersion: '2.0'
    settings: {
      vmWatchSettings: {
        enabled: true
        parameterOverrides: {
          EVENT_HUB_OUTPUT_NAMESPACE: eventHubNamespace 
          EVENT_HUB_OUTPUT_NAME: eventHubName
          EVENT_HUB_OUTPUT_USE_MANAGED_IDENTITY: true
        }
      }
    }
  }
}
