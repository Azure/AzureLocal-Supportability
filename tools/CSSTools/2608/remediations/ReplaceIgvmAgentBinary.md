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

<!-- TODO: Provide at least one usage example invoking Invoke-AzsSupportInsightRemediation. -->

## NOTES
<!-- TODO: Add operational notes, prerequisites, and the insight that triggers this remediation. -->


