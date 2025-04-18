During Azure Local solution update, the overall cluster upgrade **may fail**. Although the Azure Resource Bridge (ARB) cluster upgrade itself succeeds, a cleanup step fails when the platform tries to delete the cluster extension used to trigger the upgrade. The failure occurs because the delete operation is blocked by a resource lock.

## Symptoms

You may encounter a `ScopeLocked` error similar to the following:

```
[ERROR: (FailedToDeleteClusterExtension) DELETE https://management.azure.com/... 
RESPONSE 409: 409 Conflict ERROR CODE: ScopeLocked
```

```json
{
  "error": {
    "code": "ScopeLocked",
    "message": "The scope '/subscriptions/.../providers/Microsoft.KubernetesConfiguration/extensions/kva-management-operator' 
    cannot perform delete operation because following scope(s) are locked: 
    '/subscriptions/.../providers/microsoft.resourceconnector/appliances/...'. 
    Please remove the lock and try again."
  }
}
```

## Root Cause

During ARB upgrade, the platform deploys the **Appliance Management Cluster Extension** (also known as the **KVA Management Operator**) to initiate the upgrade. The ARB platform expects to manage the lifecycle of this extension—including deleting it after the upgrade completes. If the ARB resource is locked for deletion, the platform cannot remove the extension, causing the upgrade operation to end in an incomplete state.

## Mitigation Steps

To resolve the issue, follow these steps:

### 1. Remove the Delete Lock

1. Open the Azure portal.
2. Navigate to the resource group where the Azure Local system is deployed.
3. Locate the **Arc Resource Bridge** resource.
4. Select it, then go to the **Locks** tab in the left pane.
5. If a **Delete** lock exists, remove it.  
   > ⚠️ You need **Azure Local Administrator** role permissions for the resource group to delete the lock.

### 2. Delete the Cluster Extension

Before proceeding, make sure you:

- Have the Azure CLI installed
- Know your ARB resource's `subscriptionId`, `resourceGroupName`, and `resourceName`

```powershell
az login --use-device-code

# Install CLI extension (if not already installed)
az extension add -n k8s-extension

# Set your subscription context
az account set -s "<subscriptionId>"

# Delete the KVA Management Operator extension
az k8s-extension delete -g "<resourceGroupName>" -t "appliances" --cluster-name "<resourceName>" --name "kva-management-operator"
```

### 3. Reapply the ARB Resource Configuration

You must reapply the same ARB resource configuration used during the original deployment. Ensure you have:

- The ARB appliance YAML config file
- The ARB `kubeconfig` file
- The provider type (e.g., Azure Local or VMware)

Example paths for Azure Local deployments:

- Config file:  
  `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\MocArb\WorkingDirectory\Appliance\hci-appliance.yaml`
- Kubeconfig file:  
  `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\MocArb\WorkingDirectory\Appliance\kubeconfig`

If you've lost either file:

- Rebuild the config file using:  
  `az arcappliance createconfig`
- Retrieve kubeconfig using:  
  `az arcappliance get-credentials`

Then run:

```powershell
az arcappliance create "<provider>" --config-file "<path-to-appliance-yaml>" --kubeconfig "<path-to-kubeconfig>"
```

### 4. Verify ARB Status

```powershell
az arcappliance show --resource-group "<resource-group>" --name "<ARB name>"
```

Confirm that the ARB resource returns to a healthy state with:

- `status`: `Running`
- `provisioningState`: `Succeeded`
- `version`: matches the version before the mitigation

You can check this with:

```json
{
  "id": "/subscriptions/**********/resourceGroups/********/providers/Microsoft.ResourceConnector/appliances/****",
  "name": "**********",
  "location": "**********",
  "type": "Microsoft.ResourceConnector/appliances",
  "properties": {
    "status": "Running",
    "provisioningState": "Succeeded",
    "version": "<expected version>"
  }
}
```