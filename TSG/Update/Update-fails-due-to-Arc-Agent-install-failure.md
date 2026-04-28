# Update Fails Due to Arc Agent Install Failure

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Arc Agent</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Update</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>Arc Agent versions below 1.62</strong></td>
  </tr>
</table>

## Overview

Azure Local update may fail during Arc agent installation due to a file locking issue. The Arc agent installer may encounter problems when trying to lock the existing `azcmagent.log` file under `C:\ProgramData\AzureConnectedMachineAgent\Log`, preventing it from completing successfully.

> **Note:** This issue only affects Arc agent versions below 1.62. If you are running Arc agent 1.62 or later, this issue does not apply.

### Check your Arc Agent version

Run the following command on the affected node(s) to confirm the installed Arc Agent version:

```powershell
azcmagent version
```

If the version is **1.62 or later**, this issue does not apply and you do not need to follow the steps below.

## Symptoms

- Solution update fails during Arc agent installation step.
- Arc agent install logs indicate a lockdown or file access issue.

**Diagnosing the issue:**

Check `C:\ImageComposition\ArcAgent\arcInstallLog.txt` on the affected node(s) for errors referencing a lockdown or inability to access the log file.

**Observable behaviors:**

- Update does not progress past the Arc agent installation phase.
- The `arcInstallLog.txt` file on one or more nodes contains lockdown-related errors.

## Resolution

### Prerequisites

- Remote PowerShell access or local console access to the affected cluster node(s).

### Steps

1. **Diagnose the issue**
   Review the Arc agent install log on each affected node to confirm the lockdown error.

   ```powershell
   Get-Content "C:\ImageComposition\ArcAgent\arcInstallLog.txt" | Select-String -Pattern "lockdown"
   ```

2. **Move the existing log file**
   Move the `azcmagent.log` file to a backup location outside of the `C:\ProgramData\AzureConnectedMachineAgent` directory. This allows the Arc agent installer to create a fresh log file without encountering the locking issue.

   ```powershell
   $ErrorActionPreference = "Stop"

   $sourceLogPath = "C:\ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log"
   $backupDirectory = "C:\Temp\ArcAgentLogBackup"
   $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
   $nodeName = $env:COMPUTERNAME
   $backupFileName = "azcmagent-$nodeName-$timestamp.log"
   $destinationLogPath = Join-Path -Path $backupDirectory -ChildPath $backupFileName

   # Verify the source log file exists
   if (-not (Test-Path -Path $sourceLogPath)) {
       throw "Source log file not found: $sourceLogPath"
   }

   # Create a backup directory if it doesn't exist
   if (-not (Test-Path -Path $backupDirectory)) {
       New-Item -ItemType Directory -Path $backupDirectory | Out-Null
   }

   # Verify the backup destination doesn't already exist
   if (Test-Path -Path $destinationLogPath) {
       throw "Backup destination already exists: $destinationLogPath"
   }

   # Move the log file to the backup location
   Move-Item -Path $sourceLogPath -Destination $destinationLogPath

   # Verify the move completed successfully
   if ((-not (Test-Path -Path $destinationLogPath)) -or (Test-Path -Path $sourceLogPath)) {
       throw "Backup verification failed. Source: $sourceLogPath Destination: $destinationLogPath"
   }
   ```

   > **Note:** Repeat this step on all affected nodes in the cluster.

3. **Retry the update**
   Attempt the update again after the old log file has been moved. The Arc agent installer should now be able to proceed without the locking issue.

---
