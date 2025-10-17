# Solution Update CAU Run fails due to Windows Defender blocking WMI commands

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>{Component Name}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>{Critical/High/Medium/Low}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>{Deployment/Update/AddNode/etc.}</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>{Version ranges or "All versions"}</strong></td>
  </tr>
</table>

## Overview

{Brief description of the issue, what causes it, and when it typically occurs}

## Symptoms

Azure Local Solution Update fails in CAU.  The error reported is:

CAU Run failed. The latest cluster update status is ‘Failed’. The overall FullyQualifiedErrorId is ‘MaxFailedNodesExceeded’. The node ‘NODENAME’ failed to update.

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following behavior(s):

Check the Microsoft-Windows-Windows Defender/Operational event log for any event ID 1121 like below to see if a Defender rule is blocking a WmiPrvSE.exe process from CAU in the Azure Local Solution Update process.

Date Time  Microsoft-Windows-Windows Defender  Warning      1121  nodename.contoso.com  (pid:4284 - tid:15748)  
Microsoft Defender Exploit Guard has blocked an operation that is not allowed by your IT administrator.  
For more information please contact your IT administrator.  
  ID: D1E49AAC-8F56-4280-B9BA-993A6D77406C  
  Detection time: 2025-09-05T04:31:25.019Z  
  User: NT AUTHORITY\SYSTEM  
  Path: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe  
  Process Name: C:\Windows\System32\wbem\WmiPrvSE.exe  
**Target Commandline: "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "\\localhost\C$\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\CAUHotfix_All\InstallMsuFiles.ps1"** 
  Parent Commandline: C:\Windows\system32\wbem\wmiprvse.exe  
  Involved File:   
  Inheritance Flags: 0x00000000  
  Security intelligence Version: 1.435.584.0  
  Engine Version: 1.1.25070.4  
  Product Version: 4.18.25070.5

You can use this Powershell command to check:
```
Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -FilterXPath "*[System[(EventID=1121)]]" -MaxEvents 5 | Format-List
```

# Cause
A Windows Defender attack surface reduction rule named: **Block Process Creations originating from PSExec & WMI commands** has been enabled and set to Block (value 1).  It has a rule ID: D1E49AAC-8F56-4280-B9BA-993A6D77406C .

