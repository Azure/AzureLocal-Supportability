<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Import-Module Az.Accounts, then Import-Module Az.Storage in a new session (as ValidateClusterWitness does): This module requires Az.Accounts version <version>. An earlier version of Az.Accounts is imported in the current PowerShell session."
  },
  "validation": {
    "fidelity_level": "L4",
    "technical_grade": "A",
    "reproduction_substrate": "vm",
    "automation_status": "proven",
    "last_validated": "2026-11-24",
    "spec_ref": "KnownIssue_AzAccounts_ValidatedRecipeMismatch"
  }
}
-->

# Known issue: This module requires Az.Accounts version 5.3.0

## Table of contents

- [Revision history](#revision-history)
- [At a glance](#at-a-glance)
- [Symptoms](#symptoms)
- [Cause](#cause)
- [Where you can see this problem](#where-you-can-see-this-problem)
- [Before you start](#before-you-start)
- [Issue Validation](#issue-validation)
- [Mitigation Details](#mitigation-details)
- [Verify the fix](#verify-the-fix)
- [Rollback](#rollback)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)
- [Validation status of this article](#validation-status-of-this-article)
- [Related documentation](#related-documentation)

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-23 | Removed the fixed module versions (Az.Accounts 4.0.2, Az.Resources 7.8.0, Az.Storage 8.1.0, Az.StackHCI 2.5.0) and the commands that uninstalled every other version. On builds whose validated recipe requires Az.Accounts 5.x, those commands downgraded the product's own modules. The check and the fix now read the exact versions from the machine's validated recipe, install a missing recipe version, and remove only the versions that cause this error. They stop before changing anything when the recipe cannot be read, when another installed module still needs a version that would be removed, or when Azure PowerShell modules are already loaded in the session. |
| 2026-11-23 | Validated on an Azure Local lab machine in Windows PowerShell 5.1, which found and fixed two defects in the earlier 2026-11-23 revision. The checks now read each module's `Az.Accounts` requirement from `ModuleList` as well as `RequiredModules`, because current Az module manifests declare it there; before this fix the check reported `NOT AFFECTED` on an affected machine. Step 2 now lists installed versions one module name at a time, because `Get-InstalledModule -AllVersions` rejects several or wildcard names; before this fix Step 2 stopped with that error before making any change. |
| 2026-11-24 | Added the administrator surfaces observed in a lab run, the `RESULT` lines for each cause, the repository endpoint, and a prevention note. Validated the first cause again as an automated loop. Stated which steps automation can run and that resuming a deployment from the Azure portal needs a person. |
| 2026-11-24 | Step 2 now keeps every version that another installed module requires as an exact version (`RequiredVersion`), not only as a minimum or maximum version. It installs the recipe version of a module for all users when the only copy of that version is in a user's `Documents` folder, before it removes the newer version. After installing, it reads the installed modules again and plans the removals from that list, so that a newer `Az.Accounts` that `Install-Module` adds as a dependency is also removed, and it prints `RESULT: CHANGED` only after it confirms that no newer `Az.Accounts` remains. |

## At a glance

| | |
| --- | --- |
| What happens | An Environment Validator step, reported in the cluster witness check during deployment, fails with `This module requires Az.Accounts version 5.3.0`. The version number in the message can differ. |
| Applies to | Azure Local, any release. The correct module versions depend on the build and come from the machine's validated recipe, not from this article. |
| Severity | High. The operation stays blocked until the module versions are corrected. |
| Who should act | An administrator with local administrator rights on every machine. |
| Time to fix | About 15 minutes per machine, plus the time to retry the operation. No machine restart is needed, virtual machines are not affected, and the retry can follow as soon as every affected machine is fixed. |
| First step | Run the read-only check in [Issue Validation](#issue-validation) on every machine. After the fix, resume the deployment from the Azure portal (**Deployments** > **Resume deployment**). |

## Symptoms

The deployment validation step for the cluster witness fails with an error like this one:

```text
Type 'ValidateClusterWitness' of Role 'EnvironmentValidator' raised an exception:

{
    "ExceptionType":  "text",
    "ErrorMessage":  "This module requires Az.Accounts version 5.3.0. An earlier version of Az.Accounts is imported in the current PowerShell session. Please open a new session before importing this module. This error could indicate that multiple incompatible versions of the Azure PowerShell cmdlets are installed on your system. Please see https://aka.ms/azps-version-error for troubleshooting information.",
    "ExceptionStackTrace":  "at \u003cScriptBlock\u003e, \u003cNo file\u003e: line 8"
}
```

Other steps that load Azure PowerShell modules can show the same message with a different version number. The message comes from the same module check, so the same Issue Validation applies.

## Cause

> [!TIP]
> To prevent this error, do not install or update Azure PowerShell modules (for example with
> `Install-Module Az` or `Update-Module`) on Azure Local machines, other than the exact recipe
> versions that Step 2 of this article installs. Azure Local installs the versions
> its validated recipe needs. Run other Azure PowerShell tooling from a management computer instead.

The validated recipe is the list of exact component versions, including Azure PowerShell modules,
that an Azure Local build is tested with. Each machine can read it locally, and the steps below use it.

Every Azure PowerShell module (for example `Az.Storage` or `Az.Resources`) declares the lowest `Az.Accounts` version it works with. Current versions declare it in the `ModuleList` entry of the module manifest and leave `RequiredModules` empty. When the module is imported, it checks the `Az.Accounts` version that is already loaded in the PowerShell session. If that version is lower, the import stops with this message. The number in the message is the version that the imported module declares, not a version that Azure Local requires.

The cluster witness check imports `Az.Storage` and `Az.Accounts` by name, without a version, so PowerShell loads the highest version installed on the machine. The message therefore means that the machine has an Azure PowerShell module version that needs a newer `Az.Accounts` than the one the session uses. It usually happens in one of these two ways:

- **A module newer than the recipe was installed outside of Azure Local.** For example, `Install-Module Az` or `Install-Module Az.Storage` adds `Az.Storage` 9.2.0, which needs `Az.Accounts` 5.3.0, to a build whose recipe uses an older `Az.Accounts`. The fix is to remove the newer module versions that are not part of the recipe. `Az.Accounts` is not downgraded.
- **The recipe's `Az.Accounts` version is missing.** For example, `Az.Accounts` was downgraded by hand on a build whose recipe requires 5.x, so the product's own modules can no longer load. The fix is to install the exact recipe version of `Az.Accounts` and use a new PowerShell session.

Module versions whose published manifest requires `Az.Accounts` 5.3.0 or later include `Az.Storage` 9.2.0 and later, `Az.Resources` 8.1.1 and later, `Az.StackHCI` 2.6.2 and later, and the `Az` rollup module 14.4.0 and later (PowerShell Gallery package metadata, checked 2026-11-23).

> [!IMPORTANT]
> Do not copy module versions from an older revision of this article, from another article, or from another machine. Different Azure Local builds require different versions. For example, some builds require `Az.Accounts` 4.0.2 and newer builds require `Az.Accounts` 5.x. Installing a fixed older version on a newer build breaks the product's own modules. The steps below read the required versions from each machine's validated recipe.

## Where you can see this problem

Except for the deployment error in the Azure portal row, which comes from the original report, the rows below
come from a lab run on 2026-11-24 (solution 12.2701.1004.15, three machines, recipe
`Az.Accounts` 5.5.3) with the first cause present on one machine: `Az.Storage` 9.8.0 installed
without the `Az.Accounts` 5.5.5 that it needs. The system health check was started with
`Invoke-SolutionUpdatePrecheck -SystemHealth`, and each surface was checked while the state was
present, for about 17 minutes. The second cause was not checked on these surfaces. Surfaces marked `shown`
because of the system health check show its module version finding, which reports any recipe
module newer than the recipe; it is consistent with the first cause but does not show the import error itself.

| Surface | Status | Evidence |
| --- | --- | --- |
| PowerShell on each machine | shown | In a new Windows PowerShell 5.1 session, `Import-Module Az.Accounts` followed by `Import-Module Az.Storage`, which is what the cluster witness check does, fails with `This module requires Az.Accounts version 5.5.5. An earlier version of Az.Accounts is imported in the current PowerShell session.` [Issue Validation](#issue-validation) names the module versions that cause it. |
| Azure portal | shown | The failed deployment step shows the error text from [Symptoms](#symptoms). This comes from the original report that the article was written from; the lab run did not reproduce a failed deployment, so the deployment view was not re-checked. Also inferred, not viewed in the portal: on a deployed system, the system health check recorded `Test PowerShell Module Version` as `FAILURE` for the affected machine with `Checking version of PS module 'Az.Storage' on host '<machine>'. Got '9.8.0' but expected less-than or equal to '9.7.2' so it is invalid.`, in the update service's health check record that the portal shows under your Azure Local instance > **Updates**. Source: `Get-SolutionUpdateEnvironment -FullHealthCheckDetails`. See [Troubleshooting Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md). |
| Windows event logs | shown | The import error itself was not written to any of the 21 event channels scanned, including Application, System, Windows PowerShell, and Microsoft-Windows-PowerShell/Operational. The system health check wrote Event ID **17205** in Applications and Services Logs > **AzStackHciEnvironmentChecker** (source `AzStackHciEnvironmentChecker/Telemetry`) for `AzStackHci_ValidatedRecipe_PowerShellModule_Version`, as a Warning with `"Status": 1` for the affected machine. |
| Cluster logs (`Get-ClusterLog`) | not evident | `Get-ClusterLog -TimeSpan 16` from all three machines (about 66 MB), covering the last 16 minutes of the time the state was present, including a full system health check, contains no entry with `requires Az.Accounts version` or the check name. |
| Windows Failover Cluster Manager | not evident | No machine, role, or resource changed state compared with a snapshot taken just before the change, and `Microsoft-Windows-FailoverClustering/Operational` recorded no Critical, Error, or Warning event in the same time. The only other cluster-tool events were `Microsoft-Windows-FailoverClustering-Manager/Admin` Event ID 4657 errors about a `Get-ClusterParameter` property named `CauResourceName`, which do not concern PowerShell modules. |
| Windows Admin Center (standalone) | shown | Inferred, not viewed in Windows Admin Center: on a node connection, the **Events** tool reads the same **AzStackHciEnvironmentChecker** log, so it carries the Event ID 17205 entry described in the Windows event logs row. The cluster dashboard **Alerts** do not carry this failure: no new Health Service fault was raised while the state was present (`Get-HealthFault` compared with the snapshot taken just before). The **Updates** tool was not checked. |
| Windows Admin Center in the Azure portal | absent | Not characterized. |
| Component / tool log files | shown | The system health check wrote `HealthCheckResult.EnvironmentChecker.<date-time>.json` to `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System`; it lists `Test PowerShell Module Version` as `FAILURE` for the affected machine with the `Az.Storage` 9.8.0 detail. The import error text was not found in files written during that time under the `.AzStackHci` folders, `C:\CloudDeployment\Logs`, or `C:\MASLogs`. |

`absent` marks a surface that was not characterized; it is not proof that the problem does not
appear there.

## Before you start

- Open **Windows PowerShell 5.1** with **Run as administrator** on each machine. Do not use PowerShell 7.
- Start each block below in a **new** PowerShell window. The fix depends on which `Az.Accounts` version a session loads first, and a session that already loaded an Azure PowerShell module keeps that version until it closes.
- Close other PowerShell windows and remote sessions on the machine that you or your team opened and that used Azure PowerShell.
- Make sure no deployment or update step is running. Wait until the operation shows as failed before you change anything.
- If a recipe version needs to be installed, the machine needs access to the PowerShell Gallery or to your organization's approved repository.

## Issue Validation

Run this block in a new elevated Windows PowerShell 5.1 session on each machine. It does not install, remove, or change any module. It reads the machine's validated recipe, lists every installed Azure PowerShell module with the `Az.Accounts` version that it needs, and prints one `RESULT` line.

```powershell
& {
    $recipe = @{}
    $recipeError = $null
    try {
        if (-not (Get-Command -Name Get-ASArtifactPath -ErrorAction SilentlyContinue)) {
            throw 'Get-ASArtifactPath is not available in this session.'
        }
        $artifactPath = Get-ASArtifactPath -NugetName 'Microsoft.AzureStack.VersionControl.Operations' -ErrorAction Stop
        Import-Module (Join-Path $artifactPath 'content\Scripts\VersionControlHelpers.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $rows = @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure') -ErrorAction Stop |
            Where-Object { $_.Name -eq 'Az' -or $_.Name -like 'Az.*' })
        foreach ($row in $rows) {
            $text = [string]$row.RequiredVersion
            if ($text -notmatch '^\d+\.\d+\.\d+(\.\d+)?$' -or $recipe.ContainsKey($row.Name)) {
                throw "The recipe entry for $($row.Name) is invalid or duplicated."
            }
            $recipe[$row.Name] = [version]$text
        }
        if (-not $recipe.ContainsKey('Az.Accounts')) { throw 'The recipe does not list Az.Accounts.' }
    } catch {
        $recipeError = $_.Exception.Message
    }

    $loaded = @(Get-Module -Name 'Az', 'Az.*')
    $accountsTarget = $recipe['Az.Accounts']
    $inventory = foreach ($m in @(Get-Module -Name 'Az', 'Az.*' -ListAvailable)) {
        $needs = @(@($m.RequiredModules) + @($m.ModuleList) | Where-Object { $_.Name -eq 'Az.Accounts' -and [version]$_.Version -gt [version]'0.0' } |
            ForEach-Object { [version]$_.Version } | Sort-Object -Descending) | Select-Object -First 1
        $recipeVersion = $null
        if ($recipe.ContainsKey($m.Name)) { $recipeVersion = $recipe[$m.Name] }
        $finding = ''
        if ($accountsTarget) {
            if ($m.Name -ne 'Az.Accounts' -and $needs -and $needs -gt $accountsTarget) {
                if ($recipeVersion -and [version]$m.Version -gt $recipeVersion) { $finding = 'CAUSE: newer than recipe and needs a newer Az.Accounts' }
                elseif ($recipeVersion) { $finding = 'STOP: recipe conflict' }
                else { $finding = 'Not in recipe; needs a newer Az.Accounts' }
            } elseif ($recipeVersion) {
                if ([version]$m.Version -eq $recipeVersion) { $finding = 'Recipe version' }
                elseif ([version]$m.Version -gt $recipeVersion) { $finding = 'Newer than recipe' }
                else { $finding = 'Older than recipe' }
            }
        }
        [pscustomobject]@{
            Name            = $m.Name
            Version         = [version]$m.Version
            RecipeVersion   = $recipeVersion
            NeedsAzAccounts = $needs
            Finding         = $finding
            Path            = $m.ModuleBase
        }
    }
    $inventory = @($inventory | Sort-Object Name, Version)
    $inventory | Format-Table Name, Version, RecipeVersion, NeedsAzAccounts, Finding, Path -AutoSize | Out-String -Width 300 | Write-Output

    if ($env:SystemRoot) {
        $imageRecipePath = Join-Path $env:SystemRoot 'System32\AzureLocalImage\OSImageRecipe.xml'
        if (Test-Path -LiteralPath $imageRecipePath) {
            try {
                $imageAccounts = @(([xml](Get-Content -LiteralPath $imageRecipePath -Raw)).SelectNodes('/BuildInfo/Packages/Package[Name="Az.Accounts"]') |
                    ForEach-Object { [string]$_.Version }) -join ', '
                Write-Output "INFO: the OS image recipe lists Az.Accounts $imageAccounts. Include this line if you contact Microsoft support."
            } catch {
                Write-Output 'INFO: the OS image recipe could not be read.'
            }
        }
    }
    if ($loaded.Count -gt 0) {
        Write-Output ('NOTE: this session already has ' + (($loaded | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ') + ' loaded. Close it and run this check in a new session.')
    }
    if ($recipeError) {
        Write-Output "RESULT: UNKNOWN - the validated recipe could not be read on this machine: $recipeError Do not change modules on this machine."
    } else {
        $reasons = @()
        if (-not @($inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.Version -eq $accountsTarget })) {
            $reasons += "the recipe version of Az.Accounts ($accountsTarget) is not installed"
        }
        $reasons += @($inventory | Where-Object { $_.Finding -like 'CAUSE*' } |
            ForEach-Object { "$($_.Name) $($_.Version) needs Az.Accounts $($_.NeedsAzAccounts) but the recipe version is $accountsTarget" })
        $allUsersRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
        $otherAccounts = @($inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and
            $_.Path -ne (Join-Path (Join-Path $allUsersRoot 'Az.Accounts') ([string]$_.Version)) })
        if (@($inventory | Where-Object { $_.Finding -like 'STOP*' }).Count -gt 0) {
            Write-Output 'RESULT: UNKNOWN - a recipe module version needs a newer Az.Accounts than the recipe lists. Do not change modules; contact Microsoft support.'
        } elseif ($otherAccounts.Count -gt 0) {
            Write-Output ('RESULT: UNKNOWN - Az.Accounts is also installed outside the all-users module folder (' + (($otherAccounts | ForEach-Object { $_.Path }) -join '; ') +
                '). That copy can load first. Do not change modules; contact Microsoft support.')
        } elseif ($reasons.Count -gt 0) {
            Write-Output ('RESULT: AFFECTED - ' + ($reasons -join '; '))
        } else {
            Write-Output "RESULT: NOT AFFECTED - the recipe version of Az.Accounts ($accountsTarget) is installed and no recipe module needs a newer one."
        }
    }
}
```

Example `RESULT` lines from a lab machine whose recipe lists `Az.Accounts` 5.5.3:

- A newer module: `RESULT: AFFECTED - Az.Storage 9.8.0 needs Az.Accounts 5.5.5 but the recipe version is 5.5.3`
- The recipe `Az.Accounts` missing: `RESULT: AFFECTED - the recipe version of Az.Accounts (5.5.3) is not installed`

How to read the result for each machine:

| Result | Meaning | Next step |
| --- | --- | --- |
| `RESULT: AFFECTED` | The line names what causes the error on this machine. | Follow [Mitigation Details](#mitigation-details) on this machine. |
| `RESULT: NOT AFFECTED` | The modules on this machine do not cause this error. | None on this machine. If no machine is affected, [contact Microsoft support](#when-to-contact-microsoft-support). |
| `RESULT: UNKNOWN` | The required versions could not be established on this machine. | Do not change modules on this machine. [Contact Microsoft support](#when-to-contact-microsoft-support) with the output. |

In the table, `Finding` explains each row:

- `CAUSE: newer than recipe and needs a newer Az.Accounts`: this version causes the error. The fix removes it and keeps the recipe version.
- `Not in recipe; needs a newer Az.Accounts`: a module that Azure Local does not use, for example one installed with `Install-Module Az`. The fix does not remove it, but it stops if removing a newer `Az.Accounts` would break it.
- `Newer than recipe` or `Older than recipe`: not the cause of this error. If the system health check reports `Test PowerShell Module Version`, see [Troubleshooting Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md).
- A row whose `Path` is not under `C:\Program Files\WindowsPowerShell\Modules` is a copy in another module folder, such as a user's `Documents` folder. Such copies can load before the all-users copies. For `Az.Accounts`, the check reports `RESULT: UNKNOWN` in this case, and Step 2 stops without changes.

## Mitigation Details

Run these steps on each machine where Issue Validation reported `RESULT: AFFECTED`.

### Step 1: Open a new session

**Changes:** none. Close the PowerShell window you used for Issue Validation and open a new Windows PowerShell 5.1 window with **Run as administrator**. Do not import or run any Azure PowerShell command in it before Step 2.

### Step 2: Align the Azure PowerShell modules with the recipe

**[HIGH RISK]**

**Changes:** installs the recipe version of `Az.Accounts`, and of any recipe module whose newer version is removed, if that version is missing from `C:\Program Files\WindowsPowerShell\Modules`. A copy only in a user's `Documents` folder does not count, because other users and services cannot load it. It then uninstalls, for recipe modules only, the versions that are newer than the recipe and need a newer `Az.Accounts` than the recipe lists. Last, it uninstalls `Az.Accounts` versions newer than the recipe version, including one that `Install-Module` added as a dependency, so that the recipe version is the one that loads. Older versions and modules that are not in the recipe are not changed. `Install-Module` can also install the dependencies that the publisher declares for a module, as described in [Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module). Each removed version is printed as a `REMOVING:` line, which you need for [Rollback](#rollback).

> [!WARNING]
> Uninstalling a module version cannot be undone, except by installing that version again. If a running process, such as a deployment or update step, is using the version, the operation that uses it can be interrupted. Run this only while no deployment or update step is running.

The block stops before changing anything, and prints `No changes were made`, when any of these is true:

- It is not running in an elevated Windows PowerShell 5.1 session, or an Azure PowerShell module is already loaded in the session.
- The validated recipe cannot be read, does not list `Az.Accounts`, or lists an invalid or duplicated version.
- A copy of `Az.Accounts`, or a copy that would be removed, is outside `C:\Program Files\WindowsPowerShell\Modules` or was not installed with `Install-Module`.
- Another installed module, including modules that are not in the recipe such as the `Az` rollup module, needs a version that would be removed: an exact version (`RequiredVersion`) that would be removed, or a minimum (`ModuleVersion`) or maximum (`MaximumVersion`) version that no remaining version meets. The message names the module. This check reads each module's manifest file (`RequiredModules` and `ModuleList`); a module that enforces a version only inside its own script is not detected. `Uninstall-Module` is run with `-Force` because without it PowerShellGet refuses to remove any version that another module names as a dependency, whatever version that module needs; this check replaces that refusal with an exact version check.
- A version that needs to be installed is not available in the repository.

After it installs a version, the block reads the installed modules again and builds the plan again with the same checks, because `Install-Module` can also install a newer `Az.Accounts` as a dependency. That newer version is then removed as well. If a check fails at that point, the block stops with `The installed versions were kept and no versions were removed`. It prints `RESULT: CHANGED` only after it confirms that the recipe version of `Az.Accounts` is installed for all users and that no newer `Az.Accounts` remains.

Leave `$Repository` set to `'PSGallery'` unless your organization requires an approved internal repository. With the PowerShell Gallery, the machine needs HTTPS access to `www.powershellgallery.com` and to the Gallery's download endpoints listed in [Network access to the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/getting-started#network-access-to-the-powershell-gallery). If a download endpoint is blocked, `Install-Module` fails before any version is removed.

**Paste or run the whole block at once, not line by line.** It runs as one unit so that a failed check stops everything after it.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Repository = 'PSGallery'

    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this block in Windows PowerShell 5.1. No changes were made.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this block in an elevated session (Run as administrator). No changes were made.'
    }
    $azNames = @('Az', 'Az.*')
    $loaded = @(Get-Module -Name $azNames)
    if ($loaded.Count -gt 0) {
        throw ('This session already has ' + (($loaded | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ') +
            ' loaded. Close it, open a new elevated Windows PowerShell session, and run only this block. No changes were made.')
    }

    # Exact versions come from this machine's validated recipe. Without them, nothing is changed.
    if (-not (Get-Command -Name Get-ASArtifactPath -ErrorAction SilentlyContinue)) {
        throw 'The validated recipe cannot be read on this machine (Get-ASArtifactPath is not available). No changes were made.'
    }
    try {
        $artifactPath = Get-ASArtifactPath -NugetName 'Microsoft.AzureStack.VersionControl.Operations'
        Import-Module (Join-Path $artifactPath 'content\Scripts\VersionControlHelpers.psm1') -Force -DisableNameChecking
        $recipeRows = @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure') |
            Where-Object { $_.Name -eq 'Az' -or $_.Name -like 'Az.*' })
    } catch {
        throw "The validated recipe cannot be read on this machine: $($_.Exception.Message) No changes were made."
    }
    $recipe = @{}
    foreach ($row in $recipeRows) {
        $text = [string]$row.RequiredVersion
        if ($text -notmatch '^\d+\.\d+\.\d+(\.\d+)?$' -or $recipe.ContainsKey($row.Name)) {
            throw "The recipe entry for $($row.Name) is invalid or duplicated. No changes were made."
        }
        $recipe[$row.Name] = [version]$text
    }
    if (-not $recipe.ContainsKey('Az.Accounts')) { throw 'The validated recipe does not list Az.Accounts. No changes were made.' }
    $accountsTarget = $recipe['Az.Accounts']
    if (@(Get-Module -Name $azNames).Count -gt 0) {
        throw 'Reading the recipe loaded an Azure PowerShell module. Contact Microsoft support. No changes were made.'
    }

    $allUsersRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
    function Get-AzInventory {
        # PowerShellGet 2.2.5 returns Version as a string, so every comparison casts to [version].
        # -AllVersions accepts only one name without wildcards, so query each installed name separately.
        $managed = @(Get-InstalledModule -Name $azNames -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique |
            ForEach-Object { Get-InstalledModule -Name $_ -AllVersions -ErrorAction SilentlyContinue })
        foreach ($m in @(Get-Module -Name $azNames -ListAvailable)) {
            $expected = Join-Path (Join-Path $allUsersRoot $m.Name) ([string]$m.Version)
            $needs = @(@($m.RequiredModules) + @($m.ModuleList) | Where-Object { $_.Name -eq 'Az.Accounts' -and [version]$_.Version -gt [version]'0.0' } |
                ForEach-Object { [version]$_.Version } | Sort-Object -Descending) | Select-Object -First 1
            [pscustomobject]@{
                Name            = $m.Name
                Version         = [version]$m.Version
                NeedsAzAccounts = $needs
                AllUsers        = ($m.ModuleBase -eq $expected)
                Managed         = (@($managed | Where-Object { $_.Name -eq $m.Name -and [version][string]$_.Version -eq [version]$m.Version -and
                                        $_.InstalledLocation -eq $expected }).Count -eq 1)
                ModuleBase      = $m.ModuleBase
            }
        }
    }
    $inventory = @(Get-AzInventory)
    $inventory | Sort-Object Name, Version | Format-Table Name, Version, NeedsAzAccounts, AllUsers, Managed, ModuleBase -AutoSize |
        Out-String -Width 300 | Write-Output

    $otherAccounts = @($inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and -not $_.AllUsers })
    if ($otherAccounts.Count -gt 0) {
        throw ('Az.Accounts is also installed outside the all-users module folder: ' + (($otherAccounts | ForEach-Object { $_.ModuleBase }) -join '; ') +
            '. That copy can load first. Contact Microsoft support. No changes were made.')
    }

    function Get-UnmetDependent {
        # Lists installed modules whose manifest needs a version of $ModuleName that is not kept: RequiredVersion
        # is an exact version, ModuleVersion a minimum, and MaximumVersion a maximum. The manifest file is read
        # because Get-Module reports an exact RequiredModules version as a minimum.
        param([string]$ModuleName, [version[]]$KeptVersion, [object[]]$Modules, [string[]]$ExcludeKey = @())
        foreach ($d in $Modules) {
            if ($d.Name -eq $ModuleName -or $ExcludeKey -contains "$($d.Name)|$([version]$d.Version)") { continue }
            if (-not @(@($d.RequiredModules) + @($d.ModuleList) | Where-Object { $_ -and $_.Name -eq $ModuleName })) { continue }
            try {
                $data = Import-PowerShellDataFile -LiteralPath $d.Path -ErrorAction Stop
                foreach ($entry in @(@($data.RequiredModules) + @($data.ModuleList) | Where-Object { $_ })) {
                    $s = [Microsoft.PowerShell.Commands.ModuleSpecification]::new($entry)
                    if ($s.Name -ne $ModuleName) { continue }
                    if ($s.RequiredVersion) {
                        $ok = $KeptVersion -contains $s.RequiredVersion
                        $needs = "exactly $($s.RequiredVersion)"
                    } elseif ($s.Version -or $s.MaximumVersion) {
                        $max = $null
                        if ($s.MaximumVersion) { $max = [version]($s.MaximumVersion -replace '\*', '999999999') }
                        $ok = @($KeptVersion | Where-Object { (-not $s.Version -or $_ -ge $s.Version) -and (-not $max -or $_ -le $max) }).Count -gt 0
                        $range = @()
                        if ($s.Version) { $range += "$($s.Version) or later" }
                        if ($s.MaximumVersion) { $range += "at most $($s.MaximumVersion)" }
                        $needs = $range -join ' and '
                    } else { continue }
                    if (-not $ok) { [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Needs = "$ModuleName $needs" } }
                }
            } catch {
                [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Needs = "a $ModuleName version that could not be read from $($d.Path)" }
            }
        }
    }
    # Build the plan and check it against every installed module. The plan is built again after installation,
    # because Install-Module can also install dependencies, such as a newer Az.Accounts.
    function Get-AzPlan {
        param([object[]]$Inventory, [string]$Outcome)
        $installs = @()
        if (-not @($Inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.Version -eq $accountsTarget -and $_.AllUsers })) {
            $installs += [pscustomobject]@{ Name = 'Az.Accounts'; Version = $accountsTarget }
        }
        $removals = @()
        foreach ($m in @($Inventory | Where-Object { $_.Name -ne 'Az.Accounts' -and $_.NeedsAzAccounts -and $_.NeedsAzAccounts -gt $accountsTarget })) {
            if (-not $recipe.ContainsKey($m.Name)) {
                Write-Warning "$($m.Name) $($m.Version) is not in the validated recipe and needs Az.Accounts $($m.NeedsAzAccounts). It is not changed."
                continue
            }
            if ($m.Version -le $recipe[$m.Name]) {
                throw "The recipe version of $($m.Name) needs a newer Az.Accounts than the recipe lists. Contact Microsoft support. $Outcome"
            }
            $removals += $m
            # Only an all-users copy of the recipe version replaces the removed version for every user.
            if (-not @($Inventory | Where-Object { $_.Name -eq $m.Name -and $_.Version -eq $recipe[$m.Name] -and $_.AllUsers }) -and
                -not @($installs | Where-Object { $_.Name -eq $m.Name })) {
                $installs += [pscustomobject]@{ Name = $m.Name; Version = $recipe[$m.Name] }
            }
        }
        $removals += @($Inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.Version -gt $accountsTarget })

        $removalKeys = @($removals | ForEach-Object { "$($_.Name)|$($_.Version)" })
        $allModules = @(Get-Module -ListAvailable)
        foreach ($r in $removals) {
            if (-not $r.AllUsers -or -not $r.Managed) {
                throw "$($r.Name) $($r.Version) at $($r.ModuleBase) was not installed with Install-Module in the all-users folder. Contact Microsoft support. $Outcome"
            }
            $kept = @(@($Inventory | Where-Object { $_.Name -eq $r.Name -and $removalKeys -notcontains "$($_.Name)|$($_.Version)" } | ForEach-Object { $_.Version }) +
                @($installs | Where-Object { $_.Name -eq $r.Name } | ForEach-Object { $_.Version }))
            $dependents = @(Get-UnmetDependent -ModuleName $r.Name -KeptVersion $kept -Modules $allModules -ExcludeKey $removalKeys)
            if ($dependents.Count -gt 0) {
                throw ("These installed modules need a version of $($r.Name) that this fix would remove: " +
                    (($dependents | ForEach-Object { "$($_.Name) $($_.Version) needs $($_.Needs)" }) -join '; ') +
                    ". Decide whether they are still needed, or contact Microsoft support. $Outcome")
            }
        }
        [pscustomobject]@{ Installs = $installs; Removals = $removals }
    }
    $plan = Get-AzPlan -Inventory $inventory -Outcome 'No changes were made.'

    if ($plan.Installs.Count -eq 0 -and $plan.Removals.Count -eq 0) {
        Write-Output 'RESULT: NO CHANGE NEEDED - the modules on this machine do not cause this error. If the error persists, contact Microsoft support.'
        return
    }
    foreach ($i in $plan.Installs) {
        Get-PSRepository -Name $Repository | Out-Null
        $found = @()
        try { $found = @(Find-Module -Name $i.Name -RequiredVersion ([string]$i.Version) -Repository $Repository) } catch { $found = @() }
        if ($found.Count -ne 1 -or [version][string]$found[0].Version -ne $i.Version) {
            throw "$($i.Name) $($i.Version) is not available in $Repository. No changes were made."
        }
    }

    foreach ($i in $plan.Installs) {
        Write-Output "INSTALLING: $($i.Name) $($i.Version)"
        Install-Module -Name $i.Name -RequiredVersion ([string]$i.Version) -Repository $Repository -Scope AllUsers -Force
    }
    if ($plan.Installs.Count -gt 0) {
        $inventory = @(Get-AzInventory)
        foreach ($i in $plan.Installs) {
            if (-not @($inventory | Where-Object { $_.Name -eq $i.Name -and $_.Version -eq $i.Version -and $_.AllUsers -and $_.Managed })) {
                throw "$($i.Name) $($i.Version) could not be verified after installation. No versions were removed."
            }
        }
        $plan = Get-AzPlan -Inventory $inventory -Outcome 'The installed versions were kept and no versions were removed.' 3>$null
        if ($plan.Installs.Count -gt 0) {
            throw 'The installation did not leave the expected modules. The installed versions were kept and no versions were removed. Keep this output and contact Microsoft support.'
        }
    }

    $ordered = @($plan.Removals | Where-Object { $_.Name -ne 'Az.Accounts' }) + @($plan.Removals | Where-Object { $_.Name -eq 'Az.Accounts' })
    foreach ($r in $ordered) {
        if (@(Get-Module -Name $azNames).Count -gt 0) { throw 'An Azure PowerShell module became loaded. Stop; open a new session and run this check again.' }
        $current = @(Get-AzInventory | Where-Object { $_.Name -eq $r.Name -and $_.Version -eq $r.Version -and $_.ModuleBase -eq $r.ModuleBase -and $_.Managed })
        if ($current.Count -ne 1) { throw "$($r.Name) $($r.Version) changed before removal. Stop and run Issue Validation again." }
        Write-Output "REMOVING: $($r.Name) $($r.Version) at $($r.ModuleBase)"
        Uninstall-Module -Name $r.Name -RequiredVersion ([string]$r.Version) -Force
    }

    $final = @(Get-AzInventory)
    $final | Sort-Object Name, Version | Format-Table Name, Version, NeedsAzAccounts, ModuleBase -AutoSize | Out-String -Width 300 | Write-Output
    $left = @($ordered | Where-Object { $r = $_; @($final | Where-Object { $_.Name -eq $r.Name -and $_.Version -eq $r.Version }).Count -gt 0 })
    if ($left.Count -gt 0 -or -not @($final | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.Version -eq $accountsTarget -and $_.AllUsers }) -or
        @($final | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.Version -gt $accountsTarget }).Count -gt 0) {
        throw 'The module changes are incomplete. Keep this output and contact Microsoft support.'
    }
    Write-Output "RESULT: CHANGED - Az.Accounts $accountsTarget is the highest version installed. Close this window; the change takes effect only in new PowerShell sessions."
}
```

Expected result: `RESULT: CHANGED` or `RESULT: NO CHANGE NEEDED`. Any other ending is a stop: keep the output, do not run individual commands from the block by hand, and [contact Microsoft support](#when-to-contact-microsoft-support).

If `Uninstall-Module` reports that a module version is in use, a process still has it loaded. Close the PowerShell windows and remote sessions from [Before you start](#before-you-start) and run Step 2 again in a new session. Do not stop Azure Local services or delete module folders to work around it.

### Step 3: Retry the operation

**Changes:** resumes the operation that failed. After Step 2 completed on every affected machine, run [Issue Validation](#issue-validation) again in a new session on each machine, then retry:

| Operation | How to retry |
| --- | --- |
| Deployment | In the Azure portal, open your Azure Local instance, go to **Deployments**, and select **Resume deployment**. |
| Other operations | Retry the operation the same way you started it. |

**Automation boundary.** A script or an on-box assistant can run [Issue Validation](#issue-validation) and Step 2 on each machine and confirm `RESULT: NOT AFFECTED`. It cannot resume a deployment from the Azure portal: a person signed in to the portal selects **Resume deployment**. An operation that automation started from the machine can be retried by the same automation.

## Verify the fix

- In a new elevated Windows PowerShell 5.1 session, [Issue Validation](#issue-validation) reports `RESULT: NOT AFFECTED` on every machine.
- The retried operation continues past the step that failed.

## Rollback

There is no automatic rollback. To restore a version that Step 2 removed, take the `Name` and `Version` from its `REMOVING:` line and run this in an elevated Windows PowerShell 5.1 session on the same machine.

**Changes:** installs that one module version for all users. It does not remove other versions. Restoring a version that Step 2 removed brings this error back, so restore it only after the operation completes and only if you need it for other work.

```powershell
Install-Module -Name 'module-name-from-REMOVING-line' -RequiredVersion 'version-from-REMOVING-line' -Repository 'PSGallery' -Scope AllUsers -Force
```

Do not uninstall a version that Step 2 installed. It is the version that the machine's validated recipe requires.

## When to contact Microsoft support

Open a support request if any of these is true:

- Issue Validation reports `RESULT: UNKNOWN` on a machine.
- Step 2 stops with a message other than one asking you to open a new session.
- Every machine reports `RESULT: NOT AFFECTED`, but the operation still fails with this error.
- The error returns after the retry.

Include this information:

- The full output of Issue Validation from every machine, before and after the steps you ran.
- The full output of Step 2, including the `INSTALLING:` and `REMOVING:` lines.
- The exact error text and the time it occurred, from the failed step in the Azure portal.
- The Azure Local version that you are deploying or updating to.

## Validation status of this article

On 2026-11-23 this revision was validated on an Azure Local lab machine (solution 12.2701.1004.15, validated recipe `Az.Accounts` 5.5.3) in fresh elevated Windows PowerShell 5.1 sessions. On each of three machines, Issue Validation read the validated recipe and reported `RESULT: NOT AFFECTED`. Two full cycles then ran on one machine, each confirmed by importing `Az.Accounts` and then `Az.Storage` in a new session, as the cluster witness check does:

- A newer `Az.Storage` 9.8.0 without the `Az.Accounts` 5.5.5 that it needs: the import failed with `This module requires Az.Accounts version 5.5.5`. Issue Validation reported `RESULT: AFFECTED - Az.Storage 9.8.0 needs Az.Accounts 5.5.5 but the recipe version is 5.5.3`. Step 2 printed `REMOVING: Az.Storage 9.8.0` and `RESULT: CHANGED`. In a new session the import succeeded and Issue Validation reported `RESULT: NOT AFFECTED`.
- The recipe `Az.Accounts` 5.5.3 removed, leaving 5.5.1: the import failed with `This module requires Az.Accounts version 5.5.2`. Issue Validation reported that the recipe version was not installed. Step 2 printed `INSTALLING: Az.Accounts 5.5.3` and `RESULT: CHANGED`. In a new session the import succeeded and Issue Validation reported `RESULT: NOT AFFECTED`.

With `Az.KeyVault` 6.6.2, which is not in the recipe and needs `Az.Accounts` 5.5.4, installed beside `Az.Accounts` 5.5.5, Step 2 stopped with `No changes were made` and listed `Az.KeyVault`. The module inventory was unchanged.

On 2026-11-24 the first cause ran as an automated loop on the same build. The loop installed `Az.Storage` 9.8.0 without `Az.Accounts` 5.5.5, confirmed the import failure in a new session, ran Step 2 from this article unchanged (`REMOVING: Az.Storage 9.8.0`, `RESULT: CHANGED`), confirmed that the import succeeded in a new session, and verified that every Azure PowerShell module folder matched its state before the test. While the state was present, the system health check and the administrator surfaces were checked; see [Where you can see this problem](#where-you-can-see-this-problem).

Later on 2026-11-24 Step 2 was revised as described in [Revision history](#revision-history). With simulated module folders, not on a cluster, the revised Step 2 stopped with `No changes were made` when another module required exactly a version that would be removed (declared in `ModuleList` or in `RequiredModules`), or a minimum and maximum version that no remaining version met. It installed an all-users copy of `Az.Storage` 9.7.2 when the only copy was in a user's folder, and then removed 9.8.0. When installing `Az.Storage` 9.7.2 also installed a newer `Az.Accounts`, it removed that version as well before it printed `RESULT: CHANGED`, or stopped with `The installed versions were kept and no versions were removed` when another newly installed module required that version. On a lab machine in Windows PowerShell 5.1, the revised dependency check read the installed Az module manifests without reporting any of them and reported a scratch module that required exactly `Az.Accounts` 5.5.5. The automated loop for the first cause then ran again with the revised Step 2 unchanged and passed (`REMOVING: Az.Storage 9.8.0`, `RESULT: CHANGED`), and every Azure PowerShell module folder matched its state before the test.

Not exercised: the second cause inside the automated loop (it was exercised only in the discrete runs on 2026-11-23), the user-folder and dependency-installation cases of Step 2 on a cluster, the rollback command, the portal **Resume deployment** retry in Step 3, and the Windows Admin Center surfaces (the standalone row is inferred, not viewed).

## Related documentation

- [Troubleshooting Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md)
- [Troubleshoot Environment Checker module versions](Troubleshooting-Module-Versions.md)
- [Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module)
- [Uninstall-Module](https://learn.microsoft.com/powershell/module/powershellget/uninstall-module)
- [Deploy Azure Local using the Azure portal](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal)
- [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2)
