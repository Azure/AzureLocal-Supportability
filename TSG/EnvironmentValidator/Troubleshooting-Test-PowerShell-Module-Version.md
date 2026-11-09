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
    "fidelity_level": "L1",
    "technical_grade": null,
    "reproduction_substrate": "hardware",
    "automation_status": "not-assessed",
    "last_validated": "2026-11-06",
    "spec_ref": ""
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
| Execution surface | on-device |
| Validation | Diagnostic commands, detail expansion, installed-module inventory, module discovery/import, and helper availability were exercised on a physical lab node (OS build 26100, Windows PowerShell 5.1) on 2026-11-06. The module check returned PASS. Remediation, manual uninstall/install, failure detection, and health-fault clearing remain untested. |

## Table of contents

- [Overview](#overview)
- [Symptoms](#symptoms)
- [Issue validation](#issue-validation)
- [Contributing factors](#contributing-factors)
- [Mitigation details](#mitigation-details)
- [Rollback and escalation](#rollback-and-escalation)
- [Verify resolution](#verify-resolution)
- [Administrator detection surfaces](#administrator-detection-surfaces)

## Overview

Environment Validator runs a Validated Recipe validator prior to Update. The test detects issues with install components that have drifted from the validated recipe.

Do not infer applicability to disconnected, disaggregated, or multi-rack deployments.
If the validator or remediation helper is absent, stop and obtain release-specific
guidance rather than guessing an installation path.

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


## Issue Validation

### Read-only PASS/FAIL check

**[READ-ONLY]** Run this check on each affected node. Risk is not applicable because
it does not change the installed modules. `PASS` means every returned matching check
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

The installed and expected versions in `AdditionalData.Detail` establish the
mismatch. They do not, by themselves, establish whether an interrupted install,
a dependency change, or another operation introduced it.

## Mitigation Details

### Preconditions

Before changing installed modules:

- Confirm `FAIL` for this check on the target node and record its drift details.
- Use a new, elevated Windows PowerShell session on each affected node. Close
  other PowerShell sessions that may hold the modules being replaced.
- Do not run remediation concurrently with deployment, an update, another
  installation, or scripts that depend on these modules.
- Confirm access to the approved repository and the required recipe versions.
  Stop if downloads or installation are unavailable.
- Obtain a maintenance window and a recovery plan approved by Microsoft Support.
  The helper can uninstall and reinstall modules used by management operations.

### Discover and import the Azure Local Image module

**[LOW RISK]** This changes only the current PowerShell session. It discovers the
highest installed module version, imports its actual path, and checks for the
helper without executing remediation.

```powershell
$imageModule = Get-Module -ListAvailable -Name AzureLocalImageModule |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -eq $imageModule) {
    throw 'AzureLocalImageModule was not found in PSModulePath. Verify the Azure Local Image module installation before continuing.'
}

Import-Module -Name $imageModule.Path -Force -ErrorAction Stop
if (-not (Get-Command -Name Remediate-PSModules -Module AzureLocalImageModule -ErrorAction SilentlyContinue)) {
    throw 'The installed AzureLocalImageModule does not expose Remediate-PSModules. Verify that this node supports the remediation helper before continuing.'
}
```

Expected result: import completes and the helper check does not throw. If it
fails, stop and resolve the prerequisite. Closing this session discards its
module imports; no installation was changed.

### Remediate using the recipe-aware helper

**[HIGH RISK]** Run only after the preconditions above are satisfied. This helper
checks the PowerShell module category against the VSR and attempts to replace
incorrect versions with recipe versions. It can affect more than the first module
named in the validator result. This article does not provide an automatic rollback.

```powershell
$driftResult = Remediate-PSModules -Verbose
$driftResult
```

Inspect the returned result for completion or errors, then run
[Verify resolution](#verify-resolution). An error or a remaining `FAIL` is a stop
condition, not permission to repeatedly uninstall modules.

### Manual alternative for nodes without the helper

**[HIGH RISK]** Use this path only with Microsoft Support guidance and verified
recipe values. The following `Az.Accounts` version is an example from the failure
above, not a version to install on every release. Replace both variables with the
module and required version from the current node's validated recipe. The example
uses `PSGallery` explicitly; use it only if it is the approved source for the
required recipe package, otherwise obtain the approved repository name from
Microsoft Support and replace `PSGallery`.

On each affected node, install the required version only if it is missing, verify
that it is installed, and only then remove the incorrect versions. PowerShell
modules can be installed side by side during this replacement.

```powershell
$RequiredModuleName = 'Az.Accounts'
$RequiredModuleVersion = '4.0.2'

$availableModules = @(Get-Module -Name $RequiredModuleName -ListAvailable -ErrorAction Stop)
if (-not ($availableModules | Where-Object Version -eq $RequiredModuleVersion)) {
    Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Repository PSGallery -Scope AllUsers -Force -ErrorAction Stop
}

$installedModules = @(Get-InstalledModule -Name $RequiredModuleName -AllVersions -ErrorAction Stop)
if (-not ($installedModules | Where-Object Version -eq $RequiredModuleVersion)) {
    throw "Required version $RequiredModuleVersion of $RequiredModuleName was not found. No versions will be removed."
}

$installedModules | Where-Object Version -ne $RequiredModuleVersion | ForEach-Object {
    Uninstall-Module -Name $RequiredModuleName -RequiredVersion $_.Version -Force -ErrorAction Stop
}

$remainingModules = @(Get-InstalledModule -Name $RequiredModuleName -AllVersions -ErrorAction Stop)
if (-not ($remainingModules | Where-Object Version -eq $RequiredModuleVersion) -or
    @($remainingModules | Where-Object Version -ne $RequiredModuleVersion).Count -gt 0) {
    throw "Module replacement is incomplete. Stop and inspect the installed versions of $RequiredModuleName."
}
$remainingModules
```

If installation or the pre-removal inventory fails, stop without uninstalling
any version. If removal or final inventory fails, stop and retain the error for
Microsoft Support. Do not continue to other modules after an error.
After replacement, run [Verify resolution](#verify-resolution) in a new session.

## Rollback and escalation

There is no automatic rollback for either remediation path in this article.
If import fails, close the session; no module installation has been changed.
If installation, removal, or final validation fails, stop state-changing commands
and contact Microsoft Support with the before/after module inventory, validator
details, and installation errors. Use only the recovery plan agreed before
remediation; do not restore an arbitrary module version or apply a CLI upgrade.

## Verify resolution

**[READ-ONLY]** Repeat the PASS/FAIL script under
[Issue validation](#issue-validation) on each affected node. Require `Result = PASS`
on every affected node before retrying the update. `FAIL` or an error means
resolution is not verified.

If a drift health fault was also present, check it with `Get-HealthFault` after
the next scheduled drift-detection run. An on-demand validator result does not
prove that a previously raised health fault has already cleared.

## Administrator detection surfaces

| Surface | Status | Evidence or validation gap |
| --- | --- | --- |
| PowerShell on a node | shown | The validator result and `AdditionalData.Detail`; use the PASS/FAIL script above. |
| Azure portal | absent | Pre-update validation is described above; the current portal presentation was not exercised for this revision. |
| Windows event logs | absent | A failure-event query was not validated for this revision. |
| Cluster logs (`Get-ClusterLog`) | absent | No drift-specific cluster-log query was validated. |
| Windows Failover Cluster Manager | absent | No drift-specific view was validated. |
| Windows Admin Center (standalone) | absent | No drift-specific view was validated. |
| Windows Admin Center in the Azure portal | absent | No drift-specific view was validated. |
| Component / tool log files | shown | The validator writes `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and `AzStackHciEnvironmentReport.json`; retain them for support. |

`absent` denotes an uncharacterized surface, not proof that no signal exists.
These gaps and the untested remediation paths require maintainer validation
before publication.
