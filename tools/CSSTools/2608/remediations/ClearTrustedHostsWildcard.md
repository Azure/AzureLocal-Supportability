# ClearTrustedHostsWildcard

## SYNOPSIS
Removes the wildcard ('*') entry from the WinRM client TrustedHosts list.

## DESCRIPTION
This remediation removes the wildcard ('*') entry from the WinRM client TrustedHosts setting
(WSMan:\localhost\Client\TrustedHosts) when it is present, preserving any other explicit entries.
While '*' is present, cluster validation cannot update the TrustedHosts list with the
IP, node name, and cluster name it requires, because WSMan treats the '.' in an IP
address as a special pattern and rejects the update. Removing the wildcard entry
allows cluster validation to repopulate the list and succeed.

Run this remediation on each affected node of the cluster, then rerun validation.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "ClearTrustedHostsWildcard" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

<!-- TODO: Provide at least one usage example invoking Invoke-AzsSupportInsightRemediation. -->

## NOTES
<!-- TODO: Add operational notes, prerequisites, and the insight that triggers this remediation. -->


