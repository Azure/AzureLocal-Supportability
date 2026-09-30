# RemoveHealthCheckFilesForUpdates

## SYNOPSIS
Removes health check files created for updates from the system.

## DESCRIPTION
<!-- TODO: Provide a detailed description of what this remediation does and when to run it. -->

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | 23H2, 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates" [-Parameters <Hashtable>]
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


