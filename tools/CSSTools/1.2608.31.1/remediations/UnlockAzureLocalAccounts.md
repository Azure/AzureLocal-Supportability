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

<!-- TODO: Provide at least one usage example invoking Invoke-AzsSupportInsightRemediation. -->

## NOTES
<!-- TODO: Add operational notes, prerequisites, and the insight that triggers this remediation. -->


