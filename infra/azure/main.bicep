@description('Short globally unique prefix, using lowercase letters and numbers only.')
param namePrefix string

@description('Azure region for the platform foundation.')
param location string = resourceGroup().location

@description('Microsoft Entra tenant ID that owns Key Vault RBAC assignments.')
param tenantId string

@allowed([
  'Standard_LRS'
  'Standard_GRS'
])
param storageSku string = 'Standard_LRS'

var normalizedPrefix = toLower(replace(namePrefix, '-', ''))
var storageName = take('${normalizedPrefix}datalake', 24)

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${normalizedPrefix}acr'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleSet: {
      defaultAction: 'Allow'
    }
  }
}

resource dataLake 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${namePrefix}-kv'
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
  }
}

output acrLoginServer string = containerRegistry.properties.loginServer
output dataLakeName string = dataLake.name
output dataLakeBlobEndpoint string = dataLake.properties.primaryEndpoints.blob
output keyVaultName string = keyVault.name
output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId
