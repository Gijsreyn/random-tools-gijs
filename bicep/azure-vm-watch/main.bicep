targetScope = 'subscription'

param location string = 'westeurope'

@secure()
param password string = newGuid()

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-vm-watch'
  location: location
}

var addressPrefix = '10.0.0.0/16'

module vnet 'br/public:avm/res/network/virtual-network:0.5.4' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-vnet'
  params: {
    name: 'vnet-vm-watch'
    addressPrefixes: [
      addressPrefix
    ]
    subnets: [
      {
        name: 'subnet-vm-watch'
        addressPrefix: cidrSubnet(addressPrefix, 24, 0)
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: cidrSubnet(addressPrefix, 27, 32)
      }
    ]
  }
}

module bastion 'br/public:avm/res/network/bastion-host:0.6.1' = {
  scope: rg
  name:  '${uniqueString(deployment().name, location)}-bastion'
  params: {
    name: 'bas-vm-watch'
    virtualNetworkResourceId: vnet.outputs.resourceId 
  }
}

module vm 'br/public:avm/res/compute/virtual-machine:0.12.2' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-vm'
  params: {
    name: 'vm-watch001'
    adminUsername: 'localAdmin'
    adminPassword: password
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig'
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
            pipCOnfiguration: {
              publicIpNameSuffix: '-pip'
              zones: []
            }
          }
        ]
        nicSuffix: '-nic'
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
      diskSizeGB: 128
      caching: 'ReadWrite'
    }
    osType: 'Windows'
    vmSize: 'Standard_D2S_v3'
    zone: 0
    encryptionAtHost: false
    managedIdentities: {systemAssigned: true}
  }
}

module eventHub 'br/public:avm/res/event-hub/namespace:0.10.1' = {
  scope: rg 
  name: '${uniqueString(deployment().name, location)}-eh'
  params: {
    name: 'evhns-vm-watch'
    location: location
    skuName: 'Standard'
    eventhubs: [
      {
        name: 'evh-vm-watch'
        roleAssignments: [
          {
            principalId: vm.outputs.?systemAssignedMIPrincipalId
            roleDefinitionIdOrName: '2b629674-e913-4c01-ae53-ef4638d8f975' // Event Hubs Data Sender
          }
        ]
      }
    ]
  }
}


module vmWatch 'extension/extension.bicep' = {
  name: '${uniqueString(deployment().name, location)}-vmWatch'
  scope: rg
  params: {
    location: location
    vmName: vm.outputs.name
    eventHubNamespace: eventHub.outputs.name
    eventHubName: 'evh-vm-watch'
  }
}
