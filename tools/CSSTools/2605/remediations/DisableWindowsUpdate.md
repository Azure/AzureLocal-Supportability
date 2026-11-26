# DisableWindowsUpdate

## SYNOPSIS
Disables automatic Windows Update by configuring the appropriate registry settings under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`.

## DESCRIPTION
This remediation script disables automatic Windows Updates on an Azure Local node by setting the `NoAutoUpdate` and `AUOptions` registry values under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`. Azure Local manages OS updates through the Azure Local Update solution, so automatic Windows Update should be disabled to prevent conflicts.

The script checks whether each registry value is already set to the desired state and only applies changes when required.

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
If specified, the remediation proceeds without prompting for confirmation before applying registry changes. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

### EXAMPLE 1
Run the remediation interactively, prompting for confirmation before applying changes.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate" -Parameters @{ Force = $true }
```

### EXAMPLE 3
Run the remediation and skip the environment compatibility check.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate" -Parameters @{ SkipEnvironmentCheck = $true }
```

## NOTES
- This remediation modifies the following registry values under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`:
  - `NoAutoUpdate` — Set to `1` (Disable Automatic Updates)
  - `AUOptions` — Set to `1` (Disable Automatic Updates)
- No system restart is required after applying this remediation.
- This script is typically invoked in response to the `Windows.Update.AutomaticUpdateEnabled` insight detected by `Invoke-AzsSupportInsight`.