The [Azure Local security baseline default](https://learn.microsoft.com/azure/azure-local/manage/manage-secure-baseline?view=azloc-2508#view-and-download-security-settings) is Audit (value 2) for this rule.

A table mapping rule names to rule GUIDs is also available [here](https://learn.microsoft.com/defender-endpoint/defender-endpoint-demonstration-attack-surface-reduction-rules#test-files)

# Mitigation Details

1. Modify the rule from block (value 1) to audit (value 2) to prevent it from blocking Azure Local Solution Update installer with this powershell command:

```
Set-OSConfigDesiredConfiguration -Scenario Defender/Antivirus -Setting ASRBlockProcessCreationFromPSExecAndWMICommands -Value "2"
```
2. There are other places that this rule can be enabled, such as [Group policy (GP)](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#group-policy "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#group-policy"), [Mobile Device Management (MDM)](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#mdm "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#mdm"), and [Microsoft Configuration Manager](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#microsoft-configuration-manager "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#microsoft-configuration-manager").  You may need to explore these configurations and modify the rule there as well to avoid them overwriting the Azure Local security baseline setting configured in step 1.

### **Additional Notes**
More background information on Defender attack surface reduction rules is available [here](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction"):
You can enable attack surface reduction rules by using any of the following methods:

*   [Mobile Device Management (MDM)](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#mdm "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#mdm")
*   [Microsoft Configuration Manager](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#microsoft-configuration-manager "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#microsoft-configuration-manager")
*   [Group policy (GP)](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#group-policy "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#group-policy")
*   [PowerShell](https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#powershell "https://learn.microsoft.com/defender-endpoint/enable-attack-surface-reduction#powershell")


### **Other symptoms observed**
**Note:**  It is not necessary to confirm these other symptoms if you have already confirmed the presence of Microsoft-Windows-Windows Defender event ID 1121 with rule ID: D1E49AAC-8F56-4280-B9BA-993A6D77406C blocking InstallMsuFiles.ps1.  These symptoms are provided here to lead you to check for the Microsoft-Windows-Windows Defender event ID 1121 as the cause of the issue.

### 0x80070005 (access denied) errors in CAU debug trace
```
[0] 85F4.6FEC::<date><time> : [<date><time>] [ 6]: Fail to launch installer. Error code: 0x80070005
[0] 85F4.6FEC::<date><time> : [<date><time>] [ 6]: Failed to run a hotfix installer. Message: Cannot start hotfix installer on cluster node NODENAME. Program path: %systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe. Parameters: -File $update$. Update path: \\localhost\C$\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\CAUHotfix_All\InstallMsuFiles.ps1. Error code: 0x80070005., ErrorCode: 0x80070005.
```

### 0x80070005 (access denied) errors in CauWmi.log
```
[<date><time> 1aa4] +++++ CauRunUpdateInstallerOperation::RunUpdateInstaller 
[<date><time> 1aa4] +++++ CauOperation::MarkInstall 
[<date><time> 1aa4] CauWmiV2!CauOperation::MarkInstall: Set the Install Key
[<date><time> 1aa4] ----- CauOperation::MarkInstall 
[<date><time> 1aa4] CauWmiV2!RunUpdateInstallerHelper::RunUpdateInstaller: Running installer "%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe". pcszParameters: -File $update$. Update: \\localhost\C$\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\CAUHotfix_All\InstallMsuFiles.ps1
[<date><time> 1aa4] CauWmiV2!RunUpdateInstallerHelper::RunUpdateInstaller: Reg key BypassIntegrityCheck is set to 1. Integrity check will be skipped
[<date><time> 1aa4] CauWmiV2!RunUpdateInstallerHelper::RunUpdateInstaller: Failed to create process. Command line: "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "\\localhost\C$\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\CAUHotfix_All\InstallMsuFiles.ps1". Error: 5
[<date><time> 1aa4] +++++ CauOperation::UnmarkInstall 
[<date><time> 1aa4] CauWmiV2!CauOperation::UnmarkInstall: Reset the Install Key
[<date><time> 1aa4] ----- CauOperation::UnmarkInstall 
[<date><time> 1aa4] CauWmiV2!CauRunUpdateInstallerOperation::RunUpdateInstaller: Failed to start the hotfix installer. Installer path: "%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe". Parameters: -File $update$. Update path: \\localhost\C$\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\CAUHotfix_All\InstallMsuFiles.ps1. HRESULT 0x80070005.
[<date><time> 1aa4] +++++ CauOperation::SetComplete 
[<date><time> 1aa4] CauWmiV2!CauOperation::SetComplete: Operation 0x000002BE3140F520 (type= 4) is now completed
[<date><time> 1aa4] ----- CauOperation::SetComplete 
[<date><time> 1aa4] ----- CauRunUpdateInstallerOperation::RunUpdateInstaller 
```

### 0x80070005 (access denied) errors in C:\Windows\Logs\DISM\dism.log

```
<date> <time>, Info         DISM   DISM Manager: PID=13912 TID=14268 Create session event 0x384 for current DISM session and event name is Global\{53382856-8E48-4046-9078-EA8B9E1DB109}  - CDISMManager::CheckSessionAndLock
<date> <time>, Info         DISM   DISM Manager: PID=13912 TID=14268 Copying DISM from "C:\Windows\System32\Dism" - CDISMManager::CreateImageSessionFromLocation
<date> <time>, Info         DISM   DISM Manager: PID=13912 TID=14268 No Sandbox was created, DISM running in-place. - CDISMManager::CreateImageSessionFromLocation
<date> <time>, Error        DISM   DismHostLib: PID=13912 TID=14268 Failed to create dismhost.exe servicing process. - DismCreateObjectInHostFromCLSID(hr:0x80070005)
<date> <time>, Error        DISM   DISM Manager: PID=13912 TID=14268 Failed to create Dism Image Session in host. - CDISMManager::LoadRemoteImageSession(hr:0x80070005)
<date> <time>, Warning      DISM   DISM Manager: PID=13912 TID=14268 A problem ocurred loading the image session. Retrying...  - CDISMManager::CreateImageSession(hr:0x80070005)
<date> <time>, Info         DISM   DISM Manager: PID=13912 TID=14268 Copying DISM from "C:\Windows\System32\Dism" - CDISMManager::CreateImageSessionFromLocation
<date> <time>, Info         DISM   DISM Manager: PID=13912 TID=14268 No Sandbox was created, DISM running in-place. - CDISMManager::CreateImageSessionFromLocation
<date> <time>, Error        DISM   DismHostLib: PID=13912 TID=14268 Failed to create dismhost.exe servicing process. - DismCreateObjectInHostFromCLSID(hr:0x80070005)
<date> <time>, Error        DISM   DISM Manager: PID=13912 TID=14268 Failed to create Dism Image Session in host. - CDISMManager::LoadRemoteImageSession(hr:0x80070005)
<date> <time>, Error        DISM   DISM Manager: PID=13912 TID=14268 Failed to load the image session from location: C:\Windows\System32\Dism - CDISMManager::CreateImageSession(hr:0x80070005)
<date> <time>, Error        DISM   API: PID=13912 TID=14268 m_pDismManager->CreateImageSession failed - CDismCore::CacheImageSession(hr:0x80070005)
<date> <time>, Error        DISM   API: PID=13912 TID=14268 InternalExecute failed - CBaseCommandObject::Execute(hr:0x80070005)
<date> <time>, Error        DISM   API: PID=13912 TID=14216 CAttachPathCommandObject failed - DismOpenSessionInternal(hr:0x80070005)
```


---
