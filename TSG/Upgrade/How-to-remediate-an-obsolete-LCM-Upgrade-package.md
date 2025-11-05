# Overview
This TSG applies to a solution upgrade of a cluster from 22H2 to 23H2
This article will explain how to remediate a cluster that has an obsolete upgrade package. A cluster can have an obsolete upgrade package if the LCM extension was installed some time back.

# Symptoms 
The solution upgrade environment validator will throw errors with the message. This error will be seen in the portal deployments page 
 ``` Type 'ValidateDownloadedPackageVersionOnSeedNode' of Role 'DeploymentService' raised an exception: Current seed node deployment package version is lower than the latest manifest version. Please follow this TSG to remediateaka.ms/RemediateLCMPreviousZip ```

## Only use this TSG if you have not started a solution upgrade action. 

# Issue Validation

Run the script below on **_all of the nodes_** if the script throws the action started error on any of the nodes, then **stop and do not proceed** with this TSG
```
$actionDeployExists = Test-Path "C:\ECEStore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\086a22e3-ef1a-7b3a-dc9d-f407953b0f84"
$actionUpgradeExists= Test-Path "C:\EceStore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\4aa0e19d-e6b7-31be-bcd0-250ea438567f"
if ($actionDeployExists -or $actionUpgradeExists) { throw "An action started do not proceed with this tsg" }
```

# Mitigation Details
Run the below commands on **_all nodes_** in the cluster 
1. Close all existing Powershell sessions on the host (remote or local) and open a new Powershell session
2. Run the command ```Stop-Service LCMController```
3. Run the below script block to clean up any obsolete content

 If you get the action started error on any of the nodes then stop using the TSG and contact support. 
```  
$ErrorActionPreference = "stop"
$actionDeployExists = Test-Path "C:\ECEStore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\086a22e3-ef1a-7b3a-dc9d-f407953b0f84"
$actionUpgradeExists= Test-Path "C:\EceStore\efb61d70-47ed-8f44-5d63-bed6adc0fb0f\4aa0e19d-e6b7-31be-bcd0-250ea438567f"
if ($actionDeployExists -or $actionUpgradeExists) { throw "An action started do not proceed with this tsg" } else { Write-Host "Applying TSG to clean up obsolete LCM deployment package"; $lcmServiceNugetNameToExclude = "Microsoft.AzureStack.Solution.LCMControllerWinService"; $lcmRoleNugetNameToExclude = "Microsoft.AzureStack.Role.Deployment.Service"; $nugetsToRemove = Get-ChildItem -Path $(Join-Path $env:SystemDrive "NugetStore")  -ErrorAction Ignore | where { $_.FullName -notmatch $lcmRoleNugetNameToExclude -and $_.FullName -notmatch $lcmServiceNugetNameToExclude }; $nugetsToRemove | Remove-Item -Force -Recurse;if (Test-Path C:\CloudDeployment){    Write-Host "CloudDeployment folder found removing";    Remove-Item C:\CloudDeployment -Force -Recurse;}else {    Write-Host "CloudDeployment folder not found continuing";} $status = Get-ItemProperty -Path "HKLM:\Software\Microsoft\LCMAzureStackStampInformation" -Name InitializationComplete -ErrorAction Ignore;if ($null -eq $status){    Write-Host "Initialization Complete Reg key not found. Skipping removal of this key. Continue with the tsg";}else {    Write-Host "Initialization Complete Reg key found removing key";    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\LCMAzureStackStampInformation" -Name InitializationComplete -ErrorAction stop -Force; } $newStatus = Get-ItemProperty -Path "HKLM:\Software\Microsoft\LCMAzureStackStampInformation" -Name DownloadComplete -ErrorAction Ignore;if ($null -eq $newStatus){    Write-Host "Download Complete Reg key not found. Skipping removal of this key. Continue with the tsg";}else {    Write-Host "Download Complete Reg key found removing key";    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\LCMAzureStackStampInformation" -Name DownloadComplete -ErrorAction stop -Force; }}
```

Note: If you hit a file locking issue of file ... cannot be deleted because it is in used, please close all PowerShell sessions and open file. Then re-do the above script block.

4. Reboot the Node and Start LCM Controller Service (Optional, only do this if LCMController version in Portal is less than 30.2502 version, else continue to 5)
```
a) Suspend-ClusterNode -Name "MachineName" -Drain
b) Restart-Computer -Force
c) Resume-ClusterNode -Name "MachineName"
d) Verify storage pool health: Get-StoragePool -FriendlyName "StoragePoolName"
```
 Wait until LCM initialization completes. You can use the script below to poll the completion of the initialization. This action takes about 15-20 minutes to complete
 ```
 $ErrorActionPreference = "stop";$endTime = $(Get-Date).AddHours(1);while ($endTime.CompareTo($(get-date)) -ne -1) {    try    {        $key = 'HKLM:\Software\Microsoft\LCMAzureStackStampInformation';        $status = Get-ItemProperty -Path $key -Name InitializationComplete ;        Write-Host "Key found";        if ($status.InitializationComplete -eq "Complete")        {            return "Initialization complete please proceed";        }    }    catch    {        Write-Host "Initialization not complete please wait";        Start-Sleep -Seconds 30;    }}Write-Error "Initialization did not complete in one hour. This usually mean there was a problem please contact support";
 ```

5. Run the command ```Start-Service LCMController```

## Wait until all nodes have finished running initialization
6. Re-run environment validation from portal

