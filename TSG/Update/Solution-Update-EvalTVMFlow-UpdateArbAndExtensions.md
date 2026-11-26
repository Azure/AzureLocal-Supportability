When applying the solution update, the update fails and displays one of the error messages described below.

# Symptoms

When trying to update Azure Local 23H2 version 2408.x to 2411 you can hit this issue.  
The issue that causes the failure can result in one of the following error messages:

Error 1:
**“EvalTVMFlow” error “CloudEngine.Actions.InterfaceInvocationFailedException: Type 'EvalTVMFlow' of Role 'ArcIntegration' raised an exception: This module requires Az.Accounts version "". An earlier version of Az.Accounts is imported in the current PowerShell session."**

Error 2:
**“Type 'UpdateArbAndExtensions' of Role 'MocArb' raised an exception: Clear-AzContext failed with 0 and Exception calling "Initialize" with "1" argument(s): "Object reference not set to an instance of an object." at at Clear-AzPowershellCache, C:\NugetStore\Microsoft.AzureStack.MocArb.LifeCycle.1.2411.0.14\content\Scripts\MocArbHelper.psm1: line 3250 at Login-AzPowershellSessio."**

# Issue Validation

The required versions of `Az.Accounts`, `Az.Resources`, and `Az.ConnectedMachine` depend on the Azure Local build and come from each node's validated recipe, the list of exact component versions, including Azure PowerShell modules, that the build is tested with. Do not compare the installed versions with numbers from this article or from another node.

Run this block in a new elevated Windows PowerShell 5.1 session on each node. It does not install, remove, or change any module. It reads the node's validated recipe, lists the installed versions of the three modules, and prints one `RESULT` line.

```powershell
& {
    $targets = @('Az.Accounts', 'Az.Resources', 'Az.ConnectedMachine')
    $recipe = @{}
    try {
        if (-not (Get-Command -Name Get-ASArtifactPath -ErrorAction SilentlyContinue)) { throw 'Get-ASArtifactPath is not available in this session.' }
        $artifactPath = Get-ASArtifactPath -NugetName 'Microsoft.AzureStack.VersionControl.Operations' -ErrorAction Stop
        Import-Module (Join-Path $artifactPath 'content\Scripts\VersionControlHelpers.psm1') -Force -DisableNameChecking -ErrorAction Stop
        foreach ($row in @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure') -ErrorAction Stop | Where-Object { $targets -contains $_.Name })) {
            $text = [string]$row.RequiredVersion
            if ($text -notmatch '^\d+\.\d+\.\d+(\.\d+)?$' -or $recipe.ContainsKey($row.Name)) { throw "The recipe entry for $($row.Name) is invalid or duplicated." }
            $recipe[$row.Name] = [version]$text
        }
        if (-not $recipe.ContainsKey('Az.Accounts')) { throw 'The recipe does not list Az.Accounts.' }
    } catch {
        Write-Output "RESULT: UNKNOWN - the validated recipe could not be read on this node: $($_.Exception.Message) Do not change modules on this node."
        return
    }
    # Missing build and revision numbers count as 0, so 3.0.3 and 3.0.3.0 name the same version.
    $full = { param([version]$v) [version]::new($v.Major, $v.Minor, [math]::Max($v.Build, 0), [math]::Max($v.Revision, 0)) }
    $rows = foreach ($m in @(Get-Module -ListAvailable -Name $targets)) {
        $finding = 'Not in recipe'
        if ($recipe.ContainsKey($m.Name)) {
            $finding = switch ((& $full $m.Version).CompareTo((& $full $recipe[$m.Name]))) { 0 { 'Recipe version' } 1 { 'Newer than recipe' } default { 'Older than recipe' } }
        }
        [pscustomobject]@{ Name = $m.Name; Version = $m.Version; RecipeVersion = $recipe[$m.Name]; Finding = $finding; Path = $m.ModuleBase }
    }
    @($rows) | Sort-Object Name, Version | Format-Table -AutoSize | Out-String -Width 300 | Write-Output
    $reasons = @(@($rows) | Where-Object { $_.Finding -eq 'Newer than recipe' } | ForEach-Object { "$($_.Name) $($_.Version) is newer than the recipe version $($_.RecipeVersion)" })
    if (-not @(@($rows) | Where-Object { $_.Name -eq 'Az.Accounts' -and $_.Finding -eq 'Recipe version' }).Count) {
        $reasons += "the recipe version of Az.Accounts ($($recipe['Az.Accounts'])) is not installed"
    }
    if ($reasons.Count) { Write-Output ('RESULT: AFFECTED - ' + ($reasons -join '; ')) }
    else { Write-Output "RESULT: NOT AFFECTED - the recipe version of Az.Accounts ($($recipe['Az.Accounts'])) is installed and no version newer than the recipe is installed." }
}
```

