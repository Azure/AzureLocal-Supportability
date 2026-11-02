# IncreaseWmiQuotaConfig

## SYNOPSIS
Increases WMI Provider Host quota configuration to support more memory and handles for WMI providers.

## DESCRIPTION
Raises undersized values in the local __ProviderHostQuotaConfiguration instance to a minimum of
1 GB for MemoryPerHost, 2 GB for MemoryAllHosts, and 8192 for HandlesPerHost. Values that already
meet or exceed these thresholds are not reduced.

Run this remediation when the Windows.System.WMI.QuotaConfig insight reports that one or more WMI
Provider Host quotas are below the expected minimums. The change is node-local and requires a
restart of the Windows Management Instrumentation service before the new quotas take effect.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | Yes |
| **Expected Impact** | Change in WMI provider requires a restart of the WMI service, which may temporarily impact WMI-based applications and services. You should plan to restart the WMI service (winmgmt) to apply the new configuration. |
| **Supported OS Versions** | 23H2, 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

### EXAMPLE 1
Run the remediation interactively on an affected node.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig" -Parameters @{ Force = $true }
```

## NOTES
- Prerequisites: Run with administrative rights on a supported 23H2 or 24H2 node and plan a maintenance window to restart the Windows Management Instrumentation service.
- Risk and impact: Restarting winmgmt can temporarily interrupt WMI queries and WMI-dependent applications or services. The remediation changes quotas but does not restart winmgmt.
- Expected result: MemoryPerHost is at least 1 GB, MemoryAllHosts is at least 2 GB, and HandlesPerHost is at least 8192. Values above these thresholds remain unchanged.
- Stop conditions: Do not proceed if a maintenance window is unavailable, WMI-dependent workloads cannot tolerate a service interruption, or the root __ProviderHostQuotaConfiguration instance cannot be read.
- Recovery: There is no automated rollback. Record the original quota values before running; restore them with Set-CimInstance and restart winmgmt if the change must be reversed.
- Verification: Restart winmgmt during the maintenance window, query root\__ProviderHostQuotaConfiguration to confirm the minimum values, and rerun the Windows.System.WMI.QuotaConfig insight.
- Trigger: This remediation is recommended by the Windows.System.WMI.QuotaConfig insight when it reports WARNING.


