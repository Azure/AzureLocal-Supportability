<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "ValidateClusterWitness imports Az.Storage and then Az.Accounts; when an older Az.Accounts is already loaded in the session, Az.Storage raises: This module requires Az.Accounts version <version>. An earlier version of Az.Accounts is imported in the current PowerShell session. Recreate with Import-Module Az.Accounts, then Import-Module Az.Storage, in a new session."
  }
}
-->

# Known issue: This module requires Az.Accounts version 5.3.0

## Table of contents

- [At a glance](#at-a-glance)
- [Revision history](#revision-history)
- [Symptoms](#symptoms)
- [Cause](#cause)
- [Where you can see this problem](#where-you-can-see-this-problem)
- [Before you start](#before-you-start)
- [Issue Validation](#issue-validation)
- [Mitigation Details](#mitigation-details)
- [Verify the fix](#verify-the-fix)
- [Rollback](#rollback)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)
- [Related documentation](#related-documentation)

## At a glance

| | |
| --- | --- |
| What happens | An Environment Validator step, reported in the cluster witness check during deployment, fails with `This module requires Az.Accounts version 5.3.0`. The version number in the message can differ. |
| Applies to | Azure Local, any release. The correct module versions depend on the build and come from the machine's validated recipe, not from this article. |
| Severity | High. The operation stays blocked until the module versions are corrected. |
| Who should act | An administrator with local administrator rights on every machine. |
| Time to fix | About 15 minutes per machine, plus the time to retry the operation. No machine restart is needed, virtual machines are not affected, and the retry can follow as soon as every affected machine is fixed. |
| First step | Run the read-only check in [Issue Validation](#issue-validation) on every machine. After the fix, resume the deployment from the Azure portal (**Deployments** > **Resume deployment**). |

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-23 | Removed the fixed module versions (Az.Accounts 4.0.2, Az.Resources 7.8.0, Az.Storage 8.1.0, Az.StackHCI 2.5.0) and the commands that uninstalled every other version. On builds whose validated recipe requires Az.Accounts 5.x, those commands downgraded the product's own modules. The check and the fix now read the exact versions from the machine's validated recipe, install a missing recipe version, and remove only the versions that cause this error. They stop before changing anything when the recipe cannot be read, when another installed module still needs a version that would be removed, or when Azure PowerShell modules are already loaded in the session. |
| 2026-11-23 | Fixed two defects in the earlier 2026-11-23 revision. The checks now read each module's `Az.Accounts` requirement from `ModuleList` as well as `RequiredModules`, because current Az module manifests declare it there; before this fix the check reported `NOT AFFECTED` on an affected machine. Step 2 now lists installed versions one module name at a time, because `Get-InstalledModule -AllVersions` rejects several or wildcard names; before this fix Step 2 stopped with that error before making any change. |
| 2026-11-24 | Added the administrator surfaces, the `RESULT` lines for each cause, the repository endpoint, and a prevention note. Stated which steps automation can run and that resuming a deployment from the Azure portal needs a person. |
| 2026-11-24 | Step 2 now keeps every version that another installed module requires as an exact version (`RequiredVersion`), not only as a minimum or maximum version. It installs the recipe version of a module for all users when the only copy of that version is in a user's `Documents` folder, before it removes the newer version. After installing, it reads the installed modules again and plans the removals from that list, so that a newer `Az.Accounts` that `Install-Module` adds as a dependency is also removed, and it prints `RESULT: CHANGED` only after it confirms that no newer `Az.Accounts` remains. |
| 2026-11-24 | Issue Validation now reports `RESULT: UNKNOWN` when a module that is not in the recipe needs a newer `Az.Accounts` than any installed version and the recipe version, because this article cannot make that module importable. When another cause is also present, it still reports `RESULT: AFFECTED` and prints a `WARNING:` line for that module; Step 2 prints the same warning. Step 2's dependency check now counts only versions that remain in the all-users module folder, so a copy in a user's `Documents` folder no longer allows a version that other users and services need to be removed. |
| 2026-11-24 | Cause now states that the fix keeps or installs the recipe version of `Az.Accounts` and also removes any `Az.Accounts` version newer than the recipe, after the dependent-module check, so that the recipe version is the one that loads. Rollback now installs from the repository in `$Repository`, the same repository used in Step 2, confirms that the exact removed version is available there before it installs anything, and stops if it is not. |
| 2026-11-24 | Step 2 now confirms, before it installs or removes anything, that every version it would remove is available in the repository in `$Repository`, so that [Rollback](#rollback) can restore it; it repeats this check for a version that installation adds. Its dependency check now also covers modules in every user's `Documents` folder, and treats a requirement that it cannot read, such as one given as a file path, as unmet, so that it stops instead of removing a version that might be needed. It compares versions the way PowerShell does when it loads a module, and treats `5.5.3` and `5.5.3.0` as the same version when it compares installed versions with the recipe or the repository. |
| 2026-11-24 | Corrected the cluster witness check's import order (`Az.Storage`, then `Az.Accounts`), explained that the message means an older `Az.Accounts` was already loaded in the session, described importing `Az.Accounts` first as a way to recreate that state, and named the PowerShell Gallery download hosts in Step 2. Issue Validation now prints `RESULT: NOT AFFECTED` after the `WARNING:` line when the only finding is a module that is not in the recipe and that this article cannot make importable, so a fix that worked is verified instead of ending in `RESULT: UNKNOWN`; it also treats `5.5.3` and `5.5.3.0` as the same version when it compares installed versions with the recipe. Step 2's dependency check now treats a requirement given as a file path as unmet even when another entry names the module, accepts a requirement that names a module GUID only from a remaining version with that GUID, and checks a copy in another user's `Documents` folder even when an all-users copy with the same name and version is removed. Rollback treats `5.5.5` and `5.5.5.0` as the same version when it checks the repository, as Step 2 does. |
| 2026-11-24 | Step 2's dependency check now finds a user's modules in a redirected `Documents` folder, such as one in OneDrive, when that user is signed in, and stops with `No changes were made` when a user's `Documents` folder cannot be found or read, instead of treating a missing folder as having no modules. It also stops when a module names `Az.Accounts` or another module only by a path to its folder or manifest, and it accepts a requirement that names a module GUID only from a remaining all-users copy with that GUID, not from a copy in a user's folder. |
| 2026-11-24 | Step 2 no longer checks the `Documents` folder in the profile folder of a user who is not signed in, because that user's folder can be redirected elsewhere and the modules there would be missed. When it would remove a version and such a user has a profile on the machine, it now stops with `No changes were made` and lists those profiles, so that each user can sign in and stay signed in while it runs. A new setting at the top of the block, `$AssumeDefaultDocumentsForSignedOutUsers`, lets it check the default folder instead, only after your domain or endpoint administrator confirms that folder redirection is not used for those users; it still stops if that folder is missing. Step 2 now also prints `RESULT: NO CHANGE NEEDED` without reading users' folders when it would remove nothing. |
| 2026-11-24 | The Rollback **Changes:** line now says that restoring a module version also installs the dependencies it declares, at the newest version the repository has in the allowed range. |
| 2026-11-24 | Step 2's dependency check now also reads `NestedModules` and stops with `No changes were made` on an entry there that gives a path to the folder or manifest of a version it would remove, because that entry loads only that copy. |
| 2026-11-24 | Step 2's dependency check now applies one rule to every file that a module loads by path. Before it removes anything, and again after it installs a version, it stops with `No changes were made` when any module that remains, including another version of a module that it changes, loads a file from a version it would remove through `RootModule`, `NestedModules`, `RequiredAssemblies`, `ScriptsToProcess`, `TypesToProcess`, `FormatsToProcess`, `FileList`, `RequiredModules`, or `ModuleList`, or loads a file by a path that leaves its own folder and cannot be resolved. Before this change it read only `NestedModules` and did not check other versions of the module that it changed. |
| 2026-11-24 | Step 2's dependency check now stops with `No changes were made` when a module manifest builds a file path with an expression, such as joined strings or `-f`, that it cannot resolve without running the manifest, instead of checking the parts of the path separately. |
| 2026-11-25 | Step 2's dependency check now treats a `NestedModules` entry that names a module with a version (`RequiredVersion`, `ModuleVersion`, or `MaximumVersion`, with or without a module GUID) as a requirement, as it does for `RequiredModules` and `ModuleList`, and stops with `No changes were made` when only a version that it would remove meets the entry. PowerShell loads such an entry from the module path, so the module that lists it cannot be imported once that version is gone; an entry that gives only the module name needs no particular version. The article previously said that these entries did not matter. The check also lists the modules that have such an entry, which `Get-Module` left out of its list when it ran with the block's setting to stop at the first error. The expected result after Step 2, and [When to contact Microsoft support](#when-to-contact-microsoft-support), now send the stops that list users who are not signed in, or ask you to set `$AssumeDefaultDocumentsForSignedOutUsers` to `$false` or `$true`, to the steps for that stop in Step 2; contact Microsoft support only if the block still stops after those users sign in or the setting is changed. |
| 2026-11-25 | Step 2 now lists the installed modules in a separate PowerShell process (a background job) and reads back only their names, versions, paths, and requirements. In Windows PowerShell 5.1, listing them in the Step 2 session loaded the newest installed version of an Azure PowerShell module that another module names in `NestedModules`, and Step 2 then stopped with `An Azure PowerShell module became loaded` on every run, even when a version that it keeps met that entry. If the separate listing fails, Step 2 stops with `No changes were made`. |
| 2026-11-25 | Step 3 now says when to retry: only after Issue Validation, run again unchanged in a new session, reports `RESULT: NOT AFFECTED` on every machine. When a machine reports `RESULT: AFFECTED` or `RESULT: UNKNOWN`, Step 3 now says not to retry, to follow [Mitigation Details](#mitigation-details) first on an affected machine where Step 2 has not run, and otherwise to contact Microsoft support. [When to contact Microsoft support](#when-to-contact-microsoft-support) now lists `RESULT: AFFECTED` after Step 2 ended with `RESULT: CHANGED` or `RESULT: NO CHANGE NEEDED`. Before this change Step 3 said to run Issue Validation again and then retry, without saying what to do when it did not report `RESULT: NOT AFFECTED`. |
| 2026-11-25 | [At a glance](#at-a-glance) now comes before this table. Step 2 now lists, in order, what its block does and what a stop at each point leaves in place, including that a stop after a `REMOVING:` line can leave those versions removed, which [Rollback](#rollback) can restore. In Issue Validation, the `Finding` notes now say that Step 2 also installs the recipe version of a `CAUSE` module when it is missing for all users, and removes an `Az.Accounts` version marked `Newer than recipe`. [Where you can see this problem](#where-you-can-see-this-problem) now describes Windows Admin Center in the Azure portal, inferred from its **Events** tool and not viewed. [Rollback](#rollback) now stops unless it runs in Windows PowerShell 5.1, as Step 2 does: PowerShell 7 can be installed on Azure Local machines, and there `Install-Module` installs for all users in a folder that Windows PowerShell 5.1 does not read, so the block reported `RESTORED:` for a version that the cluster witness check could not load. Issue Validation and Step 2 are unchanged. |

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

During deployment, the cluster witness check runs `Import-Module Az.Storage` and then `Import-Module Az.Accounts`, both by name and without a version. `Az.Storage` raises this message only when an older `Az.Accounts` is already loaded in the session. When no `Az.Accounts` is loaded, `Az.Storage` imports `Az.Accounts` with its own minimum version, and if no installed version meets that minimum, the import fails with a different message: `The specified module 'Az.Accounts' with version '<version>' was not loaded because no valid module file was found in any module directory`. This message therefore means that an older `Az.Accounts` was already loaded in that session before the check imported `Az.Storage`, and that the machine has an Azure PowerShell module version that needs a newer `Az.Accounts` than the one loaded. It usually happens in one of these two ways:

- **A module newer than the recipe was installed outside of Azure Local.** For example, `Install-Module Az` or `Install-Module Az.Storage` adds `Az.Storage` 9.2.0, which needs `Az.Accounts` 5.3.0, to a build whose recipe uses an older `Az.Accounts`. The fix keeps, or installs if it is missing, the recipe version of `Az.Accounts`, and removes the newer module versions that are not part of the recipe. If an `Az.Accounts` version newer than the recipe is also installed, for example one that `Install-Module Az` added, the fix removes it too, after it checks that no other installed module still needs it, so that the recipe version is the one that loads afterward.
- **The recipe's `Az.Accounts` version is missing.** For example, `Az.Accounts` was downgraded by hand on a build whose recipe requires 5.x, so the product's own modules can no longer load. The fix is to install the exact recipe version of `Az.Accounts` and use a new PowerShell session.

Module versions whose published manifest requires `Az.Accounts` 5.3.0 or later include `Az.Storage` 9.2.0 and later, `Az.Resources` 8.1.1 and later, `Az.StackHCI` 2.6.2 and later, and the `Az` rollup module 14.4.0 and later (PowerShell Gallery package metadata, checked 2026-11-23).

> [!IMPORTANT]
> Do not copy module versions from an older revision of this article, from another article, or from another machine. Different Azure Local builds require different versions. For example, some builds require `Az.Accounts` 4.0.2 and newer builds require `Az.Accounts` 5.x. Installing a fixed older version on a newer build breaks the product's own modules. The steps below read the required versions from each machine's validated recipe.

## Where you can see this problem

Except for the deployment error in the Azure portal row, which comes from the original report, the rows below
describe the first cause on one machine of an instance whose recipe lists `Az.Accounts` 5.5.3:
`Az.Storage` 9.8.0 installed without the `Az.Accounts` 5.5.5 that it needs. The system health check
was started with `Invoke-SolutionUpdatePrecheck -SystemHealth`, and each surface was checked while
the state was present, for about 17 minutes. The second cause was not characterized on these surfaces. Surfaces marked `shown`
because of the system health check show its module version finding, which reports any recipe
module newer than the recipe; it is consistent with the first cause but does not show the import error itself.

| Surface | Status | Evidence |
| --- | --- | --- |
| PowerShell on each machine | shown | In a new Windows PowerShell 5.1 session, `Import-Module Az.Accounts` followed by `Import-Module Az.Storage` fails with `This module requires Az.Accounts version 5.5.5. An earlier version of Az.Accounts is imported in the current PowerShell session.` The cluster witness check imports `Az.Storage` first and then `Az.Accounts`; importing `Az.Accounts` first recreates the state in which the check meets this message, an older `Az.Accounts` already loaded in the session. [Issue Validation](#issue-validation) names the module versions that cause it. |
| Azure portal | shown | The failed deployment step shows the error text from [Symptoms](#symptoms). This comes from the original report that the article was written from; the deployment view was not re-checked. Also inferred, not viewed in the portal: on a deployed system, the system health check recorded `Test PowerShell Module Version` as `FAILURE` for the affected machine with `Checking version of PS module 'Az.Storage' on host '<machine>'. Got '9.8.0' but expected less-than or equal to '9.7.2' so it is invalid.`, in the update service's health check record that the portal shows under your Azure Local instance > **Updates**. Source: `Get-SolutionUpdateEnvironment -FullHealthCheckDetails`. See [Troubleshooting Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md). |
| Windows event logs | shown | The import error itself was not written to any of the 21 event channels scanned, including Application, System, Windows PowerShell, and Microsoft-Windows-PowerShell/Operational. The system health check wrote Event ID **17205** in Applications and Services Logs > **AzStackHciEnvironmentChecker** (source `AzStackHciEnvironmentChecker/Telemetry`) for `AzStackHci_ValidatedRecipe_PowerShellModule_Version`, as a Warning with `"Status": 1` for the affected machine. |
| Cluster logs (`Get-ClusterLog`) | not evident | `Get-ClusterLog -TimeSpan 16` from every machine, covering the last 16 minutes of the time the state was present, including a full system health check, contains no entry with `requires Az.Accounts version` or the check name. |
| Windows Failover Cluster Manager | not evident | No machine, role, or resource changed state compared with a snapshot taken just before the change, and `Microsoft-Windows-FailoverClustering/Operational` recorded no Critical, Error, or Warning event in the same time. The only other cluster-tool events were `Microsoft-Windows-FailoverClustering-Manager/Admin` Event ID 4657 errors about a `Get-ClusterParameter` property named `CauResourceName`, which do not concern PowerShell modules. |
| Windows Admin Center (standalone) | shown | Inferred, not viewed in Windows Admin Center: on a node connection, the **Events** tool reads the same **AzStackHciEnvironmentChecker** log, so it carries the Event ID 17205 entry described in the Windows event logs row. The cluster dashboard **Alerts** do not carry this failure: no new Health Service fault was raised while the state was present (`Get-HealthFault` compared with the snapshot taken just before). The **Updates** tool was not checked. |
| Windows Admin Center in the Azure portal | shown | Inferred, not viewed in the Azure portal: [Windows Admin Center in the Azure portal](https://learn.microsoft.com/windows-server/manage/windows-admin-center/azure/manage-hci-clusters) (preview), when its extension is installed on the machines, includes the same **Events** tool, which reads the **AzStackHciEnvironmentChecker** log and so carries the Event ID 17205 entry described in the Windows event logs row. |
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
    function ConvertTo-FullVersion {
        # Missing build and revision numbers count as 0, so 5.5.3 and 5.5.3.0 name the same installed version.
        param([version]$Version)
        [version]::new($Version.Major, $Version.Minor, [math]::Max($Version.Build, 0), [math]::Max($Version.Revision, 0))
    }
    $inventory = foreach ($m in @(Get-Module -Name 'Az', 'Az.*' -ListAvailable)) {
        $needs = @(@($m.RequiredModules) + @($m.ModuleList) | Where-Object { $_.Name -eq 'Az.Accounts' -and [version]$_.Version -gt [version]'0.0' } |
            ForEach-Object { [version]$_.Version } | Sort-Object -Descending) | Select-Object -First 1
        $recipeVersion = $null
        if ($recipe.ContainsKey($m.Name)) { $recipeVersion = $recipe[$m.Name] }
        $finding = ''
        if ($accountsTarget) {
            if ($m.Name -ne 'Az.Accounts' -and $needs -and $needs -gt $accountsTarget) {
                if ($recipeVersion -and (ConvertTo-FullVersion $m.Version) -gt (ConvertTo-FullVersion $recipeVersion)) { $finding = 'CAUSE: newer than recipe and needs a newer Az.Accounts' }
                elseif ($recipeVersion) { $finding = 'STOP: recipe conflict' }
                else { $finding = 'Not in recipe; needs a newer Az.Accounts' }
            } elseif ($recipeVersion) {
                if ((ConvertTo-FullVersion $m.Version) -eq (ConvertTo-FullVersion $recipeVersion)) { $finding = 'Recipe version' }
                elseif ((ConvertTo-FullVersion $m.Version) -gt (ConvertTo-FullVersion $recipeVersion)) { $finding = 'Newer than recipe' }
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
        if (-not @($inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and (ConvertTo-FullVersion $_.Version) -eq (ConvertTo-FullVersion $accountsTarget) })) {
            $reasons += "the recipe version of Az.Accounts ($accountsTarget) is not installed"
        }
        $reasons += @($inventory | Where-Object { $_.Finding -like 'CAUSE*' } |
            ForEach-Object { "$($_.Name) $($_.Version) needs Az.Accounts $($_.NeedsAzAccounts) but the recipe version is $accountsTarget" })
        $allUsersRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
        $otherAccounts = @($inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and
            $_.Path -ne (Join-Path (Join-Path $allUsersRoot 'Az.Accounts') ([string]$_.Version)) })
        # A module outside the recipe that needs a newer Az.Accounts than any installed version and the recipe version
        # cannot be imported, before or after the fix. This article does not change such modules.
        $accountsHighest = @(@($inventory | Where-Object { $_.Name -eq 'Az.Accounts' } | ForEach-Object { $_.Version }) + $accountsTarget |
            Sort-Object -Descending)[0]
        $unmetOther = @($inventory | Where-Object { $_.Finding -like 'Not in recipe*' -and $_.NeedsAzAccounts -gt $accountsHighest } |
            ForEach-Object { "$($_.Name) $($_.Version) is not in the recipe and needs Az.Accounts $($_.NeedsAzAccounts), newer than any installed version and the recipe version ($accountsTarget)" })
        if (@($inventory | Where-Object { $_.Finding -like 'STOP*' }).Count -gt 0) {
            Write-Output 'RESULT: UNKNOWN - a recipe module version needs a newer Az.Accounts than the recipe lists. Do not change modules; contact Microsoft support.'
        } elseif ($otherAccounts.Count -gt 0) {
            Write-Output ('RESULT: UNKNOWN - Az.Accounts is also installed outside the all-users module folder (' + (($otherAccounts | ForEach-Object { $_.Path }) -join '; ') +
                '). That copy can load first. Do not change modules; contact Microsoft support.')
        } else {
            foreach ($u in $unmetOther) {
                Write-Output "WARNING: $u. This article does not change it, and it cannot be imported on this machine. Contact Microsoft support or the owner of that module."
            }
            if ($reasons.Count -gt 0) {
                Write-Output ('RESULT: AFFECTED - ' + ($reasons -join '; '))
            } else {
                Write-Output "RESULT: NOT AFFECTED - the recipe version of Az.Accounts ($accountsTarget) is installed and no recipe module needs a newer one."
            }
        }
    }
}
```

Example `RESULT` lines from a machine whose recipe lists `Az.Accounts` 5.5.3:

- A newer module: `RESULT: AFFECTED - Az.Storage 9.8.0 needs Az.Accounts 5.5.5 but the recipe version is 5.5.3`
- The recipe `Az.Accounts` missing: `RESULT: AFFECTED - the recipe version of Az.Accounts (5.5.3) is not installed`
- A module that is not in the recipe and needs a newer `Az.Accounts` than the machine has, with no other cause present: `WARNING: <module> <version> is not in the recipe and needs Az.Accounts 5.5.4, newer than any installed version and the recipe version (5.5.3). ...`, followed by `RESULT: NOT AFFECTED - the recipe version of Az.Accounts (5.5.3) is installed and no recipe module needs a newer one.` For example, `Az.KeyVault` 6.6.2 needs `Az.Accounts` 5.5.4. With another cause present, the same `WARNING:` line comes before `RESULT: AFFECTED`, and after Step 2 the check reports the `WARNING:` line and `RESULT: NOT AFFECTED`.

How to read the result for each machine:

| Result | Meaning | Next step |
| --- | --- | --- |
| `RESULT: AFFECTED` | The line names what causes the error on this machine. A `WARNING:` line before it names a module that is not in the recipe and that the fix does not repair. | Follow [Mitigation Details](#mitigation-details) on this machine. For a module named in a `WARNING:` line, also [contact Microsoft support](#when-to-contact-microsoft-support) or the owner of that module. |
| `RESULT: NOT AFFECTED` | The modules on this machine do not cause this error. A `WARNING:` line before it names a module that is not in the recipe and needs a newer `Az.Accounts` than any installed version and the recipe version. This article does not fix that module, and removing or installing other modules does not make it importable, but it does not stop the recipe modules from loading. | None on this machine. If no machine is affected, [contact Microsoft support](#when-to-contact-microsoft-support). For a module named in a `WARNING:` line, contact Microsoft support or the owner of that module, and ask which `Az.Accounts` version it supports. |
| `RESULT: UNKNOWN` | The required versions could not be established on this machine: the recipe could not be read, a recipe module version needs a newer `Az.Accounts` than the recipe lists, or `Az.Accounts` is installed outside the all-users module folder. | Do not change modules on this machine. [Contact Microsoft support](#when-to-contact-microsoft-support) with the output. |

In the table, `Finding` explains each row:

- `CAUSE: newer than recipe and needs a newer Az.Accounts`: this version causes the error. The fix removes it and keeps the recipe version, or installs the recipe version for all users if it is missing.
- `Not in recipe; needs a newer Az.Accounts`: a module that Azure Local does not use, for example one installed with `Install-Module Az`. The fix does not remove it, but it stops if removing a newer `Az.Accounts` would break it. If neither an installed `Az.Accounts` version nor the recipe version is new enough for it, the module cannot be imported, and the check prints a `WARNING:` line for it before the `RESULT` line. It does not change the result: `RESULT: NOT AFFECTED` when it is the only finding, and `RESULT: AFFECTED` when another cause is also present.
- `Newer than recipe` or `Older than recipe`: not the cause of this error. On a machine where Issue Validation reports `RESULT: AFFECTED`, Step 2 also removes an `Az.Accounts` version marked `Newer than recipe`, so that the recipe version is the one that loads. It does not change other modules marked `Newer than recipe` or `Older than recipe`. If the system health check reports `Test PowerShell Module Version`, see [Troubleshooting Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md).
- A row whose `Path` is not under `C:\Program Files\WindowsPowerShell\Modules` is a copy in another module folder, such as a user's `Documents` folder. Such copies can load before the all-users copies. For `Az.Accounts`, the check reports `RESULT: UNKNOWN` in this case, and Step 2 stops without changes.

## Mitigation Details

Run these steps on each machine where Issue Validation reported `RESULT: AFFECTED`.

### Step 1: Open a new session

**Changes:** none. Close the PowerShell window you used for Issue Validation and open a new Windows PowerShell 5.1 window with **Run as administrator**. Do not import or run any Azure PowerShell command in it before Step 2.

### Step 2: Align the Azure PowerShell modules with the recipe

**[HIGH RISK]**

**Changes:** installs the recipe version of `Az.Accounts`, and of any recipe module whose newer version is removed, if that version is missing from `C:\Program Files\WindowsPowerShell\Modules`. A copy only in a user's `Documents` folder does not count, because other users and services cannot load it. It then uninstalls, for recipe modules only, the versions that are newer than the recipe and need a newer `Az.Accounts` than the recipe lists. Last, it uninstalls `Az.Accounts` versions newer than the recipe version, including one that `Install-Module` added as a dependency, so that the recipe version is the one that loads. Older versions and modules that are not in the recipe are not changed. Before it installs or removes anything, it confirms that every version it would remove is available in the repository in `$Repository`, so that [Rollback](#rollback) can restore it from there. `Install-Module` can also install the dependencies that the publisher declares for a module, as described in [Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module). Each removed version is printed as a `REMOVING:` line, which you need for [Rollback](#rollback). If it would remove a version while a user who has a profile on the machine is not signed in, it stops before it changes anything, unless you set `$AssumeDefaultDocumentsForSignedOutUsers` as the list below describes.

> [!WARNING]
> Uninstalling a module version cannot be undone, except by installing that version again. If a running process, such as a deployment or update step, is using the version, the operation that uses it can be interrupted. Run this only while no deployment or update step is running.

The block stops before changing anything, and prints `No changes were made`, when any of these is true:

- It is not running in an elevated Windows PowerShell 5.1 session, an Azure PowerShell module is already loaded in the session, or `$AssumeDefaultDocumentsForSignedOutUsers` is not `$false` or `$true`.
- The validated recipe cannot be read, does not list `Az.Accounts`, or lists an invalid or duplicated version.
- A copy of `Az.Accounts`, or a copy that would be removed, is outside `C:\Program Files\WindowsPowerShell\Modules` or was not installed with `Install-Module`.
- Another installed module, including modules that are not in the recipe such as the `Az` rollup module, needs a version that would be removed: an exact version (`RequiredVersion`) that would be removed, or a minimum (`ModuleVersion`) or maximum (`MaximumVersion`) version that no remaining version meets. Only versions that remain in `C:\Program Files\WindowsPowerShell\Modules` count as remaining, because other users and services cannot load a copy in a user's `Documents` folder; a module that only one user needs can therefore also stop the block. The check covers the modules in this session's module path and in every user's `Documents\WindowsPowerShell\Modules` folder. For a signed-in user, it uses the `Documents` folder that Windows records for that user, which can be redirected, for example to OneDrive. For a user who is not signed in, Windows does not show where that folder is redirected, so the block stops, as the next item describes. The message names the module. This check reads each module's manifest file (`RequiredModules`, `ModuleList`, and `NestedModules`); a module that enforces a version only inside its own script is not detected. The block lists these modules in a separate PowerShell process, so that listing them loads no module into the session that removes versions; if that listing fails, the block stops. A `NestedModules` entry that names a module with a version (`RequiredVersion`, `ModuleVersion`, or `MaximumVersion`) is a requirement in the same way, because PowerShell loads that module from the module path and the module that lists it fails to import when no remaining version meets the entry; an entry that gives only the module name needs no particular version. `Uninstall-Module` is run with `-Force` because without it PowerShellGet refuses to remove any version that another module names as a dependency, whatever version that module needs; this check replaces that refusal with an exact version check.
- Any module that remains, including another version of a module that the block changes, loads a file by path from a version that would be removed, or by a path that leaves its own folder and cannot be resolved, such as one that uses an environment variable that is not set. The block reads these paths in each remaining manifest's `RootModule`, `NestedModules`, `RequiredAssemblies`, `ScriptsToProcess`, `TypesToProcess`, `FormatsToProcess`, `FileList`, `RequiredModules`, and `ModuleList` entries, and the message names the module and the path. A `NestedModules` entry that names a module, rather than giving a path, is checked as a version requirement, as the previous item describes.
- A version would be removed, and a user who has a profile on the machine is not signed in, so where that user's `Documents` folder is, which can be redirected, cannot be read. Accepting the `Documents` folder in that user's profile folder instead could miss modules in a redirected folder, and allow a version that one of them needs to be removed. The message lists those profiles by security identifier (SID); `Get-CimInstance -ClassName Win32_UserProfile | Where-Object SID -eq '<SID>' | Select-Object LocalPath, Loaded` shows each profile's folder. Have each listed user sign in, and stay signed in, or keep a session such as a disconnected Remote Desktop session, while the block runs; then run the block again. Only if your domain or endpoint administrator confirms that `Documents` folder redirection is not used for those users, change `$AssumeDefaultDocumentsForSignedOutUsers = $false` to `$true` at the top of the block; the block then checks the `Documents` folder in each listed profile folder instead, and still stops if that folder does not exist.
- A user's `Documents` folder cannot be found or read, so modules there cannot be checked. This includes a redirected folder that this session cannot reach and, when `$AssumeDefaultDocumentsForSignedOutUsers` is `$true`, a profile of a user who is not signed in without a `Documents` folder. Service profiles, such as the system profile, are not checked. The message names the profile by its SID. If that user is not signed in, have the user sign in, and stay signed in while the block runs, then run the block again; otherwise contact Microsoft support.
- A version that needs to be installed, or a version that would be removed, is not available in the repository in `$Repository`. The message names the versions. Set `$Repository` to a repository that has them, or contact Microsoft support.

The dependency check fails closed: when it cannot show that a requirement is still met, for example because a manifest cannot be read or names any module by a file path, including an entry that is only a path to the module's folder or manifest, it treats the requirement as unmet and stops with `No changes were made`. A requirement that also names a module GUID is met only by a remaining all-users copy whose manifest has that GUID; a copy in a user's `Documents` folder, or a version that the block has not installed yet, does not count. A copy of a module in another user's `Documents` folder is checked even when an all-users copy with the same name and version would be removed. It compares versions the way PowerShell does when it loads a module, so a module that requires exactly `5.5.5.0` is not satisfied by version `5.5.5`. When it compares installed versions with the recipe or the repository, it treats a missing build or revision number as 0, so `5.5.3` and `5.5.3.0` are the same version.

The block works in this order. Its output shows how far it got, and so what a stop left in place:

1. It checks the session, reads the validated recipe, and prints a table of the installed Azure PowerShell modules.
2. It plans the change and runs the checks in the list above against the plan, including the repository check. If nothing needs to change, it prints `RESULT: NO CHANGE NEEDED` and ends. If it stops at or before this point, nothing was changed.
3. It installs each missing recipe version and prints an `INSTALLING:` line for it. It then reads the installed modules again and builds the plan again with the same checks, because `Install-Module` can also install a newer `Az.Accounts` as a dependency; that newer version is then removed as well. A stop here keeps what it installed and removes nothing, for example `The installed versions were kept and no versions were removed`.
4. It removes the planned versions, other modules first and `Az.Accounts` last, and prints a `REMOVING:` line before each one. If it stops here, treat every version on a `REMOVING:` line as possibly removed: keep the output, and use those lines for [Rollback](#rollback) if you need to restore a version.
5. It reads the installed modules again and prints `RESULT: CHANGED` only after it confirms that the recipe version of `Az.Accounts` is installed for all users and that no newer `Az.Accounts` remains.

If a module that is not in the recipe needs a newer `Az.Accounts` than the recipe version, the block prints a `WARNING:` line that names it, as Issue Validation does, and does not change it. That module cannot be imported after the fix; contact Microsoft support or the owner of that module about it.

Leave `$Repository` set to `'PSGallery'` unless your organization requires an approved internal repository. With the PowerShell Gallery, the machine needs HTTPS access to `www.powershellgallery.com` and to the hosts that [Network access to the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/getting-started#network-access-to-the-powershell-gallery) lists for package discovery and download, `cdn.powershellgallery.com` and `cdn.oneget.org`. The Gallery redirects package downloads to `cdn.powershellgallery.com`. The block's repository check uses `Find-Module`, which confirms that a version is in the repository but not that the machine can download it, so confirm that these hosts are allowed before you run the block. If a download host is blocked, `Install-Module` fails before any version is removed.

**Paste or run the whole block at once, not line by line.** It runs as one unit so that a failed check stops everything after it.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Repository = 'PSGallery'
    # Leave $false unless your domain or endpoint administrator confirms that Documents folder redirection is not
    # used for the users that the block lists as not signed in.
    $AssumeDefaultDocumentsForSignedOutUsers = $false

    if ($AssumeDefaultDocumentsForSignedOutUsers -isnot [bool]) { throw 'Set $AssumeDefaultDocumentsForSignedOutUsers to $false or $true. No changes were made.' }
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
    function ConvertTo-FullVersion {
        # Missing build and revision numbers count as 0, so 5.5.3 and 5.5.3.0 name the same installed version.
        param([version]$Version)
        [version]::new($Version.Major, $Version.Minor, [math]::Max($Version.Build, 0), [math]::Max($Version.Revision, 0))
    }
    $accountsFull = ConvertTo-FullVersion $accountsTarget
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
                FullVersion     = ConvertTo-FullVersion $m.Version
                NeedsAzAccounts = $needs
                AllUsers        = ($m.ModuleBase -eq $expected)
                Managed         = (@($managed | Where-Object { $_.Name -eq $m.Name -and (ConvertTo-FullVersion ([string]$_.Version)) -eq (ConvertTo-FullVersion $m.Version) -and
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
        $userFolders = @(foreach ($m in @($userPaths | Where-Object { Test-Path -LiteralPath $_ })) {
            try { Get-ChildItem -LiteralPath $m -Directory | ForEach-Object { $_.FullName } }
            catch { throw "The module folder $m could not be read: $($_.Exception.Message) Contact Microsoft Support. $Outcome" }
        })
        # Get-Module lists a module whose NestedModules entry names another module with a version only while errors do not
        # stop it, because PowerShell first looks for that module in the listing module's own folder and reports an error.
        # Windows PowerShell 5.1 then also imports the named module into the session that lists it, and its files stay locked
        # by that process. So the modules are listed in a separate PowerShell process (a job), which returns only plain values,
        # and nothing is loaded into this session. The job must finish and end with $end; if it does not, the block stops.
        $end = 'End of the module list.'
        $job = $null
        $listed = @()
        try {
            $job = Start-Job -ArgumentList $env:PSModulePath, $userFolders, $end -ScriptBlock {
                param([string]$ModulePath, [string[]]$Folders, [string]$End)
                $env:PSModulePath = $ModulePath
                $ErrorActionPreference = 'Continue'
                @(Get-Module -ListAvailable) + @(foreach ($f in $Folders) { Get-Module -Name $f -ListAvailable }) | ForEach-Object {
                    [pscustomobject]@{ Name = $_.Name; Version = [string]$_.Version; Path = $_.Path; ModuleBase = $_.ModuleBase; Guid = [string]$_.Guid
                        RequiredModules = @($_.RequiredModules | ForEach-Object { [string]$_.Name }); ModuleList = @($_.ModuleList | ForEach-Object { [string]$_.Name }) }
                }
                $End
            }
            # Errors that Get-Module reports for single modules are expected, as above, so they are not shown here.
            $listed = @(Receive-Job -Job $job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue)
        } catch { $listed = @() }
        if (-not $job -or $job.State -ne 'Completed' -or $listed.Count -lt 2 -or $listed[-1] -ne $end) {
            throw "The installed modules could not be listed in a separate PowerShell process. Contact Microsoft Support. $Outcome"
        }
        @($listed[0..($listed.Count - 2)] | ForEach-Object {
                [pscustomobject]@{ Name = $_.Name; Version = $_.Version -as [version]; Path = $_.Path; ModuleBase = $_.ModuleBase; Guid = $_.Guid -as [guid]
                    RequiredModules = @($_.RequiredModules | ForEach-Object { [pscustomobject]@{ Name = $_ } })
                    ModuleList = @($_.ModuleList | ForEach-Object { [pscustomobject]@{ Name = $_ } }) }
            } | Sort-Object Path -Unique)
    }
    function Get-UnmetDependent {
        # Lists installed modules whose manifest needs a version of $ModuleName that is not kept: RequiredVersion
        # is an exact version, ModuleVersion a minimum, and MaximumVersion a maximum. The manifest file is read
        # because Get-Module reports an exact RequiredModules version as a minimum. Versions are compared as
        # PowerShell compares them when it loads a module. RequiredModules, ModuleList, and NestedModules entries that name
        # the module are read; a NestedModules entry that gives only the name needs no particular version. A requirement
        # that cannot be read is reported as unmet.
        # ExcludePath lists the module folders that are removed in the same change, so they need nothing.
        param([string]$ModuleName, [version[]]$KeptVersion, [object[]]$Modules, [string[]]$ExcludePath = @())
        foreach ($d in $Modules) {
            if ($d.Name -eq $ModuleName -or $ExcludePath -contains $d.ModuleBase) { continue }
            # An entry given as a path names the module by its folder or file name; it is read too, so that the path check stops on it.
            $pathPattern = "(^|[\\/])$([regex]::Escape($ModuleName))([\\/]|\.(psd1|psm1|dll)$|$)"
            $listed = @(@($d.RequiredModules) + @($d.ModuleList) | Where-Object { $_ -and ($_.Name -eq $ModuleName -or
                    ($_.Name -match '[\\/]|\.(psd1|psm1|dll)$' -and $_.Name -match $pathPattern)) }).Count -gt 0
            # A NestedModules entry that names the module with a version is a requirement too: PowerShell loads it from the
            # module path, and the module fails to import when no installed version meets it. Get-Module does not list such
            # an entry, so a manifest whose text names the module is read as well, and a manifest whose text cannot be read is
            # reported. NestedModules entries that give a path are checked by Get-RemovedFileReference.
            $mentioned = $false
            if (-not $listed -and $d.Path -like '*.psd1') {
                try { $mentioned = [IO.File]::ReadAllText($d.Path) -match "(?<![\w.-])$([regex]::Escape($ModuleName))(?![\w-])" } catch { $mentioned = $true }
            }
            if (-not ($listed -or $mentioned)) { continue }
            try {
                try { $data = Import-PowerShellDataFile -LiteralPath $d.Path -ErrorAction Stop }
                catch {
                    if ($listed) { throw }
                    # A manifest that chooses a value with an expression, such as an if on $PSEdition, is not a data file. Without
                    # running it, each module specification that names the module, in any branch, is read from the parsed text.
                    $ast = [Management.Automation.Language.Parser]::ParseFile($d.Path, [ref]$null, [ref]$null)
                    $data = @{ NestedModules = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.HashtableAst] -and
                                @($n.KeyValuePairs | Where-Object { "$($_.Item1.Value)" -eq 'ModuleName' -and $_.Item2.Extent.Text.Trim('''"') -eq $ModuleName }).Count -gt 0 }, $true) |
                            ForEach-Object { $_.SafeGetValue() }) }
                }
                $named = $false
                $nestedEntries = @(@($data.NestedModules) | Where-Object { $_ -and ([Microsoft.PowerShell.Commands.ModuleSpecification]::new($_)).Name -eq $ModuleName })
                foreach ($entry in @(@(@($data.RequiredModules) + @($data.ModuleList) | Where-Object { $_ }) + $nestedEntries)) {
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
                # A manifest that only mentions the module, for example in its description, needs nothing.
                if (-not $named -and $listed) { throw "$ModuleName is required in a form that this check does not read." }
            } catch {
                [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Needs = "a $ModuleName version that could not be read from $($d.Path)" }
            }
        }
    }
    function Get-RemovedFileReference {
        # Lists every remaining module whose manifest loads a file from a module folder that is removed in the same change,
        # including other versions of the module being changed and modules in users' folders. ExcludePath lists the removed
        # folders; only modules in those folders are skipped. It reads RootModule (ModuleToProcess), NestedModules,
        # RequiredAssemblies, ScriptsToProcess, TypesToProcess, FormatsToProcess, FileList, RequiredModules, and ModuleList,
        # and resolves each entry from that manifest's folder. An entry inside that folder is fine. An entry that cannot be
        # resolved, and could lead out of that folder ('..', a full path, or an environment variable), is reported as well.
        # To stay fast, a manifest is read only when its text names a removed folder or has such a path.
        param([object[]]$Modules, [string[]]$ExcludePath = @())
        $sep = [IO.Path]::DirectorySeparatorChar
        $removed = @($ExcludePath | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFullPath(($_ -replace '[\\/]', $sep)).TrimEnd($sep) })
        if ($removed.Count -eq 0) { return }
        $hint = (@($removed | ForEach-Object { [regex]::Escape((Split-Path -Leaf $_)) }) +
            @('\.\.', '[%$~]', '(?<![A-Za-z0-9])[A-Za-z]:[\\/]', '[''"]\s*[\\/]')) -join '|'
        $envPattern = [regex]::new('\$\{?env:(\w+)\}?', 'IgnoreCase')
        $isUnder = { param([string]$Path) @($removed | Where-Object { $Path.Equals($_, [StringComparison]::OrdinalIgnoreCase) -or
                $Path.StartsWith($_ + $sep, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 }
        foreach ($d in $Modules) {
            if ($d.Path -notlike '*.psd1') { continue }
            $base = [IO.Path]::GetFullPath(([string]$d.ModuleBase -replace '[\\/]', $sep)).TrimEnd($sep)
            if (& $isUnder $base) { continue }
            try {
                if ([IO.File]::ReadAllText($d.Path) -notmatch $hint) { continue }
                try { $data = Import-PowerShellDataFile -LiteralPath $d.Path -ErrorAction Stop }
                catch {
                    # A manifest that picks a value with code, such as an if on $PSEdition, cannot be read as data. Its text is
                    # parsed instead, without running it, and every string in a field below counts, in whichever branch it is.
                    $parseErrors = $null
                    $table = [Management.Automation.Language.Parser]::ParseFile($d.Path, [ref]$null, [ref]$parseErrors).Find({ param($n)
                            $n -is [Management.Automation.Language.HashtableAst] }, $true)
                    if (@($parseErrors).Count -gt 0 -or -not $table) { throw }
                    $data = @{}
                    $fileKeys = 'RootModule', 'ModuleToProcess', 'NestedModules', 'RequiredAssemblies', 'ScriptsToProcess',
                        'TypesToProcess', 'FormatsToProcess', 'FileList', 'RequiredModules', 'ModuleList'
                    foreach ($pair in $table.KeyValuePairs) {
                        $key = [string]$pair.Item1.Value
                        # A file field whose value is built by an expression (joined strings, -f, a method call, or a
                        # string that embeds anything other than $env:NAME) cannot be resolved without running it, so it stops the block.
                        if ($fileKeys -contains $key -and @($pair.Item2.FindAll({ param($n)
                                    ($n -is [Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -in 'Plus', 'Format', 'Join') -or
                                    $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -or $n -is [Management.Automation.Language.SubExpressionAst] -or
                                    ($n -is [Management.Automation.Language.ExpandableStringExpressionAst] -and @($n.NestedExpressions | Where-Object {
                                            -not ($_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.VariablePath.DriveName -eq 'env') }).Count -gt 0) }, $true)).Count -gt 0) {
                            $data[$key] = @('$computed-path')
                            continue
                        }
                        $data[$key] = @($pair.Item2.FindAll({ param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -or
                                $n -is [Management.Automation.Language.ExpandableStringExpressionAst] }, $true) | ForEach-Object { $_.Value })
                    }
                }
            } catch {
                [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Reference = "a file that could not be read from $($d.Path)" }
                continue
            }
            $refs = @(foreach ($key in 'RootModule', 'ModuleToProcess', 'NestedModules', 'RequiredAssemblies', 'ScriptsToProcess',
                    'TypesToProcess', 'FormatsToProcess', 'FileList', 'RequiredModules', 'ModuleList') {
                foreach ($e in @($data[$key])) { if ($e -is [hashtable]) { [string]$e.ModuleName } elseif ($e) { [string]$e } }
            })
            foreach ($ref in @($refs | Where-Object { $_ })) {
                $leaves = $ref -match '\.\.|[%$]|^\s*([\\/]|[A-Za-z]:)'
                # Environment variables are expanded in both forms, $env:NAME and %NAME%.
                $expanded = $envPattern.Replace(($ref -replace '[\\/]', $sep), [Text.RegularExpressions.MatchEvaluator] { param($m)
                        $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value); if ($null -eq $v) { $m.Value } else { $v } })
                $expanded = [Environment]::ExpandEnvironmentVariables($expanded)
                $full = $null
                # Another variable, an environment variable that is not set, or a short (8.3) name on such a path cannot be resolved here.
                if ($expanded -notmatch '[%$]' -and -not ($leaves -and $expanded -match '~')) {
                    try { $full = [IO.Path]::GetFullPath([IO.Path]::Combine($base, $expanded)).TrimEnd($sep) } catch { $full = $null }
                }
                if ($null -eq $full) {
                    if ($leaves) { [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Reference = "$ref, a path that cannot be resolved" } }
                } elseif (& $isUnder $full) {
                    [pscustomobject]@{ Name = $d.Name; Version = $d.Version; Reference = $full }
                }
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
    # Build the plan and check it against every installed module. The plan is built again after installation,
    # because Install-Module can also install dependencies, such as a newer Az.Accounts.
    function Get-AzPlan {
        param([object[]]$Inventory, [string]$Outcome)
        $installs = @()
        if (-not @($Inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.FullVersion -eq $accountsFull -and $_.AllUsers })) {
            $installs += [pscustomobject]@{ Name = 'Az.Accounts'; Version = $accountsTarget }
        }
        $removals = @()
        foreach ($m in @($Inventory | Where-Object { $_.Name -ne 'Az.Accounts' -and $_.NeedsAzAccounts -and $_.NeedsAzAccounts -gt $accountsTarget })) {
            if (-not $recipe.ContainsKey($m.Name)) {
                Write-Warning ("$($m.Name) $($m.Version) is not in the validated recipe and needs Az.Accounts $($m.NeedsAzAccounts), newer than the recipe version $accountsTarget. " +
                    'This fix does not change it, and it cannot be imported after the fix. Contact Microsoft support or the owner of that module.')
                continue
            }
            if ($m.FullVersion -le (ConvertTo-FullVersion $recipe[$m.Name])) {
                throw "The recipe version of $($m.Name) needs a newer Az.Accounts than the recipe lists. Contact Microsoft support. $Outcome"
            }
            $removals += $m
            # Only an all-users copy of the recipe version replaces the removed version for every user.
            if (-not @($Inventory | Where-Object { $_.Name -eq $m.Name -and $_.FullVersion -eq (ConvertTo-FullVersion $recipe[$m.Name]) -and $_.AllUsers }) -and
                -not @($installs | Where-Object { $_.Name -eq $m.Name })) {
                $installs += [pscustomobject]@{ Name = $m.Name; Version = $recipe[$m.Name] }
            }
        }
        $removals += @($Inventory | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.FullVersion -gt $accountsFull })

        $removalPaths = @($removals | ForEach-Object { $_.ModuleBase })
        $allModules = @()
        if ($removals.Count -gt 0) { $allModules = @(Get-DependentCandidate -Outcome $Outcome) }
        foreach ($r in $removals) {
            if (-not $r.AllUsers -or -not $r.Managed) {
                throw "$($r.Name) $($r.Version) at $($r.ModuleBase) was not installed with Install-Module in the all-users folder. Contact Microsoft support. $Outcome"
            }
            # Only all-users copies count as kept: a copy in a user's Documents folder is not available to other accounts or services.
            $kept = @(@($Inventory | Where-Object { $_.Name -eq $r.Name -and $_.AllUsers -and $removalPaths -notcontains $_.ModuleBase } | ForEach-Object { $_.Version }) +
                @($installs | Where-Object { $_.Name -eq $r.Name } | ForEach-Object { $_.Version }))
            $dependents = @(Get-UnmetDependent -ModuleName $r.Name -KeptVersion $kept -Modules $allModules -ExcludePath $removalPaths)
            if ($dependents.Count -gt 0) {
                throw ("These installed modules need a version of $($r.Name) that this fix would remove: " +
                    (($dependents | ForEach-Object { "$($_.Name) $($_.Version) needs $($_.Needs)" }) -join '; ') +
                    ". Decide whether they are still needed, or contact Microsoft support. $Outcome")
            }
        }
        # Every remaining manifest, including other versions of the same module, must not load a file from a removed folder.
        $fileReferences = @(Get-RemovedFileReference -Modules $allModules -ExcludePath $removalPaths)
        if ($fileReferences.Count -gt 0) {
            throw ("These installed modules load a file from a version that this fix would remove: " +
                (($fileReferences | ForEach-Object { "$($_.Name) $($_.Version) loads $($_.Reference)" }) -join '; ') +
                ". Decide whether they are still needed, or contact Microsoft support. $Outcome")
        }
        # Rollback reinstalls a removed version from $Repository, so every version to remove must be available there.
        if ($removals.Count -gt 0) {
            try { Get-PSRepository -Name $Repository | Out-Null } catch { throw "The repository $Repository is not registered on this machine. $Outcome" }
            $missing = @($removals | Where-Object { -not (Test-RepositoryVersion -Name $_.Name -Version $_.Version -Repository $Repository) })
            if ($missing.Count -gt 0) {
                throw ("These versions would be removed, but $Repository does not have them, so they could not be restored: " +
                    (($missing | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ') +
                    ". Use a repository that has them, or contact Microsoft support. $Outcome")
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
        if (-not (Test-RepositoryVersion -Name $i.Name -Version $i.Version -Repository $Repository)) {
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
            if (-not @($inventory | Where-Object { $_.Name -eq $i.Name -and $_.FullVersion -eq (ConvertTo-FullVersion $i.Version) -and $_.AllUsers -and $_.Managed })) {
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
    if ($left.Count -gt 0 -or -not @($final | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.FullVersion -eq $accountsFull -and $_.AllUsers }) -or
        @($final | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.FullVersion -gt $accountsFull }).Count -gt 0) {
        throw 'The module changes are incomplete. Keep this output and contact Microsoft support.'
    }
    Write-Output "RESULT: CHANGED - Az.Accounts $accountsTarget is the highest version installed. Close this window; the change takes effect only in new PowerShell sessions."
}
```

Expected result: `RESULT: CHANGED` or `RESULT: NO CHANGE NEEDED`. Any other ending is a stop: keep the output and do not run individual commands from the block by hand. If the block stopped because users who have a profile on the machine are not signed in, or asked you to set `$AssumeDefaultDocumentsForSignedOutUsers` to `$false` or `$true`, follow the steps for that stop in the list of stops under [Step 2](#step-2-align-the-azure-powershell-modules-with-the-recipe), and run the block again. For any other stop, or if the block still stops after those users sign in or the setting is changed, [contact Microsoft support](#when-to-contact-microsoft-support).

If `Uninstall-Module` reports that a module version is in use, a process still has it loaded. Close the PowerShell windows and remote sessions from [Before you start](#before-you-start) and run Step 2 again in a new session. Do not stop Azure Local services or delete module folders to work around it.

### Step 3: Retry the operation

After Step 2 completed on every affected machine, run the [Issue Validation](#issue-validation) block again, unchanged, in a new elevated Windows PowerShell 5.1 session on each machine. This check is read-only.

- If every machine reports `RESULT: NOT AFFECTED`, retry the operation as the table below describes. A `WARNING:` line before it, for a module that is not in the recipe, does not block the retry.
- If a machine reports `RESULT: AFFECTED` or `RESULT: UNKNOWN`, do not retry. For `RESULT: AFFECTED` on a machine where you have not run Step 2, follow [Mitigation Details](#mitigation-details) on that machine and then run this check again. Otherwise, keep the output from that machine and [contact Microsoft support](#when-to-contact-microsoft-support).

**Changes:** resumes the operation that failed.

| Operation | How to retry |
| --- | --- |
| Deployment | In the Azure portal, open your Azure Local instance, go to **Deployments**, and select **Resume deployment**. |
| Other operations | Retry the operation the same way you started it. |

**Automation boundary.** A script or an on-box assistant can run [Issue Validation](#issue-validation) and Step 2 on each machine and confirm `RESULT: NOT AFFECTED`. It cannot resume a deployment from the Azure portal: a person signed in to the portal selects **Resume deployment**. An operation that automation started from the machine can be retried by the same automation.

## Verify the fix

- In a new elevated Windows PowerShell 5.1 session, [Issue Validation](#issue-validation) reports `RESULT: NOT AFFECTED` on every machine. A `WARNING:` line before it, for a module that is not in the recipe, does not block the retry; follow up on that module with Microsoft support or its owner.
- The retried operation continues past the step that failed.

## Rollback

There is no automatic rollback. Step 2 confirmed, before it changed anything, that every version it removed was available in its `$Repository`. To restore a version that Step 2 removed, take the `Name` and `Version` from its `REMOVING:` line, put them in the block below, and run it in an elevated Windows PowerShell 5.1 session on the same machine. The block stops in PowerShell 7, because there `Install-Module` installs for all users in `C:\Program Files\PowerShell\Modules`, a folder that Windows PowerShell 5.1 does not read.

Set `$Repository` to the same repository that you used in Step 2: leave it set to `'PSGallery'` unless your organization requires an approved internal repository, in which case use that repository's name. The block first confirms with `Find-Module` that this exact version is available in that repository, treating a missing build or revision number as 0 as Step 2 does, so `5.5.5` and `5.5.5.0` are the same version; it then installs the version as the repository lists it. If it is not available, the block stops without installing anything; choose an approved repository that contains this exact version, or contact Microsoft support.

**Changes:** installs that module version for all users from `$Repository`, together with the dependencies that version declares. `Install-Module` installs a dependency at the newest version the repository has in the allowed range, so restoring, for example, `Az.Storage` 9.8.0 also installs a newer `Az.Accounts` such as 5.5.5. It does not remove other versions. Restoring a version that Step 2 removed brings this error back, so restore it only after the operation completes and only if you need it for other work.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Repository = 'PSGallery'
    $Name = 'module-name-from-REMOVING-line'
    $Version = 'version-from-REMOVING-line'

    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this block in Windows PowerShell 5.1. Nothing was installed.' }
    if (-not ($Version -as [version])) { throw "Replace the version placeholder with the version from the REMOVING: line. Nothing was installed." }
    function ConvertTo-FullVersion {
        # Missing build and revision numbers count as 0, so 5.5.3 and 5.5.3.0 name the same installed version.
        param([version]$Version)
        [version]::new($Version.Major, $Version.Minor, [math]::Max($Version.Build, 0), [math]::Max($Version.Revision, 0))
    }
    Get-PSRepository -Name $Repository | Out-Null
    $found = @()
    try { $found = @(Find-Module -Name $Name -RequiredVersion $Version -Repository $Repository) } catch { $found = @() }
    if ($found.Count -ne 1 -or (ConvertTo-FullVersion ([string]$found[0].Version)) -ne (ConvertTo-FullVersion $Version)) {
        throw "$Name $Version is not available in $Repository. Nothing was installed. Choose an approved repository that contains this exact version."
    }
    # Install and confirm the version as the repository writes it, for example 5.5.5 for 5.5.5.0.
    $Version = [string]$found[0].Version
    Write-Output "INSTALLING: $Name $Version from $Repository"
    Install-Module -Name $Name -RequiredVersion $Version -Repository $Repository -Scope AllUsers -Force
    $installed = @()
    try { $installed = @(Get-InstalledModule -Name $Name -RequiredVersion $Version) } catch { $installed = @() }
    if ($installed.Count -eq 0) { throw "$Name $Version is not listed as installed. Keep this output and contact Microsoft support." }
    Write-Output "RESTORED: $Name $Version"
}
```

Expected result: `RESTORED:` followed by the module name and version.

Do not uninstall a version that Step 2 installed. It is the version that the machine's validated recipe requires.

## When to contact Microsoft support

Open a support request if any of these is true:

- Issue Validation reports `RESULT: UNKNOWN` on a machine.
- Issue Validation still reports `RESULT: AFFECTED` on a machine after Step 2 ended with `RESULT: CHANGED` or `RESULT: NO CHANGE NEEDED` there.
- Step 2 stops with a message other than one asking you to open a new session, to have users who are not signed in sign in, or to set `$AssumeDefaultDocumentsForSignedOutUsers` to `$false` or `$true`, or it still stops with one of those messages after you followed it.
- Every machine reports `RESULT: NOT AFFECTED`, but the operation still fails with this error.
- The error returns after the retry.

Include this information:

- The full output of Issue Validation from every machine, before and after the steps you ran.
- The full output of Step 2, including the `INSTALLING:` and `REMOVING:` lines.
- The exact error text and the time it occurred, from the failed step in the Azure portal.
- The Azure Local version that you are deploying or updating to.

## Related documentation

- [Troubleshooting Test PowerShell Module Version](Troubleshooting-Test-PowerShell-Module-Version.md)
- [Troubleshoot Environment Checker module versions](Troubleshooting-Module-Versions.md)
- [Install-Module](https://learn.microsoft.com/powershell/module/powershellget/install-module)
- [Uninstall-Module](https://learn.microsoft.com/powershell/module/powershellget/uninstall-module)
- [Deploy Azure Local using the Azure portal](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal)
- [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2)
