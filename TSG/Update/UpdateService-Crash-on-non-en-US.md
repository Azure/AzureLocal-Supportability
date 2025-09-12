# TSG: 2508 Update: UpdateBootstrap ResetOverrideDiscoveryUri  A WebException occurred

This failure can occur in the 2508 update. It is believed to be found in environments using a non en-US locale. This happens because of a persistent crash of the update service in these environments.

# Symptoms
There are two symptoms that may be observed. 

1. The update action plan will fail with an exception similar to:
```
Type 'ResetOverrideDiscoveryUri' of Role 'UpdateBootstrap' raised an exception:

A WebException occurred while sending a RestRequest. WebException.Status: ConnectFailure on https://host1.domain.local:4900/providers/Microsoft.Update.Admin/discoveryDiagnosticInfo?api-version=2022-08-01

at ResetOverrideDiscoveryUri, C:\NugetStore\Microsoft.AS.UpdateBootstrap.10.2508.0.5\content\Classes\UpdateBootstrap\UpdateBootstrap.psm1: line 646
```

2. The update action plan fails due to another issue earlier in the action plan and update service cmdlets like `Get-SolutionUpdate` are non-responsive.

In addition, because the condition causes update service to continually crash, update progress may not be shown in the portal and Solution update cmdlets (`Get-SolutionUpdate`, `Get-SolutionUpdateEnvironment`) would time out or fail.

# Issue Validation
To confirm the scenario that you are encountering is the issue documented in this article, confirm you are seeing the following behavior(s)

In some cases, the update will fail at the `ResetOverrideDiscoveryUri` step. This can be detected by checking the error message associated with the most recently failed action plan. Output from the command below confirms the issue.

```powershell
Get-ActionPlanInstances | where { $_.RuntimeParameters.updateId -match "Solution" } | where Status -eq "Failed" | sort EndDateTime | select -Last 1 | where ProgressAsXml -match "Type 'ResetOverrideDiscoveryUri' of Role 'UpdateBootstrap' raised an exception" | ft InstanceId
```

In case the latest update failure was not associated with the ResetOverrideDiscoveryUri interface, the failure can be detected by checking the Application log on the node owning the update service cluster group.

```powershell
Get-ClusterGroup *Update*
```

Sample output:
```
Name                                         OwnerNode State
----                                         --------- -----
Azure Stack HCI Update Service Cluster Group v-Host2   Online
```

In a PowerShell session on that node, you can then check for update service crashes in the Application log with the specified message. The presence of a matching event found indicates the issue.

```powershell
Get-WinEvent -LogName Application | ? Message -match "The compaction percentage must be between 0 and 1" | select -First 1
```

# Cause
This is caused by an incorrect handling of locale-specific string conversion in the update service that causes the service to crash continuously. Specifically, this is caused by inconsistent handling of serialization/deserialization of a value of type `double` (0.05). In locales where a comma (,) is a decimal delimiter, the conversion back to `double` is causing the value to be interpreted incorrectly.

# Mitigation Details

1. **Modify update service settings to stop the crash**

Execute the following script in a PowerShell session on one of the cluster nodes.

```powershell

$settingsMitigation = {
    $ErrorActionPreference = "Stop"
    $rootInstallPath = Get-Package -Destination C:\Agents\ -Name Microsoft.AzureStack.UpdateWinService | % Source | Split-Path
    $settingsFilePath = Join-Path $rootInstallPath "content\UpdateWinService\Settings.xml"

    Write-Host "[$($env:ComputerName)] Reading Settings.xml from $settingsFilePath"
    if (-not (Test-Path $settingsFilePath)) {
        throw "[$($env:ComputerName)] Unable to find Settings.xml at the expected path: $settingsFilePath"
    }

    Add-Type -AssemblyName "System.Xml.Linq"  

    $xml = [xml](Get-Content $settingsFilePath)
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsMgr.AddNamespace("fab", "http://schemas.microsoft.com/2011/01/fabric")

    $targetSection = $xml.SelectSingleNode("//fab:Section[@Name='ServiceConfigSection']", $nsMgr)
    if (-not $targetSection)
    {
        throw "[$($env:ComputerName)] Unable to find the ServiceConfigSection section in Settings.xml"
    }

    $paramsToAdd = @(
        "Cache/Memory/CompactionPercentage/UpdateLocation",
        "Cache/Memory/CompactionPercentage/Update",
        "Cache/Memory/CompactionPercentage/UpdateRun",
        "Cache/Memory/CompactionPercentage/DiscoveryDiagnosticInfo",
        "Cache/Memory/CompactionPercentage/ActionPlanInstance",
        "Cache/Memory/CompactionPercentage/CloudParametersXml"
    )

    foreach ($param in $paramsToAdd) {
        $existingParam = $targetSection.Parameter | Where-Object Name -eq $param
        if ($existingParam) {
            Write-Host "[$($env:ComputerName)] Parameter $param already exists. Skipping addition." -Foregroundcolor Gray
            continue
        }

        $newParam = $xml.CreateElement("Parameter", "http://schemas.microsoft.com/2011/01/fabric")
        $newParam.SetAttribute("Name", $param)
        $newParam.SetAttribute("Value", "1")

        $targetSection.AppendChild($newParam) | Out-Null
        Write-Host "[$($env:ComputerName)] Added parameter: $param"
    }

    # Save the updated XML
    Write-Host "[$($env:ComputerName)] Saving modified Settings.xml to $settingsFilePath"
    $xml.Save($settingsFilePath)
}

$nodes = Get-ClusterNode | % Name

Write-Host "Running command on nodes: $($nodes -join ', ')"
Invoke-Command -ComputerName $nodes -ScriptBlock $settingsMitigation
```

2. **Validate update service state**

If the service was continuously crashing and restarting prior to this mitigation, it will be up and running as soon as the script above completes and Settings.xml file is updated.

If the service was for some reason no longer being started by the cluster resource, it may need to be manually started. Check the status of the update service cluster group.

```powershell
Get-ClusterGroup *Update*
```

Sample output:
```
Name                                         OwnerNode State
----                                         --------- -----
Azure Stack HCI Update Service Cluster Group v-Host2   Online
```

If the state is not `Online`, start the service using: 
```powershell
Get-ClusterGroup *Update* | Start-ClusterGroup
```

You can then run `Get-SolutionUpdate` to validate that the service is responsive again.

3. **Resume the update**

Resume the update from the portal or using `Start-SolutionUpdate`.

```powershell
$update = Get-SolutionUpdate | where ResourceId -match "2508.1001" | where State -eq "InstallationFailed"
$update | Start-SolutionUpdate
```

