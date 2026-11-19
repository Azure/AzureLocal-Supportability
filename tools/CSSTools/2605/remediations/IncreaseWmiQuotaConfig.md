# IncreaseWmiQuotaConfig

## SYNOPSIS
Increases the WMI Provider Host quota configuration to support more memory and handles for WMI providers.

## DESCRIPTION
This remediation script increases the WMI Provider Host quota configuration on an Azure Local node by updating the `__ProviderHostQuotaConfiguration` settings in WMI. Insufficient WMI quota limits can cause WMI-based operations and Azure Local health checks to fail or behave unreliably.

The script checks the current quota values and only applies updates when existing values are below the desired thresholds:

| Setting | Target Value |
| --- | --- |
| `MemoryPerHost` | 1 GB |
| `MemoryAllHosts` | 2 GB |
| `HandlesPerHost` | 8192 |

> [!IMPORTANT]
> After applying this remediation, you must restart the WMI service (`winmgmt`) for the changes to take effect. This may temporarily impact WMI-based applications and services. Plan to perform this remediation during a maintenance window.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | Yes |
| **Expected Impact** | Restart of the WMI service (`winmgmt`) required to apply new configuration. WMI-based applications and services may be temporarily impacted. |
| **Supported OS Versions** | 23H2, 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation before applying changes. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

### EXAMPLE 1
Run the remediation interactively, prompting for confirmation before applying changes.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig" -Parameters @{ Force = $true }
```

### EXAMPLE 3
Run the remediation and skip the environment compatibility check.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig" -Parameters @{ SkipEnvironmentCheck = $true }
```

## NOTES
- After this remediation is applied, restart the WMI service to activate the new quota configuration:
  ```powershell
  Restart-Service -Name winmgmt
  ```
- This script is typically invoked in response to a WMI quota-related insight detected by `Invoke-AzsSupportInsight`.
