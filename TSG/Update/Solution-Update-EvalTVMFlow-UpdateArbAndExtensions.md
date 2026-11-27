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

# Where this failure appears

The update error itself appears where the update reports its failure, as described in [Symptoms](#symptoms). The rows below describe how the cause, a version of `Az.Accounts`, `Az.Resources`, or `Az.ConnectedMachine` that is newer than the node's validated recipe, shows in each administrator tool before you start or resume the update.

| Surface | Status | Evidence |
| --- | --- | --- |
| PowerShell on an Azure Local node | shown | [Issue Validation](#issue-validation) prints `RESULT: AFFECTED` and names each module version that is newer than the recipe. `Get-SolutionUpdateEnvironment -FullHealthCheckDetails` also returns the system health check result described in the next row. |
| Azure portal | shown | Your Azure Local instance > **Settings** > **Updates** shows the system health check results. On each affected node, the check `Test PowerShell Module Version` (`AzStackHci_ValidatedRecipe_PowerShellModule_Version`) fails with severity Critical and a detail such as `Checking version of PS module 'Az.Accounts' on host '<node>'. Got '<installed version>' but expected less-than or equal to '<recipe version>' so it is invalid.`, with one such sentence for each module version that is newer than the recipe. To run the system health check again, run `Invoke-SolutionUpdatePrecheck -SystemHealth` on a node. |
| Windows event logs | not-evident | No event names the newer module versions or the failed health check. Scope checked: the `AzStackHciEnvironmentChecker`, `Microsoft-AzureStack-*`, Health, Windows Update client, FailoverClustering, Application, and System event logs on the affected node, from the time the newer versions were installed until the system health check finished. High-volume trace channels and the event logs of a failed update run were not checked. |
| Cluster logs (`Get-ClusterLog`) | not-evident | `Get-ClusterLog` from every node, for the period that the newer versions were installed, contains no entry for them. A module version is not a cluster resource. |
| Windows Failover Cluster Manager | not-evident | No role, resource, or node changes state, and no FailoverClustering critical, error, or warning event is raised, while the newer versions are installed. |
| Windows Admin Center (standalone host) | absent | Not characterized. No Health Service fault is raised, so the cluster's **Alerts** do not list it; the **Updates** tool was not checked. |
| Windows Admin Center in the Azure portal | absent | Not characterized. |
| Component / tool log files | shown | The system health check writes its results, including the failed `Test PowerShell Module Version` result for each affected node, to `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck\System\HealthCheckResult.EnvironmentChecker.<timestamp>.json`. |

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
- Another installed module in this session's module path still needs a version that would be removed, or loads a file from one. The block lists the installed modules in a separate PowerShell process, so nothing is loaded into this session, and reads each module manifest. It stops when a `RequiredModules`, `ModuleList`, or `NestedModules` entry needs an exact version (`RequiredVersion`) that would be removed, or a minimum (`ModuleVersion`) or maximum (`MaximumVersion`, including a wildcard such as `5.*`) version that no remaining version in `C:\Program Files\WindowsPowerShell\Modules` meets, or when a manifest that needs one of these modules cannot be read. It also stops when an entry in `RootModule` (`ModuleToProcess`), `NestedModules`, `RequiredAssemblies`, `ScriptsToProcess`, `TypesToProcess`, `FormatsToProcess`, `FileList`, `RequiredModules`, or `ModuleList`, including the `ModuleName` of a module specification, resolves from the manifest's folder into a version folder that would be removed, whatever name the path contains (for example `..\5.5.4\Accounts.psm1`), or is a path that leads out of the manifest's folder and cannot be resolved. A module's own files that its manifest lists by path, such as `ConnectedMachine.Autorest/Az.ConnectedMachine.psm1` in `Az.ConnectedMachine`, do not stop the block. It does not check modules in other users' `Documents` folders, or a module that enforces a version only inside its own script. `Uninstall-Module` is run with `-Force` because without it PowerShellGet refuses to remove any version that another module names as a dependency, whatever version that module needs; this check replaces that refusal with a version check.
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
    function Get-DependentCandidate {
        # Modules in this session's module path. Windows PowerShell 5.1 can import a module that another module's
        # NestedModules entry names with a version while it lists modules, and keep its files locked by that process.
        # So the modules are listed in a separate PowerShell process (a job), which returns only plain values, and
        # nothing is loaded into this session. The job must finish and end with $end; if it does not, the block stops.
        param([string]$Outcome)
        $end = 'End of the module list.'
        $job = $null
        $listed = @()
        try {
            $job = Start-Job -ArgumentList $env:PSModulePath, $end -ScriptBlock {
                param([string]$ModulePath, [string]$End)
                $env:PSModulePath = $ModulePath
                $ErrorActionPreference = 'Continue'
                @(Get-Module -ListAvailable) | ForEach-Object {
                    [pscustomobject]@{ Name = $_.Name; Version = [string]$_.Version; Path = $_.Path; ModuleBase = $_.ModuleBase; Guid = [string]$_.Guid
                        RequiredModules = @($_.RequiredModules | ForEach-Object { [string]$_.Name }); ModuleList = @($_.ModuleList | ForEach-Object { [string]$_.Name }) }
                }
                $End
            }
            # Errors that Get-Module reports for single modules are expected, as above, so they are not shown here.
            $listed = @(Receive-Job -Job $job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue)
        } catch { $listed = @() }
        if (-not $job -or $job.State -ne 'Completed' -or $listed.Count -lt 2 -or $listed[-1] -ne $end) {
            throw "The installed modules could not be listed in a separate PowerShell process. Contact Microsoft support. $Outcome"
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

        # Every remaining module must still find a version that it accepts of each module whose newer versions would be
        # removed, and must not load a file from a version folder that would be removed.
        $removeBases = @($remove | ForEach-Object { $_.ModuleBase })
        $removeNames = @($remove | ForEach-Object { $_.Name } | Sort-Object -Unique)
        if ($removeNames.Count) {
            $modules = @(Get-DependentCandidate -Outcome $Outcome)
            $broken = @(@(foreach ($n in $removeNames) {
                    $kept = @(@($available | Where-Object { $_.Name -eq $n -and (& $isAllUsers $_) -and $removeBases -notcontains $_.ModuleBase } | ForEach-Object { [version]$_.Version }) +
                        @($install | Where-Object { $_.Name -eq $n } | ForEach-Object { [version]$_.Version }))
                    Get-UnmetDependent -ModuleName $n -KeptVersion $kept -Modules $modules -ExcludePath $removeBases | ForEach-Object { "$($_.Name) $($_.Version) needs $($_.Needs)" }
                }) + @(Get-RemovedFileReference -Modules $modules -ExcludePath $removeBases | ForEach-Object { "$($_.Name) $($_.Version) loads $($_.Reference)" }))
            if ($broken.Count) {
                throw ('Removing the newer versions would break these modules: ' + ($broken -join '; ') + ". Contact Microsoft support. $Outcome")
            }
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

Use this block in one of two cases:

- **Step 1 stopped after a `REMOVING:` line.** Leave the update stopped. Restore each version that the message lists as removed, then contact Microsoft support. Do not resume the update.
- **The update completed, and you need a version that Step 1 removed for other work.** This is optional. A restored version that is newer than the recipe can bring this error back, so run [Issue Validation](#issue-validation) before the next update.

Take the name and version from the `REMOVING:` line, put them in the block below, and run it in an elevated Windows PowerShell 5.1 session on the same node. Set `$Repository` to the same repository that you used in Step 1. The block first confirms with `Find-Module` that this exact version is available in that repository; if it is not, it stops without installing anything.

**Changes:** installs that module version for all users from `$Repository`, together with the dependencies that version declares, which can include a newer `Az.Accounts`. It does not remove other versions.

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
