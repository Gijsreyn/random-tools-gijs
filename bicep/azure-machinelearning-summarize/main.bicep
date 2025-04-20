
targetScope = 'subscription'

param resourceGroupName string = 'rg-ml-summarize-we'


#disable-next-line no-hardcoded-location
var enforcedLocation = 'westeurope'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: enforcedLocation
}

// The dependency resources for the workspace are the storage account and the key vault

module kv 'br/public:avm/res/key-vault/vault:0.12.1' = {
  scope: resourceGroup
  params: {
    name: 'kv-ml-summarize-we'
    location: enforcedLocation
    sku: 'standard'
    enableVaultForTemplateDeployment: true 
    enableVaultForDiskEncryption: true 
    enableVaultForDeployment: true 
    enableRbacAuthorization: true
    enablePurgeProtection: false 
  }
}

module log 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  scope: resourceGroup
  params: {
    name: 'log-ml-summarize-we'
  }
}

module appi 'br/public:avm/res/insights/component:0.6.0' = {
  scope: resourceGroup
  params: {
    name: 'appi-ml-summarize-we'
    workspaceResourceId: log.outputs.resourceId
  }
}

module st 'br/public:avm/res/storage/storage-account:0.19.0' = {
  scope: resourceGroup
  params: {
    name: 'stmlsummarizewe'
    location: enforcedLocation
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
  }
}

module ais1 'helper/cognitiveServices.bicep' = {
  scope: resourceGroup
}

// module ais 'br/public:avm/res/cognitive-services/account:0.10.2' = {
//   scope: resourceGroup
//   params: {
//     name: 'ais-ml-summarize-we'
//     kind: 'AIServices'
//     // sku: 'S1'
//     deployments: [
//       {
//         model: {
//           name: 'gpt-4o-mini'
//           format: 'OpenAI'
//           version: '2024-07-18'
//         }
//       }
//     ]
//   }
// }

// module mlw 'br/public:avm/res/machine-learning-services/workspace:0.12.0' = {
//   scope: resourceGroup
//   params: {
//     name: 'mlw-ml-summarize-we'
//     sku: 'Standard'
//     friendlyName: 'Content summarizer'
//     hbiWorkspace: false 
//     managedNetworkSettings: {
//       isolationMode: 'AllowInternetOutbound'
//     }
//     publicNetworkAccess: 'Enabled'
//     associatedApplicationInsightsResourceId: appi.outputs.resourceId
//     associatedStorageAccountResourceId: st.outputs.resourceId
//     associatedKeyVaultResourceId: kv.outputs.resourceId
//     // connections: [
//     //   {
//     //     name: 'ai github'
//     //     category: 'AIServices'
//     //     connectionProperties: {
//     //       authType: 'AccountKey'
//     //     }
//     //     target: ais.outputs.endpoints[0].?endpoint
//     //   }
//     // ]
//   }
// }

