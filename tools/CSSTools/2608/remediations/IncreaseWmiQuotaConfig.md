# IncreaseWmiQuotaConfig

## SYNOPSIS
Increases WMI Provider Host quota configuration to support more memory and handles for WMI providers.

## DESCRIPTION
<!-- TODO: Provide a detailed description of what this remediation does and when to run it. -->

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

<!-- TODO: Provide at least one usage example invoking Invoke-AzsSupportInsightRemediation. -->

## NOTES
<!-- TODO: Add operational notes, prerequisites, and the insight that triggers this remediation. -->


