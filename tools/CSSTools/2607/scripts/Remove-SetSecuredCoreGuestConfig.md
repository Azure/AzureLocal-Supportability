# Remove-SetSecuredCoreGuestConfig

## SYNOPSIS
Removes the `SetSecuredCore` guest configuration assignment from every Arc-for-Server node of an Azure
Stack HCI cluster. Uses the current `Az` PowerShell context.

> [!WARNING]
> This script is invoked through [`Invoke-AzsSupportScript`](../functions/Invoke-AzsSupportScript.md)
> and **must only be run by Microsoft CSS or Engineering.** It issues `DELETE` calls against the Arc
> guest-configuration assignments of every node in the target cluster. Run it against the wrong
> `ClusterArmId`, or without confirming the current `Az` context, and you can remove policy state from
> the wrong resources. Always run with `-WhatIf` first to preview the deletions.

## DESCRIPTION
The script uses the current `Az` PowerShell context to:

1. `GET` the cluster's `ArcSettings/default` resource and enumerate its per-node details.
2. For each node, `GET` the `SetSecuredCore` guest-configuration assignment and then `DELETE` it.
3. Emit a per-node summary of the action taken (`Deleted`, `NotFound`, `WouldDelete`, `Skip-NoArcInstance`, etc.).

If the `ClusterArmId` subscription differs from the current context subscription, the script switches
the `Az` context to the cluster's subscription before proceeding.

## WHERE TO RUN
This script can run **anywhere with an authenticated `Az` context** and network access to Azure Resource
Manager — it operates entirely through `Invoke-AzRestMethod` and does not require execution on a cluster
node. You must run `Connect-AzAccount` first; the script throws if no `Az` context is present.

## PARAMETERS

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ClusterArmId` | string | Yes | The full ARM resource ID of the Azure Stack HCI cluster, e.g. `/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.AzureStackHCI/clusters/<name>`. |

The script declares `[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]`, so it also
honors the common `-WhatIf`, `-Confirm`, and `-Verbose` parameters.

## EXAMPLES

### EXAMPLE 1 — Preview the deletions with `-WhatIf`
```powershell
Connect-AzAccount -TenantId <tid> -SubscriptionId <sub>

Invoke-AzsSupportScript -ScriptName "Remove-SetSecuredCoreGuestConfig" -Parameters @{
    ClusterArmId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.AzureStackHCI/clusters/<name>"
    WhatIf       = $true
}
```

### EXAMPLE 2 — Perform the deletions
```powershell
Connect-AzAccount -TenantId <tid> -SubscriptionId <sub>

Invoke-AzsSupportScript -ScriptName "Remove-SetSecuredCoreGuestConfig" -Parameters @{
    ClusterArmId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.AzureStackHCI/clusters/<name>"
}
```

## NOTES
- API versions used: `arcSettings` `2024-04-01`, guest configuration `2020-06-25`.
- This script is referenced by the `AzureLocal.Update.OSConfigSecuredCoreEnforcement` insight rule as
  the remediation for stale `SetSecuredCore` guest-configuration assignments.
