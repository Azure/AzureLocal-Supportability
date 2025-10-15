# Overview

Solution Upgrade during the 2508/2509 timeframe has a known issue where stamp version is set incorrectly to 2509 solution version even though the actual components on the device is 2508. 

# Issue Validation

First, please ensure that there is no admin action that is currently in progress (Solution Update / PnU, Add Server / Add Node, Repair Server / Repair Node). We should not run this TSG if any are in progress / in failed state.

The validation can be run manually on any one node to verify. 

```
Import-Module ECEClient
$stampInformation = Get-StampInformation
if ("Upgrade" -ne $stampInformation.InstallationMethod) {
    # Not brownfield env, skip checking
    Write-Host "Not HCI environment. Issue does not exist."
} else {
    $servicesVersion = $stampInformation.ServicesVersion
    $stampVersion = $stampInformation.StampVersion
    $stampVersionObj = [Version]::Parse($stampVersion)
    $servicesVersionObj = [Version]::Parse($servicesVersion)
    # Both stampVersion and ServicesVersion are going to be updated during PnU as well.
    $stampVersionMinor = $stampVersionObj.Minor
    $servicesVersionMinor = $servicesVersionObj.Minor
    if ($stampVersionMinor -eq 2509) {
        if ($servicesVersionMinor -eq 2508) {
          Write-Host "Issue exist of mismatched version. Please continue with the mitigation in the TSG."
        } else {
          Write-Host "Not 2508 services version environment. Issue does not exist on the services version $servicesVersionMinor."
        }
    } else {
        # Not impacted by this issue, skip checking
        Write-Host "Not 2509 stamp version environment. Issue does not exist on the build $stampVersionMinor."
    }
}

```

If the command above returns the below line then the issue exist and need to be mitigated by using the below script.

```
Issue exist of mismatched version. Please continue with the mitigation in the TSG.
```

# Cause

There is an issue with timing in 2509 release that can cause 2509 solution version to be incorrectly set on 2508 components.

# Mitigation Details

We will need to run this command

```
Import-Module ECEClient
$eceClient = Create-ECEClusterServiceClient
$stampInformation = Get-StampInformation
if ("Upgrade" -ne $stampInformation.InstallationMethod) {
    # Not brownfield env, skip checking
    Write-Host "Not HCI environment. Issue does not exist."
} else {
    $servicesVersion = $stampInformation.ServicesVersion
    $stampVersion = $stampInformation.StampVersion
    $stampVersionObj = [Version]::Parse($stampVersion)
    $servicesVersionObj = [Version]::Parse($servicesVersion)
    # Both stampVersion and ServicesVersion are going to be updated during PnU as well.
    $stampVersionMinor = $stampVersionObj.Minor
    $servicesVersionMinor = $servicesVersionObj.Minor
    if ($stampVersionMinor -eq 2509) {
        # Stamp Version must be 2509
        if ($servicesVersionMinor -eq 2508) {
          Write-Host "Issue exist of mismatched version."
          # Depending on the OS Version the version is different
          $osMajorVersion = $([environment]::OSVersion.Version.Major.ToString())
          $osMinorVersion = $([environment]::OSVersion.Version.Minor.ToString())
          $osBuildVersion = $([environment]::OSVersion.Version.Build.ToString())
          $is23H2 = (($osMajorVersion -eq "10") -and ($osMinorVersion -eq "0") -and ($osBuildVersion -eq "25398"))
          if ($is23H2) {
            $stampVersion = "11.2508.1001.51"
          } else {
            $stampVersion = "12.2508.1001.52"
          }
          # Set Stamp Version
          $eceClient.SetStampVersion($stampVersion).GetAwaiter().GetResult()
          $eceClient.InvalidateCloudDefinitionCache().GetAwaiter().GetResult()
          # Set Initial Deployed Version
          $parametersUpdateDefinition = New-Object Microsoft.AzureStack.Solution.Deploy.EnterpriseCloudEngine.Controllers.Models.CloudParametersUpdateDescription
          $parametersUpdateDefinition.BaseElementXPath = "//Category[@Name='Setup']//Parameter[@Name='InitialDeployedVersion']"
          $parametersUpdateDefinition.Type = "UpdateAttribute"
          $parametersUpdateDefinition.AttributeName = "Value"
          $parametersUpdateDefinition.AttributeValue = $stampVersion
          $null = $eceClient.UpdateCloudParameters($parametersUpdateDefinition).GetAwaiter().GetResult()
          $eceClient.InvalidateCloudDefinitionCache().GetAwaiter().GetResult()
          Write-Host "Fixed issue of mismatched version. Stamp Version is now $stampVersion."
        } else {
          Write-Host "Not 2508 services version environment. Issue does not exist on the services version $servicesVersionMinor."
        }
    } else {
        # Not impacted by this issue, skip checking
        Write-Host "Not 2509 stamp version environment. Issue does not exist on the build $stampVersionMinor."
    }
}
```

Then you will need to do the following: 

``` PowerShell
# Confirm that the StampInformation is now correct
$stampInformation = Get-StampInformation
$stampInformation.StampVersion # This should show either 12.2508.1001.52 or 11.2508.1001.51
```

Check Get-SolutionUpdateEnvironment (This may take a bit of time to reflect, please allow couple minutes if this is not updated yet)

```
$sle = Get-SolutionUpdateEnvironment
$sle.CurrentVersion # This should show same as above
```

Once $sle.CurrentVersion shows the right 2508 version then we have fixed the issue.
