# ResetCredSSPConfiguration

## SYNOPSIS
Resets CredSSP authentication configuration to the correct state required for Azure Local operations.

## DESCRIPTION
This remediation resets the CredSSP registry keys and WinRM settings required for delegated credential
operations (Deployment, Upgrade, Update, AddNode, RepairNode). It enables CredSSP on both the WinRM
Service and Client, and configures the AllowFreshCredentials and AllowFreshCredentialsWhenNTLMOnly
delegation policies.

Note: These values may be reverted by Group Policy. If settings revert after running gpupdate /force,
check Domain Group Policy or Local Group Policy under Computer Configuration > Administrative Templates >
System > Credentials Delegation.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "ResetCredSSPConfiguration" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "ResetCredSSPConfiguration"
```

## NOTES

- Run this remediation on each node reported by the `Windows.Security.CredSSP.Configuration` insight.
- The remediation enables CredSSP for the WinRM service and client and restores the required credential delegation policies.
- Domain or local Group Policy can overwrite these settings. If the configuration reverts after `gpupdate /force`, correct the applicable policy before rerunning the Insight.
- For additional troubleshooting, see [CredSSP authentication issues](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/Security/CredSsp-Authentication-Issues.md).
