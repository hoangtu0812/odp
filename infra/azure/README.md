# Azure foundation

`main.bicep` provisions only the shared Azure foundation: Azure Container Registry, ADLS Gen2-ready storage account, Key Vault, and Log Analytics. It deliberately does **not** deploy workload compute or make any network/security exception; those choices require the target subscription, resource group, VNet, and owner approval.

## Prerequisites

- An Azure subscription and target resource group approved for this platform.
- The service principal in `.env` assigned at least `Contributor` on that resource group. Key Vault data-plane roles are assigned separately after deployment.
- Azure CLI installed and logged in using the intended tenant.

## Validate and deploy

```powershell
az login --service-principal --username $env:AZURE_CLIENT_ID --password $env:AZURE_CLIENT_SECRET --tenant $env:AZURE_TENANT_ID
az bicep build --file infra/azure/main.bicep
az deployment group what-if --resource-group <approved-resource-group> --template-file infra/azure/main.bicep --parameters infra/azure/parameters.example.json
az deployment group create --resource-group <approved-resource-group> --template-file infra/azure/main.bicep --parameters infra/azure/parameters.example.json
```

Run `what-if` first and review its output. Do not pass secrets through Bicep parameters or commit an actual parameters file.

## Follow-up required before TEST/production

1. Place the resources behind a VNet/private endpoints and change `publicNetworkAccess` to disabled.
2. Grant managed identities least-privilege Key Vault and storage RBAC roles.
3. Push immutable, scanned images to ACR and run workloads on an approved Kubernetes/Container Apps environment.
4. Send container/platform logs to the provisioned Log Analytics workspace and configure alert ownership.
