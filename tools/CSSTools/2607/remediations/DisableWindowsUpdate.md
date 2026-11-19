# DisableWindowsUpdate

## SYNOPSIS
Disables automatic Windows Update by configuring the appropriate registry settings under HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU.

## DESCRIPTION
Disables automatic Windows Update on Azure Local nodes by setting the NoAutoUpdate registry value under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`. This prevents unplanned updates from applying outside of the solution update workflow.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate"
```

## NOTES
This remediation is typically triggered when the `OperatingSystem` insight detects that automatic Windows Update is enabled. Run on each affected node individually.


