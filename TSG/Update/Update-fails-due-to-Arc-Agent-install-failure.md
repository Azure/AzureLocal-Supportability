# Update Fails Due to Arc Agent Install Failure

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Arc Agent</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>High</strong></td>
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

Azure Local update may fail during Arc agent installation due to a file lockdown issue. The `azcmagent.log` file under `C:\ProgramData\AzureConnectedMachineAgent\Log` can become locked, preventing the Arc agent installer from completing successfully.

> **Note:** This issue only affects Arc agent versions below 1.62. If you are running Arc agent 1.62 or later, this issue does not apply.

## Symptoms

- Solution update fails during Arc agent installation step.
- Arc agent install logs indicate a lockdown or file access issue.

**Common error messages:**

Check `C:\ImageComposition\ArcAgent\arcInstallLog.txt` on the affected node(s) for errors referencing a lockdown or inability to access the log file.

**Observable behaviors:**

- Update does not progress past the Arc agent installation phase.
- The `arcInstallLog.txt` file on one or more nodes contains lockdown-related errors.

## Root Cause

The Arc agent log file (`C:\ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log`) becomes locked, which prevents the Arc agent installer from writing to it during the update process. This causes the installation to fail and blocks the overall update.

## Resolution

### Prerequisites

- Remote PowerShell access or local console access to the affected cluster node(s).

### Steps

1. **Diagnose the issue**
   Review the Arc agent install log on each affected node to confirm the lockdown error.

   ```powershell
   Get-Content "C:\ImageComposition\ArcAgent\arcInstallLog.txt" | Select-String -Pattern "lock"
   ```

2. **Back up the locked log file**
   Move the `azcmagent.log` file to a backup location outside of the `C:\ProgramData\AzureConnectedMachineAgent` directory. This releases the lock and allows the installer to create a fresh log file.

   ```powershell
   # Create a backup directory if it doesn't exist
   New-Item -ItemType Directory -Path "C:\Temp\ArcAgentLogBackup" -Force

   # Move the locked log file to the backup location
   Move-Item -Path "C:\ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log" -Destination "C:\Temp\ArcAgentLogBackup\azcmagent.log" -Force
   ```

   > **Note:** Repeat this step on all affected nodes in the cluster.

3. **Retry the update**
   Attempt the update again. The Arc agent installer should now be able to proceed without the lockdown issue.

4. **Verify resolution**
   ```powershell
   # Confirm the update is progressing past the Arc agent install step
   Get-SolutionUpdate | Format-Table -Property Title, State, Status
   ```

---
