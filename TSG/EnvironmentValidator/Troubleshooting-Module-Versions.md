<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v2",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Get-Module -Name AzStackHci.EnvironmentChecker -ListAvailable | Where-Object {$_.Path -like \"*$($_.Version)*\"}"
  }
}
-->

# Troubleshoot Environment Checker module versions

## Table of contents

- [Revision history](#revision-history)
- [At a glance](#at-a-glance)
- [Overview](#overview)
- [Symptoms](#symptoms)
- [Cause](#cause)
- [Terms used in this article](#terms-used-in-this-article)
- [Where you can see this problem](#where-you-can-see-this-problem)
- [Before you start](#before-you-start)
- [Issue Validation](#issue-validation)
- [Mitigation Details](#mitigation-details)
- [Verify the fix](#verify-the-fix)
- [Rollback](#rollback)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)
- [Prevention](#prevention)
- [Related documentation](#related-documentation)

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-20 | Corrected the expected inbox module path and the Issue Validation command. Added the error that newer builds show, steps for module files that are still in use, commands for all machines, and guidance to verify, escalate, and prevent the problem. Added the metadata marker. Step 1 now lists every PowerShell session that could hold the external copy's files, including remote sessions, and the impact labels are replaced with plain statements of what each step changes. |

## At a glance

| | |
| --- | --- |
| What happens | A deployment, update, upgrade, add node, or repair node operation stops because an extra copy of the Environment Checker PowerShell module could not be removed. |
| Applies to | Azure Local, all releases. The error text depends on the build; see [Symptoms](#symptoms). |
| Severity | High. The operation stays blocked until the extra copy is removed. Running virtual machines (VMs) are not affected. |
| Is it a network, hardware, or OEM problem? | No. The older error mentions `ValidateConnectivity`, but no network, firmware, or driver change is needed. |
| Who should act | An administrator with local administrator rights on every machine. |
| Time to fix | About 10 minutes, plus the time to retry the operation. |
| Impact | The fix removes only the extra copy. Running VMs are not affected. No restart or maintenance window is needed, except in the rare case described in [If the external copy is still listed](#if-the-external-copy-is-still-listed). On a single-machine instance, that restart stops all VMs. |
| First step | Run the check in [Issue Validation](#issue-validation). |

## Overview

Azure Local ships its own copy of the Environment Checker PowerShell module, called the inbox module. The same module is also published on the PowerShell Gallery so that you can run readiness checks before deployment. The inbox version must be the one that loads, so before a deployment, update, upgrade, add node, or repair node operation, Azure Local tries to remove every other copy.

If you installed the module from the PowerShell Gallery, remove it after use (see [Prevention](#prevention)). When you troubleshoot a related issue, removing the extra copy first also makes the results easier to read.

## Symptoms

On rare occasions Azure Local cannot remove the extra copy, and the operation fails. The error depends on the build.

**Older builds** (example from Environment Checker 10.2504.0.2040): the operation stopped when `Uninstall-Module` could not find the copy.

```text
Type 'ValidateConnectivity' of Role 'EnvironmentValidator' raised an exception:
{
    "ExceptionType":  "text",
    "ErrorMessage":  "No match was found for the specified search criteria and module names \u0027AzStackHci.EnvironmentChecker\u0027.",
    "ExceptionStackTrace":  "at Uninstall-Module\u003cProcess\u003e, C:\\Program Files\\WindowsPowerShell\\Modules\\PowerShellGet\\2.2.5\\PSModule.psm1: line 12733\r\nat CleanEnvironmentValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 1230\r\nat EnvironmentValidatorImport, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 784\r\nat RunSingleValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 806\r\nat ValidateConnectivity, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 265\r\nat \u003cScriptBlock\u003e, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 147\r\nat Invoke-EceInterfaceInternal, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 142\r\nat \u003cScriptBlock\u003e, \u003cNo file\u003e: line 36"
}
```

**Newer builds** (confirmed on Environment Checker 10.2510.0.2100): Azure Local removes the extra copy by itself and fails only when it cannot delete the files, usually because a PowerShell session still has the module loaded. The error links to this article. For example (the version folder and file name vary):

```text
Unable to remove module files at C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\1.0.0. Error: Access to the path 'Microsoft.AzureStack.Observability.Standalone.dll' is denied.. Please follow https://aka.ms/envchkrversiontsg to remove the module manually before retrying lifecycle operation.
```

The system health check (`Invoke-SolutionUpdatePrecheck -SystemHealth`) runs the same cleanup on the machine where it runs. If the cleanup fails, the check can keep showing its previous result, so a passing health check does not prove that no extra copy is present. Use [Issue Validation](#issue-validation) instead.

## Cause

- **Older builds:** `Uninstall-Module` removes only modules that PowerShellGet installed and recorded. A copy that was copied in by hand, or whose install record is missing, still loads, but `Uninstall-Module` reports `No match was found`, and the operation stopped on that error.
- **Newer builds:** Azure Local ignores that error and deletes the version-number folder itself. It fails only when Windows does not allow the delete because a process still has files from the copy loaded.
- **The usual reason files are in use:** a PowerShell window or remote session that was used to run the Environment Checker from the PowerShell Gallery, for example for readiness checks before deployment, and was left open.

## Terms used in this article

| Term | Meaning |
| --- | --- |
| Environment Checker | The `AzStackHci.EnvironmentChecker` PowerShell module that runs the Azure Local readiness checks. |
| Inbox module | The copy that ships with Azure Local, in `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker`. Its files sit directly in that folder, with no version-number subfolder. Never delete it. |
| External copy | Any other copy, for example one installed with `Install-Module` from the PowerShell Gallery. It lives in a version-number subfolder such as `...\AzStackHci.EnvironmentChecker\10.2411.0.12`. Deployment can also leave copies in version-number folders on some machines; they are removed the same way. A listed copy without the error in [Symptoms](#symptoms) is not by itself the cause of a failure. |
| PowerShell Gallery | The public online repository that `Install-Module` downloads PowerShell modules from. |
| In use | A process, usually a PowerShell window or remote session, still has files from the external copy loaded, so Windows does not allow them to be deleted. |

## Where you can see this problem

- **PowerShell on each machine:** the check in [Issue Validation](#issue-validation) lists the external copy.
- **Azure portal:** the failed step shows the error from [Symptoms](#symptoms), under **Deployments** for a deployment, or in the failure details under **Updates** for a solution update. This follows the documented behavior for failed steps; it was not reproduced during validation of this article.
- **Log files on the machine:** the deployment log for the failed step in `C:\CloudDeployment\Logs`, for example `EnvironmentValidatorFull.<date>.log` during deployment, contains `Externally installed module(s) found for AzStackHci.EnvironmentChecker` and `Attempting to uninstall` (older builds log `Uninstalling`), followed by the result or the error.
- **Windows event logs:** the error does not appear in the Windows event logs.
- **Cluster log:** the error does not appear in the cluster log (`Get-ClusterLog`), because no cluster resource changes state.
- **Failover Cluster Manager:** the error does not appear in Failover Cluster Manager.
- **Windows Admin Center:** the error does not appear in Windows Admin Center on a standalone host or in Windows Admin Center in the Azure portal.

## Before you start

- Open PowerShell with **Run as administrator** on each machine.
- Make sure no update or deployment step is running right now. If an update shows `Installing`, wait for it to stop before you change anything.
- Run [Issue Validation](#issue-validation) first. Continue only if it lists an external copy or a leftover version-number folder.
- If the inbox module is missing from the results, stop and [contact Microsoft support](#when-to-contact-microsoft-support). Do not install a replacement.

## Issue Validation

Run this in an elevated PowerShell session on each machine. It changes nothing; it lists external copies, meaning module copies whose path contains their version number.

```powershell
$moduleName = "AzStackHci.EnvironmentChecker"
Get-Module -Name $moduleName -ListAvailable | Where-Object {$_.Path -like "*$($_.Version)*"}
```

- **Affected:** one or more modules are listed, each with a version-number folder in its path.
- **Not affected:** no output.

To check every machine at once, run this from one machine. On a deployed cluster, `Get-ClusterNode` lists the machines. Before the cluster exists (during deployment), set `$nodes` to the machine names instead. If PowerShell remoting to a machine fails, run the single-machine command above on that machine instead.

```powershell
$moduleName = "AzStackHci.EnvironmentChecker"
$nodes = (Get-ClusterNode).Name
Invoke-Command -ComputerName $nodes -ScriptBlock {
    $name = $using:moduleName
    $root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$name"
    [pscustomobject]@{
        ExternalCopies      = @(Get-Module -Name $name -ListAvailable | Where-Object { $_.Path -like "*$($_.Version)*" } | ForEach-Object { $_.Path })
        VersionFolders      = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] } | ForEach-Object { $_.FullName })
        AllAvailableModules = @(Get-Module -Name $name -ListAvailable | ForEach-Object { $_.Path })
    }
} | Format-List PSComputerName, ExternalCopies, VersionFolders, AllAvailableModules
```

How to read the output for each machine:

| Result | Meaning | Next step |
| --- | --- | --- |
| `ExternalCopies` lists a path | An external copy is present. | Follow Steps 1 to 5 in [Mitigation Details](#mitigation-details). |
| `ExternalCopies` is empty but `VersionFolders` lists a folder | A leftover folder from a partly removed copy. It no longer loads. | [Step 4](#step-4-delete-leftover-folders). If Step 4 already told you to leave it until the next planned restart, no further action is needed now. |
| Both are empty and `AllAvailableModules` shows only the inbox path | This machine is not affected. | None. |
| `AllAvailableModules` does not show the inbox path | The inbox module is missing. | Stop and [contact Microsoft support](#when-to-contact-microsoft-support). |

## Mitigation Details

Run these steps on each affected machine. None of them affects running VMs or needs a maintenance window, except the restart in [If the external copy is still listed](#if-the-external-copy-is-still-listed) on a single-machine instance.

### Step 1: Find the PowerShell sessions that could hold the files

List the PowerShell processes on this machine, with their owner, start time, and command line. This step changes nothing. Any of them could have loaded files from an external copy. Windows does not report which process loaded a PowerShell module's .NET files, so this step lists every candidate rather than an exact match. Remote PowerShell sessions appear as `wsmprovhost`.

```powershell
$names = 'powershell', 'pwsh', 'wsmprovhost'
$candidates = Get-CimInstance Win32_Process | Where-Object { $names -contains [IO.Path]::GetFileNameWithoutExtension($_.Name) -and $_.ProcessId -ne $PID }
$rows = foreach ($p in $candidates) {
    [pscustomobject]@{
        ProcessId   = $p.ProcessId
        Name        = $p.Name
        Owner       = (Invoke-CimMethod -InputObject $p -MethodName GetOwner).User
        StartTime   = $p.CreationDate
        CommandLine = $p.CommandLine
    }
}
if ($rows) { $rows | Sort-Object StartTime | Format-Table -AutoSize -Wrap } else { Write-Output "No other PowerShell sessions are running on this machine." }
```

- **Sessions listed:** continue with Step 2.
- **No sessions listed:** go to Step 3.

### Step 2: Close those sessions

**Changes:** ends only the PowerShell sessions you close. Close the PowerShell windows and remote sessions from Step 1 that you or your team started, especially any that ran the Environment Checker or imported `AzStackHci.EnvironmentChecker`. For a `wsmprovhost` process, close the remote session from the machine where you opened it (or exit `Enter-PSSession` and run `Remove-PSSession`). Do not stop processes you do not recognize; Azure Local services also run PowerShell. To end a session that you cannot close normally, use its `ProcessId` from Step 1:

```powershell
Stop-Process -Id 1234   # Replace 1234 with the ProcessId of a session you started.
```

### Step 3: Run the cleanup script

**Changes:** unloads, uninstalls, and deletes only copies in version-number folders. The inbox module and running VMs are not affected. Run this script only after Issue Validation listed an external copy.

```powershell
$moduleName = "AzStackHci.EnvironmentChecker"
# Unload any previously loaded modules
$loadedModule = Get-Module -Name $moduleName | Where-Object {$_.Path -like "*$($_.Version)*"}
if ($loadedModule)
{
    Write-Host "Loaded module(s) found for $($loadedModule.Name):"
    Write-Host ($loadedModule | Format-Table Name, Version, Path -AutoSize | Out-String)
    Write-Host "Unloading"
    $loadedModule | Remove-Module -Force
}

# Uninstall any modules installed from external
$installedModule = Get-Module -Name $moduleName -ListAvailable | Where-Object {$_.Path -like "*$($_.Version)*"}
if ($installedModule)
{
    Write-Host "Externally installed module(s) found for $($installedModule.Name):"
    Write-Host ($installedModule | Format-Table Name, Version, Path -AutoSize | Out-String)
    Write-Host "Uninstalling module(s)"
    $installedModule | Uninstall-Module -Force -ErrorAction SilentlyContinue
    foreach ($im in $installedModule)
    {
        Write-Host "Checking module still exists on disk..."
        if (Test-Path $im.ModuleBase -ErrorAction SilentlyContinue) {
            Write-Host "Removing old module files $($im.ModuleBase)"
            Remove-Item -Path $im.ModuleBase -Recurse -Force
        }else {
            Write-Host "Old module files not found at $($im.ModuleBase)"
        }
    }
} else {
    Write-Host "Nothing to uninstall"
}

# Check final module is our one.
$FinalModule = Get-Module -Name $moduleName -ListAvailable
Write-Host "Final installed module:"
Write-Host ($FinalModule | Format-Table Name, Version, Path -AutoSize | Out-String)
```

The output should contain a single module whose path is `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHci.EnvironmentChecker.psd1`, with no version-number folder in the path (for example, not `...\AzStackHci.EnvironmentChecker\10.2504.0.2040\AzStackHci.EnvironmentChecker.psd1`).

If `Remove-Item` reports `Access to the path ... is denied` or `The directory is not empty`, a process still has files from that folder loaded. The script still removes the files it can, including the module manifest, so the copy usually no longer loads and the final output shows only the inbox module. Continue with Step 4.

To run the cleanup on every machine from one session, save the script above as `Remove-ExternalEnvChecker.ps1` and run:

```powershell
$nodes = (Get-ClusterNode).Name   # Before the cluster exists, set $nodes to the machine names.
Invoke-Command -ComputerName $nodes -FilePath .\Remove-ExternalEnvChecker.ps1
```

#### If the external copy is still listed

In rare cases the script cannot delete the module manifest itself. Issue Validation then still lists the copy under `ExternalCopies`, and the operation stays blocked. Close the session from Steps 1 and 2 if you can find it, then run Step 3 again. If you cannot find it, restart the machine to release the files.

**Changes:** restarts this machine. On a deployed cluster with more than one machine, drain it first so its VMs move to other machines:

- On a deployed cluster with more than one machine, follow the pause and drain procedure in [Suspend and resume Azure Local machines for planned maintenance](https://learn.microsoft.com/azure/azure-local/manage/suspend-resume-cluster-maintenance), so workloads move to other machines before the restart, and resume the machine afterward.
- On a single-machine instance, there is no other machine to drain to, so the pause and drain procedure does not apply. Plan a maintenance window, and shut down or save the VMs before the restart.
- Before the cluster exists (during deployment), restart the machine normally.

> [!WARNING]
> On a single-machine instance, this restart stops all running VMs.

After the restart, run Step 3 again, then Step 4.

### Step 4: Delete leftover folders

**Changes:** deletes only subfolders whose name is a version number. The inbox files are not in such a subfolder and are not touched. Run this after Step 3 shows only the inbox module.

```powershell
$root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker"
Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -as [version] } | ForEach-Object {
    Write-Host "Removing leftover folder $($_.FullName)"
    Remove-Item -Path $_.FullName -Recurse -Force
}
```

If this still reports that files are in use and you could not find the session in Steps 1 and 2, leave the folder for now. Its module manifest is already gone, so it does not load and does not block the operation. Delete it with the same command after the machine's next planned restart, rather than restarting the machine for this alone.

### Step 5: Retry the operation

**Changes:** resumes the operation you started. Retry the operation that failed:

| Operation | How to retry |
| --- | --- |
| Deployment | In the Azure portal, open your Azure Local instance, go to **Deployments**, and select **Resume deployment**. |
| Solution update | In the Azure portal, select **Try again** on the failed update. Or run `Get-SolutionUpdate \| Where-Object Version -eq "<version>" \| Start-SolutionUpdate`, replacing `<version>` with the version of the update that failed. This works whether the update failed in the readiness check or during installation. |
| Upgrade, add node, or repair node | Retry the operation the same way you started it. |

## Verify the fix

Run the all-machines check in [Issue Validation](#issue-validation) again. On every machine, `ExternalCopies` should be empty, and `AllAvailableModules` should show only `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHci.EnvironmentChecker.psd1`. `VersionFolders` should also be empty, except for a folder that you deliberately left in place under [Step 4](#step-4-delete-leftover-folders) until the next planned restart. The operation you retried in Step 5 should continue past the step that failed.

Do not use the system health check to confirm this fix. It can keep showing a previous result, and it runs the cleanup only on the machine where it runs.

## Rollback

Normally there is nothing to roll back. A copy installed from the PowerShell Gallery was not part of Azure Local, and a copy left behind by deployment is removed by Azure Local itself before each operation. If you need the standalone Environment Checker from the PowerShell Gallery again, reinstall it with `Install-Module -Name AzStackHci.EnvironmentChecker` after the operation completes, and remove it again before the next one. If you paused and drained a machine, resume it as described in the pause and drain procedure.

## When to contact Microsoft support

Open a support request if any of these is true:

- The inbox module is missing from `AllAvailableModules`.
- The external copy is still listed after you restarted the machine and ran Step 3 again.
- A leftover version-number folder still cannot be deleted after the machine has restarted.
- The same error returns after the retry while Issue Validation shows no external copy.

Include this information:

- The output of the all-machines Issue Validation command, before and after the steps you ran.
- The full output of the cleanup script from every machine.
- The exact error text and the time it occurred, from the failed deployment or update step in the Azure portal.
- The deployment log from `C:\CloudDeployment\Logs` that contains `Externally installed module(s) found for AzStackHci.EnvironmentChecker`.
- The Azure Local version and the version of the inbox Environment Checker module.

## Prevention

Azure Local already includes the Environment Checker. If you install it from the PowerShell Gallery to run readiness checks, close that PowerShell window when you finish, then remove the gallery copy from every machine before you start a deployment or update, as described in [Assess your environment with the Environment Checker](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker).

**Changes:** unloads the module from the current session and uninstalls only copies in version-number folders. The inbox module is not affected.

```powershell
Remove-Module AzStackHci.EnvironmentChecker -Force
Get-Module AzStackHci.EnvironmentChecker -ListAvailable | Where-Object {$_.Path -like "*$($_.Version)*"} | Uninstall-Module -Force
```

## Related documentation

- [Assess your environment with the Environment Checker](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker)
- [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2)
- [Understand update phases for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-phases-23h2)
- [Deploy Azure Local using the Azure portal](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal)
- [Suspend and resume Azure Local machines for planned maintenance](https://learn.microsoft.com/azure/azure-local/manage/suspend-resume-cluster-maintenance)
