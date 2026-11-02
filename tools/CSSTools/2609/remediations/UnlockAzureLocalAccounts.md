# UnlockAzureLocalAccounts

## SYNOPSIS
Remediates a specified Azure Local account by ensuring it exists, is not disabled, is a member of the correct groups, and is not locked.

## DESCRIPTION
Goes through each PKU2U account on the system and ensures that the specified account meets the following criteria:
1. The account exists
2. The account is not disabled
3. Validate group membership.
4. The account is not locked.
5. If locked we will:
    * Change the password for the account and Service
    * Unlock the account
    * Check to see if cross node communication is working as intended using PKU2U.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{ Account = "<Account>" }
```

## PARAMETERS

### -Account *(Required)*
The account to remediate.

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{
    Account = "HCIOrchestrator"
}
```

## NOTES

- Supported account values are `HCIOrchestrator` and `ECEAgentService`.
- Run this remediation only under Microsoft support guidance after confirming the affected account and node.
- If the account is locked, the remediation rotates the local account and service password, enables the account, restores required local group membership, and tests PKU2U communication.
- Review the returned remediation status and any reported cross-node communication failures before retrying the failed operation.
