# RemoveFailoverClusterApiDll

## SYNOPSIS
Removes the stray Microsoft.NetworkController.FailoverClusterApi.dll from the HCIOrchestrator profile.

## DESCRIPTION
Removes C:\Users\HCIOrchestrator\Documents\Microsoft.NetworkController.FailoverClusterApi.dll from
the local node it runs on. A stray copy of this assembly can be loaded ahead of the in-box,
digitally signed assembly; when it is unsigned it cannot be loaded under the enforced execution
policy and blocks the Network Controller Failover Cluster tooling. The stray file lives in a
per-node profile path, so run this remediation on each node that flagged the issue. This
remediation pairs with the AzureLocal.KI.SDN.FailoverClusterApi.Unsigned rule and targets the
affected 2601 through 2606 solution builds; the environment check limits it to those supported
builds unless -SkipEnvironmentCheck is used.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | 2601, 2602, 2603, 2604, 2605, 2606 |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveFailoverClusterApiDll" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

### EXAMPLE 1
Run the remediation interactively, prompting for confirmation before removing the file.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveFailoverClusterApiDll"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveFailoverClusterApiDll" -Parameters @{ Force = $true }
```

### EXAMPLE 3
Run the remediation and skip the environment compatibility check.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveFailoverClusterApiDll" -Parameters @{ SkipEnvironmentCheck = $true }
```

## NOTES
- This remediation removes C:\Users\HCIOrchestrator\Documents\Microsoft.NetworkController.FailoverClusterApi.dll from the local node only; run it on each node that flagged the issue.
- No system restart is required after applying this remediation.
- This script is typically invoked in response to the AzureLocal.KI.SDN.FailoverClusterApi.Unsigned insight detected by Invoke-AzsSupportInsight on the affected 2601 through 2606 builds.


