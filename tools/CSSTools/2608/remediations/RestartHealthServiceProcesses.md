# RestartHealthServiceProcesses

## SYNOPSIS
Stops every healthpih.exe process on the local node so the Health service starts a single
replacement plugin host.

## DESCRIPTION
When a stale healthpih.exe process acts as a second Storage Health leader concurrently with
the real leader, Storage Maintenance Mode does not hold: the stale host has no record of any
maintenance-mode intent set by the legitimate leader, so it clears it on its next pass.

healthpih.exe is a plugin host owned by the Health cluster resource, which starts a
replacement automatically whenever one exits. That makes terminating the processes sufficient
on its own: stopping every instance on the local node leaves the Health resource to start one
fresh host there, which re-establishes a single leader. The Health cluster resource is left
running throughout, so no cluster resource is stopped or started by this remediation.

This remediation is intentionally node-local. Run it on each affected node; it does not use
remoting or terminate healthpih.exe processes on other cluster nodes.

Found in: Azure Local 2601.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | The Health service plugin host is terminated and automatically restarted on the local node. Health monitoring is briefly interrupted while the replacement host starts. The Health cluster resource itself remains online throughout. |
| **Supported OS Versions** | All |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RestartHealthServiceProcesses" [-Parameters <Hashtable>]
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


