# DisableWindowsUpdate

## SYNOPSIS
Disables automatic Windows Update by configuring the appropriate registry settings under HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU.

## DESCRIPTION
Configures the local node to prevent Windows Update from automatically downloading or installing
operating system updates. The remediation sets the NoAutoUpdate and AUOptions policy values under
HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU to 1 when either value is missing or has
a different value.

Run this remediation when the Windows.System.Update.AutoUpdate insight reports that Windows Update
is not in the supported state. Azure Local operating system updates must be applied through the
supported solution update workflow rather than automatic Windows Update. The registry policy is
node-local, so run the remediation on each node reported by the insight.

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

### EXAMPLE 1
Run the remediation interactively on an affected node.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate"
```

### EXAMPLE 2
Run the remediation without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate" -Parameters @{ Force = $true }
```

## NOTES
- Prerequisites: Run with administrative rights on an Azure Local node. The HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU registry key must exist.
- Risk and impact: The remediation disables automatic Windows Update on the local node. It does not install updates, restart services, or restart the node.
- Expected result: NoAutoUpdate and AUOptions are both set to 1. A node that already has both values set to 1 is left unchanged.
- Stop conditions: Do not proceed if the node is intentionally managed by a different Windows Update policy or if the supported Azure Local solution update workflow is not available.
- Recovery: There is no automated rollback. Record both values before running, then restore the recorded values or remove values that did not previously exist if the policy must be reversed.
- Verification: Use Get-ItemProperty on the policy path to confirm both values are 1, then rerun the Windows.System.Update.AutoUpdate insight.
- Trigger: This remediation is recommended by the Windows.System.Update.AutoUpdate insight when it reports FAILURE.


