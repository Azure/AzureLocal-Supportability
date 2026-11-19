# Symptoms
Mainly seen on Deployment or Scale-out (i.e., AddNode or RepairNode operations) failures at AzureStackBitlocker step with error message similar to the following:

```
Type 'EncryptClusterSharedVolumes' of Role 'AzureStackBitlocker' raised an exception:
The job running on xxx failed due to: System.Management.Automation.RemoteException: 
-> Failed enabling bitlocker for C:\ClusterStorage\UserStorage_13 (F:) 
-> Exception Type : [Microsoft.PowerShell.Commands.WriteErrorException] 
-> EXCEPTION DETAILS: -> Failed backing-up recovery key Id for C:\ClusterStorage\UserStorage_13 
-> Exception Type : [Microsoft.PowerShell.Commands.WriteErrorException] -> EXCEPTION DETAILS:Group policy does not permit the storage of recovery information to Active Directory. The operation was not attempted.
```

Make sure the step is at `EncryptClusterSharedVolumes` and the message **_"Group policy does not permit the storage of recovery information to Active Directory. The operation was not attempted."_** matches your error message. 

This issue will **only occur on 24H2 OS**. If you are on 23H2 OS, the same symptom will be due to a different cause. 

This TSG is only applicable to Azure Local 24H2 nodes, not any VM.

# Cause
There is an issue with `Get-OSConfigDesiredConfiguration`, which leads to missing settings on system. Later it will fail `EncryptClusterSharedVolumes` because the pre-requisite is not met.

# Validation

Run the following script on the impacted node, where the original exception was thrown.

```powershell
# Define the directory and prefix
$directories = @("C:\CloudContent\MASLogs\ASSecurityOSConfigLogs", "C:\MASLogs\ASSecurityOSConfigLogs")
$prefix = "ASOSConfig_ASStartOSConfigSecuritySettings_"

# Get all files with the common prefix
$files = Get-ChildItem -Path $directory -Filter "$prefix*"  

foreach ($directory in $directories) {
    if (Test-Path -Path $directory) {
        $files = Get-ChildItem -Path $directory -Filter "$prefix*"
        foreach ($file in $files) {
            $content = Get-Content $file.FullName
            foreach ($line in $content) {
                if ($line -match 'without default value: (\d+)') {
                    $number = [int]$matches[1]
                    Write-Verbose "File: $($file.Name) → Number of policies without default value: $number"
                    if ($number -gt 6) {
                        Write-Warning "Number of policies without default value: $number found in file: $($file.Name)."
                        Write-Warning "Issue validated"
                    }
                }
            }
        }
    }
}
```

If you see warning messages, that means this issue happened at least once.

# Mitigation
This can be a transient error so there are two steps to mitigate the issue.

## 1. Validate if the issue is still there
Run script on the impacted node. If it shows `Expected count and issue cannot be reproduced.`, the issue is no longer applicable and reproducible on this node.

**Change the `domainJoinedCluster` value properly based on your deployment type.**
```powershell
# Change this value if cluster is not domain joined
$domainJoinedCluster = $true
$scenario = if ($domainJoinedCluster) { "SecurityBaseline/AL/MemberServer" } else { "SecurityBaseline/AL/WorkgroupMember" }
$allSettings = Get-OSConfigDesiredConfiguration -Scenario $scenario
$noDefault = ($allSettings | Where-Object {$null -eq $_.Default}).Count
$actionType = 0
if ($noDefault -gt 6) {
    Write-Warning "$noDefault settings do not have a default value. Issue can be reproduced."
    $actionType = 2
}
elseif (6 -eq $noDefault) {
    Write-Host "$noDefault settings do not have a default value. Expected count and issue cannot be reproduced."
    $actionType = 1
}
else {
    Write-Warning "$noDefault settings do not have a default value. Unexpected count."
    $actionType = 2
}
```

## 2. Set the policy manually
Please run the following script to apply settings manually. Please run it using the same PowerShell context (i.e., Same window or same remote session). 
```powershell
if ($actionType -eq 1) {
    $scenario = if ($domainJoinedCluster) { "SecurityBaseline/AL/MemberServer" } else { "SecurityBaseline/AL/WorkgroupMember" }
    $allSettings = Get-OSConfigDesiredConfiguration -Scenario $scenario
    $settingsWithDefault = $allSettings | Where-Object {$null -ne $_.Default} | ForEach-Object Name
    Write-Host "Number of settings with default value defined in $scenario`: $($settingsWithDefault.Count)"
    Set-OSConfigDesiredConfiguration -Scenario $scenario -Authority "8345CBE6-CEFC-462A-8219-78F3FC0377C1" -Setting $settingsWithDefault -Default
}
elseif ($actionType -eq 2) {
    reg import "C:\Program Files\WindowsPowerShell\Modules\AzureStackOSConfigAgent\OSConfigCfg\OSConfig.reg"
    reg import "C:\Program Files\WindowsPowerShell\Modules\AzureStackOSConfigAgent\OSConfigCfg\PMSystem.reg"
    $content = Get-Content -Raw "C:\Program Files\WindowsPowerShell\Modules\AzureStackOSConfigAgent\OSConfigDoc\SecurityBaseLine.json"
    Set-OsConfigurationDocument -Content $content -SourceId "8345CBE6-CEFC-462A-8219-78F3FC0377C1" -Wait
}
else {
    Write-Error "Unexpected action type. Please double check if you have run the Step #1 mitigation script."
}
```
Once you've applied the script without seeing any issues (you can ignore the registry import error that says `The operation completed successfully`), go ahead and resume the deployment or scale-out process that previously failed.

Once deployment or scale-out operation has completed, **please reboot your impacted machine** to make sure all updated settings are in effect.
