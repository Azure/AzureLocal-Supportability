# RemovedFailedUpdateEceActionPlans

## SYNOPSIS
Removes failed ECE action plans from the system.

## DESCRIPTION
Removes older failed ECE action plan instances whose ActionPlanName contains "MAS Update". The
remediation sorts matching failures by LastModifiedDateTime, preserves the newest failed instance,
and deletes every older failed instance through the ECE cluster service client. It does not delete
successful, active, or non-update action plans.

Run this remediation when the AzureLocal.UpdateService.HighMemUsage insight reports that the Azure
Stack HCI Update Service was terminated after reaching its memory limit and stale failed update
plans are contributing to retained state.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | 23H2, 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

### EXAMPLE 1
Run the remediation interactively after reviewing the failed update action plans.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans" -Parameters @{ Force = $true }
```

## NOTES
- Prerequisites: Run with administrative rights on a supported 23H2 or 24H2 environment where the ECE action plan commands and cluster service client are available.
- Risk and impact: Deleting an action plan instance is irreversible and removes its retained execution history. The newest failed MAS Update plan is preserved, and no service or node restart is performed. No impact to workloads or services expected.
- Expected result: At most the newest failed MAS Update action plan remains; older failed MAS Update instances are removed.
- Stop conditions: Do not proceed while a solution update is active or when older failed action plan history is still needed for investigation or support evidence.
- Recovery: There is no automated rollback and deleted action plan instances cannot be restored by this remediation. Capture required action plan details before running.
- Verification: Run Get-ActionPlanInstances, filter for failed MAS Update plans, and confirm that no older failed instances remain. Rerun the AzureLocal.UpdateService.HighMemUsage insight after observing the update service.
- Trigger: This remediation is recommended by the AzureLocal.UpdateService.HighMemUsage insight when it reports WARNING.


