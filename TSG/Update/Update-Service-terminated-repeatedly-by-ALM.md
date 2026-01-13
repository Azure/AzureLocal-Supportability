# TSG | 2509 | Update Service terminated repeatedly by ALM due to high memory usage

Update service can be frequently terminated due to exceeding the maximum configured memory limit. If the service is terminated in this way during preparation, preparation may be unable to complete successfully.

# Symptoms
One symptom observed is that update service is continuously terminated in the middle of every update preparation attempt, while update service is waiting for the health check action plan to complete.

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following behavior(s)

## PowerShell script

Update service process termination can be detected in the Windows Event logs by examining events in Event Viewer or through PowerShell on the cluster node that is the owner of the `Azure Stack HCI Update Service Cluster Group`. 

Find the current update service owner node:
```powershell
Get-ClusterGroup "Azure Stack HCI Update Service Cluster Group"
```

Sample output:
```
Name                                         OwnerNode State
----                                         --------- -----
Azure Stack HCI Update Service Cluster Group v-Host1   Online
```

Run the following commands to find events indicating that the update service was terminated due to exceeding the memory limit:

```powershell
Get-WinEvent -LogName Application | where ProviderName -eq "AzureStack Agent Lifecycle Agent" | where Message -match "Azure Stack HCI Update Service: Memory Error Limit Reached"
```

Sample output. Note the `TimeCreated` value to determine that these are recent, relevant events. If the event times are not recent they are likely not relevant:
```
   ProviderName: AzureStack Agent Lifecycle Agent

TimeCreated                      Id LevelDisplayName Message
-----------                      -- ---------------- -------
10/10/2025 6:46:46 PM             1 Error            Azure Stack HCI Update Service: Memory Error Limit Reached, terminating process. Current private memory usage = 4294967384 bytes, memory limit = 4294967296 bytes.
```

The same events can be viewed in Event Viewer, in the Windows Logs > Application log.


# Cause

There is a bug found in 2509 which is a memory leak in a serializer used by the update service cache. This leak can be exacerbated by a large number of health check result objects. These objects are retained even for installed updates and are reported in the corresponding update object returned by `Get-SolutionUpdate`.

# Mitigation Details

## Remove health check result files for installed updates
Health check result files are stored in the `C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1> cd .\Updates\HealthCheck\` directory on the infrastructure volume. Within that directory, there will be a subdirectory named `System` and additional subdirectories containing the names of installed updates like (for example) `Solution11.2508.1001.51` or `SBE4.1.2508.1`. Directories that correspond to updates that are already installed can be cleaned up.

The following command can be used to clean up all the directories. Save this script on one of the cluster nodes and run.

```powershell
$ErrorActionPreference = "Stop"

Write-Host "Checking for installed updates."
$installedUpdates = Get-SolutionUpdate | where State -eq Installed
$resourceIds = @( $installedUpdates | % { $_.ResourceId.Split('/')[-1] } )
Write-Host "Found $($installedUpdates.Count) installed updates: $($resourceIds -join ", ")"

if ($resourceIds.Count -gt 0)
{
    $removedHC = $false
    foreach ($resourceId in $resourceIds)
    {
        $healthCheckPath = Join-Path "C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\HealthCheck" $resourceId
        if (Test-Path $healthCheckPath)
        {
            Write-Host "Removing health check directory for $resourceId"
            $removedHC = $true
            Remove-Item -Path $healthCheckPath -Recurse -Force -Verbose
        }
        else
        {
            Write-Host "No health check found for $resourceId at $healthCheckPath"
        }
    }

    if ($removedHC)
    {
        Write-Host "Some health checks were removed, so clearing update service cache."
        $clientCert = ls Cert:\LocalMachine\My\ | ? Subject -match "URP" | sort NotAfter | select -last 1
        $updateEndpoint = "https://$(Get-ClusterGroup *update* | % OwnerNode | % Name).$($env:USERDNSDOMAIN):4900"
        $clearCacheResult = Invoke-WebRequest -Certificate $clientCert -UseBasicParsing -Uri "$updateEndpoint/caches/Update" -Method "Delete"
        if ([int]::TryParse($clearCacheResult.Content, [ref]$null))
        {
            Write-Host "Removed $($clearCacheResult.Content) updates from the cache."
        }
        else
        {
            Write-Warning "Unexpected result from clearing the cache: $($clearCacheResult | Out-String)"
        }
    }
}
```

## Remove failed Update action plan instances
Delete all failed Update action plans except for the last failed one.

```
Import-Module ECEClient -DisableNameChecking 
$failedUpdates = Get-ActionPlanInstances | ? { $_.Status -eq "Failed" -and $_.ActionPlanName -match "MAS Update" } | sort LastModifiedDateTime -Descending | select -Skip 1
$instanceIDs = $failedUpdates.InstanceID
   
