module account 'br/public:avm/res/cognitive-services/account:0.10.2' = {
  name: 'accountDeployment'
  params: {
    kind: 'AIServices'
    name: 'csad002'
    customSubDomainName: 'xcsadai'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    deployments: [
      {
        model: {
          format: 'OpenAI'
          name: 'gpt-4o-mini'
          version: '2024-07-18'
        }
        name: 'gpt-4o-mini'
        sku: {
          capacity: 10
          name: 'GlobalStandard'

        }
      }
    ]
    location: 'westeurope'
  }
}

// https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.azure-ai-agent-service/basic-agent-keys/modules-basic/basic-dependent-resources.bicep
// https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.azure-ai-agent-service/basic-agent-keys/main.bicep
// https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models?tabs=global-standard%2Cstandard-chat-completions#model-summary-table-and-region-availability
