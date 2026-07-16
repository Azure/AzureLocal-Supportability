# RemoveIncompatibleAzCliExtensions

## SYNOPSIS
Removes unmanaged (incompatible) Az CLI extensions from the current node so a solution update can proceed.

## DESCRIPTION
Compares the Az CLI extensions installed on the current node against the Azure Local ValidatedRecipe and
removes any extension that is not part of the recipe (an unmanaged extension). The remediation runs locally
on the node it is invoked on and does not act on the other nodes in the cluster. Unmanaged extensions may be
incompatible with the Az CLI core shipped in the target release and cause UpdatePreRequisites or the
pre-update environment validator (AzStackHci_ARBStack_AzCLIKnownIncompatibleExtensions) to fail.
UpdatePreRequisites reinstalls the correct managed extensions automatically after the update resumes.

| Property | Value |
| --- | --- |
| **Maintenance Window Recommended** | No |
| **Expected Impact** | None |
| **Supported OS Versions** | 23H2, 24H2 |
| **Supported Solution Updates** | All |

## SYNTAX

```powershell
Invoke-AzsSupportInsightRemediation -ScriptName "RemoveIncompatibleAzCliExtensions" [-Parameters <Hashtable>]
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


