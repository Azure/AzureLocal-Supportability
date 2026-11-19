# ValidateDotNetUpdatesOnCluster wusa.exe process completed with exit code

.NET update validation fails due to an unexpected exit code from wusa.exe (usually 5).

# Symptoms
You would see a failed Solution update with a message similar to:
```
Type 'ValidateDotNetUpdatesOnCluster' of Role 'OsUpdate' raised an exception: Windows11.0-KB5046270-x64-NDP481.msu was not successfully installed on HOST01. wusa.exe process completed with exit code: 5 (0x00000005).
at Test-InstalledDotNetUpdates, C:\NugetStore\Microsoft.AzureStack.Role.OsUpdate.2.2411.0.21\content\Roles\OsUpdate\Common.psm1: line 380
at ValidateDotNetUpdatesOnCluster, C:\NugetStore\Microsoft.AzureStack.Role.OsUpdate.2.2411.0.21\content\Classes\OsUpdate\OsUpdate.psm1: line 166
```

# Issue Validation
See example message above that you would see in Azure portal or action plan output. 

# Cause
This validation failure can happen for a few reasons. The most common reason is that the CAU did not succeed and that one or more nodes do not have their .NET framework updates installed. When the .msu file is invoked on the node, it is invoked in a remote PowerShell command. When this command determines that the update is missing, it tries to invoke WU APIs, which fail by design when invoked in a remote context.

Sometimes we see a different error code like -939523070 (0xC8000402). 

# Mitigation Details

To install the updates, you can connect directly to the node (e.g. using remote desktop) and invoke the installer from the command prompt.

```powershell
#-------------------
# Manually install .msu file dotnet update
# Note: This should be run directly on the node and will not work using a remote PS session from a different node
#-------------------

$msuFilePath = "C:\ClusterStorage\Infrastructure_1\Shares\SU1_Infrastructure_1\CloudMedia\KBs\DotNet\CAUHotfix_All\Windows11.0-KB5049620-x64-NDP481.msu"
$process = Start-Process -FilePath "C:\WINDOWS\system32\wusa.exe" -ArgumentList "$msuFilePath /quiet /norestart" -Wait -NoNewWindow -Verbose -PassThru
$process.ExitCode
```

If the exit code is 3010, this indicates that a reboot is required. Suspend/reboot/resume the node to finish installing the update.

After examining all nodes, you can resume the Solution update using the steps below.

# Resuming the Solution update

Save the following script with a .ps1 extension to create a PowerShell script file. Then, execute it from one of the nodes within the cluster environment

```powershell
$ErrorActionPreference = "Stop"

$failedUpdates = Get-ActionPlanInstances | where Status -eq "Failed" | where { $_.RuntimeParameters.updateId -match "Solution" }
if (-not $failedUpdates)
{
    throw "Cannot find the failed update action plan in ECE."
}

$update = $null
if ($failedUpdates.Count -gt 1)
{
    Write-Host "Found $($failedUpdates.Count) failed update action plans in ECE. Getting the most recently failed one."
    $update = $failedUpdates | sort EndDateTime | select -Last 1
}
else
{
    $update = $failedUpdates
}

Write-Host "Found action plan $($update.InstanceID) for update version $($update.RuntimeParameters.UpdateVersion)."

$xml = [xml]($update.ProgressAsXml)
$validateDotnetInterfaces = $xml.SelectNodes("//Task") | where RolePath -eq "Cloud\Fabric\OsUpdate" | where InterfaceType -eq "ValidateDotNetUpdatesOnCluster"
if (-not $validateDotnetInterfaces)
{
    throw "Cannot find interfaces of type 'ValidateDotNetUpdatesOnCluster' in the action plan."
}

Write-Host "Modifying status of $($validateDotnetInterfaces.Count) ValidateDotNetUpdatesOnCluster interfaces to 'Skipped'."
foreach ($interface in $validateDotnetInterfaces)
{
    if ($interface.HasAttribute("Status"))
    {
        $interface.Status = "Skipped"
    }
    else
    {
        $newStatusAttribute = $xml.CreateAttribute("Status")
        $newStatusAttribute.Value = "Skipped"
        $interface.Attributes.SetNamedItem($newStatusAttribute) | Out-Null
    }
}

$modifiedActionPlanPath = Join-Path $env:TEMP "modifiedUpdateValidateDotnetSkipped.xml"
Write-Host "Saving modified action plan to $modifiedActionPlanPath"
$xml.Save($modifiedActionPlanPath)

Write-Host "Resuming update action plan using the modified action plan XML."
Invoke-ActionPlanInstance -ActionPlanPath $modifiedActionPlanPath -ExclusiveLock -Retries 3
```

# Additional notes
Especially in the case of an unexpected error code from wusa.exe (not 5), there may be another cause to the failure. In this case, you can check the packages in CBS on the impacted node to determine if the package we are expecting, or a higher version, is already installed. 

To directly query CBS installed packages, the following script can be used.

```powershell
$installedPackagesRaw = ls "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages" | ? Name -match "DotNetRollup"

$highestInstalledVersion = 0

foreach ($pkg in $installedPackagesRaw)
{
    Write-Host "Processing package $($pkg | Out-String)"
    $fullVersion = $pkg.Name.Split('~')[-1]
    Write-Host "Package full version: $fullVersion"
    $majorVersion = [int]($fullVersion.Split('.')[2])
    Write-Host "Major version: $majorVersion"

    $state = $pkg | Get-ItemProperty -Name CurrentState | % CurrentState

    # 112: Installed
    # 80: Superseded
    if ($state -in @("112", "80"))\
    {
        Write-Host "State for $majorVersion is $state"

        if ($highestInstalledVersion -lt $majorVersion)
        {
            $highestInstalledVersion = $majorVersion
        }
        else
        {
            Write-Host "Not considering $majorVersion because its state was $state"
        }
    }
} 

Write-Host "Highest version package installed was: $highestInstalledVersion"
```

You can then reference the highest version installed against the version associated with the .NET framework KB: 

| KB | Version |
| --- | --- |
| KB5054705  | 9305 |
| KB5049620 | 9294 |
| KB5046270 | 9287 |
| KB5044028 | 9277 |

If a higher version is already installed on all nodes, nothing further needs to be done and you can resume the update using the steps in `Resuming the Solution update`.