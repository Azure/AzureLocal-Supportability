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
    "technical_grade": "B",
    "reproduction_substrate": "either",
    "automation_status": "proven",
    "last_validated": "2026-11-23",
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
| Execution surface | on-device |
| Validation | On 2026-11-23, on a lab cluster (solution 12.2701.1004.15, validator 10.2701.0.2017, Windows PowerShell 5.1), the full loop ran with the recipe-aware helper path: baseline PASS; an injected missing module and, separately, a newer gallery module beside the recipe version each produced FAILURE; the image-module import and helper blocks remediated; and the check returned PASS. The manual alternative ran verbatim on the same build with the helper module temporarily moved out of the module path. With `Az.Accounts` 5.5.5 installed and the recipe version 5.5.3 missing, it installed 5.5.3, removed 5.5.5, kept the older 5.5.1, and the check returned PASS. The live run also showed that current Az modules declare their `Az.Accounts` minimum under `ModuleList`, not `RequiredModules`: the previous dependent-module guard removed `Az.Accounts` 5.5.5 while `Az.Storage` 9.8.0 still needed it, after which importing `Az.Storage` failed with `This module requires Az.Accounts version 5.5.5`. The guard now reads both lists and stopped before any change when `Az.KeyVault` 6.6.2 needed `Az.Accounts` 5.5.4. Health-fault clearing was not tested. |

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
  Stop if downloads or installation are unavailable.
- Obtain a maintenance window and a recovery plan approved by Microsoft Support.
  The helper can uninstall and reinstall modules used by management operations.

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
than the first module named in the validator result. In the 2026-11-23 lab run,
repairing a missing `ArcHci` also reinstalled its dependency modules and removed an
older side-by-side `Az.Accounts` version that was not in the recipe.

> [!WARNING]
> There is no automatic rollback for this helper. Replacing a module that a
> management operation is using can interrupt that operation, so run it only in
> the maintenance window agreed with Microsoft Support.

```powershell
if (-not (Get-Command -Name Remediate-PSModules -Module AzureLocalImageModule -ErrorAction SilentlyContinue)) {
    throw 'The recipe-aware helper is unavailable. Do not run automatic remediation.'
}
$driftResult = Remediate-PSModules -Verbose
$driftResult
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
Windows PowerShell **AllUsers** directory only. Stop for CurrentUser copies,
duplicate paths, unregistered copies, or a module loaded in this session.
Do not use it to replace `PowerShellGet`, `PackageManagement`, or the modules
providing the validator and recipe commands; those require Support-led recovery.
Install the recipe version side by side if missing, verify the exact installed
path, and only then remove versions above the recipe upper bound. Preserve older
versions; this validator message alone does not justify removing them. If the
module is not installed at all, the block stops; use the recipe-aware helper or
contact Microsoft Support. The block also stops, before any change, if another
installed module requires a version newer than the recipe version, because
`Uninstall-Module -Force` skips the dependency check and removing that version
would break the dependent module. The check reads both `RequiredModules` and
`ModuleList`, because current Az modules declare their `Az.Accounts` minimum
under `ModuleList`.

Close other module-dependent PowerShell and remote sessions before starting.
`Remove-Module` does not guarantee that loaded .NET assemblies release file locks.
If installation or removal reports files in use, stop and arrange release of the
owning session with its operator. Do not force-stop management processes, reboot
the node, or delete module folders as a workaround.

**[HIGH RISK]**

**Changes:** For the one module you name, installs the recipe version if it is
missing and uninstalls only versions newer than that recipe version. Older
versions are not changed. When it installs the recipe version, `Install-Module`
may also install modules that the publisher declares as dependencies of that
version, as described in
[Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module).
No other modules are uninstalled.

> [!WARNING]
> There is no automatic rollback for this block. Removing a version that a
> management operation is using can interrupt that operation, so run it only in
> the maintenance window agreed with Microsoft Support.

Run this block as a whole, for example saved as a `.ps1` file. Do not execute
only the install or removal lines; the preceding guards and inventories are
required in the same session.

```powershell
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this block in Windows PowerShell 5.1. No changes were made.' }
$RequiredModuleName = '<module-from-current-failure>'
$ApprovedRepository = '<approved-repository>'

if ($RequiredModuleName -notmatch '^[A-Za-z][A-Za-z0-9.]{0,99}$' -or
    $ApprovedRepository -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$') {
    throw 'Set the affected module and approved repository names. No changes were made.'
}

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
$recipeRows = @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure') -ErrorAction Stop |
    Where-Object Name -eq $RequiredModuleName)
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
        $pathMatches = @($available | Where-Object { [version]$_.Version -eq [version]$module.Version -and $_.ModuleBase -eq $expectedPath })
        if ($module.Name -ne $RequiredModuleName -or $module.InstalledLocation -ne $expectedPath -or $pathMatches.Count -ne 1) {
            throw 'A module path is ambiguous or outside the scoped AllUsers inventory. Stop.'
        }
    }
    return $installed
}
$before = @(Get-ScopedModuleInventory)
$before | Select-Object Name, Version, InstalledLocation
$toRemove = @($before | Where-Object { [version]$_.Version -gt $targetVersion })
if ($toRemove.Count -gt 0) {
    $dependents = @(Get-Module -ListAvailable | Where-Object {
        $_.Name -ne $RequiredModuleName -and @(@($_.RequiredModules) + @($_.ModuleList) | Where-Object {
            $_.Name -eq $RequiredModuleName -and $_.Version -and [version]$_.Version -gt $targetVersion }).Count -gt 0 })
    if ($dependents.Count -gt 0) {
        $dependents | Select-Object Name, Version, ModuleBase
        throw "The modules listed above require a newer $RequiredModuleName than $RequiredModuleVersion. Contact Microsoft Support. No changes were made."
    }
}
if (@($before | Where-Object { [version]$_.Version -eq $targetVersion }).Count -eq 0) {
    Get-PSRepository -Name $ApprovedRepository -ErrorAction Stop | Out-Null
    $package = @(Find-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Repository $ApprovedRepository -ErrorAction Stop)
    if ($package.Count -ne 1 -or $package[0].Name -ne $RequiredModuleName -or [version]$package[0].Version -ne $targetVersion) {
        throw 'The exact recipe package is unavailable. No changes were made.'
    }
    Install-Module -Name $RequiredModuleName -RequiredVersion $RequiredModuleVersion -Repository $ApprovedRepository -Scope AllUsers -Force -ErrorAction Stop
}
$installed = @(Get-ScopedModuleInventory)
if (@($installed | Where-Object { [version]$_.Version -eq $targetVersion }).Count -ne 1) {
    throw 'The exact recipe version was not verified. No versions will be removed.'
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
if (@($remaining | Where-Object { [version]$_.Version -eq $targetVersion }).Count -ne 1 -or
    @($remaining | Where-Object { [version]$_.Version -gt $targetVersion }).Count -gt 0) {
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

Repeat the read-only PASS/FAIL script under
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
These six surfaces and health-fault clearing remain unvalidated.
