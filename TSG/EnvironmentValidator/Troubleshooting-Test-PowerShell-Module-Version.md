<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "AzStackHci_ValidatedRecipe_PowerShellModule_Version"
  },
  "validation": {
    "fidelity_level": "L4",
    "technical_grade": "A",
    "reproduction_substrate": "vm",
    "automation_status": "proven",
    "last_validated": "2026-11-24",
    "spec_ref": "AzStackHci_ValidatedRecipe_PowerShellModule_Version"
  }
}
-->

# AzStackHci_ValidatedRecipe_PowerShellModule_Version

| Field | Value |
| --- | --- |
| Component | Environment Validator / Validated Solution Recipe (VSR) |
| Validator / test | `Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules` |
| Applicable products | Azure Local nodes with the Validated Recipe validator installed |
| Applicability | Pre-update validation; the automatic remediation path additionally requires `AzureLocalImageModule` and `Remediate-PSModules` |
| Severity | Critical validator failure; update readiness may be affected |
| Time and impact | In the lab, the full check, helper repair, and recheck on one node took under 10 minutes; plan for 30 minutes per affected node plus the update retry. Neither remediation path restarts the node or moves virtual machines. Module replacement can interrupt a management operation that is using the module, so remediate in a maintenance window. |
| Who acts | A local administrator on each affected node. The manual alternative runs only with Microsoft Support guidance. |
| Execution surface | on-device |
| Validation | On 2026-11-23, on a lab cluster (solution 12.2701.1004.15, validator 10.2701.0.2017, Windows PowerShell 5.1), the full loop ran with the recipe-aware helper path: baseline PASS; an injected missing module and, separately, a newer gallery module beside the recipe version each produced FAILURE; the image-module import and helper blocks remediated; and the check returned PASS. The manual alternative ran verbatim on the same build with the helper module temporarily moved out of the module path. With `Az.Accounts` 5.5.5 installed and the recipe version 5.5.3 missing, it installed 5.5.3, removed 5.5.5, kept the older 5.5.1, and the check returned PASS. The live run also showed that current Az modules declare their `Az.Accounts` minimum under `ModuleList`, not `RequiredModules`: the previous dependent-module guard removed `Az.Accounts` 5.5.5 while `Az.Storage` 9.8.0 still needed it, after which importing `Az.Storage` failed with `This module requires Az.Accounts version 5.5.5`. The guard now reads both lists and stopped before any change when `Az.KeyVault` 6.6.2 needed `Az.Accounts` 5.5.4. Health-fault clearing was not tested. On 2026-11-24, on the same build, the loop ran again with the system health check started while the module was missing, and each administrator surface was checked; see [Administrator detection surfaces](#administrator-detection-surfaces). Later on 2026-11-24 the dependent-module check in the manual alternative was revised (see [Revision history](#revision-history)). With simulated module folders, not on a cluster, the revised block stopped before any change when another module required an exact `Az.Accounts` version that would be removed, or a minimum or maximum version that no remaining version met, and it continued when every requirement was still met. On a lab node in Windows PowerShell 5.1, the revised check read the installed Az module manifests without reporting any of them, and it reported a scratch module that required exactly `Az.Accounts` 5.5.5. The complete manual block was not run again on a cluster after this revision. The recipe-aware helper loop ran again on the revised article and returned PASS. A further revision added the repository check and the wider dependency check (see [Revision history](#revision-history)). With simulated module folders, not on a cluster, the manual block stopped before any change when a version it would remove was not in the repository, when a dependent module's manifest could not be read or named the module by a file path, and when a dependent module was in another user's `Documents` folder, and it used the repository name in `$ApprovedRepository` for every repository command. In Windows PowerShell 5.1 on a lab node and in PowerShell 7, the dependency check agreed with `Import-Module` in all 54 combinations of exact, minimum, maximum, and wildcard maximum requirements that were tried, and on the lab node it parsed and read the installed Az module manifests without reporting any of them. The complete manual block was not run on a cluster after these revisions. A later 2026-11-24 revision made the manual block one statement and extended its checks (see [Revision history](#revision-history)). With simulated module folders, not on a cluster, it stopped before any change when a dependent module named `Az.Accounts` by a file path beside an ordinary requirement, when a requirement's module GUID matched only a version it would remove, and when a requirement was met only by recipe version `5.5.3.0`, which equals the installed `5.5.3` and is therefore not installed again; it stopped without removing anything when the version that installation actually added did not meet a dependent module's requirement. When installing `Az.Storage` 9.7.2 also installed `Az.Accounts` 5.5.5, it finished `Az.Storage` and then stopped with an error that named `Az.Accounts` 5.5.5; a second run for `Az.Accounts` removed it. Run one statement at a time, as a console can run pasted text, the previous block still reached `Uninstall-Module` after its dependency check had failed twice; the new block is one statement and stopped at the first failed check. On a lab node in Windows PowerShell 5.1, the new block parsed as one statement and stopped at its first check (`Use the recipe-aware helper instead of the manual alternative.`) without changing any module, and the dependency check agreed with `Import-Module` in the 54 earlier combinations and in 5 combinations of requirements with a module GUID. The complete manual block was still not run through an install and removal on a cluster. A further 2026-11-24 revision changed how the dependency check finds each user's module folder and reads requirements given as a path or with a module GUID (see [Revision history](#revision-history)). With simulated module folders, not on a cluster, the manual block stopped before any change when a dependent module named `Az.Accounts` only by a path to its manifest under `ModuleList`, when a requirement's module GUID matched only a copy in another user's `Documents` folder or a version that was not installed yet, when a signed-in user's `Documents` folder was redirected to another folder or to OneDrive and a module there needed `Az.Accounts` 5.5.4, and when a user's `Documents` folder could not be found or read. It continued when a path entry named a different module, when the module GUID matched the kept all-users copy, and when a service profile had no `Documents` folder, and the earlier simulated cases still passed. On a lab node with 19 user profiles, the check read every user's module folder without stopping, and in Windows PowerShell 5.1 it reported a module that named a scratch module only by a path under `ModuleList`. The complete manual block was still not run through an install and removal on a cluster. A last 2026-11-24 revision made the dependency check stop by default when a user who has a profile on the node is not signed in (see [Revision history](#revision-history)). With simulated module folders, not on a cluster, the manual block stopped before any change and listed the profile, or every such profile, when a user who was not signed in had a profile; with `$AssumeDefaultDocumentsForSignedOutUsers` set to `$true` it checked the `Documents` folder in that profile folder, stopped for a module there that pinned a version it would remove, and stopped when that folder did not exist; it still read a signed-in user's redirected folder, and it stopped when the setting was not `$false` or `$true`. The earlier simulated cases still passed. On 2026-11-24 the complete manual block then ran on a lab node (Windows PowerShell 5.1, three-node cluster, recipe `Az.Accounts` 5.5.3) in a new elevated session in which the recipe-aware helper was hidden from that session only, with only the module name (`Az.Accounts`) and the repository (`PSGallery`) set. With `Az.Accounts` 5.5.5 installed for all users beside 5.5.3 and an older 5.5.1, the read-only check returned `FAIL` (`Got '5.5.5' but expected less-than or equal to '5.5.3'`). The block as published stopped with `No changes were made` and listed the 5 profiles on the node whose users were not signed in. No loaded user registry on that node recorded a redirected `Documents` folder and no Folder Redirection policy had been applied, so `$AssumeDefaultDocumentsForSignedOutUsers` was then set to `$true`: the block completed, removed `Az.Accounts` 5.5.5, kept 5.5.1 and 5.5.3, and installed nothing, and the check returned `PASS`. Every file in the node's all-users module folder then matched a backup taken before the test, and the module folders on all three nodes matched their state before the test. That run did not exercise the installation path, because the recipe version was already installed. Later on 2026-11-24 the same block, run the same way on the same node (helper hidden from that session only, `Az.Accounts`, `PSGallery`, and `$AssumeDefaultDocumentsForSignedOutUsers` set to `$true` for the same reason), exercised it: with the recipe version `Az.Accounts` 5.5.3 uninstalled and 5.5.5 installed for all users beside 5.5.1, the check returned `FAIL` (`Got '5.5.5' but expected less-than or equal to '5.5.3'`). The block installed 5.5.3 from `PSGallery`, removed 5.5.5, and kept 5.5.1, and it did not stop with the `Install-Module also installed` error, because `Az.Accounts` declares no dependencies, so no second run was needed; the check then returned `PASS`. Following [Rollback and escalation](#rollback-and-escalation), `Install-Module` with `-RequiredVersion`, the repository `PSGallery`, and `-Scope AllUsers` then installed the removed version 5.5.5 again; `-Force` was added only because the PowerShell Gallery was not a trusted repository on that node and the remote session could not answer the confirmation prompt. Every file in the node's all-users module folder was then returned to a full backup taken before the run and matched it file by file, and the module folders on all three nodes matched their state before the test. A further 2026-11-24 revision added the read-only list of the modules that the helper would repair and the `NestedModules` check in the manual alternative (see [Revision history](#revision-history)). In Windows PowerShell 5.1 on a lab node and in PowerShell 7, a `NestedModules` entry that named a scratch module with an exact or a minimum version did not load an installed copy of that module, even when that version was installed, while an entry that gave a path to an installed version loaded that version, and the module that listed it failed to import after that version was removed. With simulated module folders, not on a cluster, the manual block stopped before any change for a `NestedModules` entry that gave a path, directly or in a module specification, to a version it would remove, and continued for an entry that named the module, for a module's own files listed there, and for a manifest that mentioned the module only in its description; the earlier simulated cases still passed. The read-only list showed the expected modules and versions, treated `5.5.3` and `5.5.3.0` as the same version, and stopped when the recipe could not be read. On a lab node it listed `Az.Accounts` 5.5.1, which is older than the recipe version 5.5.3 and is not named by the check, and the `PackageManagement` and `PowerShellGet` 1.0.0.1 versions that come with Windows, and changed no module; there, the revised dependency check read all 188 modules in the node's module paths and users' folders without reporting any of them for any recipe module. The complete manual block was not run again on a cluster after this revision. |

## Table of contents

- [Revision history](#revision-history)
- [Overview](#overview)
- [Symptoms](#symptoms)
- [Issue validation](#issue-validation)
- [Contributing factors](#contributing-factors)
- [Mitigation details](#mitigation-details)
- [Rollback and escalation](#rollback-and-escalation)
- [Verify resolution](#verify-resolution)
- [Administrator detection surfaces](#administrator-detection-surfaces)

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-24 | The manual alternative now keeps every version of the module that another installed module requires, as declared in that module's manifest file: an exact version (`RequiredVersion`), a minimum version, or a maximum version. Before this change it checked only minimum versions, so a module that required an exact newer version could lose that version. The block names the module and stops before any change. It also repeats the check after it installs the recipe version and before it removes anything. |
| 2026-11-24 | The manual alternative now confirms, before any change, that every version it would remove is available in `$ApprovedRepository`, so that the version can be restored from there, and stops if one is not. Its dependency check now also covers modules in every user's `Documents` folder, and treats a requirement that it cannot read, such as one given as a file path, as unmet, so that it stops instead of removing a version that might be needed. It compares versions the way PowerShell does when it loads a module, and treats `5.5.3` and `5.5.3.0` as the same version when it compares installed versions with the recipe or the repository. |
| 2026-11-24 | Named the PowerShell Gallery download hosts (`cdn.powershellgallery.com`, `cdn.oneget.org`) in Preconditions and noted that the `Find-Module` restore check does not show that downloads work. The recipe-aware helper's **Changes** line now states that it removes versions that are not in the recipe, including older ones and `Az.Accounts` versions that are not in the recipe, without checking dependent modules, and that it uninstalls before it reinstalls; checks to run with Microsoft Support first were added. The manual alternative is now one statement, wrapped in `& { }`, so a failed check ends the whole block even when it is pasted into a console. Its dependency check now treats a requirement given as a file path as unmet even when another entry names the module, accepts a requirement that names a module GUID only from a kept version with that GUID, and, after an installation, counts only the versions that are actually installed. When `Install-Module` also installs a dependency version newer than the recipe, such as `Az.Accounts`, the block finishes the named module and then stops with an error that names that version and tells you to run the block again for it. |
| 2026-11-24 | The recipe-aware helper block now runs as one statement (`& { ... }`), so if the helper is unavailable its check stops the block before `Remediate-PSModules` runs, even when the block is pasted line by line. |
| 2026-11-24 | The manual alternative's dependency check now finds a user's modules in a redirected `Documents` folder, such as one in OneDrive, when that user is signed in, and stops with `No changes were made` when a user's `Documents` folder cannot be found or read, instead of treating a missing folder as having no modules. It also stops when a module names the target module only by a path to its folder or manifest, and it accepts a requirement that names a module GUID only from a kept all-users copy with that GUID, not from a copy in a user's folder. |
| 2026-11-24 | The manual alternative no longer checks the `Documents` folder in the profile folder of a user who is not signed in, because that user's folder can be redirected elsewhere and the modules there would be missed. When it would remove a version and such a user has a profile on the node, it now stops with `No changes were made` and lists those profiles, so that each user can sign in and stay signed in while it runs. A new setting at the top of the block, `$AssumeDefaultDocumentsForSignedOutUsers`, lets it check the default folder instead, only after your domain or endpoint administrator confirms that folder redirection is not used for those users; it still stops if that folder is missing. |
| 2026-11-24 | Before you run the recipe-aware helper, you now check every module that it would repair, not only the modules named in the failure details, because the helper also repairs a module whose other installed versions are older than the recipe version and so pass the check. A new read-only block lists, for each module in the validated recipe, the installed versions that differ from the recipe version. The manual alternative's dependency check now also reads `NestedModules` and stops with `No changes were made` on an entry there that gives a path to the folder or manifest of a version it would remove, because that entry loads only that copy. |

## Overview

Environment Validator runs a Validated Recipe validator prior to Update. The test detects issues with install components that have drifted from the validated recipe.
The validated recipe is the list of exact component versions, including PowerShell modules, that a
given Azure Local build is tested with; each node can read it locally.

After the fix, the check reports `SUCCESS` on every node and the update readiness check no longer
lists `Test PowerShell Module Version` as failed.

Do not infer applicability to disconnected, disaggregated, or multi-rack deployments.
If the validator is absent, stop and obtain release-specific guidance. If the
remediation helper is absent, use the manual alternative only with Microsoft
Support guidance and a verified current recipe; never guess an installation path.

## Symptoms

During pre-update validation, the Validated Recipe tests fail on Test PowerShell Module version.

Inspecting the Pre-Update health check results (the example is PowerShell but these results are available in the console)
```powershell
Get-SolutionUpdateEnvironment | Select-Object -ExpandProperty HealthCheckResult | Where-Object Status -ne 'Success'
```

Reveals the following failure:

```
Name               : AzStackHci_ValidatedRecipe_PowerShellModule_Version
DisplayName        : Test PowerShell Module Version
Tags               : {}
Title              : Test PowerShell Module Version
Status             : FAILURE
Severity           : CRITICAL
Description        : Validating that the PS modules installed on the host are the same versions defined in the
                     validated recipe.
Remediation        : https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2
TargetResourceID   : NODE01
TargetResourceName : NODE01
TargetResourceType : ValidatedRecipe
Timestamp          : 5/27/2025 2:59:37 PM
AdditionalData     : {}
HealthCheckSource  : Manual\Standard\Medium\ValidatedRecipe\6f49f155
```

This result means the validation found PowerShell Modules it was not expecting but it is lacking the detail on which modules are wrong (this issue is being addressed). 

On newer builds the system health check keeps one result per node, with the module detail. This
read-only block, run on any node, lists each node's latest result. It reads the last completed
health check; the `completed` time shows how old that result is.

```powershell
$checkName = 'AzStackHci_ValidatedRecipe_PowerShellModule_Version'
$environment = @(Get-SolutionUpdateEnvironment -FullHealthCheckDetails -ErrorAction Stop)[0]
"Last system health check: $($environment.HealthState), completed $($environment.HealthCheckDate)"
@($environment.HealthCheckResult) | Where-Object Name -eq $checkName |
    Sort-Object TargetResourceName, Status -Unique |
    Select-Object TargetResourceName, Status, @{ Name = 'Detail'; Expression = { $_.AdditionalData.Detail } } |
    Format-List | Out-String -Width 200
```

Expected result: one entry per node. A node with `Status : FAILURE` needs the steps below; its
`Detail` names the module. Two forms appear in `Detail`:

- A newer module: `Checking version of PS module 'Az.Accounts' on host 'NODE01'. Got '5.0.1' but expected less-than or equal to '4.0.2' so it is invalid.`
- A missing module: `Failed to parse installed version of PS module 'ArcHci' on host 'NODE01'. Got 'N/A'.`

While a health check is running, the first line shows `InProgress` with a completion time of
`01/01/0001` and no entries are listed; run the block again after it finishes. If a completed health
check returns no entry, it did not evaluate this check; use the read-only check in
[Issue validation](#issue-validation) on each node instead.


## Issue Validation

### Read-only PASS/FAIL check

Run this check on each affected node. It does not change the installed modules.
`PASS` means every returned matching check
succeeded; `FAIL` includes drift details. Missing results, unexpected statuses, and
validator errors stop the script instead of reporting a false pass.

```powershell
$checkName = 'AzStackHci_ValidatedRecipe_PowerShellModule_Version'
$checks = @(Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules -ErrorAction Stop |
    Where-Object Name -eq $checkName)

if ($checks.Count -eq 0) {
    throw "The validator did not return $checkName. Drift status is unknown; do not remediate based on this result."
}

$unexpected = @($checks | Where-Object { $_.Status -notin @('SUCCESS', 'FAILURE') })
if ($unexpected.Count -gt 0) {
    throw "The validator returned an unexpected or missing status for $checkName. Drift status is unknown; inspect the validator output."
}

$failed = @($checks | Where-Object Status -eq 'FAILURE')
[pscustomobject]@{
    Check   = $checkName
    Result  = if ($failed.Count -gt 0) { 'FAIL' } else { 'PASS' }
    Details = ($failed | ForEach-Object { $_.AdditionalData.Detail }) -join '; '
}
```

If the result is `PASS`, no PowerShell module remediation is needed. For `FAIL`,
inspect `Details` and follow the preconditions below. If the script errors, stop:
the drift state is unknown.

### Inspect the full failure details

The validation can be run manually to verify and give us more information. Note: you can pass PsSession array to this cmdlet, the example just focusses on running locally.

```powershell
$result = Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules
```

The output can be viewed to confirm a failure state:

```
PS C:\> $result

HealthCheckSource  : Manual\Standard\Medium\ValidatedRecipe\166243fa
Name               : AzStackHci_ValidatedRecipe_PowerShellModule_Version
DisplayName        : Test PowerShell Module Version
Tags               : {}
Title              : Test PowerShell Module Version
Status             : FAILURE
Severity           : CRITICAL
Description        : Validating that the PS modules installed on the host are the same versions defined in the
                     validated recipe.
Remediation        : https://learn.microsoft.com/en-us/azure/azure-local/update/update-troubleshooting-23h2
TargetResourceID   : NODE01
TargetResourceName : NODE01
TargetResourceType : ValidatedRecipe
Timestamp          : 5/28/2025 11:59:26 AM
AdditionalData     : {[Detail, 'PackageManagement':'1.4.8.1' found;  'PowershellGet':'2.2.5' found;  Checking version
                     of PS module 'Az.Accounts' on host 'NODE01'. Got '5.0.1' but expected less-than or equal to
                     '4.0.2' so it is invalid.;  'Az.Resources':'7.8.0' found;  'Az.ConnectedMachine':'1.1.1' found;
                     'Az.Storage':'8.1.0' found;  'Az.Attestation':'2.1.0' found;  'Az.AksArc':'0.1.3' found;
                     'TraceProvider':'1.0.28' found;  'DownloadSdk':'1.1.20' found;  'moc':'1.2.27' found;
                     'ArcHci':'1.2.68' found;  'Az.StackHCI':'2.5.0' found;  'SdnDiagnostics':'4.2504.1.2119' found],
                     [Status, FAILURE], [TimeStamp, 05/28/2025 11:59:26], [Resource, Validated Assembly Recipe]...}
```

Inspect the AdditionalData > detail property for a breakdown of what needs remediating:

```text
PS C:\> ($result | ? Name -eq AzStackHci_ValidatedRecipe_PowerShellModule_Version).AdditionalData.Detail -split ';'
'PackageManagement':'1.4.8.1' found
  'PowershellGet':'2.2.5' found
  Checking version of PS module 'Az.Accounts' on host 'NODE01'. Got '5.0.1' but expected less-than or equal to '4.0.2' so it is invalid.
  'Az.Resources':'7.8.0' found
  'Az.ConnectedMachine':'1.1.1' found
  'Az.Storage':'8.1.0' found
  'Az.Attestation':'2.1.0' found
  'Az.AksArc':'0.1.3' found
  'TraceProvider':'1.0.28' found
  'DownloadSdk':'1.1.20' found
  'moc':'1.2.27' found
  'ArcHci':'1.2.68' found
  'Az.StackHCI':'2.5.0' found
  'SdnDiagnostics':'4.2504.1.2119' found
```

## Contributing factors

The pertinent information in the result above is **Checking version of PS module 'Az.Accounts' on host 'NODE01'. Got '5.0.1' but expected less-than or equal to '4.0.2' so it is invalid.**

The installed version and upper bound in this historical `AdditionalData.Detail`
establish the mismatch. "Less-than or equal to" is not an exact installation pin.
Obtain an exact installation target from the current node's validated recipe,
not from this example or a drift-category `ExpectedValue`. These details do not,
by themselves, establish whether an interrupted install, a dependency change,
or another operation introduced the mismatch.

The shipped validator `10.2701.0.2017`, inspected on solution `12.2701.1004.15`,
compares the newest PowerShellGet-installed version, not every
side-by-side copy. A matching newest version can pass while older versions remain
installed. A missing module instead yields an empty installed-version value in
the shipped inventory helper and fails version parsing; it is not a passing
`0.0.0` version. Confirm the current failure before changing any module.

## Mitigation Details

### Preconditions

Before changing installed modules:

- Confirm `FAIL` for this check on the target node and record its drift details.
- Use a new, elevated Windows PowerShell session on each affected node. Close
  other PowerShell sessions that may hold the modules being replaced.
- Do not run remediation concurrently with deployment, an update, another
  installation, or scripts that depend on these modules.
- Confirm access to the approved repository and the required recipe versions.
  Stop if downloads or installation are unavailable. With the public PowerShell Gallery, the
  node needs HTTPS access to `www.powershellgallery.com` and to the hosts that
  [Network access to the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/getting-started#network-access-to-the-powershell-gallery)
  lists for package discovery and download, `cdn.powershellgallery.com` and `cdn.oneget.org`.
  The Gallery redirects package downloads to `cdn.powershellgallery.com`, so with only
  `www.powershellgallery.com` allowed, `Find-Module` can succeed while `Install-Module` fails.
  The manual alternative's check that removed versions can be restored uses `Find-Module`: it
  confirms that a version is in the repository, not that the node can download it. Confirm
  that these hosts are allowed before running either remediation path. An internal
  repository needs the same versions.
- Obtain a maintenance window and a recovery plan approved by Microsoft Support.
  The helper can uninstall and reinstall modules used by management operations.

Which path to use: run the import block below. If it finds `Remediate-PSModules`, use the
recipe-aware helper. If it warns that the helper is unavailable, stop and contact Microsoft
Support; use the manual alternative only with their guidance.

### Discover and import the Azure Local Image module

**Changes:** imports a module into the current PowerShell session only. Installed
modules are not changed. The block discovers the highest installed module version,
imports its actual path, and checks for the helper without executing remediation.

```powershell
$imageModule = Get-Module -ListAvailable -Name AzureLocalImageModule |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -ne $imageModule) {
    Import-Module -Name $imageModule.Path -Force -ErrorAction Stop
}

$remediationCommand = Get-Command -Name Remediate-PSModules -Module AzureLocalImageModule -ErrorAction SilentlyContinue
if ($null -eq $remediationCommand) {
    Write-Warning 'The recipe-aware helper is unavailable. Stop here unless Microsoft Support has approved the manual alternative below.'
}
```

Expected result: the import completes and `$remediationCommand` identifies the
helper. An import error is a stop condition. A missing module or helper permits
only the Support-approved manual alternative, not an arbitrary install.
Closing this session discards its module imports; no installation was changed.

### Remediate using the recipe-aware helper

**[HIGH RISK]** Run only after the preconditions above are satisfied.

**Changes:** checks the PowerShell module category against the VSR and uninstalls
and reinstalls modules whose versions differ from the recipe. It can affect more
than the first module named in the validator result. For each module it repairs, it
removes every installed version except the recipe version, older versions included,
and whenever it repairs drift it also removes every `Az.Accounts` version except the
recipe version. It removes those versions without checking whether other installed
modules need them, so a module that needs one of them can fail to import afterward.
It uninstalls before it reinstalls and has no rollback, so if the recipe version
cannot be downloaded, a module whose only installed version was newer than the recipe
can be left not installed at all. In the 2026-11-23 lab run,
repairing a missing `ArcHci` also reinstalled its dependency modules and removed an
older side-by-side `Az.Accounts` version that was not in the recipe.

> [!WARNING]
> There is no automatic rollback for this helper. Replacing a module that a
> management operation is using can interrupt that operation, so run it only in
> the maintenance window agreed with Microsoft Support.

Before you run the helper, check these with Microsoft Support:

1. The node can download the recipe versions, including from the PowerShell Gallery
   download hosts named in [Preconditions](#preconditions). A blocked download host
   is found only after the helper has started uninstalling.
2. No other installed module needs a version that the helper would remove: any
   version, other than the recipe version, of a module that the helper would repair,
   and any `Az.Accounts` version other than the recipe version. The helper repairs
   every recipe module that has an installed version other than its recipe version,
   not only the modules named in the failure details: a module whose other versions
   are older than the recipe passes the check but is still repaired. List those
   modules and versions with the read-only block below. Then look in the module
   manifests (`.psd1` files) in the session's module path and in each user's
   `Documents\WindowsPowerShell\Modules` folder, including a redirected `Documents`
   folder such as one in OneDrive, for `RequiredModules` or `ModuleList`
   entries that name one of those modules, and for `NestedModules` entries that give a
   path to one of their folders or manifests. Current Az modules declare their
   `Az.Accounts` requirement under `ModuleList`. A requirement matters if only a
   version that would be removed meets it: an exact `RequiredVersion`, a minimum
   `ModuleVersion` above the recipe version, or a `MaximumVersion` below it. In the
   lab run for this article, `Az.KeyVault` 6.6.2 needed `Az.Accounts` 5.5.4, above
   the recipe version 5.5.3. A `NestedModules` entry given as a path loads only that
   copy, so it matters if that copy would be removed. A `NestedModules` entry that
   names one of those modules does not matter: in Windows PowerShell 5.1 and
   PowerShell 7, with a version it loads only a copy in the module's own folder, and
   without one it loads any installed version.

**Changes:** none to installed modules. The block imports the recipe module into the
current session only and lists, for each module in the validated recipe, the
installed versions that differ from the recipe version.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $artifactPath = Get-ASArtifactPath -NugetName Microsoft.AzureStack.VersionControl.Operations
    Import-Module (Join-Path $artifactPath 'content\Scripts\VersionControlHelpers.psm1') -Force -DisableNameChecking
    $recipe = @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure'))
    if ($recipe.Count -eq 0) { throw 'The validated recipe lists no PowerShell modules, so the drift is unknown. Do not run the helper.' }
    function ConvertTo-FullVersion([version]$Version) {
        [version]::new($Version.Major, $Version.Minor, [math]::Max($Version.Build, 0), [math]::Max($Version.Revision, 0))
    }
    foreach ($row in $recipe) {
        $recipeVersion = [string]$row.RequiredVersion -as [version]
        if (-not $recipeVersion) { throw "The recipe version of $($row.Name) cannot be read, so the drift is unknown. Do not run the helper." }
        $installed = @(Get-Module -Name $row.Name -ListAvailable | ForEach-Object { $_.Version } | Sort-Object -Unique)
        $other = @($installed | Where-Object { (ConvertTo-FullVersion $_) -ne (ConvertTo-FullVersion $recipeVersion) })
        if ($other.Count -gt 0 -or $installed.Count -eq 0) {
            [pscustomobject]@{ Module = $row.Name; RecipeVersion = "$recipeVersion"; RecipeVersionInstalled = $other.Count -lt $installed.Count; OtherVersions = $other -join ', ' }
        }
    }
}
```

Expected result: one row for each recipe module that the helper would repair, with
the installed versions other than the recipe version, which the helper can remove, in
`OtherVersions`; a module that is missing shows `RecipeVersionInstalled` as `False`.
The list can also include versions that come with Windows, such as `PackageManagement`
and `PowerShellGet` 1.0.0.1; checking a listed version that the helper does not remove
does no harm. Check every version in `OtherVersions`, including every `Az.Accounts`
version listed there. No rows means that no installed version differs from the recipe.
An error means the drift is unknown: do not run the helper.

If either check fails, do not run the helper; contact Microsoft Support. The
[manual alternative](#manual-alternative-for-nodes-without-the-helper) makes the
dependent-module check itself and stops before any change, but use it only with
Microsoft Support guidance.

Paste or run the whole block at once. It runs as one statement, so if the helper is
unavailable the check stops the block before `Remediate-PSModules` runs.

```powershell
& {
    if (-not (Get-Command -Name Remediate-PSModules -Module AzureLocalImageModule -ErrorAction SilentlyContinue)) {
        throw 'The recipe-aware helper is unavailable. Do not run automatic remediation.'
    }
    $driftResult = Remediate-PSModules -Verbose
    $driftResult
}
```

Inspect the returned result for completion or errors, then run
[Verify resolution](#verify-resolution). An error or a remaining `FAIL` is a stop
condition, not permission to repeatedly uninstall modules.

### Manual alternative for nodes without the helper

Use this path only when the recipe-aware helper is unavailable,
with Microsoft Support guidance and the recovery plan agreed above. Set only the
module name from the current failure and the approved repository name. The block
derives the exact target from `Get-ValidatedRecipe.RequiredVersion`. If that
product authority is unavailable, empty, ambiguous, or invalid, the recipe-version
guard throws before any install or removal. Do not replace that guard
with the historical `4.0.2` example or interpret a validator upper bound as an
exact pin.

This narrow fallback handles versioned, PowerShellGet-managed modules in the
Windows PowerShell **AllUsers** directory only (`C:\Program Files\WindowsPowerShell\Modules`,
where modules installed with `-Scope AllUsers` are available to every user on the node). Stop for CurrentUser copies,
duplicate paths, unregistered copies, or a module loaded in this session.
Do not use it to replace `PowerShellGet`, `PackageManagement`, or the modules
providing the validator and recipe commands; those require Support-led recovery.
Install the recipe version side by side if missing, verify the exact installed
path, and only then remove versions above the recipe upper bound. Preserve older
versions; this validator message alone does not justify removing them. If the
module is not installed at all, the block stops; use the recipe-aware helper or
contact Microsoft Support. The block also stops, before any change, and names the
module, if another installed module declares a requirement that the remaining
versions do not meet: an exact version (`RequiredVersion`) that would be removed,
or a minimum (`ModuleVersion`) or maximum (`MaximumVersion`) version that no
remaining version satisfies. `Uninstall-Module -Force` skips the dependency check,
so removing that version would break the dependent module. The check reads both
`RequiredModules` and `ModuleList` from each manifest file, because current Az
modules declare their `Az.Accounts` requirement under `ModuleList`. It also reads
`NestedModules` and stops on an entry there that gives a path to the module's folder or
manifest, because that entry loads only that copy. An entry there that names the module
needs no version that the block removes: in Windows PowerShell 5.1 and PowerShell 7, with
a version it loads only a copy in the module's own folder, and without one it loads any
installed version. It checks the
modules in the session's module path and in every user's
`Documents\WindowsPowerShell\Modules` folder. For a signed-in user, it uses the
`Documents` folder that Windows records for that user, which can be redirected,
for example to OneDrive. For a user who is not signed in, Windows does not show
where that folder is redirected, and accepting the `Documents` folder in that
user's profile folder instead could miss modules in a redirected folder and allow
a version that one of them needs to be removed. So, when it would remove a version
and a user who has a profile on the node is not signed in, the block stops with
`No changes were made` and lists those profiles by security identifier (SID);
`Get-CimInstance -ClassName Win32_UserProfile | Where-Object SID -eq '<SID>' | Select-Object LocalPath, Loaded`
shows each profile's folder. Have each listed user sign in, and stay signed in,
or keep a session such as a disconnected Remote Desktop session, while the block
runs; then run the block again. Only if your domain or endpoint administrator
confirms that `Documents` folder redirection is not used for those users, change
`$AssumeDefaultDocumentsForSignedOutUsers = $false` to `$true` at the top of the
block; the block then checks the `Documents` folder in each listed profile folder
instead, and still stops if that folder does not exist. Service profiles, such as
the system profile, are not checked. If a user's `Documents` folder cannot be
found or read, for example a redirected folder that this session cannot reach,
the block stops with `No changes were made` and names the profile by its SID. If
that user is not signed in, have the user sign in, and stay signed in while the
block runs, then run the block again; otherwise contact
Microsoft Support. The check fails closed: when it
cannot show that a requirement is still met, for example because a manifest
cannot be read or names any module by a file path, including an entry that is
only a path to the module's folder or manifest, it treats the requirement as
unmet and stops with `No changes were made`. A requirement that also names a
module GUID is met only by a kept version whose all-users copy has that GUID; a
copy in a user's `Documents` folder, or a version that the block has not
installed yet, does not count. It
compares versions the way PowerShell does when it loads a module, so a
requirement of exactly `5.5.5.0` is not met by version `5.5.5`. The block also stops before any change if a version
that it would remove is not available in `$ApprovedRepository`, because that
repository is where the version would be restored from; use a repository that has
those versions, or contact Microsoft Support. After an installation, the block
reads the inventory again and repeats these checks before it removes anything,
because `Install-Module` can also install dependency modules. In that repeated
check, only versions that are now installed count as kept.

Close other module-dependent PowerShell and remote sessions before starting.
`Remove-Module` does not guarantee that loaded .NET assemblies release file locks.
If installation or removal reports files in use, stop and arrange release of the
owning session with its operator. Do not force-stop management processes, reboot
the node, or delete module folders as a workaround.

**[HIGH RISK]**

**Changes:** For the one module you name, installs the recipe version if it is
missing and uninstalls only versions newer than that recipe version. Older
versions are not changed. Before any change, it confirms that every version it
would remove is available in `$ApprovedRepository`. That check uses `Find-Module`, which
does not show that the download hosts in [Preconditions](#preconditions) are reachable;
the block installs before it removes, so a failed download stops it before any removal.
When it installs the recipe version, `Install-Module`
also installs the modules that the publisher declares as dependencies of that
version, as described in
[Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module).
With `-Force`, it installs the newest version of each dependency that the
repository has, even when a compatible version is already installed. For an Az
module other than `Az.Accounts`, that usually adds an `Az.Accounts` version newer
than the recipe. The block does not remove that version. After it finishes the
named module, it stops with an error that names each added version that is newer
than the recipe; then run this block again, in a new session, with
`$RequiredModuleName` set to that module (for example `Az.Accounts`), because
[Verify resolution](#verify-resolution) fails until you do.
No other modules are uninstalled. If it would remove a version while a user who
has a profile on the node is not signed in, it stops before any change unless you
set `$AssumeDefaultDocumentsForSignedOutUsers` as described above.

> [!WARNING]
> There is no automatic rollback for this block. Removing a version that a
> management operation is using can interrupt that operation, so run it only in
> the maintenance window agreed with Microsoft Support.

Edit the two names on the lines near the top, and change
`$AssumeDefaultDocumentsForSignedOutUsers` only as described above, then paste the whole block at once
or save it as a `.ps1` file and run that file. The block is one statement,
wrapped in `& { }`: the console reads it up to the closing brace before running
any of it, and a failed check (`throw`) ends the whole block, so no install or
removal line runs after a check fails. Do not run individual lines from it; the
preceding guards and inventories are required in the same run.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this block in Windows PowerShell 5.1. No changes were made.' }
    $RequiredModuleName = '<module-from-current-failure>'
    $ApprovedRepository = '<approved-repository>'
    # Leave $false unless your domain or endpoint administrator confirms that Documents folder redirection is not
    # used for the users that the block lists as not signed in.
    $AssumeDefaultDocumentsForSignedOutUsers = $false

    if ($RequiredModuleName -notmatch '^[A-Za-z][A-Za-z0-9.]{0,99}$' -or
        $ApprovedRepository -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$') {
        throw 'Set the affected module and approved repository names. No changes were made.'
    }
    if ($AssumeDefaultDocumentsForSignedOutUsers -isnot [bool]) { throw 'Set $AssumeDefaultDocumentsForSignedOutUsers to $false or $true. No changes were made.' }

    $imageModule = Get-Module -ListAvailable -Name AzureLocalImageModule |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($imageModule) {
        Import-Module -Name $imageModule.Path -Force -ErrorAction Stop
    }
    if (Get-Command -Name Remediate-PSModules -ErrorAction SilentlyContinue) {
        throw 'Use the recipe-aware helper instead of the manual alternative.'
    }
    $checkName = 'AzStackHci_ValidatedRecipe_PowerShellModule_Version'
    $escapedName = [regex]::Escape($RequiredModuleName)
    $failurePattern = "Checking version of PS module '$escapedName' on host '[^']*'\. " +
        "Got '[^']*' but expected less-than or equal to '[^']*' so it is invalid\."
    $missingPattern = "Failed to parse installed version of PS module '$escapedName' on host '[^']*'\."
    $checks = @(Invoke-AzStackHciValidatedRecipeValidation -PassThru -Include Test-PSModules -ErrorAction Stop |
        Where-Object Name -eq $checkName)
    if (@($checks | Where-Object { "$($_.Status)" -eq 'FAILURE' -and
            ([string]$_.AdditionalData.Detail) -match $missingPattern }).Count -gt 0) {
        throw "$RequiredModuleName is missing or its version is unreadable. Use the recipe-aware helper or contact Microsoft Support. No changes were made."
    }
    if ($checks.Count -eq 0 -or @($checks | Where-Object { "$($_.Status)" -notin @('SUCCESS', 'FAILURE') }).Count -gt 0 -or
        @($checks | Where-Object { "$($_.Status)" -eq 'FAILURE' -and
            ([string]$_.AdditionalData.Detail) -match $failurePattern }).Count -eq 0) {
        throw 'No confirmed validator failure for this module. No changes were made.'
    }
    $artifactPath = Get-ASArtifactPath -NugetName Microsoft.AzureStack.VersionControl.Operations -ErrorAction Stop
    Import-Module (Join-Path $artifactPath 'content\Scripts\VersionControlHelpers.psm1') -Force -DisableNameChecking -ErrorAction Stop
    $recipeAll = @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure') -ErrorAction Stop)
    $recipeRows = @($recipeAll | Where-Object Name -eq $RequiredModuleName)
    if ($recipeRows.Count -ne 1) { throw 'The exact recipe target is unresolved or ambiguous. No changes were made.' }
    $RequiredModuleVersion = [string]$recipeRows[0].RequiredVersion
    if ($RequiredModuleVersion -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$') { throw 'Invalid recipe version. No changes were made.' }
    $targetVersion = [version]$RequiredModuleVersion
    $protectedModules = @('PowerShellGet', 'PackageManagement', 'AzureLocalImageModule') +
        @(Get-Command Get-ValidatedRecipe, Get-ASArtifactPath, Invoke-AzStackHciValidatedRecipeValidation -ErrorAction Stop |
            Select-Object -ExpandProperty ModuleName)
    if ($RequiredModuleName -in $protectedModules -or (Get-Module -Name $RequiredModuleName)) {
        throw 'The target is a tooling dependency or is loaded. Stop for Support-led recovery.'
    }
    $moduleRoot = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$RequiredModuleName"
    function Get-ScopedModuleInventory {
        $installed = @(Get-InstalledModule -Name $RequiredModuleName -AllVersions -ErrorAction SilentlyContinue)
        $available = @(Get-Module -Name $RequiredModuleName -ListAvailable -ErrorAction Stop)
        if ($installed.Count -eq 0 -and $available.Count -eq 0) {
            throw "$RequiredModuleName is not installed. Use the recipe-aware helper or contact Microsoft Support."
        }
        if ($installed.Count -ne $available.Count) {
            throw 'The installed and available inventories disagree. Stop.'
        }
        foreach ($module in $installed) {
            if ($null -eq ([string]$module.Version -as [version])) {
                throw 'An installed version is not a numeric version. Stop for Support-led recovery.'
            }
            $expectedPath = Join-Path $moduleRoot ([string]$module.Version)
            $pathMatches = @($available | Where-Object { (ConvertTo-FullVersion $_.Version) -eq (ConvertTo-FullVersion ([string]$module.Version)) -and $_.ModuleBase -eq $expectedPath })
            if ($module.Name -ne $RequiredModuleName -or $module.InstalledLocation -ne $expectedPath -or $pathMatches.Count -ne 1) {
                throw 'A module path is ambiguous or outside the scoped AllUsers inventory. Stop.'
            }
        }
        return $installed
    }
    function ConvertTo-FullVersion {
        # Missing build and revision numbers count as 0, so 5.5.3 and 5.5.3.0 name the same installed version.
        param([version]$Version)
        [version]::new($Version.Major, $Version.Minor, [math]::Max($Version.Build, 0), [math]::Max($Version.Revision, 0))
    }
    function Get-DependentCandidate {
        # Modules in this session's module path and in every user's Documents folder, because a module that
        # another user installed can also need a version that would be removed. A user's Documents folder can be
        # redirected, and only that user's loaded registry shows where. A user whose registry is not loaded, because
        # that user is not signed in, stops the check, unless $AssumeDefaultDocumentsForSignedOutUsers is $true; then
        # the default folder under the profile is used. A folder that cannot be found or read stops the check.
        param([string]$Outcome)
        $signedOut = @()
        $userPaths = @(foreach ($p in @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object { -not $_.Special })) {
            $documents = Join-Path $p.LocalPath 'Documents'
            $hive = "Registry::HKEY_USERS\$($p.SID)"
            try {
                if (Test-Path -LiteralPath $hive) {
                    $personal = (Get-Item -LiteralPath "$hive\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders").GetValue('Personal', $null, 'DoNotExpandEnvironmentNames')
                    # %USERPROFILE% means that user's profile folder, not the profile of the account running this block.
                    if ($personal -like '%USERPROFILE%*') { $documents = $p.LocalPath + $personal.Substring(13) } elseif ($personal) { $documents = $personal }
                } elseif (-not $AssumeDefaultDocumentsForSignedOutUsers) {
                    # Without that user's registry, a redirected Documents folder cannot be found, so the default folder is not trusted.
                    $signedOut += $p.SID
                    continue
                }
                $found = ($documents -notmatch '%') -and (Test-Path -LiteralPath $documents)
            } catch { $found = $false }
            if (-not $found) {
                throw ("The Documents folder of user profile $($p.SID) could not be found or read, so the modules of that user cannot be checked. " +
                    "If that user is not signed in, have that user sign in, and stay signed in while the block runs, then run the block again; otherwise contact Microsoft Support. $Outcome")
            }
            Join-Path $documents 'WindowsPowerShell\Modules'
        })
        if ($signedOut.Count -gt 0) {
            throw ('These user profiles are not signed in, so where Windows keeps their Documents folder, which can be redirected, cannot be read: ' +
                ($signedOut -join ', ') + '. Have each of these users sign in, and stay signed in while the block runs, then run the block again. ' +
                'Only if your domain or endpoint administrator confirms that Documents folder redirection is not used for these users, set ' +
                '$AssumeDefaultDocumentsForSignedOutUsers to $true at the top of the block, so that the Documents folder in each profile folder is checked instead. ' + $Outcome)
        }
        $userModules = @(foreach ($m in @($userPaths | Where-Object { Test-Path -LiteralPath $_ })) {
            try { Get-ChildItem -LiteralPath $m -Directory | ForEach-Object { Get-Module -Name $_.FullName -ListAvailable } }
            catch { throw "The module folder $m could not be read: $($_.Exception.Message) Contact Microsoft Support. $Outcome" }
        })
        @(@(Get-Module -ListAvailable) + $userModules | Sort-Object Path -Unique)
    }
    function Get-UnmetDependent {
        # Lists installed modules whose manifest needs a version of $ModuleName that is not kept: RequiredVersion
        # is an exact version, ModuleVersion a minimum, and MaximumVersion a maximum. The manifest file is read
        # because Get-Module reports an exact RequiredModules version as a minimum. Versions are compared as
        # PowerShell compares them when it loads a module. A requirement that cannot be read is reported as unmet.
        # ExcludePath lists the module folders that are removed in the same change, so they need nothing.
        param([string]$ModuleName, [version[]]$KeptVersion, [object[]]$Modules, [string[]]$ExcludePath = @())
        foreach ($d in $Modules) {
            if ($d.Name -eq $ModuleName -or $ExcludePath -contains $d.ModuleBase) { continue }
            # An entry given as a path names the module by its folder or file name; it is read too, so that the path check stops on it.
            $pathPattern = "(^|[\\/])$([regex]::Escape($ModuleName))([\\/]|\.(psd1|psm1|dll)$|$)"
            $listed = @(@($d.RequiredModules) + @($d.ModuleList) | Where-Object { $_ -and ($_.Name -eq $ModuleName -or
                    ($_.Name -match '[\\/]|\.(psd1|psm1|dll)$' -and $_.Name -match $pathPattern)) }).Count -gt 0
            # Get-Module does not keep a path given under NestedModules, so a manifest file that mentions the module is read too.
            $mentioned = $listed
            if (-not $listed -and $d.Path -like '*.psd1') {
                try { $mentioned = [bool](Select-String -LiteralPath $d.Path -Pattern ([regex]::Escape($ModuleName)) -Quiet) } catch { $mentioned = $true }
            }
            if (-not $mentioned) { continue }
            try {
                $data = Import-PowerShellDataFile -LiteralPath $d.Path -ErrorAction Stop
                # A NestedModules entry given as a path to the module's folder or manifest loads only that copy, so it is not checked here.
                # An entry that names the module needs no removed copy: with a version it loads only a copy in the module's own folder,
                # and without one it loads any installed version.
                foreach ($entry in @(@($data.NestedModules) | Where-Object { $_ })) {
                    $n = if ($entry -is [hashtable]) { [string]$entry.ModuleName } else { [string]$entry }
                    if ($n -match '[\\/]|\.(psd1|psm1|dll)$' -and $n -match $pathPattern) { throw "A module is loaded by a file path: $n" }
                }
                if (-not $listed) { continue }
                $named = $false
                foreach ($entry in @(@($data.RequiredModules) + @($data.ModuleList) | Where-Object { $_ })) {
                    $s = [Microsoft.PowerShell.Commands.ModuleSpecification]::new($entry)
                    # A requirement given as a path to a module file or folder can pin any version, so it is not checked here.
                    if ($s.Name -match '[\\/]|\.(psd1|psm1|dll)$') { throw "A module is required by a file path: $($s.Name)" }
                    if ($s.Name -ne $ModuleName) { continue }
                    $named = $true
                    # A GUID in the requirement is met only by a kept version whose remaining all-users copy has that GUID.
                    # A copy in a user's folder, or a version that is not installed yet, does not show the GUID of that copy.
                    $candidates = $KeptVersion
                    if ($s.Guid) {
                        $sharedRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
                        $guidVersions = @($Modules | Where-Object { $_.Name -eq $ModuleName -and $_.Guid -eq $s.Guid -and $ExcludePath -notcontains $_.ModuleBase -and
                                (Split-Path -Parent (Split-Path -Parent $_.ModuleBase)) -eq $sharedRoot } | ForEach-Object { $_.Version })
                        $candidates = @($KeptVersion | Where-Object { $guidVersions -contains $_ })
                    }
                    if ($s.RequiredVersion) {
                        $ok = $candidates -contains $s.RequiredVersion
                        $needs = "exactly $($s.RequiredVersion)"
                    } elseif ($s.Version -or $s.MaximumVersion) {
                        $max = $null
                        if ($s.MaximumVersion) { $max = [version]($s.MaximumVersion -replace '\*', '999999999') }
                        $ok = @($candidates | Where-Object { (-not $s.Version -or $_ -ge $s.Version) -and (-not $max -or $_ -le $max) }).Count -gt 0
                        $range = @()
                        if ($s.Version) { $range += "$($s.Version) or later" }
                        if ($s.MaximumVersion) { $range += "at most $($s.MaximumVersion)" }
                        $needs = $range -join ' and '
                    } else { continue }
                    if ($s.Guid) { $needs += " with GUID $($s.Guid)" }
                    if (-not $ok) { [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Needs = "$ModuleName $needs" } }
                }
                if (-not $named) { throw "$ModuleName is required in a form that this check does not read." }
            } catch {
                [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Needs = "a $ModuleName version that could not be read from $($d.Path)" }
            }
        }
    }
    function Test-RepositoryVersion {
        # True when the repository has exactly this version, so it can be installed, or restored after removal, from there.
        param([string]$Name, [version]$Version, [string]$Repository)
        $found = @()
        try { $found = @(Find-Module -Name $Name -RequiredVersion ([string]$Version) -Repository $Repository) } catch { $found = @() }
        ($found.Count -eq 1) -and ((ConvertTo-FullVersion ([string]$found[0].Version)) -eq (ConvertTo-FullVersion $Version))
    }
    $targetFull = ConvertTo-FullVersion $targetVersion
    $before = @(Get-ScopedModuleInventory)
    $before | Select-Object Name, Version, InstalledLocation
    $keptVersions = @($before | Where-Object { (ConvertTo-FullVersion $_.Version) -le $targetFull } | ForEach-Object { [version]$_.Version })
    if (@($before | Where-Object { (ConvertTo-FullVersion $_.Version) -eq $targetFull }).Count -eq 0) { $keptVersions += $targetVersion }
    $toRemove = @($before | Where-Object { (ConvertTo-FullVersion $_.Version) -gt $targetFull })
    if ($toRemove.Count -gt 0) {
        $dependents = @(Get-UnmetDependent -ModuleName $RequiredModuleName -KeptVersion $keptVersions -Modules @(Get-DependentCandidate -Outcome 'No changes were made.'))
        if ($dependents.Count -gt 0) {
            throw ("These installed modules need a version of $RequiredModuleName that this block would remove: " +
                (($dependents | ForEach-Object { "$($_.Name) $($_.Version) needs $($_.Needs)" }) -join '; ') + '. Contact Microsoft Support. No changes were made.')
        }
        # A removed version can be restored only from a repository that has it.
        Get-PSRepository -Name $ApprovedRepository -ErrorAction Stop | Out-Null
        $missing = @($toRemove | Where-Object { -not (Test-RepositoryVersion -Name $RequiredModuleName -Version $_.Version -Repository $ApprovedRepository) })
        if ($missing.Count -gt 0) {
            throw ("These versions would be removed, but $ApprovedRepository does not have them, so they could not be restored: " +
                (($missing | ForEach-Object { "$RequiredModuleName $($_.Version)" }) -join ', ') + '. Use a repository that has them, or contact Microsoft Support. No changes were made.')
        }
    }
    # Install-Module -Force also installs the newest version of each dependency that the repository has, such as Az.Accounts.
    $otherNames = @($recipeAll | ForEach-Object { [string]$_.Name } | Where-Object { $_ -ne $RequiredModuleName })
    $otherBefore = @()
    if ($otherNames.Count -gt 0) { $otherBefore = @(Get-Module -Name $otherNames -ListAvailable | ForEach-Object { $_.ModuleBase }) }
    if (@($before | Where-Object { (ConvertTo-FullVersion $_.Version) -eq $targetFull }).Count -eq 0) {
        Get-PSRepository -Name $ApprovedRepository -ErrorAction Stop | Out-Null
        if (-not (Test-RepositoryVersion -Name $RequiredModuleName -Version $targetVersion -Repository $ApprovedRepository)) {
            throw 'The exact recipe package is unavailable. No changes were made.'
        }
        Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Repository $ApprovedRepository -Scope AllUsers -Force -ErrorAction Stop
    }
    $installed = @(Get-ScopedModuleInventory)
    if (@($installed | Where-Object { (ConvertTo-FullVersion $_.Version) -eq $targetFull }).Count -ne 1) {
        throw 'The exact recipe version was not verified. No versions will be removed.'
    }
    # Install-Module can add modules, so plan the removals again from the refreshed inventory, and count only the
    # versions that are now installed as kept.
    $toRemove = @($installed | Where-Object { (ConvertTo-FullVersion $_.Version) -gt $targetFull })
    $keptVersions = @($installed | Where-Object { (ConvertTo-FullVersion $_.Version) -le $targetFull } | ForEach-Object { [version]$_.Version })
    if ($toRemove.Count -gt 0) {
        $dependents = @(Get-UnmetDependent -ModuleName $RequiredModuleName -KeptVersion $keptVersions -Modules @(Get-DependentCandidate -Outcome 'No versions were removed.'))
        if ($dependents.Count -gt 0) {
            throw ("These installed modules need a version of $RequiredModuleName that this block would remove: " +
                (($dependents | ForEach-Object { "$($_.Name) $($_.Version) needs $($_.Needs)" }) -join '; ') + '. No versions were removed. Contact Microsoft Support.')
        }
        $missing = @($toRemove | Where-Object { -not (Test-RepositoryVersion -Name $RequiredModuleName -Version $_.Version -Repository $ApprovedRepository) })
        if ($missing.Count -gt 0) {
            throw ("These versions would be removed, but $ApprovedRepository does not have them, so they could not be restored: " +
                (($missing | ForEach-Object { "$RequiredModuleName $($_.Version)" }) -join ', ') + '. No versions were removed. Contact Microsoft Support.')
        }
    }
    if (Get-Module -Name $RequiredModuleName) { throw 'The module became loaded. No versions will be removed.' }
    foreach ($module in $toRemove) {
        $current = @(Get-ScopedModuleInventory | Where-Object { [version]$_.Version -eq [version]$module.Version })
        if ($current.Count -ne 1 -or $current[0].InstalledLocation -ne $module.InstalledLocation) {
            throw 'Inventory changed before removal. Stop.'
        }
        Uninstall-Module -Name $RequiredModuleName -RequiredVersion $module.Version -Force -ErrorAction Stop
    }
    $remaining = @(Get-ScopedModuleInventory)
    if (@($remaining | Where-Object { (ConvertTo-FullVersion $_.Version) -eq $targetFull }).Count -ne 1 -or
        @($remaining | Where-Object { (ConvertTo-FullVersion $_.Version) -gt $targetFull }).Count -gt 0) {
        throw 'Module replacement is incomplete. Stop and retain the inventories and error.'
    }
    foreach ($module in @($before | Where-Object { [version]$_.Version -le $targetVersion })) {
        $preserved = @($remaining | Where-Object { [version]$_.Version -eq [version]$module.Version -and
            $_.InstalledLocation -eq $module.InstalledLocation })
        if ($preserved.Count -ne 1) {
            throw 'A previously accepted version or path changed. Stop for Support-led recovery.'
        }
    }
    $remaining | Select-Object Name, Version, InstalledLocation
    $added = @()
    if ($otherNames.Count -gt 0) { $added = @(Get-Module -Name $otherNames -ListAvailable | Where-Object { $otherBefore -notcontains $_.ModuleBase }) }
    $newer = @(foreach ($m in $added) {
        $row = @($recipeAll | Where-Object Name -eq $m.Name)
        if ($row.Count -ne 1 -or -not (([string]$row[0].RequiredVersion) -as [version]) -or
            (ConvertTo-FullVersion $m.Version) -gt (ConvertTo-FullVersion ([string]$row[0].RequiredVersion))) { "$($m.Name) $($m.Version)" }
    })
    if ($newer.Count -gt 0) {
        throw ("$RequiredModuleName now matches the recipe, but Install-Module also installed " + ($newer -join ', ') +
            ', newer than the recipe. Run this block again in a new session for each of those modules, for example with $RequiredModuleName = ''' +
            (($newer[0] -split ' ')[0]) + "'. Do not continue to other modules until then.")
    }
}
```

If installation or the pre-removal inventory fails, stop without uninstalling
any version. If removal or final inventory fails, stop and retain the error for
Microsoft Support. Do not continue to other modules after an error. The one
exception is the error that says `Install-Module also installed` a version newer
than the recipe: the named module is already done, so run this block again for
each module it names, as the error says.
After replacement, run [Verify resolution](#verify-resolution) in a new session.

## Rollback and escalation

There is no automatic rollback for either remediation path in this article.
If import fails, close the session; no module installation has been changed.
If installation, removal, or final validation fails, stop state-changing commands
and contact Microsoft Support with the before/after module inventory, validator
details, and installation errors. Use only the recovery plan agreed before
remediation; do not restore an arbitrary module version or apply a CLI upgrade.
The manual alternative confirmed, before it changed anything, that every version
it removed was available in `$ApprovedRepository`; if the recovery plan restores
one, install that exact version from the same repository with `Install-Module`
and `-RequiredVersion`.

## Verify resolution

Repeat the read-only PASS/FAIL script under
[Issue validation](#issue-validation) on each affected node. Require `Result = PASS`
on every affected node before retrying the update. `FAIL` or an error means
resolution is not verified.

The node-by-node view in [Symptoms](#symptoms) shows the last completed system health check, so
it keeps showing `FAILURE` until a new system health check completes; it is not a resolution check.
Do not start a system health check (`Invoke-SolutionUpdatePrecheck -SystemHealth`) while an update or
another health check is in progress; in the lab one took about 11 to 26 minutes to complete.

If a drift health fault was also present, check it with `Get-HealthFault` after
the next scheduled drift-detection run. An on-demand validator result does not
prove that a previously raised health fault has already cleared.

## Administrator detection surfaces

These rows come from a lab run on 2026-11-24 (solution 12.2701.1004.15, three nodes): a recipe
module was removed from one node, the system health check was started with
`Invoke-SolutionUpdatePrecheck -SystemHealth`, and each surface was checked while the failure was
present, for about 15 minutes, before the module was repaired.

| Surface | Status | Evidence or validation gap |
| --- | --- | --- |
| PowerShell on a node | shown | The validator result and `AdditionalData.Detail`; use the PASS/FAIL script above. A missing module reads `Failed to parse installed version of PS module '<name>' on host '<node>'. Got 'N/A'.` From any node, `Get-SolutionUpdateEnvironment -FullHealthCheckDetails` lists every node's result from the last system health check (block in [Symptoms](#symptoms)). |
| Azure portal | shown | Inferred, not viewed in the portal: the system health check that ran while the module was missing recorded `Test PowerShell Module Version` as `FAILURE` for the affected node and `SUCCESS` for the others in the update service's health check record, which the Azure portal shows under your Azure Local instance > **Updates**. Source: `Get-SolutionUpdateEnvironment -FullHealthCheckDetails`. |
| Windows event logs | shown | Event Viewer > Applications and Services Logs > **AzStackHciEnvironmentChecker**, source `AzStackHciEnvironmentChecker/Telemetry`, Event ID **17205**. Each run writes one event per node whose JSON message has `"Name": "AzStackHci_ValidatedRecipe_PowerShellModule_Version"`; the failing node's event is a Warning with `"Status": 1`, passing nodes are Information with `"Status": 0`. |
| Cluster logs (`Get-ClusterLog`) | not evident | `Get-ClusterLog -TimeSpan 15` from all three nodes (about 65 MB), covering the time the module was missing and a full system health check, contains no entry for this check, its title, or `Test-PSModules`. |
| Windows Failover Cluster Manager | not evident | No node, role, or resource changed state compared with a snapshot taken just before the module was removed, and `Microsoft-Windows-FailoverClustering/Operational` recorded no Critical, Error, or Warning event in the same 15 minutes. The other cluster-tool events in that time were `Microsoft-Windows-FailoverClustering-NetFt/Operational` Event ID 57344 timer-skew warnings and `Microsoft-Windows-FailoverClustering-Manager/Admin` Event ID 4657 errors about a `Get-ClusterParameter` property named `CauResourceName`; neither concerns PowerShell modules. |
| Windows Admin Center (standalone) | shown | Inferred, not viewed in Windows Admin Center: on a node connection, the **Events** tool reads the same **AzStackHciEnvironmentChecker** log, so it carries the Event ID 17205 entry described in the Windows event logs row. The cluster dashboard **Alerts** do not carry this failure: no new Health Service fault was raised while the module was missing (`Get-HealthFault` compared with the snapshot taken just before). The **Updates** tool was not checked. |
| Windows Admin Center in the Azure portal | absent | Not characterized. |
| Component / tool log files | shown | Each system health check writes `HealthCheckResult.EnvironmentChecker.<date-time>.json` to `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System`. In the lab run it listed this check as `FAILURE` for the affected node with the `Failed to parse installed version` detail. A validator run that you start yourself also writes `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log`; retain both for support. |

`absent` denotes an uncharacterized surface, not proof that no signal exists. Health-fault
clearing was not tested.
