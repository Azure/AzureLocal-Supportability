# RemovedFailedUpdateEceActionPlans

## SYNOPSIS
Removes failed `MAS Update` ECE action plans from the system.

## DESCRIPTION
This remediation script removes failed `MAS Update` ECE (Enterprise Cloud Engine) action plans from an Azure Local node. Accumulation of failed ECE action plans can block or interfere with subsequent update operations. The most recent failed action plan is retained for diagnostic purposes; all older failed plans are removed.

The script uses the ECE cluster service client to identify and delete failed action plan instances matching `MAS Update`.

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
Run the remediation interactively, prompting for confirmation before removing action plans.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans" -Parameters @{ Force = $true }
```

### EXAMPLE 3
Run the remediation and skip the environment compatibility check.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans" -Parameters @{ SkipEnvironmentCheck = $true }
```

## NOTES
- The most recent failed `MAS Update` action plan is preserved to aid in diagnostics. Only older failed plans are removed.
- This script is typically invoked in response to an ECE action plan insight detected by `Invoke-AzsSupportInsight`.
