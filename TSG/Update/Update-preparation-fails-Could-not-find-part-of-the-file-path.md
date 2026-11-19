# TSG | Update preparation fails with 'Could not find part of the path' after 24H2 upgrade

After performing a 24H2 upgrade (Solution update from 11.* to 12.* build), the subsequent update preparation fails with a state of PreparationFailed and the error message similar to _`Could not find a part of the path`_.

# Symptoms
An example of the failure message:
```
Could not find a part of the path 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\Packages\Solution12.2510.1002.94\Platform\ISO\sources\replacementmanifests\microsoft-windows-appx-deployment-server\microsoft.windows.secondarytileexperience_10.0.0.0_neutral__cw5n1h2txyewy.xml
```

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following behavior(s)

## Failure/Errors seen on Portal/CLI

See the exception above that would be visible in the portal or in the output of the update run (`Get-SolutionUpdateRun`) in PowerShell.

## PowerShell script

PowerShell code to confirm/detect the symptom that can be run to confirm the symptoms of this TSG.

```Powershell
# Select the update by state, or by specific ID
$update = Get-SolutionUpdate | where State -eq "PreparationFailed"

$run = $update | Get-SolutionUpdateRun
$run.Progress.Steps
```

If the cluster is experiencing this problem, the second step will have an error message with the `Could not find a part of the path` exception.

```Output
Name                    : Downloading update
Description             :
ErrorMessage            :
AggregatedErrorMessages :
Status                  : Success
StartTimeUtc            : 11/6/2025 10:16:22 PM
EndTimeUtc              : 11/6/2025 10:16:22 PM
ExpectedExecutionTime   :
LastUpdatedTimeUtc      : 11/6/2025 10:16:22 PM
Steps                   :
 
Name                    : Invalid update package
Description             : 1. Verify update file contents and prepare the update package manually.
                          For detailed instructions, see https://aka.ms/TroubleshootAzureStackUpdates
ErrorMessage            : Could not find a part of the path 'C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\Updates\Packages\Solution12.2510.1002.94\Platform\ISO\sources\
                          replacementmanifests\microsoft-windows-appx-deployment-server\microsoft.windows.secondarytileexperience_10.0.0.0_neutral__cw5n1h2txyewy.xml'.
AggregatedErrorMessages :
Status                  : Error
StartTimeUtc            : 11/6/2025 10:16:22 PM
EndTimeUtc              : 11/6/2025 10:17:41 PM
ExpectedExecutionTime   :
LastUpdatedTimeUtc      : 11/6/2025 10:17:41 PM
Steps                   :
 
Name                    : Checking health.
Description             :
ErrorMessage            :
AggregatedErrorMessages :
Status                  : NotStarted
StartTimeUtc            :
EndTimeUtc              :
ExpectedExecutionTime   :
LastUpdatedTimeUtc      :
Steps                   :
 
Name                    : Initiating update installation.
Description             :
ErrorMessage            :
AggregatedErrorMessages :
Status                  : NotStarted
StartTimeUtc            :
EndTimeUtc              :
ExpectedExecutionTime   :
LastUpdatedTimeUtc      :
Steps                   :
 
```


# Cause
A sequence of operations in the upgrade results in update service process running without long path support, which causes a failure while extracting the Platform package for the next update that contains file names longer than the default 260 characters.

# Mitigation Details

## 1. Validate long path support
Ensure that the `LongPathsEnabled` registry key is set to `1` on all nodes. This is expected to already be set, but it's a good idea to double check. The following script can be used to validate the setting.

```powershell
$nodes = Get-ClusterNode | % Name
icm $nodes { Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled } | ft PSComputerName, LongPathsEnabled
```

Sample expected output:
```Output
PSComputerName LongPathsEnabled
-------------- ----------------
v-Host2                       1
v-Host1                       1
```

If any node has a setting of 0, this should be set to 1 using the following command.
```powershell
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1
```

## 2. Restart update service
To get update service to run with long path support and be able to extract the package with long paths, it's sufficient to restart the service, to ensure that the new process picks up the correct LongPathsEnabled setting from the registry.

```powershell
Get-ClusterGroup "Azure Stack HCI Update Service Cluster Group" | Move-ClusterGroup
```

After this completes, the update can be resumed from the portal or PowerShell.