$eceClient = Create-ECEClusterServiceClient  
$deleteActionPlanInstanceDescription = New-Object Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.DeleteActionPlanInstanceDescription  
  
foreach ($actionPlanInstanceId in $instanceIDs) {  
   # remove old instance  
   $deleteActionPlanInstanceDescription.ActionPlanInstanceID = $actionPlanInstanceID  
   $eceClient.DeleteActionPlanInstance($deleteActionPlanInstanceDescription).Wait()  
}
```

## (Last Resort) Increase update service memory limit
If the problem is still occurring, the final thing to do is to temporarily increase the configured memory limit for the update service.

This can be done by changing the configured value for the memory limit in the update service agent manifest on each node and restarting the ALM agent. To do so, set the expected values at the top of this script in MB (existing suggested values are warning: 5.5GB and error: 6GB) and run this script **on every cluster node**.

```powershell
$ErrorActionPreference = "Stop"

# Values in MB
$memoryWarningLimit = 5632
$memoryErrorLimit = 6144

if ($memoryErrorLimit -lt 4096)
{
    throw "Current memory limit is 4096. If this TSG is being used, the suggested memory limit should be higher."
}

if ($memoryErrorLimit -lt $memoryWarningLimit)
{
    throw "Warning limit ($memoryWarningLimit) must be lower than the Error limit $($memoryErrorLimit)"
}

$updateAgentManifestFileName = ls "C:\Agents\AgentManifests\*Update Service*"
if ($updateAgentManifestFileName.Count -gt 1)
{
    throw "Unexpectedly found more than one update service agent manifest in C:\Agents"
}

if (-not $updateAgentManifestFileName)
{
    throw "Unable to find the update agent manifest at C:\Agents\AgentManifests"
}

Write-Host "Found update agent manifest at $($updateAgentManifestFileName.FullName)"
$updateAgentManifest = Get-Content $updateAgentManifestFileName.FullName -Raw | ConvertFrom-Json

if ($updateAgentManifest.WindowsServiceInstallationParameters.ResourceGovernanceConfiguration.WarningMemoryLimitMB -ne $memoryWarningLimit -or `
    $updateAgentManifest.WindowsServiceInstallationParameters.ResourceGovernanceConfiguration.ErrorMemoryLimitMB -ne $memoryErrorLimit)
{
    Write-Host "Setting Warning limit to $($memoryWarningLimit)MB and Error limit to $($memoryErrorLimit)MB"
    $updateAgentManifest.WindowsServiceInstallationParameters.ResourceGovernanceConfiguration.WarningMemoryLimitMB = $memoryWarningLimit
    $updateAgentManifest.WindowsServiceInstallationParameters.ResourceGovernanceConfiguration.ErrorMemoryLimitMB = $memoryErrorLimit

    Write-Host "Saving edited agent manifest back to $($updateAgentManifestFileName.FullName)"
    $updateAgentManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $updateAgentManifestFileName.FullName

    Write-Host "Restarting ALM agent to pick up new config."
    Get-Service "AzureStack Agent Lifecycle Agent" | Restart-Service

    $updateService = Get-Service "Azure Stack HCI Update Service"
    if ($updateService.Status -eq "Running")
    {
        Write-Host "Restarting update service to be monitored with new memory limit values."
        $updateService | Restart-Service
    }
    else
    {
        Write-Host "Update service is not primary on this node. Current status: $($updateService.Status)"
    }
}
else
{
    Write-Host "No changes needed. Existing limits are already set. Warning limit $($memoryWarningLimit)MB and Error limit $($memoryErrorLimit)MB"
}
```

