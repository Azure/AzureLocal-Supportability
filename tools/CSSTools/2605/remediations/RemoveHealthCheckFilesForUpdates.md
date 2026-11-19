# RemoveHealthCheckFilesForUpdates

## SYNOPSIS
Removes health check files created for updates from the system.

## DESCRIPTION
This remediation script removes stale or orphaned health check files associated with installed Azure Local updates. These files are stored under `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck`. Over time, leftover health check data can cause the update service to report incorrect health states or block update progress.

The script performs the following actions:
- Removes health check directories for each currently installed update.
- Removes old system health check results under the `System` subfolder, retaining the 10 most recent entries.
- If any health check files were removed, clears the update service cache so it re-reads the current data.

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

### EXAMPLE 1
Run the remediation interactively, prompting for confirmation before removing health check files.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates" -Parameters @{ Force = $true }
```

### EXAMPLE 3
Run the remediation and skip the environment compatibility check.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates" -Parameters @{ SkipEnvironmentCheck = $true }
```

## NOTES
- The update service cache is automatically cleared after health check files are removed, ensuring the update service reflects the latest state.
- The 10 most recent system health check result files are always preserved.
- This script must be run from a node that has access to the cluster storage path and the Azure Stack HCI Update Service cluster group.
- This script is typically invoked in response to an update health check insight detected by `Invoke-AzsSupportInsight`.
