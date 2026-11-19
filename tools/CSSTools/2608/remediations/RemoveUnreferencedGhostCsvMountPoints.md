# RemoveUnreferencedGhostCsvMountPoints

## SYNOPSIS
Removes unreferenced ghost Cluster Shared Volume mount points (C:\ClusterStorage.00X).

## DESCRIPTION
Removes leftover numbered CSV roots ONLY when nothing on the cluster still
references them. The gate is deliberately strict and is re-evaluated
immediately before any deletion, because deleting a referenced ghost root can
take virtual machines or Arc Resource Bridge offline.

The remediation refuses to act when any of the following is true:
  * an ACTIVE Cluster Shared Volume is mounted under a numbered root
  * a cluster resource parameter references a numbered root
  * a virtual machine disk, configuration, checkpoint, or paging path
    references a numbered root
  * an SMB client has a file open under a numbered root
  * any child of a ghost root is a reparse point, meaning it still redirects
    to a live volume
  * a ghost root contains live platform working data (a MocArb or ImageStore
    directory, WorkingDirectory content, or any virtual hard disk); this is a
    hard blocker even with no other reference, because deleting it destroys
    live state

A lone Infrastructure_<n> directory (an orchestrator breadcrumb with no other
platform content) does not block by itself; it is only treated as a blocker
when the root is otherwise referenced.

See the TSG for the full procedure:
https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/Storage/Troubleshoot-Storage-GhostCsvMountPoints.md

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | 23H2, 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveUnreferencedGhostCsvMountPoints" [-Parameters <Hashtable>]
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