| Result | Meaning | Next step |
| --- | --- | --- |
| `RESULT: AFFECTED` | The line names the module versions that do not match the recipe on this node. | Follow [Mitigation Details](#mitigation-details) on this node. |
| `RESULT: NOT AFFECTED` | The versions of these three modules match the recipe on this node. Older versions do not cause this issue and do not need to be removed. | None on this node. If no node is affected and the update still fails with an error above, contact Microsoft support. |
| `RESULT: UNKNOWN` | The required versions could not be read on this node. | Do not change modules on this node. Contact Microsoft support with the output. |

# Cause

There is an issue with Az.Accounts module versions 3.0.4 and up that causes it to write an error to $global:error which causes update flow to throw an exception and fail.
We also need compatible versions of Az.Resources and Az.ConnectedMachine with Az.Accounts 3.0.3

These version numbers are the ones that this issue was reported with, on the update to 2411. They apply only where the node's validated recipe lists them. In general, the update fails when a version of these modules that is newer than the recipe is installed outside of Azure Local, for example with `Install-Module Az` or `Update-Module`, or when the recipe version of `Az.Accounts` is missing.

> [!IMPORTANT]
> Do not install fixed module versions from an older revision of this article, from another article, or from another node. Different Azure Local builds require different versions. For example, some builds require `Az.Accounts` 4.0.2 and newer builds require `Az.Accounts` 5.x. Installing a fixed older version on a newer build breaks the product's own modules. The steps below read the required versions from each node's validated recipe.

# Mitigation Details

## Before you start

- Open **Windows PowerShell 5.1** with **Run as administrator** on each node. Do not use PowerShell 7.
- Start each block below in a **new** PowerShell window. A session that already loaded an Azure PowerShell module keeps that version until it closes.
- Make sure no update step is running. Wait until the update shows as failed before you change anything.
- The node needs access to the PowerShell Gallery or to your organization's approved repository.

## Step 1: Align the modules with the recipe

**[HIGH RISK]**

**Changes:** installs the recipe version of `Az.Accounts` for all users if it is missing from `C:\Program Files\WindowsPowerShell\Modules`, and the recipe version of `Az.Resources` or `Az.ConnectedMachine` if a newer version of that module is removed. It then uninstalls the versions of these three modules that are newer than the recipe, including a newer `Az.Accounts` that `Install-Module` added as a dependency. Older versions, modules that the recipe does not list, and other modules are not changed. Each removed version is printed as a `REMOVING:` line, which you need for [Rollback](#rollback).

> [!WARNING]
> Uninstalling a module version cannot be undone, except by installing that version again. Another module that needs a removed version stops loading. Run this only while no update step is running.

The block stops before changing anything, and prints `No changes were made`, when any of these is true:

- It is not running in an elevated Windows PowerShell 5.1 session, or an Azure PowerShell module is already loaded in the session.
- The validated recipe cannot be read, does not list `Az.Accounts`, or lists an invalid or duplicated version.
- A copy of `Az.Accounts`, or a copy that would be removed, is outside `C:\Program Files\WindowsPowerShell\Modules` or was not installed with `Install-Module`. Do not delete such a copy by hand; contact Microsoft support.
- Another installed module in this session's module path needs a version that would be removed: an exact version (`RequiredVersion`) that would be removed, or a minimum (`ModuleVersion`) or maximum (`MaximumVersion`) version that no remaining version in `C:\Program Files\WindowsPowerShell\Modules` meets. The check reads the `RequiredModules`, `ModuleList`, and `NestedModules` entries of each module manifest without loading the module, and stops when a manifest that names one of these modules cannot be read or loads it by a path. It does not check modules in other users' `Documents` folders, or a module that enforces a version only inside its own script. `Uninstall-Module` is run with `-Force` because without it PowerShellGet refuses to remove any version that another module names as a dependency, whatever version that module needs; this check replaces that refusal with a version check.
- A version that needs to be installed, or a version that would be removed, is not available in the repository in `$Repository`, so it could not be installed or restored from there.

After it installs a version, the block reads the installed modules again and repeats the same checks, because `Install-Module` can also install a newer `Az.Accounts` as a dependency. If a check fails at that point, it stops with `The installed versions were kept and no versions were removed`. It prints `RESULT: CHANGED` only after it confirms that the recipe version of `Az.Accounts` is installed for all users and that no version newer than the recipe remains.

Leave `$Repository` set to `'PSGallery'` unless your organization requires an approved internal repository; in that case, set it to that repository's registered name (`Get-PSRepository` lists them). With the PowerShell Gallery, the node needs HTTPS access to `www.powershellgallery.com` and to the download hosts `cdn.powershellgallery.com` and `cdn.oneget.org` ([Network access to the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/getting-started#network-access-to-the-powershell-gallery)). The repository check uses `Find-Module`, which confirms that a version is listed but not that the node can download it. If a download fails, `Install-Module` fails before any version is removed.

**Paste or run the whole block at once, not line by line.** It runs as one unit so that a failed check stops everything after it.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    # Leave 'PSGallery' unless your organization requires an approved internal repository.
    $Repository = 'PSGallery'
    $targets = @('Az.Accounts', 'Az.Resources', 'Az.ConnectedMachine')

    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this block in Windows PowerShell 5.1, not PowerShell 7. No changes were made.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this block in an elevated session (Run as administrator). No changes were made.'
    }
    $loaded = @(Get-Module -Name 'Az', 'Az.*')
    if ($loaded.Count) {
        throw ('This session already has ' + (($loaded | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ') +
            ' loaded. Open a new elevated Windows PowerShell session and run only this block. No changes were made.')
    }

    # The required versions come from this node's validated recipe. Without them, nothing is changed.
    try {
        if (-not (Get-Command -Name Get-ASArtifactPath -ErrorAction SilentlyContinue)) { throw 'Get-ASArtifactPath is not available.' }
        $artifactPath = Get-ASArtifactPath -NugetName 'Microsoft.AzureStack.VersionControl.Operations'
        Import-Module (Join-Path $artifactPath 'content\Scripts\VersionControlHelpers.psm1') -Force -DisableNameChecking
        $rows = @(Get-ValidatedRecipe -TypesToInclude @('PowerShell') -TagsToInclude @('Azure') | Where-Object { $targets -contains $_.Name })
    } catch {
        throw "The validated recipe cannot be read on this node: $($_.Exception.Message) No changes were made."
    }
    $recipe = @{}
    foreach ($row in $rows) {
        $text = [string]$row.RequiredVersion
        if ($text -notmatch '^\d+\.\d+\.\d+(\.\d+)?$' -or $recipe.ContainsKey($row.Name)) {
            throw "The recipe entry for $($row.Name) is invalid or duplicated. No changes were made."
        }
        $recipe[$row.Name] = [version]$text
    }
    if (-not $recipe.ContainsKey('Az.Accounts')) { throw 'The validated recipe does not list Az.Accounts. No changes were made.' }
    if (@(Get-Module -Name 'Az', 'Az.*').Count) { throw 'Reading the recipe loaded an Azure PowerShell module. Contact Microsoft support. No changes were made.' }
    foreach ($n in $targets) { if (-not $recipe.ContainsKey($n)) { Write-Output "NOTE: the recipe does not list $n, so this block does not change it." } }
    $names = @($recipe.Keys)

    # Missing build and revision numbers count as 0, so 3.0.3 and 3.0.3.0 name the same version.
    $full = { param([version]$v) [version]::new($v.Major, $v.Minor, [math]::Max($v.Build, 0), [math]::Max($v.Revision, 0)) }
    $allUsersRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
    $isAllUsers = { param($m) $m.ModuleBase -eq (Join-Path (Join-Path $allUsersRoot $m.Name) ([string]$m.Version)) }

    $getPlan = {
        param([string]$Outcome)
        $available = @(Get-Module -ListAvailable -Name $names)
        $remove = @($available | Where-Object { (& $full $_.Version) -gt (& $full $recipe[$_.Name]) } | Sort-Object Name, Version)
        $install = @(@(foreach ($n in $names) {
            $present = @($available | Where-Object { $_.Name -eq $n -and (& $full $_.Version) -eq (& $full $recipe[$n]) -and (& $isAllUsers $_) }).Count
            if (-not $present -and ($n -eq 'Az.Accounts' -or @($remove | Where-Object { $_.Name -eq $n }).Count)) {
                [pscustomobject]@{ Name = $n; Version = $recipe[$n] }
            }
        }) | Sort-Object { $_.Name -ne 'Az.Accounts' })

        # Uninstall-Module removes only the copy that Install-Module recorded in the all-users folder.
        # PowerShellGet 2.x returns Version as a string, so it is converted before comparing.
        $managed = @(foreach ($n in @($remove | ForEach-Object { $_.Name } | Sort-Object -Unique)) { Get-InstalledModule -Name $n -AllVersions -ErrorAction SilentlyContinue })
        $unmanaged = @(@($available | Where-Object { $_.Name -eq 'Az.Accounts' -and -not (& $isAllUsers $_) }) + @($remove | Where-Object {
            $r = $_
            -not (& $isAllUsers $r) -or -not @($managed | Where-Object { $_.Name -eq $r.Name -and (& $full ([string]$_.Version)) -eq (& $full $r.Version) -and $_.InstalledLocation -eq $r.ModuleBase }).Count
        }) | Sort-Object ModuleBase -Unique)
        if ($unmanaged.Count) {
            throw ('These copies are outside ' + $allUsersRoot + ' or were not installed with Install-Module: ' +
                (($unmanaged | ForEach-Object { "$($_.Name) $($_.Version) at $($_.ModuleBase)" }) -join '; ') + ". Do not delete them by hand; contact Microsoft support. $Outcome")
        }

        # Every remaining module that names a module version that would be removed must still find a version it accepts.
        $removeBases = @($remove | ForEach-Object { $_.ModuleBase })
        $removeNames = @($remove | ForEach-Object { $_.Name } | Sort-Object -Unique)
        $broken = @()
        if ($removeNames.Count) {
            $remainingOf = { param($n)
                @($available | Where-Object { $_.Name -eq $n -and (& $isAllUsers $_) -and $removeBases -notcontains $_.ModuleBase } | ForEach-Object { [version]$_.Version }) +
                @($install | Where-Object { $_.Name -eq $n } | ForEach-Object { $_.Version })
            }
            try {
                $manifests = @(foreach ($root in @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ -and (Test-Path -LiteralPath $_) })) {
                    foreach ($dir in @(Get-ChildItem -LiteralPath $root -Directory)) {
                        @(Get-ChildItem -LiteralPath $dir.FullName -Filter "$($dir.Name).psd1" -File) +
                            @(Get-ChildItem -LiteralPath $dir.FullName -Directory | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter "$($dir.Name).psd1" -File })
                    }
                })
            } catch {
                throw "The installed modules could not be listed: $($_.Exception.Message) $Outcome"
            }
            foreach ($file in $manifests) {
                if ($removeBases -contains $file.DirectoryName) { continue }
                $text = Get-Content -LiteralPath $file.FullName -Raw
                if (-not @($removeNames | Where-Object { $text -like "*$_*" }).Count) { continue }
                try { $data = Import-PowerShellDataFile -LiteralPath $file.FullName } catch { $broken += "$($file.FullName) cannot be read"; continue }
                foreach ($entry in @($data.RequiredModules) + @($data.ModuleList) + @($data.NestedModules)) {
                    if ($entry -is [string]) {
                        if ($removeNames -contains $entry) { $spec = @{ ModuleName = $entry } }
                        elseif ($entry -match '[\\/]' -and @($removeNames | Where-Object { $entry -like "*$_*" }).Count) { $broken += "$($file.FullName) loads $entry by path"; continue }
                        else { continue }
                    } elseif ($entry -is [hashtable]) {
                        if ($removeNames -notcontains $entry.ModuleName) { continue }
                        $spec = $entry
                    } else { continue }
                    $ok = @(& $remainingOf $spec.ModuleName | Where-Object {
                        $v = $_
                        (-not $spec.RequiredVersion -or ($spec.RequiredVersion -as [version]) -eq $v) -and
                        (-not $spec.ModuleVersion -or (($min = $spec.ModuleVersion -as [version]) -and $v -ge $min)) -and
                        (-not $spec.MaximumVersion -or (($max = $spec.MaximumVersion -as [version]) -and $v -le $max))
                    }).Count
                    if (-not $ok) { $broken += "$($file.FullName) needs $($spec.ModuleName) $($spec.RequiredVersion)$($spec.ModuleVersion)$($spec.MaximumVersion)" }
                }
            }
        }
        if ($broken.Count) {
            throw ('Removing the newer versions would break these modules: ' + ($broken -join '; ') + ". Contact Microsoft support. $Outcome")
        }

        # Rollback restores removed versions from $Repository, so it must have them and every version to install.
        $needed = @($install) + @($remove | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Version = [version]$_.Version } })
        if ($needed.Count) {
            try { Get-PSRepository -Name $Repository | Out-Null } catch { throw "The repository $Repository is not registered on this node. $Outcome" }
            $missing = @($needed | Where-Object {
                $want = $_
                $found = @()
                try { $found = @(Find-Module -Name $want.Name -RequiredVersion ([string]$want.Version) -Repository $Repository) } catch { $found = @() }
                -not @($found | Where-Object { (& $full ([string]$_.Version)) -eq (& $full $want.Version) }).Count
            })
            if ($missing.Count) {
                throw ((($missing | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ') + " is not available in $Repository, so it could not be installed or restored from there. $Outcome")
            }
        }
        [pscustomobject]@{ Install = $install; Remove = $remove }
    }

    $plan = & $getPlan 'No changes were made.'
    if (-not $plan.Install.Count -and -not $plan.Remove.Count) {
        Write-Output 'RESULT: NO CHANGE NEEDED - the recipe versions are installed and no newer version is installed.'
        return
    }
    $installed = @()
    foreach ($i in $plan.Install) {
        Write-Output "INSTALLING: $($i.Name) $($i.Version) from $Repository"
        Install-Module -Name $i.Name -RequiredVersion ([string]$i.Version) -Repository $Repository -Scope AllUsers -Force
        $installed += "$($i.Name) $($i.Version)"
    }

    # Install-Module can add a newer Az.Accounts as a dependency, so plan the removals again from what is installed now.
    $kept = 'The installed versions were kept and no versions were removed. Installed: ' + $(if ($installed.Count) { $installed -join ', ' } else { 'none' }) + '.'
    $plan = & $getPlan $kept
    if ($plan.Install.Count) {
        throw ('These recipe versions are still not installed for all users: ' + (($plan.Install | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ') + ". Contact Microsoft support. $kept")
    }
    $removed = @()
    try {
        foreach ($r in @($plan.Remove | Sort-Object { $_.Name -eq 'Az.Accounts' }, Name, Version)) {
            Write-Output "REMOVING: $($r.Name) $($r.Version) at $($r.ModuleBase)"
            Uninstall-Module -Name $r.Name -RequiredVersion ([string]$r.Version) -Force
            $removed += "$($r.Name) $($r.Version)"
        }
    } catch {
        throw ("Uninstall-Module failed: $($_.Exception.Message) Removed: " + $(if ($removed.Count) { $removed -join ', ' } else { 'none' }) +
            '. Do not retry the update. Restore the removed versions with Rollback and contact Microsoft support.')
    }

    $now = @(Get-Module -ListAvailable -Name $names)
    $problems = @($now | Where-Object { (& $full $_.Version) -gt (& $full $recipe[$_.Name]) } | ForEach-Object { "$($_.Name) $($_.Version) is still installed" })
    if (-not @($now | Where-Object { $_.Name -eq 'Az.Accounts' -and (& $full $_.Version) -eq (& $full $recipe['Az.Accounts']) -and (& $isAllUsers $_) }).Count) {
        $problems += "Az.Accounts $($recipe['Az.Accounts']) is not installed for all users"
    }
    if ($problems.Count) {
        throw ('Post-change check failed: ' + ($problems -join '; ') + '. Installed: ' + $(if ($installed.Count) { $installed -join ', ' } else { 'none' }) +
            '; removed: ' + $(if ($removed.Count) { $removed -join ', ' } else { 'none' }) + '. Do not retry the update; keep this output and contact Microsoft support.')
    }
    Write-Output "RESULT: CHANGED - the recipe versions are installed and no newer version remains. Close this window; the change takes effect only in new PowerShell sessions."
}
```

Expected result: `RESULT: CHANGED` or `RESULT: NO CHANGE NEEDED`. Any other ending is a stop: keep the output and do not run individual commands from the block by hand. If it stopped after an `INSTALLING:` line with `The installed versions were kept and no versions were removed`, keep those versions; they are the versions that the recipe requires. If it stopped after a `REMOVING:` line, restore the versions that the message lists with [Rollback](#rollback), and contact Microsoft support.

## Step 2: Verify the fix and resume the update

**Changes:** Issue Validation changes nothing. Resuming the update continues the solution update from the step that failed. In a new elevated Windows PowerShell 5.1 session, run [Issue Validation](#issue-validation) again on each node. Expected result: `RESULT: NOT AFFECTED` on every node. Then proceed with the update. If it fails again with an error above, contact Microsoft support with the output of both blocks.

## Rollback

To restore a version that Step 1 removed, take the name and version from its `REMOVING:` line, put them in the block below, and run it in an elevated Windows PowerShell 5.1 session on the same node. Set `$Repository` to the same repository that you used in Step 1. The block first confirms with `Find-Module` that this exact version is available in that repository; if it is not, it stops without installing anything.

**Changes:** installs that module version for all users from `$Repository`, together with the dependencies that version declares, which can include a newer `Az.Accounts`. It does not remove other versions. Restoring a version that Step 1 removed can bring this error back, so restore it only after the update completes and only if you need it for other work.

**Paste or run the whole block at once, not line by line.**

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $Repository = 'PSGallery'
    $Name = 'module-name-from-REMOVING-line'
    $Version = 'version-from-REMOVING-line'

    if (-not ($Version -as [version])) { throw 'Replace the version placeholder with the version from the REMOVING: line. Nothing was installed.' }
    Get-PSRepository -Name $Repository | Out-Null
    $found = @()
    try { $found = @(Find-Module -Name $Name -RequiredVersion $Version -Repository $Repository) } catch { $found = @() }
    if ($found.Count -ne 1) {
        throw "$Name $Version is not available in $Repository. Nothing was installed. Choose an approved repository that contains this exact version."
    }
    $Version = [string]$found[0].Version
    Write-Output "INSTALLING: $Name $Version from $Repository"
    Install-Module -Name $Name -RequiredVersion $Version -Repository $Repository -Scope AllUsers -Force
    if (-not @(Get-InstalledModule -Name $Name -RequiredVersion $Version -ErrorAction SilentlyContinue).Count) {
        throw "$Name $Version is not listed as installed. Keep this output and contact Microsoft support."
    }
    Write-Output "RESTORED: $Name $Version"
}
```

Expected result: `RESTORED:` followed by the module name and version. Do not uninstall a version that Step 1 installed; it is the version that the node's validated recipe requires.
