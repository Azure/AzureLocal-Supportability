# RemoveHealthCheckFilesForUpdates

## SYNOPSIS
Removes health check files created for updates from the system.

## DESCRIPTION
Removes stale update health-check data from the cluster infrastructure share. For each installed
solution update, the remediation removes the matching directory under
C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck. It also removes
older entries from the System health-check directory while retaining the ten most recently written
entries.

If any health-check data is removed, the remediation clears the Azure Stack HCI Update Service
update cache through the update service endpoint so current data can be read again. Run this
remediation when the AzureLocal.UpdateService.HighMemUsage insight reports that the update service
was terminated after reaching its memory limit and stale health-check data is contributing to the
retained state.

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
Run the remediation interactively after confirming that no solution update is active.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates" -Parameters @{ Force = $true }
```

## NOTES
- Prerequisites: Run with administrative rights on a supported 23H2 or 24H2 environment with access to the cluster infrastructure share. Cache clearing also requires the Update Service cluster group, its owner node, and a valid URP client certificate.
- Risk and impact: Matching installed-update health-check directories and older System health-check entries are deleted permanently. If files are removed, the Update Service cache is cleared; no service or node restart is performed. No impact to workloads or services expected.
- Expected result: Installed-update health-check directories are removed, the ten newest System health-check entries are retained, and the Update Service cache is cleared when cleanup occurred.
- Stop conditions: Do not proceed while a solution update or health check is active, when the health-check files are needed for investigation, or when the expected infrastructure share, Update Service endpoint, or client certificate cannot be resolved.
- Recovery: There is no automated rollback. Preserve required files before running; deleted files can only be restored from a backup if one was taken.
- Verification: Confirm the installed-update directories are absent, no more than ten System entries remain, and the remediation log reports a successful cache clear when files were removed. Rerun the AzureLocal.UpdateService.HighMemUsage insight after observing the update service.
- Trigger: This remediation is recommended by the AzureLocal.UpdateService.HighMemUsage insight when it reports WARNING.


