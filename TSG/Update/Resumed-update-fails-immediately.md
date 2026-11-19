# Resuming an update can result in an empty action plan being submitted to ECE service, which immediately fails and contains no progress steps

# Symptoms
After resuming the update, the update action plan immediately fails.

# Issue Validation
To validate that this problem is occurring, you can check the status of the latest update action plan and verify that it failed with a message indicating that the XML is incorrect using the script below. Output will indicate whether the issue has been detected.

```powershell
$updates = Get-ActionPlanInstances | where { $_.RuntimeParameters.updateId -ne $null }
$mostRecentUpdate = $updates | sort LastModifiedDateTime | select -Last 1
if ($mostRecentUpdate.AdditionalInformation -match "does not contain the mandatory") {
  Write-Host "Detected empty action plan issue in update $($mostRecentUpdate.RuntimeParameters.updateId.Split('/')[-1]) instance ID $($mostRecentUpdate.InstanceID)"
} else {
  Write-Host "Issue was NOT detected. Most recent update $($mostRecentUpdate.RuntimeParameters.updateId.Split('/')[-1]) had a valid action plan."
}
```

# Cause
This is caused by a cache synchronization issue in update service that was introduced in 2508. The result is that on resume of a failed action plan, update service submits an empty action plan instance to ECE instead of the previously failed action plan XML. The issue is not consistent but once an action plan has been incorrectly resumed in this way, all subsequent resume attempts will continue to fail in the same way.

# Mitigation Details

The following script can be run in a PowerShell session on one of the cluster nodes to remediate the issue. The script will do the following:

1.  Clean up the empty action plans that resulted from incorrect resumes.
2.  Clear update service cache.
3.  Restart update service.
4.  Resume the update.

```powershell
  
# TSG for failure to resume update
$ErrorActionPreference = "Stop"

$failedUpdate = Get-SolutionUpdate | where State -eq "InstallationFailed"

if (-not $failedUpdate)
{
    throw "Could not find the failed update that needs to be resumed."
}

if ($failedUpdate.Count -gt 1)
{
    throw "Found multiple failed updates: $($failedUpdate | Out-String)"
}

$updates = Get-ActionPlanInstances | where { $_.RuntimeParameters.updateId -ne $null }
$emptyUpdates = $updates | ? { $_.RuntimeParameters.updateId -match 2508 } | where AdditionalInformation -match "does not contain the mandatory"
Write-Host "Found $($emptyUpdates.Count) empty action plan instances to delete."

$eceClient = Create-ECEClientSimple
$desc = [Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.DeleteActionPlanInstanceDescription]::new()
foreach ($emptyUpdate in $emptyUpdates) {
    Write-Host "Deleting action plan instance: $($emptyUpdate.InstanceId)"
    $desc.ActionPlanInstanceId = $emptyUpdate.InstanceId
    $eceClient.DeleteActionPlanInstance($desc).Wait()
}

Get-SolutionUpdateEnvironment

$updateEndpoint = "https://$(Get-ClusterGroup *update* | % OwnerNode | % Name).$($env:USERDNSDOMAIN):4900"
Write-Host "Update endpoint: $updateEndpoint"

$clientCert = ls Cert:\LocalMachine\My\ | ? Subject -match "URP" | sort NotAfter | select -last 1

Write-Host "Clearing ActionPlanInstance cache"

$clearCacheResult = Invoke-WebRequest -Certificate $clientCert -UseBasicParsing -Uri "$updateEndpoint/caches/ActionPlanInstance" -Method "Delete"
if ($clearCacheResult.StatusCode -ne 200) {
    throw "Failed to clear ActionPlanInstance cache. Status code: $($clearCacheResult.StatusCode). Result: $($clearCacheResult | Out-String)"
}

Write-Host "Restarting update service"
Get-ClusterGroup *update* | Stop-ClusterGroup
Get-ClusterGroup *update* | Start-ClusterGroup

$update = Get-SolutionUpdate | where State -eq "InstallationFailed"
$run = $update | Start-SolutionUpdate

$newInstance = $run -split "/" | select -last 1
$resumedUpdate = Get-ActionPlanInstance -actionPlanInstanceId $newInstance

if ($resumedUpdate.Status -eq "Failed") {
    throw "Resumed update still in a failed state. $($resumedUpdate | Out-String)"
}

Write-Host "Resumed update with instance ID $newInstance"
```
