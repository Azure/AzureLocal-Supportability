# Overview
When applying a solution update to your cluster, an updating run may fail and cause the overall update to get stuck at the `CauPostVersionCheck` or `CauPostCheck` step. If you retry, the system attempts to resume from the failed step, but because this step (`CauPostVersionCheck` or `CauPostCheck`) does not trigger a new update run, the solution update may remain stuck at this step.

**Example error message:**
```
Type 'CauPostVersionCheck' of Role 'CAU' raised an exception: Current node platform version is '10.0.25398.1668' but expect version should be greater than or equal to '10.0.26100.4349'.
```
---

# Cause
The solution update action plan may incorrectly proceed to `CauPostVersionCheck` in case of a failed CAU run instead of retrying because of an issue in the retry detection logic. This results in some of the nodes not getting the update installed, causing the final version check in solution update to fail.

---

# Mitigation Steps 
Below is a simplified **PowerShell script** that will automate the steps necessary to trigger a full retry of the host OS update step in the solution update action plan (previously, this was done manually). The script will
1. Identify and select the most recent failed MAS Update action plan.
2. Validate that the status of `Update Host OS` step is `Error`.
3. Replace the child `<Task>` node inside the `Update Host Os` step to configure for a full retry.
4. Save the modified XML with a timestamped filename to temp.
5. Invoke the updated action plan to trigger retry.

## How to Run the Script
1. Contents of the script:  
   ```powershell
   $ErrorActionPreference = "Stop"
   # Get all failed MAS Update action plans
   $failedUpdates = Get-ActionPlanInstances | where Status -eq "Failed" | where { $_.ActionPlanName -match "MAS Update" }
   if (-not $failedUpdates) {
       throw "Cannot find any failed MAS Update action plan in ECE."
   }
   
   # Pick the most recent failed update
   $update = $null
   if ($failedUpdates.Count -gt 1)    {
       Write-Host "Found $($failedUpdates.Count) failed MAS Update action plans. Selecting the most recent one."
       $update = $failedUpdates | sort EndDateTime | select -Last 1
   } else {
       $update = $failedUpdates
   }
   Write-Host "Found action plan $($update.InstanceID) for update version $($update.RuntimeParameters.UpdateVersion)."
   
   # Load XML and locate 'Update Host OS' step
   $xml = $update.ProgressAsXml
   $updateHostStep = $xml.SelectSingleNode("//Step[@Name='Update Host OS']")
   if (-not $updateHostStep) {
       throw "Cannot find 'Update Host OS' step in the action plan."
   }
   
   # Validate the step is already in Status='Error'
   if (-not $updateHostStep.HasAttribute("Status") -or $updateHostStep.Status -ne "Error") {
       $actual = if ($updateHostStep.HasAttribute("Status")) { $updateHostStep.Status } else { "<missing>" }
       throw "The 'Update Host OS' step must be in Status='Error' before modifying. Current Status: $actual"
   }
   Write-Host "Replacing Task node(s) inside 'Update Host OS' step."
   
   # Remove existing Task child nodes only
   $existingTasks = $updateHostStep.SelectNodes("Task")
   foreach ($task in $existingTasks) {
       $updateHostStep.RemoveChild($task) | Out-Null
   }
   
   # Create new task to trigger full retry
   $newTask = $xml.CreateElement("Task")
   $newTask.SetAttribute("RolePath", "CAU")
   $newTask.SetAttribute("ActionType", "ClusterAwareUpdateForOSUpdate")
   $updateHostStep.AppendChild($newTask) | Out-Null
   
   # Save the modified xml file
   $timestamp = (Get-Date).ToString("yyMMdd-HHmm")
   $modifiedActionPlanPath = Join-Path $env:TEMP ("LastUpdate_{0}.xml" -f $timestamp)
   
   Write-Host "Saving modified action plan to $modifiedActionPlanPath"
   $xml.Save($modifiedActionPlanPath)
   
   # Resume update
   Write-Host "Resuming update action plan using the modified action plan XML."
   Invoke-ActionPlanInstance -ActionPlanPath $modifiedActionPlanPath -ExclusiveLock -Retries 3
   ```

2. You can either choose to save the contents to a script file (example: RetryUpdate.ps1) or run the above script directly in an **Administrator PowerShell window** on a cluster member node.
   ```powershell
   .\RetryUpdate.ps1
   ```
   The script will run the necessary checks and modify the action plan XML, save it as `LastUpdate_yymmdd-hhMM.xml` temp folder, and then trigger a retry automatically.

4. **Monitor progress**:
   The script outputs the new Action Plan Instance ID. You can monitor it using:
   ```powershell
   Get-ActionPlanInstance -actionplaninstanceid <InstanceID>
   ```

## What if the retry fails again?
- If the retry fails, collect the latest update XML:
  ```powershell
  $LastUpdate = Get-ActionPlanInstances | Where-Object ActionPlanName -match "MAS Update" | Sort-Object EndDateTime -Descending | Select-Object -First 1
  $LastUpdate.ProgressAsXml | Out-File C:\temp\LatestUpdate.xml
  ```
- Collect logs for troubleshooting:
  ```powershell
  $clusterName = Get-Cluster
  Save-CauDebugTrace -ClusterName $clusterName -FeatureUpdateLogs All -Force
  ```
- Share these logs with Microsoft Support for further assistance.

---
