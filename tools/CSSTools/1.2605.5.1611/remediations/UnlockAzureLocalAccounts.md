# UnlockAzureLocalAccounts

## SYNOPSIS
Remediates a specified Azure Local account by ensuring it exists, is not disabled, is a member of the correct groups, and is not locked.

## DESCRIPTION
This remediation script validates and repairs the health of the `HCIOrchestrator` and `ECEAgentService` local accounts on an Azure Local node. These accounts are used by core Azure Local services and must remain enabled, properly grouped, and unlocked for the system to function correctly.

For each specified account, the script performs the following checks and corrective actions:

1. Verifies the account exists on the local system.
2. Re-enables the account if it is disabled.
3. Adds the account to the `Administrators` group if it is missing.
4. If the account is locked:
   - Rotates the account password using a cryptographically random 128-character value.
   - Updates the corresponding Windows service with the new password.
   - Unlocks the account.
   - Validates cross-node PKU2U communication from the current node to all cluster nodes.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | Password rotation for the specified account and its associated service. The service will be updated with the new password and started if not running. |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{ Account = "<AccountName>" }
```

## PARAMETERS

### -Account *(Required)*
The Azure Local service account to remediate. Must be one of the following values:

| Value | Associated Service |
| --- | --- |
| `HCIOrchestrator` | Azure Stack HCI Orchestrator Service |
| `ECEAgentService` | ECEAgent |

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

### EXAMPLE 1
Remediate the `HCIOrchestrator` account interactively, prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{ Account = "HCIOrchestrator" }
```

### EXAMPLE 2
Remediate the `ECEAgentService` account without prompting for confirmation.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{ Account = "ECEAgentService"; Force = $true }
```

### EXAMPLE 3
Remediate the `HCIOrchestrator` account and skip the environment compatibility check.
```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{ Account = "HCIOrchestrator"; SkipEnvironmentCheck = $true }
```

## NOTES
- This script must be run on a cluster node with local administrator privileges.
- If the account was disabled by a Group Policy Object (GPO), re-enabling it via this script may be reverted on the next GPO refresh. Investigate and resolve any GPO conflicts if the account becomes disabled again.
- PKU2U cross-node communication failures are logged as warnings but do not cause the remediation to fail.
- This script is typically invoked in response to an `HCIOrchestrator` or `ECEAgentService` account health insight detected by `Invoke-AzsSupportInsight`.
