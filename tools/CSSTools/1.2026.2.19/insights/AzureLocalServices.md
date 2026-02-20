# AzureLocalServices

This script checks the state of the host network.

## AzureStack.ECE.OpState

This analyzer checks the state of Enterprise Cloud Engine (ECE) services.

| Rule | Synopsis |
| --- | --- |
| Windows.System.Service.State | This script checks the state of a service on the system. |
| Windows.System.LocalAccount.State | Determines if the local user account is locked or disabled on the host |

## AzureStack.Orchestrator.OpState

This analyzer checks the state of Orchestrator.

| Rule | Synopsis |
| --- | --- |
| Windows.System.LocalAccount.State | Determines if the local user account is locked or disabled on the host |

## AzureLocal.LCM.OpState

This analyzer checks for issues related to the Update Service.

| Rule | Synopsis |
| --- | --- |
| AzureLocal.UpdateService.HighMemUsage | Checks event logs to determine if AzureStack Lifecycle Agent has terminated Update Service due to High Memory Usage |
| AzureLocal.LCM.Account.ProtectedUser | Checks to ensure that LCM User is not a member of the Protected Users group |
| Windows.Security.ActiveDirectory.SPN.WsManCluster | Checks to see if SPN is present for WSMAN for the cluster name |


