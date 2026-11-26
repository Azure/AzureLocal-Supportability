# ReplaceIgvmAgentBinary

## SYNOPSIS
Replaces AszIgvmAgent.exe from the bundled package and restarts the IgvmAgent service.

## DESCRIPTION
Stops the IgvmAgent service, copies AszIgvmAgent.exe from
packages\Microsoft.AzureStack.IgvmAgentDeployment into the configured IGVM installation
directory, and starts the service again.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | Yes |
| **Expected Impact** | The IgvmAgent service is restarted during remediation and may be briefly unavailable. |
| **Supported OS Versions** | 24H2 |
| **Supported Solution Updates** | 2607 |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "ReplaceIgvmAgentBinary" [-Parameters <Hashtable>]
```

## PARAMETERS

### -Force
If specified, the remediation proceeds without prompting for confirmation. Use with caution, as this may apply changes to the system unexpectedly.

### -SkipEnvironmentCheck
If specified, the remediation proceeds even if environment requirements are not met. Use with caution, as applying the remediation in an unsupported environment could cause issues.

## EXAMPLES

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "ReplaceIgvmAgentBinary"
```

## NOTES

- Run this remediation only when the `AzureLocal.KI.IgvmAgent` insight reports an IGVM agent binary mismatch on Azure Local 2607.
- Run it on each affected node; the remediation uses the IGVM installation path configured on that node.
- Schedule a maintenance window because the `IgvmAgent` service is stopped while the bundled binary is copied and is then restarted.
- Verify that the service is running and retry the affected Trusted Launch VM operation after remediation.
