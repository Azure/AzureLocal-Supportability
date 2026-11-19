# TSG | 23H2 | 11.2510.1002.87 update fails at CauPostVersionCheck

Update of 23H2 clusters from 11.2509 to 11.2510 can fail at CauPostVersionCheck due to the expected KB not installed on the system.

# Symptoms
Customers would encounter an update failure with an error similar to:

```
CloudEngine.Actions.InterfaceInvocationFailedException: Type 'CauPostVersionCheck' of Role 'CAU' raised an exception:

Current node platform version is '10.0.25398.1849' but expect version should be greater than or equal to '10.0.25398.1913'.
```
  
# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm that you are seeing the error message above in the update portal.

## Failure/Errors seen on Portal/CLI

Expected error to see on the Portal/CLI
```
Type 'CauPostVersionCheck' of Role 'CAU' raised an exception:

Current node platform version is '10.0.25398.1849' but expect version should be greater than or equal to '10.0.25398.1913'.
```


## PowerShell script

PowerShell code to confirm/detect the symptom that CSS can run on the customer environment to confirm the symptoms of this TSG.

```Powershell
Get-ActionPlanInstances | where { $_.updateId -match "Solution11.2510.1002.87" } | where Status -eq "Failed" | where ProgressAsXml -match "Current node platform version is '10.0.25398.1849'" | ft StartDateTime, EndDateTime, InstanceId, ActionPlanName, RuntimeParameters
```

# Cause
During the Solution update, OS and .NET security updates are installed and nodes rebooted using Cluster Aware Updating (CAU). However, in some systems an earlier step in the action plan also removes an unneeded Windows optional feature, which results in a pending servicing state. Due to the pending servicing, the initial install and reboot orchestrated by CAU results in only a partial installation of the OS updates.

# Mitigation Details

To complete installation, the same content can be installed again, followed by a reboot of the nodes to complete update installation.

## Step 1: Install the updates on all nodes.
The same installers that are downloaded as part of the 11.2510 update can be used to complete the installation. You can run the following in a PowerShell session on each of the cluster nodes. Refer to the possible exit codes and explanations in the script below.

```PowerShell
C:\Windows\System32\Dism.exe /Online /Add-Package /PackagePath:C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\MSU\UnifiedCumulative\Windows11.0-KB5066780-x64.msu /PackagePath:C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\Platform\MSU\DotNet\Windows11.0-KB5066129-x64-NDP481.msu /Quiet /NoRestart

$successExitCodes = @(
    0,          # Installation success
    0x80240017, # Not applicable
    0x00240006, # Already installed
    0x00240005, # Reboot required
    3010        # Reboot required
)

$dismExitCode = $LASTEXITCODE
Write-Host "DISM last exit code was $dismExitCode"
if ($dismExitCode -notin $successExitCodes)
{
    Write-Error "Unexpected exit code: $dismExitCode"
}
```

The most likely exit code is 3010, which indicates that a reboot is required.

## Step 2: Drain, Reboot, and Resume Nodes

Choose **one** of the following options:

### Option A: Use CAU RollingUpgrade Plugin (Recommended)

Run the plugin in MockSetup mode using the PowerShell command:

```powershell
Invoke-CauRun -CauPluginName Microsoft.RollingUpgradePlugin -CauPluginArguments @{'WuConnected'='false';'PathToSetupMedia'='\\localhost\C$\temp\CAU\CAUHotfix_All\InstallMsuFiles.ps1';'MockSetup'='true'} -ForceSelfUpdate -Force
```

Monitor the CAU run using the `Get-CauRun` cmdlet.

### Option B: Manual Node Processing (one node at a time)

1.  Drain the node:
```
Suspend-ClusterNode -Drain -Wait
```    
2.  Reboot the node:
```
Restart-Computer -Force  
```
    
3.  Resume the node:
```    
Resume-ClusterNode -Failback Immediate  
```

### Step 3: Resume Solution Update
Resume the update from the Azure portal.