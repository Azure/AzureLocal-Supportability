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
- [Retry the failed operation](#retry-the-failed-operation)
- [Rollback](#rollback)
- [When to contact Microsoft support](#when-to-contact-microsoft-support)
- [Prevention](#prevention)
- [Related documentation](#related-documentation)

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-20 | Corrected the expected inbox module path and the Issue Validation command. Added the error that newer builds show, steps for module files that are still in use, commands for all machines, and guidance to verify, escalate, and prevent the problem. Added the metadata marker. Step 1 now lists every PowerShell session that could hold the external copy's files, including remote sessions, and the impact labels are replaced with plain statements of what each step changes. |
| 2026-11-26 | Step 1 now names the exact processes that hold the files, Step 2 stops only the user PowerShell sessions from that reviewed list while no update is running, and new scripts check every reachable machine and resume an update that failed with this error. Step 2 and Step 6 now stop when they cannot tell whether the machine is in a cluster, and the retry script resumes an update only when a failed step shows the error. |
| 2026-11-27 | Step 1 saves its list in a folder that only administrators can change, and Step 2 reads it from there, so each step can run in its own PowerShell window or process. Step 2 stops a window only when it can trace it back to the SConfig menu, the command prompt that opens at sign-in, or File Explorer, and it checks that it is still the same process before it stops it. Step 3 now says where to stop and confirm, Step 4 again checks the files directly and reports a file that it cannot open, and a machine with only a leftover folder follows all the steps. |
| 2026-11-28 | Steps 1 and 2 now treat the PowerShell window that started the script the same as the window it runs in, so Step 2 never stops it. Step 3 no longer asks to close the processes that Step 1 says to leave running, and says when it is done. The all-machines check, Verify the fix, and the retry script now tell whether the machine is in a cluster the same way as Step 2: when they cannot tell, they say so instead of treating the cluster as not deployed, and the retry script retries nothing. Step 2's description now says plainly in which case it treats a machine as not deployed. |

## At a glance

| | |
| --- | --- |
| What happens | A deployment, update, upgrade, add node, or repair node operation stops because an extra copy of the Environment Checker PowerShell module could not be removed. |
| Applies to | Azure Local, all releases. The error text depends on the build; see [Symptoms](#symptoms). |
| Severity | High. The operation stays blocked until the extra copy is removed. Running virtual machines (VMs) are not affected. |
| Is it a network, hardware, or OEM problem? | No. The older error mentions `ValidateConnectivity`, but no network, firmware, or driver change is needed. |
| Who should act | An administrator with local administrator rights on every machine. |
| Time to fix | About 10 minutes, plus the time to retry the operation. |
| Impact | The fix removes only the extra copy and, after you review the list, stops only the user PowerShell sessions that hold its files. It never stops services or system processes. If another program holds them, [Step 3](#step-3-close-the-other-programs-that-hold-the-files) asks you to close it. Running VMs are not affected. No restart or maintenance window is needed, except in the rare case described in [Step 6](#step-6-check-whether-a-restart-is-needed). On a single-machine instance, that restart stops all VMs. |
| First step | Run the check in [Issue Validation](#issue-validation). |

## Overview

Azure Local ships its own copy of the Environment Checker PowerShell module, called the inbox module. The same module is also published on the PowerShell Gallery so that you can run readiness checks before deployment. The inbox version must be the one that loads, so before a deployment, update, upgrade, add node, or repair node operation, Azure Local tries to remove every other copy, but only on the machine where the Azure Stack HCI Orchestrator Service is running at the time. Copies on the other machines stay until the service runs these checks there, or until you remove them with the steps below, so check every machine.

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

**Newer builds** (example from Environment Checker 10.2510.0.2100): Azure Local removes the extra copy by itself on the machine running the Orchestrator Service, and fails only when it cannot delete the files, usually because a PowerShell session still has the module loaded. The error links to this article. For example (the version folder and file name vary):

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
| External copy | Any other copy, for example one installed with `Install-Module` from the PowerShell Gallery. It lives in a version-number subfolder such as `...\AzStackHci.EnvironmentChecker\10.2411.0.12`. Deployment and solution updates can also leave copies in version-number folders on some machines, and those copies can stay after the operation succeeds. They are removed the same way. A listed copy without the error in [Symptoms](#symptoms) is not by itself the cause of a failure. |
| PowerShell Gallery | The public online repository that `Install-Module` downloads PowerShell modules from. |
| In use | A process, usually a PowerShell window or remote session, still has files from the external copy loaded, so Windows does not allow them to be deleted. |
| Restart Manager | A built-in Windows component that reports which processes hold a file. [Step 1](#step-1-find-the-processes-that-hold-the-external-copys-files) uses it to name the exact processes that keep the external copy's files in use. |
| Result line | A line in capital letters, for example `NO_LOCKING_SESSIONS`, that a script in this article prints to report its result. Each step says what each result line means and what to do next. |

## Where you can see this problem

- **PowerShell on each machine:** the check in [Issue Validation](#issue-validation) lists the external copy.
- **Azure portal:** the failed step shows the error from [Symptoms](#symptoms), under **Deployments** for a deployment, or in the failure details under **Updates** for a solution update. This follows the documented behavior for failed steps.
- **Log files on the machine:** the deployment log for the failed step in `C:\CloudDeployment\Logs`, for example `EnvironmentValidatorFull.<date>.log` during deployment, contains `Externally installed module(s) found for AzStackHci.EnvironmentChecker` and `Attempting to uninstall` (older builds log `Uninstalling`), followed by the result or the error.
- **Windows event logs:** the error does not appear in the Windows event logs.
- **Cluster log:** the error does not appear in the cluster log (`Get-ClusterLog`), because no cluster resource changes state.
- **Failover Cluster Manager:** the error does not appear in Failover Cluster Manager.
- **Windows Admin Center:** the error does not appear in Windows Admin Center on a standalone host or in Windows Admin Center in the Azure portal.

## Before you start

- Open PowerShell with **Run as administrator** on each machine.
- Make sure no update or deployment step is running right now. Step 2 checks this for solution updates and stops nothing while one is running.
- Use Windows PowerShell 5.1 (`powershell.exe`), not PowerShell 7, in full language mode: `$ExecutionContext.SessionState.LanguageMode` returns `FullLanguage`. This is the default on Azure Local, including when Application Control is enforced. In a constrained session, Step 1 reports `LOCK_CHECK_UNAVAILABLE`, and some of the later scripts stop with an error.
- Run [Issue Validation](#issue-validation) first. Continue only if it prints `EXTERNAL_COPY_FOUND` or `LEFTOVER_FOLDER_ONLY`.
- If it prints `INBOX_MODULE_MISSING`, stop and [contact Microsoft support](#when-to-contact-microsoft-support). Do not install a replacement.

## Issue Validation

Run this in an elevated PowerShell session on each machine. It changes nothing. It lists external copies, meaning module copies whose path contains their version number, and leftover version-number folders, and its first line is the result.

```powershell
& {
    $moduleName = "AzStackHci.EnvironmentChecker"
    $root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$moduleName"
    $available = @(Get-Module -Name $moduleName -ListAvailable)
    $external = @($available | Where-Object { $_.Path -like "*$($_.Version)*" })
    $versionFolders = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] })
    if (@($available | Where-Object { $_.Path -notlike "*$($_.Version)*" }).Count -eq 0) { Write-Output "INBOX_MODULE_MISSING" }
    elseif ($external.Count -gt 0) { Write-Output "EXTERNAL_COPY_FOUND" }
    elseif ($versionFolders.Count -gt 0) { Write-Output "LEFTOVER_FOLDER_ONLY" }
    else { Write-Output "NOT_AFFECTED" }
    $external | Format-Table Name, Version, Path -AutoSize
    $versionFolders | ForEach-Object { "Version-number folder: $($_.FullName)" }
}
```

To check every machine at once, run this from one machine. It checks this machine and every other machine of the cluster that it can reach with PowerShell remoting, and prints one result for each machine. A machine that it cannot reach shows `Not checked from here`; run the single-machine check above on that machine. Before the cluster exists (during deployment), it checks only this machine, so run the single-machine check on each machine. If it cannot tell whether this machine is in a cluster, it prints `CLUSTER_STATE_UNKNOWN` first and checks only this machine.

```powershell
& {
    $moduleName = "AzStackHci.EnvironmentChecker"
    $checkMachine = {
        param($Name)
        $root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$Name"
        $available = @(Get-Module -Name $Name -ListAvailable)
        $external = @($available | Where-Object { $_.Path -like "*$($_.Version)*" } | ForEach-Object { $_.Path })
        $folders = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] } | ForEach-Object { $_.FullName })
        if (@($available | Where-Object { $_.Path -notlike "*$($_.Version)*" }).Count -eq 0) { $result = 'INBOX_MODULE_MISSING' }
        elseif ($external.Count -gt 0) { $result = 'EXTERNAL_COPY_FOUND' }
        elseif ($folders.Count -gt 0) { $result = 'LEFTOVER_FOLDER_ONLY' }
        else { $result = 'NOT_AFFECTED' }
        [pscustomobject]@{ Result = $result; ExternalCopies = ($external -join '; '); VersionFolders = ($folders -join '; ') }
    }
    $clusterNote = 'Get-ClusterNode returned no machines.'
    $nodes = @()
    try { $nodes = @(Get-ClusterNode -ErrorAction Stop | ForEach-Object { "$($_.Name)" }) } catch { $clusterNote = $_.Exception.Message }
    $hasClusSvc = $true
    $hasClusDb = $true
    if ($nodes.Count -eq 0) {
        try { $hasClusSvc = @(Get-CimInstance -ClassName Win32_Service -Filter "Name = 'ClusSvc'" -ErrorAction Stop).Count -gt 0 } catch { }
        try { $null = Get-Item -LiteralPath (Join-Path $env:SystemRoot 'Cluster\CLUSDB') -Force -ErrorAction Stop } catch [System.Management.Automation.ItemNotFoundException] { $hasClusDb = $false } catch { }
    }
    $inCluster = if ($nodes.Count -gt 0) { 'Yes' } elseif ($hasClusSvc -and $hasClusDb) { 'Unknown' } else { 'No' }
    if ($nodes -notcontains $env:COMPUTERNAME) { $nodes = @($env:COMPUTERNAME) + $nodes }
    $rows = @(foreach ($node in $nodes) {
        try {
            if ($node -eq $env:COMPUTERNAME) { $state = & $checkMachine $moduleName }
            else { $state = Invoke-Command -ComputerName $node -ScriptBlock $checkMachine -ArgumentList $moduleName -ErrorAction Stop }
            [pscustomobject]@{ Machine = $node; Result = $state.Result; ExternalCopies = $state.ExternalCopies; VersionFolders = $state.VersionFolders; Note = '' }
        } catch {
            [pscustomobject]@{ Machine = $node; Result = 'Not checked from here'; ExternalCopies = ''; VersionFolders = ''; Note = $_.Exception.Message }
        }
    })
    if ($inCluster -eq 'Unknown') {
        Write-Output 'CLUSTER_STATE_UNKNOWN'
        "Could not tell whether this machine is in a cluster, so only this machine was checked: $clusterNote"
        'Run this check on another machine of the cluster.'
    }
    elseif ($inCluster -eq 'No') { 'The cluster does not exist yet, so only this machine was checked. Run the single-machine check on each machine.' }
    $rows | Format-List Machine, Result, ExternalCopies, VersionFolders, Note
}
```

How to read the result for each machine. The all-machines check prints the same results in its `Result` field, one for each machine.

| Result | Meaning | Next step |
| --- | --- | --- |
| `EXTERNAL_COPY_FOUND` | An external copy is present. | Follow Steps 1 to 7 in [Mitigation Details](#mitigation-details). |
| `LEFTOVER_FOLDER_ONLY` | A leftover folder from a partly removed copy. It no longer loads. | Follow Steps 1 to 7 in [Mitigation Details](#mitigation-details). Steps 1 to 4 release the folder's files if a program still holds them, Step 5 has nothing to uninstall, and [Step 7](#step-7-delete-leftover-folders) deletes the folder. If Step 7 tells you to leave the folder until the next planned restart, no further action is needed now. |
| `NOT_AFFECTED` | This machine is not affected. | None. |
| `INBOX_MODULE_MISSING` | The inbox module is missing. | Stop and [contact Microsoft support](#when-to-contact-microsoft-support). Do not install a replacement. The cleanup scripts in Steps 5 and 7 remove nothing on a machine without the inbox module, and the retry script retries nothing. |
| `Not checked from here` | All-machines check only: PowerShell remoting to that machine failed, so it was not checked. This does not mean that it is affected. `Note` shows the reason. | Run the single-machine check on that machine. |
| `CLUSTER_STATE_UNKNOWN` | All-machines check only, printed before the results: `Get-ClusterNode` failed or returned no machines, and the script could not confirm that the Cluster service is not installed or that the machine has no cluster database, so it could not tell whether this machine is in a cluster and checked only this machine. The line after it shows the reason. | Read this machine's `Result` as the other rows say. Then run the all-machines check on another machine of the cluster. If every machine prints this, run the single-machine check on each machine. |

## Mitigation Details

Run these steps in order on each affected machine. Step 2 uses the list that Step 1 saves on the machine, so you can run each step in a new PowerShell window. Each script checks or changes only the machine it runs on, is safe to run when it has nothing to do, and prints its result line first. Paste or run each block whole. None of the steps affects running VMs or needs a maintenance window, except the restart that [Step 6](#step-6-check-whether-a-restart-is-needed) can ask for.

### Step 1: Find the processes that hold the external copy's files

This step asks Windows Restart Manager which processes hold files in the external copy's folders, including a copy outside `C:\Program Files`, for example one installed for the current user only, and in leftover version-number folders, lists each one with its owner, sign-in session, start time, Windows service, and command line, and says in `NextStep` what to do about it. `Get-Process` does not show these files, because PowerShell loads the module's .NET files in a way that it does not list. Remote PowerShell sessions appear as `wsmprovhost`.

The script marks a process `Step 2 stops it.` only if it is a PowerShell window (`powershell`, `powershell_ise`, or `pwsh`) that a person started: it does not run as SYSTEM, LocalService, NetworkService, or an account that runs a Windows service, does not run or belong to a Windows service, is in a signed-in user's session, and was opened by a person signed in to this machine: its parent processes in that session lead back to the SConfig menu or the command prompt that opens when you sign in to the machine, or to File Explorer on a machine with the desktop, with no service, Task Scheduler, WMI, or remote session host between them. If Step 1 cannot confirm that, for example because a parent process has already ended, it does not mark the window, and you close it in Step 3. It never marks a remote session (`wsmprovhost`), because Azure Local's own operations also run in remote sessions, and the two look the same. It never marks the PowerShell window that it runs in, or the window that started it, for example when you run it as a new process from your window: it tells you to close that window, open a new one, and start again at Step 1. It saves the list, with each process's ID, start time, name, owner, and whether it is marked, for Step 2. If it cannot save the list, it says so after its result line, and Step 2 stops nothing.

**Changes:** saves the list to `Step1List.json` in the folder `C:\ProgramData\AzStackHci.EnvironmentChecker.Step1`, replacing an earlier list. It creates the folder if needed and sets its permissions so that only Administrators and SYSTEM can change it. When no process holds the files, it deletes the folder and saves nothing. Step 2 deletes the folder when it ends. Nothing else changes.

```powershell
& {
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        Write-Output 'WINDOWS_POWERSHELL_REQUIRED'
        Write-Output 'Run this in Windows PowerShell 5.1 (powershell.exe), not in PowerShell 7.'
        return
    }
    function Get-EnvCheckerFileHolder {
        $moduleRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker'
        $folders = @(Get-ChildItem -Path $moduleRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] } | ForEach-Object { $_.FullName }) +
            @(Get-Module -Name 'AzStackHci.EnvironmentChecker' -ListAvailable | Where-Object { $_.Path -like "*$($_.Version)*" } | ForEach-Object { $_.ModuleBase })
        $files = @($folders | Sort-Object -Unique |
            ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Force -ErrorAction SilentlyContinue } |
            ForEach-Object { $_.FullName } | Sort-Object -Unique)
        if ($files.Count -eq 0) { return }
        if (-not ('EnvCheckerFileHolders' -as [type])) {
            Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public static class EnvCheckerFileHolders {
    [StructLayout(LayoutKind.Sequential)]
    struct RM_UNIQUE_PROCESS { public int ProcessId; public System.Runtime.InteropServices.ComTypes.FILETIME StartTime; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string AppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string ServiceShortName;
        public int ApplicationType; public uint AppStatus; public uint SessionId;
        [MarshalAs(UnmanagedType.Bool)] public bool Restartable;
    }
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmStartSession(out uint session, int flags, StringBuilder key);
    [DllImport("rstrtmgr.dll")]
    static extern int RmEndSession(uint session);
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmRegisterResources(uint session, uint fileCount, string[] files, uint appCount, RM_UNIQUE_PROCESS[] apps, uint serviceCount, string[] services);
    [DllImport("rstrtmgr.dll")]
    static extern int RmGetList(uint session, out uint needed, ref uint count, [In, Out] RM_PROCESS_INFO[] info, ref uint reasons);
    public static int[] GetProcessIds(string[] files) {
        uint session;
        int rc = RmStartSession(out session, 0, new StringBuilder(64));
        if (rc != 0) { throw new Win32Exception(rc); }
        try {
            rc = RmRegisterResources(session, (uint)files.Length, files, 0, null, 0, null);
            if (rc != 0) { throw new Win32Exception(rc); }
            for (int attempt = 0; attempt < 5; attempt++) {
                uint needed = 0, count = 0, reasons = 0;
                rc = RmGetList(session, out needed, ref count, null, ref reasons);
                if (rc == 0) { return new int[0]; }
                if (rc != 234) { throw new Win32Exception(rc); }
                RM_PROCESS_INFO[] info = new RM_PROCESS_INFO[needed];
                count = needed;
                rc = RmGetList(session, out needed, ref count, info, ref reasons);
                if (rc == 0) {
                    List<int> ids = new List<int>();
                    for (int i = 0; i < count; i++) { ids.Add(info[i].Process.ProcessId); }
                    return ids.ToArray();
                }
                if (rc != 234) { throw new Win32Exception(rc); }
            }
            throw new Win32Exception(234);
        }
        finally { RmEndSession(session); }
    }
}
'@
        }
        $holderIds = @([EnvCheckerFileHolders]::GetProcessIds([string[]]$files) | Sort-Object -Unique)
        $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
        $servicePids = @($services | Where-Object { $_.ProcessId -gt 0 } | ForEach-Object { $_.ProcessId })
        $serviceSids = @('S-1-5-18', 'S-1-5-19', 'S-1-5-20') + @($services | ForEach-Object {
            try { ([System.Security.Principal.NTAccount]($_.StartName -replace '^\.\\', "$env:COMPUTERNAME\")).Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { }
        })
        $byId = @{}
        foreach ($p in @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)) { $byId[[int]$p.ProcessId] = $p }
        $self = @([int]$PID)
        $selfChild = $byId[[int]$PID]
        for ($depth = 0; $selfChild -and $depth -lt 16; $depth++) {
            $selfUp = $byId[[int]$selfChild.ParentProcessId]
            if (-not $selfUp -or ($selfUp.CreationDate -gt $selfChild.CreationDate) -or ($self -contains [int]$selfUp.ProcessId)) { break }
            $self += [int]$selfUp.ProcessId
            $selfChild = $selfUp
        }
        $hostNames = 'services.exe', 'svchost.exe', 'taskhostw.exe', 'taskeng.exe', 'wmiprvse.exe', 'wsmprovhost.exe', 'winrshost.exe'
        $isHost = { param($q) ($q.SessionId -ne $process.SessionId) -or ($servicePids -contains $q.ProcessId) -or ($hostNames -contains $q.Name) }
        foreach ($id in $holderIds) {
            $process = $byId[[int]$id]
            if (-not $process) { continue }
            $name = $process.Name -replace '\.exe$', ''
            $sid = (Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction SilentlyContinue).Sid
            $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwner -ErrorAction SilentlyContinue
            $ownerName = if ($owner.User) { "$($owner.Domain)\$($owner.User)" } else { 'unknown' }
            $hostsService = $servicePids -contains $id
            $origin = 'Unknown'
            $child = $process
            for ($depth = 0; $depth -lt 16 -and $origin -eq 'Unknown'; $depth++) {
                $up = $byId[[int]$child.ParentProcessId]
                if (-not $up -or ($up.CreationDate -gt $child.CreationDate)) { break }
                if (& $isHost $up) { $origin = 'Service' }
                elseif (('explorer.exe', 'servercoreshell.exe' -contains $up.Name) -or (($up.Name -eq 'cmd.exe') -and ("$($up.CommandLine)" -like '*runonce.exe /AlternateShellStartup*'))) {
                    $top = $byId[[int]$up.ParentProcessId]
                    if ($top -and ($top.CreationDate -le $up.CreationDate) -and (& $isHost $top)) { $origin = 'Service' } else { $origin = 'SignIn' }
                }
                else { $child = $up }
            }
            $userAccount = $sid -and ($serviceSids -notcontains $sid)
            $isPowerShell = 'powershell', 'pwsh', 'powershell_ise' -contains $name
            $canStop = $isPowerShell -and $userAccount -and -not $hostsService -and ($origin -eq 'SignIn') -and ($process.SessionId -ne 0)
            $why = if ($isPowerShell -and $origin -eq 'Unknown') { 'Step 2 could not confirm that a person signed in to this machine opened it, so it does not stop it. ' } else { '' }
            if ($self -contains [int]$id) { $canStop = $false; $next = 'This PowerShell window, or the window that started this script, holds the files. Close it, open a new window, and start again at Step 1.' }
            elseif ($canStop) { $next = 'Step 2 stops it.' }
            elseif ($name -eq 'wsmprovhost' -and $userAccount -and -not $hostsService) { $next = "Remote PowerShell session of $ownerName. Ask them to end it on the computer that opened it. If no one can, leave it running; Step 5 removes what it can." }
            elseif (-not $userAccount -or $hostsService -or ($origin -eq 'Service')) { $next = 'It runs as or for a Windows service, or a service such as Task Scheduler started it. Leave it running; Step 5 removes what it can, and Step 6 says whether a restart is needed.' }
            elseif ($process.SessionId -eq 0) { $next = "$($why)Ask $ownerName to close it or end their remote session. Never sign out session 0." }
            elseif ($process.SessionId -eq (Get-Process -Id $PID).SessionId) { $next = "$($why)It runs in your own sign-in session. Close it." }
            else { $next = "$($why)Ask $ownerName to close it. If that is not possible, sign the user out with: logoff $($process.SessionId)" }
            [pscustomobject]@{
                ProcessId   = $id
                Name        = $process.Name
                Owner       = $ownerName
                SessionId   = $process.SessionId
                Service     = @($services | Where-Object { $_.ProcessId -eq $id } | ForEach-Object { $_.Name }) -join ', '
                StartTime   = $process.CreationDate
                CanStop     = $canStop
                NextStep    = $next
                CommandLine = $process.CommandLine
                Key         = "$id|$(if ($process.CreationDate) { $process.CreationDate.ToUniversalTime().Ticks })"
            }
        }
    }
    $holders = @()
    $checkError = $null
    try { $holders = @(Get-EnvCheckerFileHolder) } catch { $checkError = $_.Exception.Message }
    $listDir = Join-Path $env:ProgramData 'AzStackHci.EnvironmentChecker.Step1'
    $listPath = Join-Path $listDir 'Step1List.json'
    $listError = $null
    try {
        if (Test-Path -LiteralPath $listDir) { Remove-Item -LiteralPath $listDir -Recurse -Force -ErrorAction Stop }
        if (-not $checkError -and $holders.Count -gt 0) {
            $admins = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
            $system = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
            $dirAcl = New-Object System.Security.AccessControl.DirectorySecurity
            $fileAcl = New-Object System.Security.AccessControl.FileSecurity
            foreach ($acl in $dirAcl, $fileAcl) {
                $acl.SetOwner($admins)
                $acl.SetAccessRuleProtection($true, $false)
            }
            foreach ($sid in $admins, $system) {
                $dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
                $fileAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'Allow')))
            }
            $null = New-Item -ItemType Directory -Path $listDir -ErrorAction Stop
            Set-Acl -LiteralPath $listDir -AclObject $dirAcl -ErrorAction Stop
            [pscustomobject]@{
                Machine      = $env:COMPUTERNAME
                Written      = (Get-Date).ToString('o')
                WrittenTicks = [DateTime]::UtcNow.Ticks
                Processes    = @($holders | ForEach-Object { [pscustomobject]@{ ProcessId = $_.ProcessId; Name = $_.Name; Owner = $_.Owner; StartTime = "$($_.StartTime)"; StepTwoStops = $_.CanStop; Key = $_.Key } })
            } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $listPath -Encoding UTF8 -ErrorAction Stop
            Set-Acl -LiteralPath $listPath -AclObject $fileAcl -ErrorAction Stop
        }
    } catch {
        $listError = $_.Exception.Message
        Remove-Item -LiteralPath $listDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($checkError) {
        Write-Output 'LOCK_CHECK_UNAVAILABLE'
        Write-Output "Restart Manager could not be used in this PowerShell session: $checkError"
    }
    elseif ($holders.Count -eq 0) {
        Write-Output 'NO_LOCKING_SESSIONS'
        Write-Output "No process holds files in the external copy's folders."
    }
    else {
        if (@($holders | Where-Object { -not $_.CanStop }).Count -gt 0) { Write-Output 'OTHER_HOLDERS_FOUND' }
        else { Write-Output 'LOCKING_SESSIONS_FOUND' }
        if ($listError) { "Step 2 cannot run, because this list could not be saved to ${listPath}: $listError Close the PowerShell windows marked 'Step 2 stops it.' yourself, or ask their owners to, then continue after Step 2." }
        else { "This list is saved in $listPath for Step 2." }
        $holders | Format-List ProcessId, Name, Owner, SessionId, Service, StartTime, NextStep, CommandLine
    }
}
```

| Result | Meaning | Next step |
| --- | --- | --- |
| `LOCKING_SESSIONS_FOUND` | Only PowerShell sessions that Step 2 stops hold the files. The list is saved for Step 2. Check each `Owner` and `CommandLine` before you continue. | Go to Step 2. |
| `OTHER_HOLDERS_FOUND` | At least one listed process is one that Step 2 does not stop. Its `NextStep` says what to do. The list is saved for Step 2. | Go to Step 2, then Step 3. |
| `NO_LOCKING_SESSIONS` | No process holds the files. | Go to Step 5. |
| `LOCK_CHECK_UNAVAILABLE` | Restart Manager could not run in this session, so nothing was checked, and Step 2 stops nothing. The cleanup in Step 5 still removes the copy's module manifest, so the copy stops loading even if some files stay in use. | Close any other PowerShell window that you opened on this machine and no longer need, then go to Step 5. |
| `WINDOWS_POWERSHELL_REQUIRED` | The script ran in PowerShell 7 and checked nothing. | Open Windows PowerShell 5.1 as administrator and run Step 1 again. |

### Step 2: Stop the PowerShell sessions that hold the files

Run this after you have read the Step 1 list, in any PowerShell window on the same machine. It reads the list that Step 1 saved and stops a process only if Step 1 marked it `Step 2 stops it.`, it is the same process (same process ID and start time), it still holds the files, and the same check that Step 1 runs still marks it. It uses a list only if it was written in the last 60 minutes and only Administrators and SYSTEM can change the list and its folder, and it deletes the folder when it ends, whatever it prints, so each list is used once. Just before it stops a process, it opens that process and checks its start time again, and it stops it through that same handle, so a process that reused the ID is never stopped. On a deployed system it first reads the solution update state and stops nothing while an update or a health check is running. It treats the machine as not yet deployed when the Cluster service (ClusSvc) is not installed or the machine has no cluster database (`%SystemRoot%\Cluster\CLUSDB`), which every cluster member keeps, and in no other case. If `Get-ClusterNode` fails and neither is confirmed, it stops nothing. It cannot check deployment, add node, or repair node operations, so confirm in the Azure portal that none is running. If the list includes another person's session, ask them before you run this step.

**Changes:** stops the PowerShell windows described above. Work that is not saved in them is lost. It does not stop the window you run it from, the window that started it, any service, or any other process. It deletes the folder with the list that Step 1 saved. Running VMs are not affected.

```powershell
& {
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        Write-Output 'WINDOWS_POWERSHELL_REQUIRED'
        Write-Output 'Nothing was stopped. Run this in Windows PowerShell 5.1 (powershell.exe), not in PowerShell 7.'
        return
    }
    $listDir = Join-Path $env:ProgramData 'AzStackHci.EnvironmentChecker.Step1'
    $listPath = Join-Path $listDir 'Step1List.json'
    if (-not (Test-Path -LiteralPath $listPath)) {
        Write-Output 'STEP_1_LIST_MISSING'
        Write-Output 'Nothing was stopped. Run Step 1 again, review its list, then run this step.'
        return
    }
    try {
        function Get-EnvCheckerFileHolder {
            $moduleRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker'
            $folders = @(Get-ChildItem -Path $moduleRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] } | ForEach-Object { $_.FullName }) +
                @(Get-Module -Name 'AzStackHci.EnvironmentChecker' -ListAvailable | Where-Object { $_.Path -like "*$($_.Version)*" } | ForEach-Object { $_.ModuleBase })
            $files = @($folders | Sort-Object -Unique |
                ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Force -ErrorAction SilentlyContinue } |
                ForEach-Object { $_.FullName } | Sort-Object -Unique)
            if ($files.Count -eq 0) { return }
            if (-not ('EnvCheckerFileHolders' -as [type])) {
                Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public static class EnvCheckerFileHolders {
    [StructLayout(LayoutKind.Sequential)]
    struct RM_UNIQUE_PROCESS { public int ProcessId; public System.Runtime.InteropServices.ComTypes.FILETIME StartTime; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string AppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string ServiceShortName;
        public int ApplicationType; public uint AppStatus; public uint SessionId;
        [MarshalAs(UnmanagedType.Bool)] public bool Restartable;
    }
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmStartSession(out uint session, int flags, StringBuilder key);
    [DllImport("rstrtmgr.dll")]
    static extern int RmEndSession(uint session);
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmRegisterResources(uint session, uint fileCount, string[] files, uint appCount, RM_UNIQUE_PROCESS[] apps, uint serviceCount, string[] services);
    [DllImport("rstrtmgr.dll")]
    static extern int RmGetList(uint session, out uint needed, ref uint count, [In, Out] RM_PROCESS_INFO[] info, ref uint reasons);
    public static int[] GetProcessIds(string[] files) {
        uint session;
        int rc = RmStartSession(out session, 0, new StringBuilder(64));
        if (rc != 0) { throw new Win32Exception(rc); }
        try {
            rc = RmRegisterResources(session, (uint)files.Length, files, 0, null, 0, null);
            if (rc != 0) { throw new Win32Exception(rc); }
            for (int attempt = 0; attempt < 5; attempt++) {
                uint needed = 0, count = 0, reasons = 0;
                rc = RmGetList(session, out needed, ref count, null, ref reasons);
                if (rc == 0) { return new int[0]; }
                if (rc != 234) { throw new Win32Exception(rc); }
                RM_PROCESS_INFO[] info = new RM_PROCESS_INFO[needed];
                count = needed;
                rc = RmGetList(session, out needed, ref count, info, ref reasons);
                if (rc == 0) {
                    List<int> ids = new List<int>();
                    for (int i = 0; i < count; i++) { ids.Add(info[i].Process.ProcessId); }
                    return ids.ToArray();
                }
                if (rc != 234) { throw new Win32Exception(rc); }
            }
            throw new Win32Exception(234);
        }
        finally { RmEndSession(session); }
    }
}
'@
            }
            $holderIds = @([EnvCheckerFileHolders]::GetProcessIds([string[]]$files) | Sort-Object -Unique)
            $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
            $servicePids = @($services | Where-Object { $_.ProcessId -gt 0 } | ForEach-Object { $_.ProcessId })
            $serviceSids = @('S-1-5-18', 'S-1-5-19', 'S-1-5-20') + @($services | ForEach-Object {
                try { ([System.Security.Principal.NTAccount]($_.StartName -replace '^\.\\', "$env:COMPUTERNAME\")).Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { }
            })
            $byId = @{}
            foreach ($p in @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)) { $byId[[int]$p.ProcessId] = $p }
            $self = @([int]$PID)
            $selfChild = $byId[[int]$PID]
            for ($depth = 0; $selfChild -and $depth -lt 16; $depth++) {
                $selfUp = $byId[[int]$selfChild.ParentProcessId]
                if (-not $selfUp -or ($selfUp.CreationDate -gt $selfChild.CreationDate) -or ($self -contains [int]$selfUp.ProcessId)) { break }
                $self += [int]$selfUp.ProcessId
                $selfChild = $selfUp
            }
            $hostNames = 'services.exe', 'svchost.exe', 'taskhostw.exe', 'taskeng.exe', 'wmiprvse.exe', 'wsmprovhost.exe', 'winrshost.exe'
            $isHost = { param($q) ($q.SessionId -ne $process.SessionId) -or ($servicePids -contains $q.ProcessId) -or ($hostNames -contains $q.Name) }
            foreach ($id in $holderIds) {
                $process = $byId[[int]$id]
                if (-not $process) { continue }
                $name = $process.Name -replace '\.exe$', ''
                $sid = (Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction SilentlyContinue).Sid
                $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwner -ErrorAction SilentlyContinue
                $ownerName = if ($owner.User) { "$($owner.Domain)\$($owner.User)" } else { 'unknown' }
                $hostsService = $servicePids -contains $id
                $origin = 'Unknown'
                $child = $process
                for ($depth = 0; $depth -lt 16 -and $origin -eq 'Unknown'; $depth++) {
                    $up = $byId[[int]$child.ParentProcessId]
                    if (-not $up -or ($up.CreationDate -gt $child.CreationDate)) { break }
                    if (& $isHost $up) { $origin = 'Service' }
                    elseif (('explorer.exe', 'servercoreshell.exe' -contains $up.Name) -or (($up.Name -eq 'cmd.exe') -and ("$($up.CommandLine)" -like '*runonce.exe /AlternateShellStartup*'))) {
                        $top = $byId[[int]$up.ParentProcessId]
                        if ($top -and ($top.CreationDate -le $up.CreationDate) -and (& $isHost $top)) { $origin = 'Service' } else { $origin = 'SignIn' }
                    }
                    else { $child = $up }
                }
                $userAccount = $sid -and ($serviceSids -notcontains $sid)
                $isPowerShell = 'powershell', 'pwsh', 'powershell_ise' -contains $name
                $canStop = $isPowerShell -and $userAccount -and -not $hostsService -and ($origin -eq 'SignIn') -and ($process.SessionId -ne 0)
                $why = if ($isPowerShell -and $origin -eq 'Unknown') { 'Step 2 could not confirm that a person signed in to this machine opened it, so it does not stop it. ' } else { '' }
                if ($self -contains [int]$id) { $canStop = $false; $next = 'This PowerShell window, or the window that started this script, holds the files. Close it, open a new window, and start again at Step 1.' }
                elseif ($canStop) { $next = 'Step 2 stops it.' }
                elseif ($name -eq 'wsmprovhost' -and $userAccount -and -not $hostsService) { $next = "Remote PowerShell session of $ownerName. Ask them to end it on the computer that opened it. If no one can, leave it running; Step 5 removes what it can." }
                elseif (-not $userAccount -or $hostsService -or ($origin -eq 'Service')) { $next = 'It runs as or for a Windows service, or a service such as Task Scheduler started it. Leave it running; Step 5 removes what it can, and Step 6 says whether a restart is needed.' }
                elseif ($process.SessionId -eq 0) { $next = "$($why)Ask $ownerName to close it or end their remote session. Never sign out session 0." }
                elseif ($process.SessionId -eq (Get-Process -Id $PID).SessionId) { $next = "$($why)It runs in your own sign-in session. Close it." }
                else { $next = "$($why)Ask $ownerName to close it. If that is not possible, sign the user out with: logoff $($process.SessionId)" }
                [pscustomobject]@{
                    ProcessId   = $id
                    Name        = $process.Name
                    Owner       = $ownerName
                    SessionId   = $process.SessionId
                    Service     = @($services | Where-Object { $_.ProcessId -eq $id } | ForEach-Object { $_.Name }) -join ', '
                    StartTime   = $process.CreationDate
                    CanStop     = $canStop
                    NextStep    = $next
                    CommandLine = $process.CommandLine
                    Key         = "$id|$(if ($process.CreationDate) { $process.CreationDate.ToUniversalTime().Ticks })"
                }
            }
        }
        $reviewed = @()
        $listAge = $null
        $listProblem = $null
        try {
            $trusted = @('S-1-5-32-544', 'S-1-5-18')
            foreach ($item in $listDir, $listPath) {
                $acl = Get-Acl -LiteralPath $item -ErrorAction Stop
                $itemOwner = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
                $writers = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) | Where-Object { ("$($_.AccessControlType)" -eq 'Allow') -and (([int]$_.FileSystemRights -band 0x500D0156) -ne 0) -and ($trusted -notcontains $_.IdentityReference.Value) } | ForEach-Object { $_.IdentityReference.Value })
                if ($trusted -notcontains $itemOwner) { $listProblem = "$item is owned by $itemOwner, not by Administrators or SYSTEM."; break }
                if ($writers.Count -gt 0) { $listProblem = "$item can be changed by $($writers[0]), not only by Administrators and SYSTEM."; break }
            }
            if (-not $listProblem) {
                $list = Get-Content -LiteralPath $listPath -Raw -ErrorAction Stop | ConvertFrom-Json
                $listAge = [TimeSpan]::FromTicks([DateTime]::UtcNow.Ticks - [long]$list.WrittenTicks).TotalMinutes
                $reviewed = @(@($list.Processes) | Where-Object { $_.StepTwoStops -eq $true } | ForEach-Object { "$($_.Key)" })
            }
        } catch { $listProblem = $_.Exception.Message }
        if ($listProblem) {
            Write-Output 'STEP_1_LIST_NOT_USABLE'
            Write-Output "Nothing was stopped. The list that Step 1 saved cannot be used: $listProblem"
            return
        }
        if ($listAge -lt 0 -or $listAge -gt 60) {
            Write-Output 'STEP_1_LIST_STALE'
            Write-Output 'Nothing was stopped, because the list that Step 1 saved was not written in the last 60 minutes. Run Step 1 again, review its list, then run this step.'
            return
        }
        $clusterState = 'Unknown'
        $clusterNote = 'Get-ClusterNode returned no machines.'
        try { $clusterNodes = @(Get-ClusterNode -ErrorAction Stop); if ($clusterNodes.Count -gt 0) { $clusterState = 'Cluster' } } catch { $clusterNote = $_.Exception.Message }
        if ($clusterState -eq 'Unknown') {
            try { if (@(Get-CimInstance -ClassName Win32_Service -Filter "Name = 'ClusSvc'" -ErrorAction Stop).Count -eq 0) { $clusterState = 'None' } } catch { }
        }
        if ($clusterState -eq 'Unknown') {
            try { $null = Get-Item -LiteralPath (Join-Path $env:SystemRoot 'Cluster\CLUSDB') -Force -ErrorAction Stop }
            catch [System.Management.Automation.ItemNotFoundException] { $clusterState = 'None' }
            catch { }
        }
        if ($clusterState -eq 'Unknown') {
            Write-Output 'CLUSTER_STATE_UNKNOWN'
            Write-Output "Nothing was stopped. Could not tell whether this machine is in a cluster: $clusterNote"
            return
        }
        if ($clusterState -eq 'Cluster') {
            Import-Module -Name Microsoft.AzureStack.Lcm.PowerShell -ErrorAction SilentlyContinue 4>$null
            try {
                $active = @(Get-SolutionUpdate -ErrorAction Stop 4>$null | Where-Object { ('Installing', 'Preparing', 'HealthChecking', 'Downloading', 'ScanInProgress' -contains $_.State) -or ($_.HealthState -eq 'InProgress') })
                $environment = Get-SolutionUpdateEnvironment -ErrorAction Stop 4>$null
                if (("$($environment.State)" -like '*InProgress*') -or ("$($environment.HealthState)" -eq 'InProgress')) { $active += [pscustomobject]@{ DisplayName = 'The system health check'; State = 'InProgress' } }
            }
            catch {
                Write-Output 'UPDATE_STATE_UNKNOWN'
                Write-Output "Nothing was stopped. Could not read the solution update state: $($_.Exception.Message)"
                return
            }
            if ($active.Count -gt 0) {
                Write-Output 'UPDATE_IN_PROGRESS'
                Write-Output "Nothing was stopped. $($active[0].DisplayName) is $($active[0].State)."
                return
            }
        }
        try { $holders = @(Get-EnvCheckerFileHolder) }
        catch {
            Write-Output 'LOCK_CHECK_UNAVAILABLE'
            Write-Output "Nothing was stopped: $($_.Exception.Message)"
            return
        }
        $lines = @(foreach ($row in $holders) {
            if ($row.CanStop -and ($reviewed -contains $row.Key)) {
                $target = $null
                try {
                    $target = Get-Process -Id $row.ProcessId -ErrorAction Stop
                    $null = $target.Handle
                    $started = $target.StartTime
                    if ([math]::Abs($started.ToUniversalTime().Ticks - [long]($row.Key -split '\|')[1]) -gt 10000) {
                        "Left running: process ID $($row.ProcessId) is now a different process, started $started, not the one in the list you reviewed. Run Steps 1 and 2 again."
                    } else {
                        Stop-Process -InputObject $target -Force -ErrorAction Stop
                        $null = $target.WaitForExit(30000)
                        "Stopped $($row.Name), process ID $($row.ProcessId), owner $($row.Owner), started $($row.StartTime)."
                    }
                }
                catch { "Could not stop $($row.Name), process ID $($row.ProcessId): $($_.Exception.Message)" }
                finally { if ($target) { $target.Dispose() } }
            }
            elseif ($row.CanStop) { "Left running: $($row.Name), process ID $($row.ProcessId). It was not in the list you reviewed. Run Steps 1 and 2 again to review it." }
            else { "Left running: $($row.Name), process ID $($row.ProcessId). $($row.NextStep)" }
        })
        if (@($lines | Where-Object { $_ -like 'Stopped *' }).Count -gt 0) { Write-Output 'SESSIONS_STOPPED' } else { Write-Output 'NO_SESSIONS_STOPPED' }
        $lines
    }
    finally { Remove-Item -LiteralPath $listDir -Recurse -Force -ErrorAction SilentlyContinue }
}
```

| Result | Meaning | Next step |
| --- | --- | --- |
| `SESSIONS_STOPPED` | The script stopped the sessions it lists, and lists each process that it left running, including a process ID that now belongs to a different process. | Go to Step 3 if Step 1 printed `OTHER_HOLDERS_FOUND`; otherwise go to Step 4. |
| `NO_SESSIONS_STOPPED` | No reviewed session still held the files. | Go to Step 3 if Step 1 printed `OTHER_HOLDERS_FOUND`; otherwise go to Step 4. |
| `UPDATE_IN_PROGRESS` | A solution update or a health check is running, so nothing was stopped. Its PowerShell sessions can hold the files. | Wait until the update stops, then start again at Step 1. |
| `UPDATE_STATE_UNKNOWN` | The update state could not be read, so nothing was stopped. | Run Steps 1 and 2 again in a minute. If Step 2 keeps printing this, go to Step 5. |
| `CLUSTER_STATE_UNKNOWN` | `Get-ClusterNode` failed or returned no machines, and the script could not confirm that the Cluster service is not installed or that the machine has no cluster database, so it could not tell whether an update can be running. Nothing was stopped. The line after it shows the reason. | Confirm in the Azure portal that no update, deployment, add node, or repair node operation is running. Then ask the owner of each session that Step 1 marked `Step 2 stops it.` to close it, or close it yourself if it is yours, and go to Step 4. |
| `STEP_1_LIST_MISSING` | No list from Step 1 is saved on this machine, so nothing was stopped. Step 1 saves a list only when it finds processes that hold the files, and this step deletes it when it ends. | Run Step 1 again, review its list, then run this step. |
| `STEP_1_LIST_STALE` | The saved list was not written in the last 60 minutes, so it was not used and nothing was stopped. | Run Step 1 again, review its list, then run this step. |
| `STEP_1_LIST_NOT_USABLE` | The saved list could not be read, or someone other than Administrators and SYSTEM owns or can change it or its folder, so it was not used and nothing was stopped. The line after it shows the reason. | Run Step 1 again, review its list, then run this step. |
| `LOCK_CHECK_UNAVAILABLE` | Restart Manager could not run in this session, so nothing was stopped. | Follow the `LOCK_CHECK_UNAVAILABLE` row of Step 1. |
| `WINDOWS_POWERSHELL_REQUIRED` | The script ran in PowerShell 7 and stopped nothing. | Open Windows PowerShell 5.1 as administrator and run Steps 1 and 2 again. |

### Step 3: Close the other programs that hold the files

Do this step only if Step 1 printed `OTHER_HOLDERS_FOUND`. For each process whose `NextStep` does not say `Step 2 stops it.`, do what its `NextStep` says. Contact the owner before you close anything of theirs. Never sign out session 0: it runs the Windows services and remote sessions.

**Stop here and confirm.** The owner of each program that Step 1 listed, other than the PowerShell windows that Step 2 stops and the processes whose `NextStep` says to leave them running, confirms that it can be closed and closes it, or lets you close it. Then run Step 4. This step is done when Step 4 prints `FILES_RELEASED`, or when it prints `FILES_IN_USE` and running Step 1 again shows that only processes whose `NextStep` says to leave them running, or that their owners cannot close now, still hold the files.

**Changes:** ends each program that you or its owner closes, and any work that is not saved in it. Signing a user out with `logoff` ends all of that user's programs in that session. Running VMs are not affected.

### Step 4: Confirm that the files are released

This step changes nothing. It opens each file in the folders that Step 1 checks for exclusive use, without reading or writing anything, and closes it again at once. A file that another process has open is still in use. If a file cannot be opened for another reason, for example because it is read-only, the step says so instead of guessing. Paste or run the whole block at once.

```powershell
& {
    $moduleRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker'
    $folders = @(Get-ChildItem -Path $moduleRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] } | ForEach-Object { $_.FullName }) +
        @(Get-Module -Name 'AzStackHci.EnvironmentChecker' -ListAvailable | Where-Object { $_.Path -like "*$($_.Version)*" } | ForEach-Object { $_.ModuleBase })
    $files = @($folders | Sort-Object -Unique |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Force -ErrorAction SilentlyContinue } |
        ForEach-Object { $_.FullName } | Sort-Object -Unique)
    $inUse = @()
    $checkError = $null
    foreach ($file in $files) {
        try {
            $stream = [System.IO.File]::Open($file, 'Open', 'ReadWrite', 'None')
            $stream.Close()
        }
        catch [System.IO.IOException] { if (Test-Path -LiteralPath $file) { $inUse += $file } }
        catch { $checkError = "Could not open ${file}: $($_.Exception.Message)"; break }
    }
    if ($checkError) {
        Write-Output 'LOCK_CHECK_UNAVAILABLE'
        Write-Output $checkError
    }
    elseif ($files.Count -eq 0) {
        Write-Output 'NO_FILES_TO_CHECK'
        Write-Output "This machine has no files in the external copy's folders."
    }
    elseif ($inUse.Count -gt 0) {
        Write-Output 'FILES_IN_USE'
        $inUse | ForEach-Object { "In use: $_" }
        Write-Output 'Run the Step 1 script again to see which processes hold these files.'
    }
    else {
        Write-Output 'FILES_RELEASED'
        Write-Output "No file in the external copy's folders is in use ($($files.Count) files checked)."
    }
}
```

| Result | Meaning | Next step |
| --- | --- | --- |
| `FILES_RELEASED` | No file of the external copy is in use on this machine. | Go to Step 5. |
| `FILES_IN_USE` | The script lists the files that are still in use. | Run Step 1 again to see which processes hold them. If it marks a process `Step 2 stops it.`, run Step 2 and then this step again. If it lists a process that you can close, close it as Step 3 describes and run this step again. If it lists only processes whose `NextStep` says to leave them running, or that their owners cannot close now, go to Step 5 anyway: it removes everything it can, and Step 6 tells you whether a restart is needed. |
| `NO_FILES_TO_CHECK` | This machine has no files in the external copy's folders. | Go to Step 5. |
| `LOCK_CHECK_UNAVAILABLE` | The check could not open a file, for example because the file is read-only or this account is not allowed to open it, so it could not tell whether every file is released. The line after it names the file and the error. | Go to Step 5. It removes everything it can and reports any file that it cannot remove. |

### Step 5: Run the cleanup script

**Changes:** unloads, uninstalls, and deletes only copies in version-number folders. The inbox module and running VMs are not affected. When the inbox module is missing, the script removes nothing.

```powershell
& {
    $moduleName = 'AzStackHci.EnvironmentChecker'
    if (-not (Get-Module -Name $moduleName -ListAvailable | Where-Object { $_.Path -notlike "*$($_.Version)*" })) {
        Write-Output 'INBOX_MODULE_MISSING'
        Write-Output 'The inbox module is missing, so nothing was removed.'
        return
    }
    $log = @()
    foreach ($loaded in @(Get-Module -Name $moduleName | Where-Object { $_.Path -like "*$($_.Version)*" })) {
        $loaded | Remove-Module -Force
        $log += "Unloaded $($loaded.Path)"
    }
    $external = @(Get-Module -Name $moduleName -ListAvailable | Where-Object { $_.Path -like "*$($_.Version)*" })
    if ($external.Count -eq 0) { $log += 'Nothing to uninstall.' }
    foreach ($module in $external) {
        $module | Uninstall-Module -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $module.ModuleBase) {
            Remove-Item -LiteralPath $module.ModuleBase -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable removeErrors
            if ($removeErrors) { $log += "Some files in $($module.ModuleBase) are still in use and were not removed: $($removeErrors[0].Exception.Message)" }
            else { $log += "Removed $($module.ModuleBase)" }
        }
        else { $log += "Uninstalled $($module.ModuleBase)" }
    }
    $final = @(Get-Module -Name $moduleName -ListAvailable)
    if (-not ($final | Where-Object { $_.Path -notlike "*$($_.Version)*" })) { Write-Output 'INBOX_MODULE_MISSING' }
    elseif ($final | Where-Object { $_.Path -like "*$($_.Version)*" }) { Write-Output 'CLEANUP_EXTERNAL_REMAINS' }
    else { Write-Output 'CLEANUP_EXTERNAL_REMOVED' }
    $log
    'Modules listed now:'
    $final | Format-Table Name, Version, Path -AutoSize
}
```

| Result | Meaning | Next step |
| --- | --- | --- |
| `CLEANUP_EXTERNAL_REMOVED` | Only the inbox module is listed, at `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHci.EnvironmentChecker.psd1`, with no version-number folder in its path. If the script reported files that are still in use, the copy no longer loads because its module manifest is gone. | Go to Step 6. |
| `CLEANUP_EXTERNAL_REMAINS` | The external copy is still listed, so the operation stays blocked. This is rare: a program that is still running holds the copy's module manifest. | Go to Step 6. |
| `INBOX_MODULE_MISSING` | The inbox module is not listed, so the script removed nothing. | [Contact Microsoft support](#when-to-contact-microsoft-support). Do not install a replacement. The later steps change nothing on this machine, and the retry script retries nothing. |

### Step 6: Check whether a restart is needed

This step changes nothing. A restart is needed only in the rare case where Step 5 printed `CLEANUP_EXTERNAL_REMAINS`. The script checks for that case again and, when a restart is needed, prints how to restart this machine safely for its cluster size. If it cannot tell whether the machine is in a cluster, it says so and prints no restart instructions.

```powershell
& {
    $remaining = @(Get-Module -Name 'AzStackHci.EnvironmentChecker' -ListAvailable | Where-Object { $_.Path -like "*$($_.Version)*" })
    if ($remaining.Count -eq 0) {
        Write-Output 'NO_RESTART_NEEDED'
        return
    }
    Write-Output 'RESTART_REQUIRED'
    $remaining | ForEach-Object { "Still listed: $($_.Path)" }
    $clusterState = 'Unknown'
    $clusterNote = 'Get-ClusterNode returned no machines.'
    try { $clusterNodes = @(Get-ClusterNode -ErrorAction Stop); if ($clusterNodes.Count -gt 0) { $clusterState = 'Cluster' } } catch { $clusterNote = $_.Exception.Message }
    if ($clusterState -eq 'Unknown') {
        try { if (@(Get-CimInstance -ClassName Win32_Service -Filter "Name = 'ClusSvc'" -ErrorAction Stop).Count -eq 0) { $clusterState = 'None' } } catch { }
    }
    if ($clusterState -eq 'Unknown') {
        try { $null = Get-Item -LiteralPath (Join-Path $env:SystemRoot 'Cluster\CLUSDB') -Force -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] { $clusterState = 'None' }
        catch { }
    }
    if ($clusterState -eq 'Unknown') {
        Write-Output 'CLUSTER_STATE_UNKNOWN'
        "Could not tell whether this machine is in a cluster, so do not restart it yet: $clusterNote"
        return
    }
    if ($clusterState -eq 'None') {
        'The Cluster service is not installed or this machine has no cluster database, so it is not in a cluster. Restart it normally.'
    } elseif ($clusterNodes.Count -gt 1) {
        "This machine is in a cluster of $($clusterNodes.Count) machines. Pause and drain it before the restart, and resume it afterward: https://learn.microsoft.com/azure/azure-local/manage/suspend-resume-cluster-maintenance"
    } else {
        'This is a single-machine instance. The restart stops all running VMs, so plan a maintenance window and shut down or save the VMs first.'
    }
    'After the restart, run Steps 5, 6, and 7 again.'
}
```

| Result | Meaning | What to do |
| --- | --- | --- |
| `NO_RESTART_NEEDED` | The external copy no longer loads. | Go to Step 7. |
| `RESTART_REQUIRED` | The external copy is still listed, and only a restart releases the files that hold it. Until the restart, Step 7 deletes nothing and the retry script retries nothing. | Restart the machine as the script prints. |
| `CLUSTER_STATE_UNKNOWN` | Printed after `RESTART_REQUIRED`. `Get-ClusterNode` failed or returned no machines, and the script could not confirm that the Cluster service is not installed or that the machine has no cluster database, so it could not tell how to restart it safely. The line after it shows the reason. | Do not restart yet. Check in the Azure portal or in Failover Cluster Manager on another machine whether this machine is in a cluster. If it is one of several machines, [pause and drain it](https://learn.microsoft.com/azure/azure-local/manage/suspend-resume-cluster-maintenance) before the restart. If it is the only machine, plan a maintenance window and shut down or save its VMs first. After the restart, run Steps 5, 6, and 7 again. |

If you restart the machine: **Changes:** restarts this machine and ends every program on it. In a cluster, pausing and draining the machine first moves its VMs to the other machines.

**Plan for:** on a single-machine instance, a maintenance window, because there is no other machine to drain to.

> [!WARNING]
> On a single-machine instance, this restart stops all running VMs.

### Step 7: Delete leftover folders

**Changes:** deletes only subfolders whose name is a version number. The inbox files are not in such a subfolder and are not touched. The script deletes nothing when the inbox module is missing or while an external copy still loads.

```powershell
& {
    $moduleName = 'AzStackHci.EnvironmentChecker'
    $root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$moduleName"
    $available = @(Get-Module -Name $moduleName -ListAvailable)
    if (@($available | Where-Object { $_.Path -notlike "*$($_.Version)*" }).Count -eq 0) {
        Write-Output 'INBOX_MODULE_MISSING'
        Write-Output 'The inbox module is missing, so nothing was deleted.'
        return
    }
    if (@($available | Where-Object { $_.Path -like "*$($_.Version)*" }).Count -gt 0) {
        Write-Output 'RESTART_REQUIRED'
        Write-Output 'An external copy still loads, so nothing was deleted. Step 6 prints how to restart this machine.'
        return
    }
    $leftover = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] })
    $inUse = @()
    foreach ($folder in $leftover) {
        Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $folder.FullName) { $inUse += $folder.FullName }
    }
    if ($leftover.Count -eq 0) { Write-Output 'NO_LEFTOVER_FOLDERS' }
    elseif ($inUse.Count -gt 0) { Write-Output 'LEFTOVER_FOLDER_IN_USE'; $inUse | ForEach-Object { "Still in use, left in place: $_" } }
    else { Write-Output 'LEFTOVER_FOLDERS_REMOVED'; $leftover | ForEach-Object { "Removed $($_.FullName)" } }
}
```

| Result | Meaning | What to do |
| --- | --- | --- |
| `LEFTOVER_FOLDERS_REMOVED` or `NO_LEFTOVER_FOLDERS` | No version-number folder is left. | Go to [Verify the fix](#verify-the-fix). |
| `LEFTOVER_FOLDER_IN_USE` | A program that is still running holds files in the folder. The folder's module manifest is already gone, so it does not load and does not block the operation. | Leave the folder for now and go to [Verify the fix](#verify-the-fix). Run this step again after the machine's next planned restart, rather than restarting the machine for this alone. |
| `RESTART_REQUIRED` | An external copy still loads, so nothing was deleted. | See Step 6. |
| `INBOX_MODULE_MISSING` | The inbox module is not listed, so nothing was deleted. | [Contact Microsoft support](#when-to-contact-microsoft-support). |

## Verify the fix

Run this on one machine. It changes nothing. It checks this machine and every other machine of the cluster that it can reach with PowerShell remoting, and prints a result line. A machine that it cannot reach is reported as not checked from here, not as a problem: run this on that machine too. Before the cluster exists (during deployment), it checks only the machine it runs on, so run it on each machine. If it cannot tell whether this machine is in a cluster, it checks only this machine and says so. Paste or run the whole block at once.

```powershell
& {
    $moduleName = "AzStackHci.EnvironmentChecker"
    $checkMachine = {
        param($Name)
        $root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\$Name"
        $found = @(Get-Module -Name $Name -ListAvailable)
        [pscustomobject]@{
            ExternalCopies = @($found | Where-Object { $_.Path -like "*$($_.Version)*" } | ForEach-Object { $_.Path })
            InboxModule    = @($found | Where-Object { $_.Path -notlike "*$($_.Version)*" } | ForEach-Object { $_.Path })
            VersionFolders = @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -as [version] } | ForEach-Object { $_.FullName })
        }
    }
    $clusterNote = 'Get-ClusterNode returned no machines.'
    $nodes = @()
    try { $nodes = @(Get-ClusterNode -ErrorAction Stop | ForEach-Object { "$($_.Name)" }) } catch { $clusterNote = $_.Exception.Message }
    $hasClusSvc = $true
    $hasClusDb = $true
    if ($nodes.Count -eq 0) {
        try { $hasClusSvc = @(Get-CimInstance -ClassName Win32_Service -Filter "Name = 'ClusSvc'" -ErrorAction Stop).Count -gt 0 } catch { }
        try { $null = Get-Item -LiteralPath (Join-Path $env:SystemRoot 'Cluster\CLUSDB') -Force -ErrorAction Stop } catch [System.Management.Automation.ItemNotFoundException] { $hasClusDb = $false } catch { }
    }
    $inCluster = if ($nodes.Count -gt 0) { 'Yes' } elseif ($hasClusSvc -and $hasClusDb) { 'Unknown' } else { 'No' }
    if ($nodes -notcontains $env:COMPUTERNAME) { $nodes = @($env:COMPUTERNAME) + $nodes }
    $results = @(foreach ($node in $nodes) {
        try {
            if ($node -eq $env:COMPUTERNAME) { $state = & $checkMachine $moduleName }
            else { $state = Invoke-Command -ComputerName $node -ScriptBlock $checkMachine -ArgumentList $moduleName -ErrorAction Stop }
            [pscustomobject]@{
                Machine        = $node
                Status         = if (($state.ExternalCopies.Count -eq 0) -and ($state.InboxModule.Count -ge 1)) { 'Clean' } else { 'Not clean' }
                ExternalCopies = ($state.ExternalCopies -join '; ')
                InboxModule    = ($state.InboxModule -join '; ')
                VersionFolders = ($state.VersionFolders -join '; ')
            }
        } catch {
            [pscustomobject]@{
                Machine        = $node
                Status         = if ($node -eq $env:COMPUTERNAME) { 'Not clean' } else { 'Not checked from here' }
                ExternalCopies = "Could not be checked: $($_.Exception.Message)"
                InboxModule    = ''
                VersionFolders = ''
            }
        }
    })
    $notChecked = @($results | Where-Object { $_.Status -eq 'Not checked from here' } | ForEach-Object { $_.Machine })
    $unknownLine = "Only this machine was checked, because the script could not tell whether it is in a cluster: $clusterNote"
    if (@($results | Where-Object { $_.Status -eq 'Not clean' }).Count -gt 0) {
        Write-Output "NOT_ALL_MACHINES_CLEAN"
        if ($inCluster -eq 'Unknown') { $unknownLine }
    }
    elseif ($inCluster -eq 'Unknown') {
        Write-Output "CLUSTER_STATE_UNKNOWN"
        $unknownLine
        Write-Output "Run this on another machine of the cluster."
    }
    elseif ($inCluster -eq 'Yes' -and $notChecked.Count -eq 0) { Write-Output "ALL_MACHINES_CLEAN" }
    else {
        Write-Output "THIS_MACHINE_CLEAN"
        if ($notChecked.Count -gt 0) {
            Write-Output "OTHER_MACHINES_NOT_CHECKED: $($notChecked -join ', ')"
            Write-Output "Run this on each named machine."
        } else {
            Write-Output "The cluster does not exist yet, so only this machine was checked. Run this on each machine."
        }
    }
    $results | Format-List Machine, Status, ExternalCopies, InboxModule, VersionFolders
}
```

| Result | Meaning | What to do |
| --- | --- | --- |
| `ALL_MACHINES_CLEAN` | No machine has an external copy, and every machine has the inbox module at `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHci.EnvironmentChecker.psd1`. A `VersionFolders` entry is a folder you deliberately left in place under [Step 7](#step-7-delete-leftover-folders) until the next planned restart; it does not load. | Go to [Retry the failed operation](#retry-the-failed-operation). |
| `THIS_MACHINE_CLEAN` | This machine is clean, and no other machine that the script reached has a problem. Either the cluster does not exist yet, or some machines could not be reached; the next line says which. | Run this on each machine that was not checked. When every machine prints `ALL_MACHINES_CLEAN` or `THIS_MACHINE_CLEAN`, go to [Retry the failed operation](#retry-the-failed-operation). |
| `OTHER_MACHINES_NOT_CHECKED:` followed by machine names | Printed after `THIS_MACHINE_CLEAN`. PowerShell remoting from this machine to the named machines failed, for example with `Access is denied`, so they were not checked. This does not mean that they have a problem. | Run this on each named machine. |
| `NOT_ALL_MACHINES_CLEAN` | This machine, or another machine that the script reached, still has an external copy or is missing the inbox module. A machine you did not work on can still have a copy that deployment or an update left there. If the next line says that only this machine was checked, the script could not tell whether this machine is in a cluster. | Run Steps 1 to 7 on each machine whose `Status` is `Not clean`. |
| `CLUSTER_STATE_UNKNOWN` | This machine is clean, but `Get-ClusterNode` failed or returned no machines, and the script could not confirm that the Cluster service is not installed or that the machine has no cluster database. It could not tell whether this machine is in a cluster, so it checked only this machine. The line after it shows the reason. | Run this on another machine of the cluster. If every machine prints this, run this on each machine, and when none prints `NOT_ALL_MACHINES_CLEAN`, go to [Retry the failed operation](#retry-the-failed-operation). |

Do not use the system health check to confirm this fix. It can keep showing a previous result, and it runs the cleanup only on the machine where it runs.

## Retry the failed operation

Run this script on one machine, after [Verify the fix](#verify-the-fix) printed `ALL_MACHINES_CLEAN`, or printed `THIS_MACHINE_CLEAN` on every machine. It first checks this machine and every other machine that it can reach, the same way as Verify the fix, and it retries nothing if one of them is not clean or if it cannot tell whether this machine is in a cluster. A machine that it cannot reach does not stop the retry, so run Verify the fix on each such machine first. It then resumes a solution update whose installation failed with the error in this article. For any other operation, it prints how to retry it. Paste or run the whole block at once. To retry a solution update by hand instead, select **Try again** on the failed update in the Azure portal, or run `Get-SolutionUpdate | Where-Object Version -eq "<version>" | Start-SolutionUpdate`, replacing `<version>` with the version of the update that failed. This works whether the update failed in the readiness check (`HealthCheckFailed`) or during installation. If you ran the readiness check with `Start-SolutionUpdate -PrepareOnly`, retry in PowerShell, not in the Azure portal.

**Changes:** resumes the update only when this machine and every machine that the script can reach are clean, no update is downloading, preparing, installing, or running health checks, and exactly one update is in the `InstallationFailed` state with the error from [Symptoms](#symptoms) in a failed step of its last run. The update continues from the step that failed. In every other case the script changes nothing.

**Plan for:** the rest of the update installation, including any machine restarts that the update performs, as when you first started it.

```powershell
& {
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        Write-Output "WINDOWS_POWERSHELL_REQUIRED"
        Write-Output "Nothing was retried. Run this in Windows PowerShell 5.1 (powershell.exe), not in PowerShell 7."
        return
    }
    $moduleName = "AzStackHci.EnvironmentChecker"
    $checkMachine = {
        param($Name)
        $found = @(Get-Module -Name $Name -ListAvailable)
        [pscustomobject]@{
            ExternalCopies = @($found | Where-Object { $_.Path -like "*$($_.Version)*" }).Count
            InboxModule    = @($found | Where-Object { $_.Path -notlike "*$($_.Version)*" }).Count
        }
    }
    $clusterNote = 'Get-ClusterNode returned no machines.'
    $nodes = @()
    try { $nodes = @(Get-ClusterNode -ErrorAction Stop | ForEach-Object { "$($_.Name)" }) } catch { $clusterNote = $_.Exception.Message }
    $hasClusSvc = $true
    $hasClusDb = $true
    if ($nodes.Count -eq 0) {
        try { $hasClusSvc = @(Get-CimInstance -ClassName Win32_Service -Filter "Name = 'ClusSvc'" -ErrorAction Stop).Count -gt 0 } catch { }
        try { $null = Get-Item -LiteralPath (Join-Path $env:SystemRoot 'Cluster\CLUSDB') -Force -ErrorAction Stop } catch [System.Management.Automation.ItemNotFoundException] { $hasClusDb = $false } catch { }
    }
    $inCluster = if ($nodes.Count -gt 0) { 'Yes' } elseif ($hasClusSvc -and $hasClusDb) { 'Unknown' } else { 'No' }
    if ($nodes -notcontains $env:COMPUTERNAME) { $nodes = @($env:COMPUTERNAME) + $nodes }
    $notChecked = @()
    $notClean = @(foreach ($node in $nodes) {
        try {
            if ($node -eq $env:COMPUTERNAME) { $state = & $checkMachine $moduleName }
            else { $state = Invoke-Command -ComputerName $node -ScriptBlock $checkMachine -ArgumentList $moduleName -ErrorAction Stop }
            if ($state.ExternalCopies -gt 0 -or $state.InboxModule -eq 0) { "$node still has an external copy, or its inbox module is missing." }
        } catch {
            if ($node -eq $env:COMPUTERNAME) { "$node could not be checked: $($_.Exception.Message)" }
            else { $notChecked += $node }
        }
    })
    $notCheckedLines = @(if ($notChecked.Count -gt 0) {
        "OTHER_MACHINES_NOT_CHECKED: $($notChecked -join ', ')"
        "These machines could not be reached from this machine. Run Verify the fix on each of them. If one is not clean, a resumed update can fail again with the same error."
    })
    if ($notClean.Count -gt 0) {
        Write-Output "RETRY_BLOCKED"
        $notCheckedLines
        $notClean | ForEach-Object { "Nothing was retried. $_" }
    } elseif ($inCluster -eq 'Unknown') {
        Write-Output "CLUSTER_STATE_UNKNOWN"
        Write-Output "Nothing was retried. Could not tell whether this machine is in a cluster, so the script could not tell whether the failed operation is an update or a deployment: $clusterNote"
        Write-Output "Run this script on another machine of the cluster."
    } elseif ($inCluster -eq 'No') {
        Write-Output "CLUSTER_NOT_DEPLOYED"
        Write-Output "The cluster does not exist yet, so only this machine was checked. Run Verify the fix on every machine. When every machine is clean, resume the deployment: open your Azure Local instance, go to Deployments, and select Resume deployment."
    } else {
        $updates = $null
        $updateError = $null
        $busy = $false
        Import-Module -Name Microsoft.AzureStack.Lcm.PowerShell -ErrorAction SilentlyContinue 4>$null
        foreach ($attempt in 1..3) {
            try { $updates = @(Get-SolutionUpdate -ErrorAction Stop 4>$null); break }
            catch { $updateError = $_.Exception.Message }
            $busy = $updateError -like '*already in progress*'
            if (-not $busy) { break }
            if ($attempt -lt 3) { Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 21) }
        }
        if ($null -eq $updates -and $busy) {
            Write-Output "UPDATE_CHECK_BUSY"
            Write-Output "Another machine is checking the update at the same time, so nothing was retried. Run this script again in a minute."
            $notCheckedLines
        } elseif ($null -eq $updates) {
            Write-Output "UPDATE_SERVICE_NOT_AVAILABLE"
            Write-Output "Could not read solution updates: $updateError"
            Write-Output "If a deployment failed, resume it: open your Azure Local instance, go to Deployments, and select Resume deployment."
            $notCheckedLines
        } else {
            $active = @($updates | Where-Object { ('Installing', 'Preparing', 'HealthChecking', 'Downloading', 'ScanInProgress' -contains $_.State) -or ($_.HealthState -eq 'InProgress') })
            $healthError = $null
            try {
                $environment = Get-SolutionUpdateEnvironment -ErrorAction Stop 4>$null
                if (("$($environment.State)" -like '*InProgress*') -or ("$($environment.HealthState)" -eq 'InProgress')) { $active += [pscustomobject]@{ DisplayName = 'The system health check'; State = 'InProgress' } }
            } catch { $healthError = $_.Exception.Message }
            $failed = @($updates | Where-Object { $_.State -eq 'InstallationFailed' })
            $related = $false
            if ($failed.Count -eq 1) {
                try {
                    $lastRun = @($failed[0] | Get-SolutionUpdateRun -ErrorAction Stop 4>$null | Sort-Object -Property TimeStarted)[-1]
                    $stepErrors = @()
                    $pending = New-Object System.Collections.Stack
                    if ($lastRun -and $lastRun.PSObject.Properties['Progress']) { $pending.Push($lastRun.Progress) }
                    while ($pending.Count -gt 0) {
                        $step = $pending.Pop()
                        if ($null -eq $step) { continue }
                        $props = $step.PSObject.Properties
                        if ($props['Status'] -and ('Error', 'Failed' -contains "$($step.Status)")) {
                            foreach ($field in 'ErrorMessage', 'AggregatedErrorMessages') {
                                if ($props[$field] -and ($null -ne $step.$field)) { $stepErrors += ($step.$field | ConvertTo-Json -Depth 10 -Compress) }
                            }
                        }
                        if ($props['Steps']) { foreach ($child in @($step.Steps)) { if ($null -ne $child) { $pending.Push($child) } } }
                    }
                    $related = @($stepErrors | Where-Object { $_ -match 'envchkrversiontsg|module names .{0,12}AzStackHci\.EnvironmentChecker' }).Count -gt 0
                } catch { $related = $false }
            }
            if ($active.Count -gt 0) {
                Write-Output "ALREADY_IN_PROGRESS"
                Write-Output "$($active[0].DisplayName) is $($active[0].State), so nothing was resumed."
            } elseif ($healthError -and $related) {
                Write-Output "HEALTH_CHECK_STATE_UNKNOWN"
                Write-Output "Could not read whether the system health check is running, so nothing was resumed: $healthError"
            } elseif ($failed.Count -eq 1 -and -not $related) {
                Write-Output "UPDATE_FAILED_FOR_OTHER_REASON"
                Write-Output "The last run of $($failed[0].DisplayName) did not fail with the error in this article, or its error could not be read, so it was not resumed."
            } elseif ($failed.Count -eq 1) {
                try {
                    $run = $failed[0] | Start-SolutionUpdate -ErrorAction Stop 4>$null
                    Write-Output "SOLUTION_UPDATE_RESUMED"
                    Write-Output "Resumed $($failed[0].DisplayName). Update run: $run"
                } catch {
                    $startError = $_.Exception.Message
                    $state = $null
                    foreach ($attempt in 1..3) {
                        try { $state = (Get-SolutionUpdate -Id $failed[0].ResourceId -ErrorAction Stop 4>$null).State } catch { $state = $null }
                        if ($state -eq 'Installing' -or $startError -notlike '*already in progress*') { break }
                        if ($attempt -lt 3) { Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 21) }
                    }
                    if ($state -eq 'Installing') {
                        Write-Output "SOLUTION_UPDATE_RESUMED"
                        Write-Output "$($failed[0].DisplayName) is already installing again."
                    } elseif ($startError -like '*already in progress*') {
                        Write-Output "UPDATE_CHECK_BUSY"
                        Write-Output "Another machine is starting or checking the update at the same time, so this machine did not resume it. Run this script again in a minute."
                    } else {
                        Write-Output "SOLUTION_UPDATE_NOT_RESUMED"
                        Write-Output "Start-SolutionUpdate did not resume $($failed[0].DisplayName): $startError"
                    }
                }
            } elseif ($failed.Count -gt 1) {
                Write-Output "SOLUTION_UPDATE_NOT_RESUMED"
                Write-Output "More than one update is in the InstallationFailed state, so none was resumed."
            } else {
                Write-Output "NO_UPDATE_TO_RESUME"
                Write-Output "No solution update failed during installation. Retry the operation that failed the same way you started it."
                foreach ($other in @($updates | Where-Object { "$($_.State)" -like '*Failed' })) {
                    "$($other.DisplayName) is $($other.State). To retry it, run: Get-SolutionUpdate | Where-Object Version -eq `"$($other.Version)`" | Start-SolutionUpdate"
                    "  Add -PrepareOnly if you ran only its readiness check with -PrepareOnly. If you started it in the Azure portal, you can instead select Try again on it there."
                }
            }
            $notCheckedLines
            try { Get-SolutionUpdate -ErrorAction Stop 4>$null | Format-Table DisplayName, Version, State -AutoSize } catch { }
        }
    }
}
```

| Result | Meaning | What to do |
| --- | --- | --- |
| `SOLUTION_UPDATE_RESUMED` | The update is installing again. Its `State` in the list is `Installing`. If you run this script on several machines at the same time, one of them resumes the update and the others report that it is already installing. | Follow its progress under **Updates** for your Azure Local instance. It should continue past the step that failed. |
| `ALREADY_IN_PROGRESS` | An update is already downloading, preparing, installing, or running health checks, so nothing was resumed. | Follow its progress under **Updates** for your Azure Local instance. |
| `HEALTH_CHECK_STATE_UNKNOWN` | The failed update shows the error from [Symptoms](#symptoms), but the script could not read whether the system health check is running, so it resumed nothing. The line after it shows the reason. | Run this script again in a few minutes. If it keeps printing this, open **Updates** for your Azure Local instance, and when no health check is running and the failed update shows the error from [Symptoms](#symptoms), select **Try again**. |
| `UPDATE_FAILED_FOR_OTHER_REASON` | No failed step in the failed update's last run shows the error from [Symptoms](#symptoms), or its error could not be read, so the script did not resume it. | Check the error under **Updates**. If it is the error from [Symptoms](#symptoms), select **Try again**. Otherwise, see [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2). |
| `WINDOWS_POWERSHELL_REQUIRED` | The script ran in PowerShell 7 and did nothing. | Run it in Windows PowerShell 5.1. |
| `NO_UPDATE_TO_RESUME` | No solution update failed during installation, so nothing was resumed. For each update in another failed state, for example `HealthCheckFailed` after its readiness check failed, the script prints the command that retries it. | Retry the operation that failed the same way you started it. For a solution update, run the command the script printed: `Get-SolutionUpdate \| Where-Object Version -eq "<version>" \| Start-SolutionUpdate`. This works whether the update failed in the readiness check or during installation. If you ran only its readiness check with `Start-SolutionUpdate -PrepareOnly`, add `-PrepareOnly` to run only the check again, and do not continue in the Azure portal. If you started the update in the Azure portal, you can instead select **Try again** there. |
| `CLUSTER_NOT_DEPLOYED` | The Cluster service is not installed or this machine has no cluster database, so the cluster does not exist yet and the failed operation is a deployment. Only this machine was checked. | Confirm with [Verify the fix](#verify-the-fix) that every machine prints `THIS_MACHINE_CLEAN`, then resume the deployment as described in [Resume deployment](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal#resume-deployment). |
| `CLUSTER_STATE_UNKNOWN` | `Get-ClusterNode` failed or returned no machines, and the script could not confirm that the Cluster service is not installed or that the machine has no cluster database, so it could not tell whether the failed operation is an update or a deployment. Nothing was retried. The line after it shows the reason. | Run this script on another machine of the cluster. If every machine prints this, retry the failed update by hand as described at the start of this section, or resume a failed deployment as described in [Resume deployment](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal#resume-deployment). |
| `UPDATE_SERVICE_NOT_AVAILABLE` | The cluster exists, but the solution update service did not answer. This can happen when a deployment failed after the cluster was created. | For a deployment, see [Resume deployment](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal#resume-deployment). On a deployed system, see [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2). |
| `UPDATE_CHECK_BUSY` | Another machine was reading or starting the update at the same moment, for example because this script runs on several machines at once, and the update service was still busy after three tries within about a minute. Nothing was retried on this machine. | Run this script again in a minute. |
| `SOLUTION_UPDATE_NOT_RESUMED` | The update did not start again. The script prints the reason. | Retry the update the same way you started it. If it still does not start, [contact Microsoft support](#when-to-contact-microsoft-support). |
| `RETRY_BLOCKED` | This machine, or another machine that the script reached, still has an external copy or is missing the inbox module. The script names each one. | Run Steps 1 to 7 on each named machine, then run this script again. |
| `OTHER_MACHINES_NOT_CHECKED:` followed by machine names | Printed after the result. The script could not reach these machines with PowerShell remoting, so it did not check them. This does not mean that they have a problem. | Run [Verify the fix](#verify-the-fix) on each named machine. If one is not clean, run Steps 1 to 7 there and then this script again; until then, a resumed update can fail again with the same error. |

## Rollback

Normally there is nothing to roll back. Azure Local needs only the inbox module, so a copy you removed does not need to be put back. If you need the standalone Environment Checker from the PowerShell Gallery again, install it only after the operation completes, and remove it again before the next one, as described in [Prevention](#prevention). If you paused and drained a machine, resume it as described in the pause and drain procedure. Sessions that Step 2 stopped and programs that you closed in Step 3 cannot be restored; start them again if you still need them. If you stopped after Step 1, delete the folder `C:\ProgramData\AzStackHci.EnvironmentChecker.Step1` if it is still there; Step 2 never uses a list older than 60 minutes.

## When to contact Microsoft support

Open a support request if any of these is true:

- A check prints `INBOX_MODULE_MISSING`.
- Step 5 still prints `CLEANUP_EXTERNAL_REMAINS` after you restarted the machine and ran Step 5 again.
- A leftover version-number folder still cannot be deleted after the machine has restarted.
- The same error returns after the retry while Issue Validation shows no external copy.
- The solution update does not start again after **Try again** in the Azure portal.

Include this information:

- The output of the all-machines Issue Validation command before the steps you ran, and of [Verify the fix](#verify-the-fix) after them.
- The full output of Step 1 and of the cleanup script from every machine.
- The exact error text and the time it occurred, from the failed deployment or update step in the Azure portal.
- The deployment log from `C:\CloudDeployment\Logs` that contains `Externally installed module(s) found for AzStackHci.EnvironmentChecker`.
- The Azure Local version and the version of the inbox Environment Checker module.

## Prevention

Azure Local already includes the Environment Checker, so you do not need the PowerShell Gallery copy on its machines. If you install it from the PowerShell Gallery to run readiness checks, as described in [Assess your environment with the Environment Checker](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker), close that PowerShell window when you finish. Then, before you start a deployment, update, upgrade, add node, or repair node operation, remove the gallery copy from every machine with the cleanup script in [Step 5](#step-5-run-the-cleanup-script). Closing the window first matters: the module's .NET files stay in use until the PowerShell process that loaded them ends.

## Related documentation

- [Assess your environment with the Environment Checker](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker)
- [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2)
- [Understand update phases for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-phases-23h2)
- [Deploy Azure Local using the Azure portal](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal)
- [Suspend and resume Azure Local machines for planned maintenance](https://learn.microsoft.com/azure/azure-local/manage/suspend-resume-cluster-maintenance)
