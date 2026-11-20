<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Get-Module -Name AzStackHci.EnvironmentChecker -ListAvailable returns a copy whose path contains its version number"
  },
  "validation": {
    "fidelity_level": "L4",
    "technical_grade": "A",
    "reproduction_substrate": "hardware",
    "automation_status": "proven",
    "last_validated": "2026-11-20",
    "spec_ref": "AzStackHci_EnvironmentChecker_ModuleShadowing"
  }
}
-->

# Troubleshoot Environment Checker module versions

## Table of contents

- [Revision history](#revision-history)
- [Article metadata](#article-metadata)
- [Executive triage summary](#executive-triage-summary)
- [Overview](#overview)
- [Symptoms](#symptoms)
- [Terms used in this article](#terms-used-in-this-article)
- [Where this appears](#where-this-appears)
- [Preconditions and stop gates](#preconditions-and-stop-gates)
- [Issue Validation](#issue-validation)
- [Contributing factors](#contributing-factors)
- [Mitigation Details](#mitigation-details)
- [Rollback](#rollback)
- [Verify the fix](#verify-the-fix)
- [Escalation and evidence](#escalation-and-evidence)
- [Prevention](#prevention)
- [Future test automation metadata](#future-test-automation-metadata)
- [Related documentation](#related-documentation)

## Revision history

| Date | Summary |
| --- | --- |
| 2026-11-20 | Corrected the expected inbox path and made Issue Validation self-contained. Added the error that newer builds show, a triage summary, risk labels, terms, all-node commands, verification, escalation, and prevention guidance. Validated on a lab cluster. |

## Article metadata

| Field | Value |
| --- | --- |
| Component | Azure Local Environment Checker (`AzStackHci.EnvironmentChecker` PowerShell module) |
| Applicable products | Azure Local |
| Supported versions | All releases. Older builds (for example Environment Checker 10.2504.0.2040) show the `No match was found` error. Newer builds (confirmed on 10.2510.0.2100) show the `Unable to remove module files` error. |
| Audience | Azure Local administrators, partner or systems integrator (SI) deployment engineers, and Microsoft Customer Support Services (CSS) engineers |
| Applicable scenarios | Deployment, solution update, upgrade, add node, and repair node |
| Severity | High. The lifecycle operation stays blocked until the extra module copy is removed. |
| Customer impact | Deployment, update, or add node blocked. No impact on running virtual machines (VMs). |
| Primary owner | Customer IT or the deployment engineer |
| Execution surface | on-device |
| Risk summary | Low. The cleanup removes only module copies in version-number folders. No drain, restart, or maintenance window is needed unless a file stays in use (see Step 4). |

## Executive triage summary

| Question | Answer |
| --- | --- |
| What is broken? | An extra copy of the Environment Checker module, usually installed from the PowerShell Gallery, could not be removed automatically, so the lifecycle operation stopped. |
| Is this a network, hardware, or OEM problem? | No. The older error names `ValidateConnectivity`, but no network, switch, DNS, proxy, firewall, firmware, or driver change is needed. |
| Who should act? | The administrator who runs the deployment or update, with local administrator rights on every machine. |
| Fastest safe next action | Run the read-only check in [Issue Validation](#issue-validation) on every machine. |
| Estimated duration | About 10 minutes for the cluster, plus the time to retry the operation. |
| Downtime or workload risk | None for Steps 1 to 3. Step 4 restarts a machine only if a file stays in use and the owning session cannot be found. |
| Escalate immediately if | The inbox module is missing from the Issue Validation output, or the copy is still listed after Step 4. |

## Overview

Azure Local ships its own copy of the Environment Checker PowerShell module, called the inbox module. The same module is also published on the PowerShell Gallery so that you can run readiness checks before deployment. The inbox version must be the one that loads. Before deployment, update, upgrade, add node, and repair node operations, the automation tries to remove every copy that is not the inbox copy.

If you installed the module from the PowerShell Gallery, remove it after use (see [Prevention](#prevention)). When you troubleshoot a related issue, removing the extra copy first also makes the results easier to read.

## Symptoms

On rare occasions the automation cannot remove the extra copy, and the lifecycle operation fails. The error depends on the build.

**Older builds** (example from Environment Checker 10.2504.0.2040): the automation stopped when `Uninstall-Module` could not find the copy.

```text
Type 'ValidateConnectivity' of Role 'EnvironmentValidator' raised an exception:
{
    "ExceptionType":  "text",
    "ErrorMessage":  "No match was found for the specified search criteria and module names \u0027AzStackHci.EnvironmentChecker\u0027.",
    "ExceptionStackTrace":  "at Uninstall-Module\u003cProcess\u003e, C:\\Program Files\\WindowsPowerShell\\Modules\\PowerShellGet\\2.2.5\\PSModule.psm1: line 12733\r\nat CleanEnvironmentValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 1230\r\nat EnvironmentValidatorImport, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 784\r\nat RunSingleValidator, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 806\r\nat ValidateConnectivity, C:\\NugetStore\\AzStackHci.EnvironmentChecker.Deploy.10.2504.0.2040\\content\\Classes\\EnvironmentValidator\\EnvironmentValidator.psm1: line 265\r\nat \u003cScriptBlock\u003e, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 147\r\nat Invoke-EceInterfaceInternal, C:\\CloudDeployment\\ECEngine\\InvokeInterfaceInternal.psm1: line 142\r\nat \u003cScriptBlock\u003e, \u003cNo file\u003e: line 36"
}
```

**Newer builds** (confirmed on Environment Checker 10.2510.0.2100): the automation removes the extra copy by itself. It fails only when it cannot delete the files, usually because a PowerShell session still has the module loaded. The error links to this article. Example from a lab reproduction (the version folder and file name vary):

```text
Unable to remove module files at C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\1.0.0. Error: Access to the path 'Microsoft.AzureStack.Observability.Standalone.dll' is denied.. Please follow https://aka.ms/envchkrversiontsg to remove the module manually before retrying lifecycle operation.
```

The system health check (`Invoke-SolutionUpdatePrecheck -SystemHealth`) does not run this cleanup. A passing health check does not mean that no external copy is present, so use [Issue Validation](#issue-validation) instead.

## Terms used in this article

| Term | Meaning |
| --- | --- |
| Environment Checker | The `AzStackHci.EnvironmentChecker` PowerShell module that runs the Azure Local readiness checks (validators). |
| Inbox module | The copy that ships with Azure Local, in `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker`. Its files sit directly in that folder, with no version-number subfolder. Never delete it. |
| External copy | Any other copy, for example one installed with `Install-Module` from the PowerShell Gallery. It lives in a version-number subfolder such as `...\AzStackHci.EnvironmentChecker\10.2411.0.12`. |
| PowerShell Gallery | The public online repository that `Install-Module` downloads PowerShell modules from. |
| Lifecycle operation | An Azure Local operation that removes external copies and then runs the Environment Checker: deployment, solution update, upgrade, add node, and repair node. |
| In use | A process, usually a PowerShell window or remote session, still has files from the external copy loaded, so Windows does not allow them to be deleted. |

## Where this appears

| Admin surface | Status | What you see |
| --- | --- | --- |
| PowerShell on an Azure Local node | shown | The read-only check in [Issue Validation](#issue-validation) lists the external copy. |
| Azure portal | shown | The failed step shows the error text from [Symptoms](#symptoms): under **Deployments** for a deployment, or in the update's failure details under **Updates** for a solution update. |
| Windows event logs | not-evident | The error does not appear in the Windows event logs; the cleanup writes only to the deployment engine log files described in the last row. |
| Cluster logs (`Get-ClusterLog`) | not-evident | This is a PowerShell module problem, not a failover cluster event, so the cluster log does not record it. |
| Windows Failover Cluster Manager | not-evident | No clustered role, resource, or node changes state, so Failover Cluster Manager does not show it. |
| Windows Admin Center (standalone host) | not-evident | Windows Admin Center does not run the lifecycle operation, so the error does not appear there. |
| Windows Admin Center in the Azure portal | not-evident | The error does not appear there; use the Azure portal deployment or update views instead. |
| Component / tool log files (on disk) | shown | The deployment engine log for the failed step under `C:\CloudDeployment\Logs`, for example `EnvironmentValidatorFull.<date>.log` during deployment, contains `Externally installed module(s) found for AzStackHci.EnvironmentChecker` and `Attempting to uninstall`, followed by the result or the error. |

## Preconditions and stop gates

| Gate | Check | Continue when | Stop when |
| --- | --- | --- | --- |
| Permissions | Open PowerShell as Administrator on each machine. | The session is elevated. | You do not have local administrator rights. |
| Right article | Run [Issue Validation](#issue-validation). | A copy in a version-number folder is listed, or a version-number folder is left over. | Nothing is listed and no version-number folder exists. This article does not apply. |
| Inbox module present | Check that the inbox path appears in the full module list in Issue Validation. | The inbox path is listed. | The inbox module is missing. Do not install a replacement. Escalate. |
| Operation state | Check that no update or deployment step is running now. | The operation has failed or stopped. | An update shows `Installing`. Wait for it to stop before you change anything. |

## Issue Validation

[READ-ONLY] Run this in an elevated PowerShell session on each machine. It lists external copies, meaning module copies whose path contains their version number.

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
| `ExternalCopies` lists a path | An external copy is present. | Mitigation Steps 1 to 3. |
| `ExternalCopies` is empty but `VersionFolders` lists a folder | A leftover folder from a partly removed copy. It no longer loads, but delete it. | Mitigation Step 4. |
| Both are empty and `AllAvailableModules` shows only the inbox path | This machine is not affected. | None. |
| `AllAvailableModules` does not show the inbox path | The inbox module is missing. | Stop and [escalate](#escalation-and-evidence). |

## Contributing factors

- **Older builds:** `Uninstall-Module` removes only modules that PowerShellGet installed and recorded. A copy that was copied in by hand, or whose install record is missing, is still listed by `Get-Module`, but `Uninstall-Module` reports `No match was found`. The automation stopped on that error.
- **Newer builds:** the automation ignores that `Uninstall-Module` error and deletes the version-number folder itself. It fails only when Windows does not allow the delete, because a process still has files from the copy loaded. In a lab reproduction, a PowerShell process that had loaded one of the module's DLLs caused exactly this error.
- **Common cause of the in-use state:** a PowerShell window or remote session that was used to run the Environment Checker from the PowerShell Gallery (for example, readiness checks before deployment) and was left open.

## Mitigation Details

Run the steps in order on every affected machine. Steps 1 to 3 do not affect running VMs and need no maintenance window.

| Step | Label | Action | Expected result | Stop condition |
| --- | --- | --- | --- | --- |
| 1 | [READ-ONLY] | List PowerShell processes that could have the module loaded. | A list of PowerShell processes with their owner and start time. | None. |
| 2 | [LOW RISK] | Close the PowerShell windows and remote sessions that you or your team started on this machine, especially any used to run the Environment Checker. | Those processes are gone. | Do not stop processes you do not recognize. Azure Local services also run PowerShell. |
| 3 | [LOW RISK] | Run the cleanup script. It unloads, uninstalls, and deletes only copies in version-number folders. | The final output lists only the inbox module. | `Remove-Item` reports `Access to the path ... is denied` or `The directory is not empty`. Go to Step 4. |
| 4 | [LOW RISK], or [MEDIUM RISK] if a restart is needed | Delete leftover version-number folders. If the files are still in use and you cannot find the session, drain and restart the machine first. | No version-number folders remain. | The files are still in use after a restart. [Escalate](#escalation-and-evidence). |
| 5 | [LOW RISK] | Retry the lifecycle operation. | The operation continues past the failed step. | The same error returns. Repeat Issue Validation, then escalate. |

**Step 1** [READ-ONLY]: list PowerShell processes on this machine.

```powershell
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" |
    Select-Object ProcessId, CreationDate, @{ Name = 'Owner'; Expression = { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User } }, CommandLine |
    Format-Table -AutoSize -Wrap
```

**Step 2** [LOW RISK]: close the windows and sessions you recognize. To end one that you cannot close normally, use its `ProcessId` from Step 1:

```powershell
Stop-Process -Id 1234   # Replace 1234 with the ProcessId of a session you started.
```

**Step 3** [LOW RISK]: run the cleanup script. Run it only after Issue Validation listed a copy in a version-number folder. It never removes the inbox module, because the inbox module's path has no version-number folder.

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

If `Remove-Item` reports `Access to the path ... is denied` or `The directory is not empty`, a process still has files from that folder loaded. The script still removes the files it can, including the module manifest, so the copy usually no longer loads and the final output shows only the inbox module. Continue with Step 4 to delete the leftover folder.

To run the cleanup on every machine from one session, save the script above as `Remove-ExternalEnvChecker.ps1` and run:

```powershell
$nodes = (Get-ClusterNode).Name   # Before the cluster exists, set $nodes to the machine names.
Invoke-Command -ComputerName $nodes -FilePath .\Remove-ExternalEnvChecker.ps1
```

**Step 4** [LOW RISK]: delete leftover version-number folders. Run this only after Step 3 shows only the inbox module. It deletes subfolders whose name is a version number and never touches the inbox files, which are not in such a subfolder.

```powershell
$root = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker"
Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -as [version] } | ForEach-Object {
    Write-Host "Removing leftover folder $($_.FullName)"
    Remove-Item -Path $_.FullName -Recurse -Force
}
```

If this still reports that files are in use, and you could not find the session in Steps 1 and 2, restart the machine to release them [MEDIUM RISK]. On a deployed cluster, drain it first so its VMs move to other nodes, then bring it back:

```powershell
Suspend-ClusterNode -Name $env:COMPUTERNAME -Drain -Wait
Restart-Computer -Force
```

After the machine is back online, sign in again and bring it back into the cluster:

```powershell
Resume-ClusterNode -Name $env:COMPUTERNAME -Failback Immediate
```

Before the cluster exists (during deployment), restart the machine without the drain. After the restart, run the Step 4 command again.

**Step 5** [LOW RISK]: retry the lifecycle operation.

| Operation | How to retry |
| --- | --- |
| Deployment | In the Azure portal, open your Azure Local instance, go to **Deployments**, and select **Resume deployment**. |
| Solution update | Resume it from the Azure portal, or run `Get-SolutionUpdate \| Where-Object State -eq "InstallationFailed" \| Start-SolutionUpdate`. |
| Upgrade, add node, or repair node | Retry the operation the same way you started it. |

## Rollback

| Step | Rollback |
| --- | --- |
| 1 | Not applicable. No state changes. |
| 2 | Open a new PowerShell session if you still need one. |
| 3 and 4 | Normally none. The removed copy was not part of Azure Local. If you need the standalone Environment Checker again, reinstall it with `Install-Module -Name AzStackHci.EnvironmentChecker` after the lifecycle operation completes, and remove it again before the next one. |
| 4 (restart) | If you drained a node, run `Resume-ClusterNode -Name $env:COMPUTERNAME -Failback Immediate` on it after it is back online. |

## Verify the fix

[READ-ONLY] Run the all-machines check in [Issue Validation](#issue-validation) again.

| Check | Expected result |
| --- | --- |
| `ExternalCopies` | Empty on every machine. |
| `VersionFolders` | Empty on every machine. |
| `AllAvailableModules` | Only `C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHci.EnvironmentChecker.psd1`. |
| Lifecycle operation | The operation you retried in Step 5 continues past the step that failed. |

Do not use the system health check to confirm this fix. It does not check for external copies.

## Escalation and evidence

Open a support request with Microsoft if any of these is true:

- The inbox module is missing from `AllAvailableModules`.
- An external copy or leftover folder remains after Steps 1 to 4, including after a restart.
- The same error returns after the retry while Issue Validation shows no external copy.

Include this evidence:

- The output of the all-machines Issue Validation command, before and after the steps you ran.
- The full output of the cleanup script from every machine.
- The exact error text and the time it occurred, from the failed deployment or update step in the Azure portal.
- The deployment engine log from `C:\CloudDeployment\Logs` that contains `Externally installed module(s) found for AzStackHci.EnvironmentChecker`.
- The Azure Local version and the Environment Checker version shown for the inbox module.

## Prevention

Azure Local already includes the Environment Checker. If you install it from the PowerShell Gallery to run readiness checks, close that PowerShell window when you finish, then remove the gallery copy from every machine before you start a deployment or update, as described in [Assess your environment with the Environment Checker](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker). This command removes only copies in version-number folders; it never removes the inbox module.

```powershell
Remove-Module AzStackHci.EnvironmentChecker -Force
Get-Module AzStackHci.EnvironmentChecker -ListAvailable | Where-Object {$_.Path -like "*$($_.Version)*"} | Uninstall-Module -Force
```

## Future test automation metadata

| Field | Value |
| --- | --- |
| Detector type | command |
| Detector signal | `Get-Module -Name AzStackHci.EnvironmentChecker -ListAvailable` returns a copy whose path contains its version number |
| Inject strategy | Reversible inject: an empty module manifest in a version-number folder under the inbox module folder |
| Mitigation selector | The `Uninstall-Module` block in Mitigation Details |
| Safety floor | The injected copy has a lower version than every installed copy, so it never loads in place of the inbox module |
| Rollback check | Issue Validation returns no external copy and no version-number folder |
| Reproduction substrate | hardware |
| Fidelity level | L4 |
| Technical grade | A |
| Automation status | proven |
| Spec reference | AzStackHci_EnvironmentChecker_ModuleShadowing |
| Last validated | 2026-11-20 |

## Related documentation

- [Assess your environment with the Environment Checker](https://learn.microsoft.com/azure/azure-local/manage/use-environment-checker)
- [Troubleshoot solution updates for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-troubleshooting-23h2)
- [Understand update phases for Azure Local](https://learn.microsoft.com/azure/azure-local/update/update-phases-23h2)
- [Deploy Azure Local using the Azure portal](https://learn.microsoft.com/azure/azure-local/deploy/deploy-via-portal)
