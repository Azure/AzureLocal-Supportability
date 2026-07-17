# Microsoft.AzLocal.CSSTools command overview

This page lists every command documented for `Microsoft.AzLocal.CSSTools` version `1.2607.16.2249`.
It covers exported functions, insight component invocations, remediation invocations and support script
invocations. Follow each command link for parameter details and examples. Each linked page also
describes command output.

## Contents

- [Module setup](#module-setup)
- [Exported functions](#exported-functions)
- [Insight commands](#insight-commands)
- [Remediation commands](#remediation-commands)
- [Support script commands](#support-script-commands)
- [Related references](#related-references)
- [Release notes](#release-notes)

## Module setup

Run PowerShell as an administrator on an Azure Local system or a management computer with access to
the target environment.

```powershell
Install-Module -Name Microsoft.AzLocal.CSSTools -Force
Import-Module -Name Microsoft.AzLocal.CSSTools -Force
```

List the commands exported by the installed module:

```powershell
Get-Command -Module Microsoft.AzLocal.CSSTools
```

Open the complete help for one function:

```powershell
Get-Help <FunctionName> -Full
```

The syntax below omits `-ProgressAction` and PowerShell common parameters. Optional parameters appear
in square brackets. Required parameters appear without square brackets.

## Exported functions

| Function | Condensed syntax | Purpose |
| --- | --- | --- |
| [Clear-AzsSupportDirectory](./functions/Clear-AzsSupportDirectory.md) | `Clear-AzsSupportDirectory [-Path <String[]>] [-Recurse] [-Force]`<br>`Clear-AzsSupportDirectory [-ComputerName <String[]>] [-Credential <PSCredential>] [-Path <String[]>] [-Recurse] [-Force]` | Clears approved local or remote directory contents. |
| [Clear-AzsSupportParentWorkingDirectory](./functions/Clear-AzsSupportParentWorkingDirectory.md) | `Clear-AzsSupportParentWorkingDirectory [[-LastWriteTime] <DateTime>]` | Clears stale support working directory contents on infrastructure nodes. |
| [Compress-AzsSupportArchive](./functions/Compress-AzsSupportArchive.md) | `Compress-AzsSupportArchive -Path <DirectoryInfo> [[-Destination] <FileInfo>] [[-CompressionLevel] <String>]` | Creates a ZIP archive from a directory. |
| [Confirm-AzsSupportOSVersion](./functions/Confirm-AzsSupportOSVersion.md) | `Confirm-AzsSupportOSVersion -Version <String>`<br>`Confirm-AzsSupportOSVersion -MinimumVersion <String>` | Checks the current operating system version. |
| [Convert-AzsSupportStorageAttributes](./functions/Convert-AzsSupportStorageAttributes.md) | `Convert-AzsSupportStorageAttributes -DiskHealth <Object>` | Translates SBL storage attribute values. |
| [Copy-AzsSupportFileFromComputer](./functions/Copy-AzsSupportFileFromComputer.md) | `Copy-AzsSupportFileFromComputer -Path <String[]> -ComputerName <String[]> [[-Destination] <FileInfo>] [[-Credential] <PSCredential>] [-Recurse] [-Force]` | Copies items from remote computers. |
| [Copy-AzsSupportFileToComputer](./functions/Copy-AzsSupportFileToComputer.md) | `Copy-AzsSupportFileToComputer -Path <String[]> -ComputerName <String[]> [[-Destination] <FileInfo>] [[-Credential] <PSCredential>] [-Recurse] [-Force]` | Copies local items to remote computers. |
| [Disable-AzsSupportInsightLog](./functions/Disable-AzsSupportInsightLog.md) | `Disable-AzsSupportInsightLog` | Disables AzStack Insights file logging. |
| [Disable-AzsSupportTraceLog](./functions/Disable-AzsSupportTraceLog.md) | `Disable-AzsSupportTraceLog` | Disables AzStack Support file logging. |
| [Enable-AzsSupportInsightLog](./functions/Enable-AzsSupportInsightLog.md) | `Enable-AzsSupportInsightLog` | Enables AzStack Insights file logging. |
| [Enable-AzsSupportTraceLog](./functions/Enable-AzsSupportTraceLog.md) | `Enable-AzsSupportTraceLog` | Enables AzStack Support file logging. |
| [Get-AzsStorageDiskPnpId](./functions/Get-AzsStorageDiskPnpId.md) | `Get-AzsStorageDiskPnpId [[-ComputerName] <Object>] [[-Credential] <PSCredential>]` | Gets PNP data for Storage Spaces disks. |
| [Get-AzsSupportBlocklistedDisk](./functions/Get-AzsSupportBlocklistedDisk.md) | `Get-AzsSupportBlocklistedDisk [[-ComputerName] <String>] [[-Credential] <PSCredential>] [[-SerialNumber] <String>]` | Gets blocklisted disks from the cluster filter service. |
| [Get-AzsSupportClusterName](./functions/Get-AzsSupportClusterName.md) | `Get-AzsSupportClusterName [[-Name] <String>]` | Gets the failover cluster name. |
| [Get-AzsSupportClusterUsage](./functions/Get-AzsSupportClusterUsage.md) | `Get-AzsSupportClusterUsage [[-ClusterName] <String>] [[-CimSession] <CimSession>]` | Calculates cluster storage usage and capacity. |
| [Get-AzsSupportDataIntegrityScanState](./functions/Get-AzsSupportDataIntegrityScanState.md) | `Get-AzsSupportDataIntegrityScanState [[-ComputerName] <Array>] [[-Credential] <PSCredential>]` | Gets the data integrity task state from reachable cluster nodes. |
| [Get-AzsSupportDiskSpace](./functions/Get-AzsSupportDiskSpace.md) | `Get-AzsSupportDiskSpace [[-ComputerName] <String[]>] -DriveLetter <Char> [[-Credential] <PSCredential>]` | Gets free space for one drive on target computers. |
| [Get-AzsSupportDiskSpaceReport](./functions/Get-AzsSupportDiskSpaceReport.md) | `Get-AzsSupportDiskSpaceReport [[-Cluster] <String>] -DriveLetter <Char>` | Creates a free space report for infrastructure hosts. |
| [Get-AzsSupportECECloudDefinitionXml](./functions/Get-AzsSupportECECloudDefinitionXml.md) | `Get-AzsSupportECECloudDefinitionXml` | Gets the ECE cloud definition as XML. |
| [Get-AzsSupportEceDeploymentDetails](./functions/Get-AzsSupportEceDeploymentDetails.md) | `Get-AzsSupportEceDeploymentDetails` | Gets ECE deployment details. |
| [Get-AzsSupportEceManagementClusterName](./functions/Get-AzsSupportEceManagementClusterName.md) | `Get-AzsSupportEceManagementClusterName` | Gets the management cluster name from the ECE cloud definition. |
| [Get-AzsSupportHostNetworkDiagnosticData](./functions/Get-AzsSupportHostNetworkDiagnosticData.md) | `Get-AzsSupportHostNetworkDiagnosticData [[-FilePrefix] <String>] [[-OutputDirectory] <String>] [-SkipCompression]` | Collects local host network diagnostic data. |
| [Get-AzsSupportInfrastructureHost](./functions/Get-AzsSupportInfrastructureHost.md) | `Get-AzsSupportInfrastructureHost [[-Name] <String>] [[-Cluster] <String>] [[-State] <String>]` | Gets physical host node data from Failover Clustering. |
| [Get-AzsSupportLcmDeploymentUserName](./functions/Get-AzsSupportLcmDeploymentUserName.md) | `Get-AzsSupportLcmDeploymentUserName` | Gets the LCM deployment account name. |
| [Get-AzsSupportPhysicalDisk](./functions/Get-AzsSupportPhysicalDisk.md) | `Get-AzsSupportPhysicalDisk [[-CimSession] <CimSession>] [[-SerialNumber] <String>] [[-PD] <String>] [-UnhealthyDisks] [-LocalOnly] [[-UniqueId] <String>] [[-StorageSubSystem] <CimInstance>] [[-StoragePool] <CimInstance>]` | Gets physical disks from a target computer. |
| [Get-AzsSupportPhysicalDiskIndicator](./functions/Get-AzsSupportPhysicalDiskIndicator.md) | `Get-AzsSupportPhysicalDiskIndicator [[-SerialNumber] <String>] -CimSession <CimSession>` | Gets disk indicator light state. |
| [Get-AzsSupportProcess](./functions/Get-AzsSupportProcess.md) | `Get-AzsSupportProcess [-ComputerName <String>] [-UseWinRM] [-Top <Int32>]`<br>`Get-AzsSupportProcess [-ComputerName <String>] [-UseTasklist]`<br>`Get-AzsSupportProcess [-ComputerName <String>] [-ProcessId <Int32>] [-UseWinRM]`<br>`Get-AzsSupportProcess [-ComputerName <String>] [-Name <String>] [-UseWinRM]` | Gets processes from a remote computer. |
| [Get-AzsSupportService](./functions/Get-AzsSupportService.md) | `Get-AzsSupportService [-ComputerName <Array>] [-UseWinRM]`<br>`Get-AzsSupportService [-ComputerName <Array>] [-Name <String>] [-UseWinRM]` | Gets services from target computers. |
| [Get-AzsSupportStampInformation](./functions/Get-AzsSupportStampInformation.md) | `Get-AzsSupportStampInformation` | Gets common stamp information. |
| [Get-AzsSupportStorageAutoPauseEvents](./functions/Get-AzsSupportStorageAutoPauseEvents.md) | `Get-AzsSupportStorageAutoPauseEvents -StartTime <DateTime> -EndTime <DateTime> -Nodes <Array[]>` | Gets volume autopause events. |
| [Get-AzsSupportStorageCacheDetails](./functions/Get-AzsSupportStorageCacheDetails.md) | `Get-AzsSupportStorageCacheDetails [[-ComputerName] <Array>] [[-Credential] <PSCredential>]` | Gets cache drive usage and error data. |
| [Get-AzsSupportStorageDirtyCount](./functions/Get-AzsSupportStorageDirtyCount.md) | `Get-AzsSupportStorageDirtyCount [[-ComputerName] <String[]>] [[-Credential] <PSCredential>]` | Checks dirty counts for Cluster Shared Volumes. |
| [Get-AzsSupportStorageDiskInfoGraphicDisplay](./functions/Get-AzsSupportStorageDiskInfoGraphicDisplay.md) | `Get-AzsSupportStorageDiskInfoGraphicDisplay [[-ClusterName] <String>]` | Displays threshold-based Cluster Shared Volume space data. |
| [Get-AzsSupportStorageDiskLatency](./functions/Get-AzsSupportStorageDiskLatency.md) | `Get-AzsSupportStorageDiskLatency [[-Latency] <String>] [[-StartTime] <DateTime>] [[-EndTime] <DateTime>] -Nodes <Array> [[-Credential] <PSCredential>]` | Checks live cluster events for disk latency. |
| [Get-AzsSupportStorageDiskSBLState](./functions/Get-AzsSupportStorageDiskSBLState.md) | `Get-AzsSupportStorageDiskSBLState [[-ComputerName] <Array>] [[-Credential] <PSCredential>]` | Gets the SBL state for disks. |
| [Get-AzsSupportStorageFirmwareDrift](./functions/Get-AzsSupportStorageFirmwareDrift.md) | `Get-AzsSupportStorageFirmwareDrift [[-CimSession] <CimSession>]` | Checks Storage Spaces firmware drift. |
| [Get-AzsSupportStorageHealthActionDetail](./functions/Get-AzsSupportStorageHealthActionDetail.md) | `Get-AzsSupportStorageHealthActionDetail [[-ComputerName] <String>] [[-Credential] <PSCredential>] [-FilterNotSucceeded] [-ShowFailedOnly] [-ShowRunningOnly] [[-TimeFilterHours] <Int32>]` | Gets filtered storage health action details. |
| [Get-AzsSupportStorageHealthFault](./functions/Get-AzsSupportStorageHealthFault.md) | `Get-AzsSupportStorageHealthFault [[-CimSession] <CimSession>]` | Gets cluster storage health faults. |
| [Get-AzsSupportStorageJob](./functions/Get-AzsSupportStorageJob.md) | `Get-AzsSupportStorageJob [-CimSession <CimSession>] [-Wait] [-IncludeStoragePoolOptimizationJob] [-RefreshInSeconds <Int32>]` | Gets active storage jobs. |
| [Get-AzsSupportStorageMissingDisks](./functions/Get-AzsSupportStorageMissingDisks.md) | `Get-AzsSupportStorageMissingDisks [[-Cluster] <String>] [[-Credential] <PSCredential>]` | Checks Storage Spaces for missing disks. |
| [Get-AzsSupportStorageNode](./functions/Get-AzsSupportStorageNode.md) | `Get-AzsSupportStorageNode [[-Name] <String>] [[-CimSession] <CimSession>]` | Gets one storage node or all storage nodes. |
| [Get-AzsSupportStoragePartitionInfo](./functions/Get-AzsSupportStoragePartitionInfo.md) | `Get-AzsSupportStoragePartitionInfo [[-ComputerName] <Array>] [[-Credential] <PSCredential>]` | Gets disk partition data from cluster nodes. |
| [Get-AzsSupportStoragePhysicalExtent](./functions/Get-AzsSupportStoragePhysicalExtent.md) | `Get-AzsSupportStoragePhysicalExtent -Friendlyname <Object> -CimSession <CimSession>` | Gets physical allocations for an unhealthy virtual disk. |
| [Get-AzsSupportStoragePool](./functions/Get-AzsSupportStoragePool.md) | `Get-AzsSupportStoragePool [[-FriendlyName] <String>] [[-CimSession] <CimSession>] [[-IsPrimordial] <Boolean>]` | Gets one storage pool or all storage pools. |
| [Get-AzsSupportStorageSNV](./functions/Get-AzsSupportStorageSNV.md) | `Get-AzsSupportStorageSNV [[-CimSession] <CimSession>]` | Checks storage node views for unhealthy disks. |
| [Get-AzsSupportStorageSubsystem](./functions/Get-AzsSupportStorageSubsystem.md) | `Get-AzsSupportStorageSubsystem [[-FriendlyName] <String>] [[-CimSession] <CimSession>]` | Gets one storage subsystem or all storage subsystems. |
| [Get-AzsSupportStorageSupportedComponents](./functions/Get-AzsSupportStorageSupportedComponents.md) | `Get-AzsSupportStorageSupportedComponents [[-CimSession] <CimSession>]` | Checks supported Storage Spaces hardware and firmware. |
| [Get-AzsSupportStorPortDriverEvents](./functions/Get-AzsSupportStorPortDriverEvents.md) | `Get-AzsSupportStorPortDriverEvents -ClusterName <String> -StartTime <DateTime> -EndTime <DateTime> [[-Credential] <PSCredential>]` | Gets StorPort driver events. |
| [Get-AzsSupportStorPortOpEvents](./functions/Get-AzsSupportStorPortOpEvents.md) | `Get-AzsSupportStorPortOpEvents -ClusterName <String> -StartTime <DateTime> -EndTime <DateTime> [[-Credential] <PSCredential>]` | Gets StorPort operational events. |
| [Get-AzsSupportVirtualDisk](./functions/Get-AzsSupportVirtualDisk.md) | `Get-AzsSupportVirtualDisk [[-CimSession] <CimSession>] [[-FriendlyName] <String>]` | Gets virtual disks and their health state. |
| [Get-AzsSupportVolumeUtilization](./functions/Get-AzsSupportVolumeUtilization.md) | `Get-AzsSupportVolumeUtilization [[-Filter] <String>] [[-CimSession] <CimSession>]` | Reports object store utilization. |
| [Get-AzsSupportWinEvent](./functions/Get-AzsSupportWinEvent.md) | `Get-AzsSupportWinEvent -LogName <String> [[-Cluster] <String>] [[-ClusterNodes] <String>] [[-Message] <String>] [[-EventId] <Array>] [[-FilterInformation] <Boolean>] [[-ProviderName] <Array>] [[-Backwards] <Boolean>] [[-Date] <String>] [[-Duration] <String>] [[-Detailed] <Boolean>]` | Gets filtered event log entries. |
| [Get-AzsSupportWorkingDirectory](./functions/Get-AzsSupportWorkingDirectory.md) | `Get-AzsSupportWorkingDirectory` | Gets the current support tools working directory. |
| [Install-AzsSupportModule](./functions/Install-AzsSupportModule.md) | `Install-AzsSupportModule -ComputerName <String[]> [[-Credential] <PSCredential>] [-Force]` | Installs the support module on remote computers. |
| [Invoke-AzsSupportApplianceEndpoint](./functions/Invoke-AzsSupportApplianceEndpoint.md) | `Invoke-AzsSupportApplianceEndpoint [[-Url] <Uri>] [[-Certificate] <X509Certificate2>] -Endpoint <String> [-ConvertToJson]` | Calls an Azure Local support appliance endpoint. |
| [Invoke-AzsSupportCommand](./functions/Invoke-AzsSupportCommand.md) | `Invoke-AzsSupportCommand -ComputerName <String[]> [-Credential <PSCredential>] -ScriptBlock <ScriptBlock> [-HideComputerName] [-ArgumentList <Object>] [-AsJob] [-Wait] [-PassThru] [-Activity <String>] [-ExecutionTimeout <Int32>]` | Runs a script block on local or remote computers. |
| [Invoke-AzsSupportDiagnosticCheck](./functions/Invoke-AzsSupportDiagnosticCheck.md) | `Invoke-AzsSupportDiagnosticCheck -Component <Component>` | Runs a diagnostic check. Deprecated. |
| [Invoke-AzsSupportInsight](./functions/Invoke-AzsSupportInsight.md) | `Invoke-AzsSupportInsight [-OutputDirectory <String>] [-ComputerName <String[]>] [-Credential <PSCredential>] [-SkipSummary] [-SkipHtmlReport]`<br>`Invoke-AzsSupportInsight -Component <String[]> [-OutputDirectory <String>] [-ComputerName <String[]>] [-Credential <PSCredential>] [-SkipSummary] [-SkipHtmlReport]` | Runs all insight components or selected components. |
| [Invoke-AzsSupportInsightRemediation](./functions/Invoke-AzsSupportInsightRemediation.md) | `Invoke-AzsSupportInsightRemediation -ScriptName <String> [[-Parameters] <Hashtable>]` | Runs a signed insight remediation. |
| [Invoke-AzsSupportScript](./functions/Invoke-AzsSupportScript.md) | `Invoke-AzsSupportScript -ScriptName <String> [[-Parameters] <Hashtable>]` | Runs a signed support script. |
| [New-AzsSupportDataBundle](./functions/New-AzsSupportDataBundle.md) | `New-AzsSupportDataBundle [-Component <Component>]`<br>`New-AzsSupportDataBundle [-ClusterCommands <Array>] [-NodeCommands <Array>] [-NodeEvents <Array>] [-NodeRegistry <Array>] [-NodeFolders <Array>] [-ComputerName <Array>]` | Creates an automatic or custom support data bundle. |
| [New-AzsSupportStorageSupportedComponents](./functions/New-AzsSupportStorageSupportedComponents.md) | `New-AzsSupportStorageSupportedComponents [[-CimSession] <CimSession>]` | Builds a proposed supported components configuration. |
| [Restart-AzsSupportClusterHealthService](./functions/Restart-AzsSupportClusterHealthService.md) | `Restart-AzsSupportClusterHealthService [[-Cluster] <String>]` | Restarts the cluster health service. |
| [Set-AzsSupportNetworkATCIntentApplyWithTracing](./functions/Set-AzsSupportNetworkATCIntentApplyWithTracing.md) | `Set-AzsSupportNetworkATCIntentApplyWithTracing -IntentName <String> [[-OutputDirectory] <String>]` | Applies a Network ATC intent with tracing enabled. |
| [Set-AzsSupportPhysicalDiskIndicator](./functions/Set-AzsSupportPhysicalDiskIndicator.md) | `Set-AzsSupportPhysicalDiskIndicator -Enable -SerialNumber <String> -CimSession <CimSession>`<br>`Set-AzsSupportPhysicalDiskIndicator -Disable -SerialNumber <String> -CimSession <CimSession>` | Enables or disables a physical disk indicator light. |
| [Show-AzsSupportEceData](./functions/Show-AzsSupportEceData.md) | `Show-AzsSupportEceData` | Displays ECE data for the current cluster. |
| [Show-AzsSupportEceDeploymentDetail](./functions/Show-AzsSupportEceDeploymentDetail.md) | `Show-AzsSupportEceDeploymentDetail` | Displays ECE deployment details for the current cluster. |
| [Show-AzsSupportEceUpdateDetail](./functions/Show-AzsSupportEceUpdateDetail.md) | `Show-AzsSupportEceUpdateDetail [[-MaxUpdateRuns] <Object>]` | Displays ECE update action plan details. |
| [Show-AzsSupportEnvironmentValidatorSummary](./functions/Show-AzsSupportEnvironmentValidatorSummary.md) | `Show-AzsSupportEnvironmentValidatorSummary [-Concise]` | Displays environment validator results from the event log. |
| [Show-AzsSupportSDNStateSummary](./functions/Show-AzsSupportSDNStateSummary.md) | `Show-AzsSupportSDNStateSummary` | Displays the current SDN state. |
| [Start-AzsSupportStorageDiagnostic](./functions/Start-AzsSupportStorageDiagnostic.md) | `Start-AzsSupportStorageDiagnostic [[-ClusterName] <String>] [[-Credential] <PSCredential>] [[-PhysicalExtentCheck] <String>] [[-Include] <String[]>]` | Runs storage diagnostic tests and creates a report. |
| [Test-AzsSupportSolutionInstalled](./functions/Test-AzsSupportSolutionInstalled.md) | `Test-AzsSupportSolutionInstalled [-Terminating]` | Checks for the Azure Local solution on the current system. |
| [Update-AzsSupportStorageHealthCache](./functions/Update-AzsSupportStorageHealthCache.md) | `Update-AzsSupportStorageHealthCache [[-Cluster] <String>]` | Refreshes storage cache and health cluster resources. |

## Insight commands

Run every insight component:

```powershell
Invoke-AzsSupportInsight
```

Run one component with the command shown in the table. Pass several component names to `-Component`
as a PowerShell array.

| Component | Command | Scope |
| --- | --- | --- |
| [ControlPlaneOperations](./insights/ControlPlaneOperations.md) | `Invoke-AzsSupportInsight -Component ControlPlaneOperations` | Azure Local control plane services. |
| [HostCompute](./insights/HostCompute.md) | `Invoke-AzsSupportInsight -Component HostCompute` | Cluster nodes and host compute services. |
| [HostNetwork](./insights/HostNetwork.md) | `Invoke-AzsSupportInsight -Component HostNetwork` | Host networking and Network ATC. |
| [HostStorage](./insights/HostStorage.md) | `Invoke-AzsSupportInsight -Component HostStorage` | Host storage and Cluster Shared Volumes. |
| [KnownIssues](./insights/KnownIssues.md) | `Invoke-AzsSupportInsight -Component KnownIssues` | Recognized Azure Local issues. |
| [LifecycleOrchestration](./insights/LifecycleOrchestration.md) | `Invoke-AzsSupportInsight -Component LifecycleOrchestration` | Lifecycle services for ECE and LCM update operations. |
| [OperatingSystem](./insights/OperatingSystem.md) | `Invoke-AzsSupportInsight -Component OperatingSystem` | Operating system state and failure events. |
| [VirtualMachines](./insights/VirtualMachines.md) | `Invoke-AzsSupportInsight -Component VirtualMachines` | Virtual machines and VM network adapters. |

## Remediation commands

Run a remediation only when an insight result names it. Review its linked page before execution.
Remediations change system state and run on the local node. The dispatcher accepts `-Force` and
`-SkipEnvironmentCheck` inside the `-Parameters` hashtable when the selected remediation supports them.

| Remediation | Command | Action |
| --- | --- | --- |
| [ClearTrustedHostsWildcard](./remediations/ClearTrustedHostsWildcard.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "ClearTrustedHostsWildcard"` | Removes the wildcard entry from WinRM TrustedHosts. |
| [DisableWindowsUpdate](./remediations/DisableWindowsUpdate.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "DisableWindowsUpdate"` | Disables automatic Windows Update through policy. |
| [IncreaseWmiQuotaConfig](./remediations/IncreaseWmiQuotaConfig.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "IncreaseWmiQuotaConfig"` | Increases WMI Provider Host quotas. |
| [RemovedFailedUpdateEceActionPlans](./remediations/RemovedFailedUpdateEceActionPlans.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "RemovedFailedUpdateEceActionPlans"` | Removes failed ECE update action plans. |
| [RemoveFailoverClusterApiDll](./remediations/RemoveFailoverClusterApiDll.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "RemoveFailoverClusterApiDll"` | Removes the stray Failover Cluster API DLL. |
| [RemoveHealthCheckFilesForUpdates](./remediations/RemoveHealthCheckFilesForUpdates.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "RemoveHealthCheckFilesForUpdates"` | Removes update health check files. |
| [RemoveIncompatibleAzCliExtensions](./remediations/RemoveIncompatibleAzCliExtensions.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "RemoveIncompatibleAzCliExtensions"` | Removes unmanaged Azure CLI extensions. |
| [ResetCredSSPConfiguration](./remediations/ResetCredSSPConfiguration.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "ResetCredSSPConfiguration"` | Restores the required CredSSP configuration. |
| [UnlockAzureLocalAccounts](./remediations/UnlockAzureLocalAccounts.md) | `Invoke-AzsSupportInsightRemediation -ScriptName "UnlockAzureLocalAccounts" -Parameters @{ Account = "<account>" }` | Restores the required state for an Azure Local account. |

## Support script commands

Support scripts perform high-impact operations. Microsoft CSS or Engineering personnel must direct
their use. Confirm every precondition on the linked script page. Use `WhatIf = $true` in the parameter
hashtable when the script supports preview mode.

| Script | Command | Execution location |
| --- | --- | --- |
| [ClearStorageHealthData](./scripts/ClearStorageHealthData.md) | `Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{ MaintenanceModeIntent = $true; WhatIf = $true }`<br>`Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{ PhysicalDiskIntent = $true; PhysicalDiskPolicy = $true; UniqueId = "<unique-id>"; WhatIf = $true }`<br>`Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{ PhysicalDiskIntent = $true; PhysicalDiskPolicy = $true; SerialNumber = "<serial-number>"; WhatIf = $true }`<br>`Invoke-AzsSupportScript -ScriptName "ClearStorageHealthData" -Parameters @{ Name = "<record-name>"; Key = "<entity-key>"; ProviderGuid = "<provider-guid>"; WhatIf = $true }` | A cluster node with `healthapi.dll`. |
| [Remove-SetSecuredCoreGuestConfig](./scripts/Remove-SetSecuredCoreGuestConfig.md) | `Invoke-AzsSupportScript -ScriptName "Remove-SetSecuredCoreGuestConfig" -Parameters @{ ClusterArmId = "<resource-id>"; WhatIf = $true }`<br>`Invoke-AzsSupportScript -ScriptName "Remove-SetSecuredCoreGuestConfig" -Parameters @{ ClusterArmId = "<resource-id>" }` | A computer with an authenticated Az PowerShell context. |

## Related references

Folder indexes provide focused references for [functions](./functions/README.md), [insights](./insights/README.md),
[remediations](./remediations/README.md) and [support scripts](./scripts/README.md).

## Release notes

This article describes the contents of the latest [Microsoft.AzLocal.CSSTools](https://www.powershellgallery.com/packages/Microsoft.AzLocal.CSSTools) module changes. This update includes improvements and fixes for the latest release of Microsoft.AzLocal.CSSTools that is supported to run on Azure Local deployments. 

### Download the update

You can download the latest version of Microsoft.AzLocal.CSSTools by running `Update-Module -Name Microsoft.AzLocal.CSSTools` on each of the Azure Local cluster nodes. After you have downloaded the module, ensure you remove the current version from the runspace by using `Remove-Module` and import the latest version using `Import-Module`.

```powershell
# update the current module directly from PowerShell Gallery
Update-Module -Name Microsoft.AzLocal.CSSTools

# remove the current version from the runspace in case it was already imported prior to update
Remove-Module -Name Microsoft.AzLocal.CSSTools

# load the latest version into the runspace
Import-Module -Name Microsoft.AzLocal.CSSTools
```

### What's new

#### Support Insights

The following insight rules are new and run within the existing [ControlPlaneOperations](insights/ControlPlaneOperations.md), [HostNetwork](insights/HostNetwork.md), [HostStorage](insights/HostStorage.md), [KnownIssues](insights/KnownIssues.md), [LifecycleOrchestration](insights/LifecycleOrchestration.md), [OperatingSystem](insights/OperatingSystem.md), and [VirtualMachines](insights/VirtualMachines.md) components. For the full component reference, see [insights](insights/README.md).

| New Rule | Synopsis |
| --- | --- |
| AzStackHci.DiagnosticSettings.AzureConnectionStatus | Reports this Azure Local node's Azure connection state: its cloud registration status (Get-AzureStackHCI), its Arc for Servers agent status (azcmagent), and whether the Arc machine has an Azure Private Link Scope. |
| AzStackHci.DiagnosticSettings.CrlRevocationOffline | Flags certificate revocation (CRL / OCSP) checks that could not be completed because the CA's revocation responder is unreachable from an Azure Local node. |
| AzStackHci.DiagnosticSettings.NetworkConnectivity | Evaluates the results of network connectivity tests to the required Azure Local endpoints. |
| AzStackHci.DiagnosticSettings.OsConfig.ConsistencyCheck | Maps a single cross-node OS configuration "Consistency Check" (as produced by Get-AzStackHciOsConfigSettings) onto an Insights rule result. |
| AzStackHci.DiagnosticSettings.OsConfig.DriverVersionsInventory | Surfaces the per-node device "Driver Versions" inventory (as produced by Get-AzStackHciOsConfigSettings) as a single INFO Insights rule. |
| AzStackHci.DiagnosticSettings.OsConfig.HealthCheck | Maps a single OS configuration "health section" (as produced by Get-AzStackHciOsConfigSettings) onto an Insights rule result. |
| AzStackHci.DiagnosticSettings.OsConfig.InstalledProgramsInventory | Surfaces the per-node "Installed Programs" software inventory (as produced by Get-AzStackHciOsConfigSettings) as a single INFO Insights rule. |
| AzStackHci.DiagnosticSettings.PrivateLinkConfiguration | Evaluates Azure Local Private Link configuration health from the connectivity test results. |
| AzStackHci.DiagnosticSettings.SslInspection | Flags TLS / SSL inspection (HTTPS interception) in front of Azure Local endpoints. |
| AzureLocal.KI.SDN.FailoverClusterApi.Unsigned | Detects a stray Microsoft.NetworkController.FailoverClusterApi.dll left in the HCIOrchestrator profile. |
| AzureLocal.LCM.RegistrationStatus | Detects an invalid or inactive Azure Local subscription/registration status that blocks solution update pre-checks. |
| AzureLocal.Update.AzCliIncompatibleExtensions | Detects unmanaged (incompatible) Az CLI extensions that block solution updates during UpdatePreRequisites. |
| AzureLocal.Update.CAU.MsuHostUpdateBreadcrumb | Checks for a leftover MsuHostUpdate CAU breadcrumb file that prevents update retries on 2604 builds. |
| AzureLocal.Update.OSConfigSecuredCoreEnforcement | Detects the OSConfig SetSecuredCore guest configuration SET document that causes SecuredCore enforcement failures during updates. |
| MocArb.ArbAzCliExtensionVersionFormat | Checks for Az CLI extensions with non-numeric version strings that block the Environment Validator. |
| MocArb.MocHostAgentLogStale | Detects a hung MOC Host Agent (mochostagent) service by checking for stale logs. |
| Windows.Hyperv.VM.MountedISO | Checks whether any virtual machines have an ISO image mounted to a virtual DVD drive. |
| Windows.Network.Dns.ResolveClusterNodes | Validates that all cluster node DNS names can be resolved from a specified DNS server. |
| Windows.Network.VMSwitch.MacSpoofingOnSRIOV | Detects VM network adapters with MAC address spoofing enabled that are connected to an SR-IOV (IOV) enabled VM switch. |
| Windows.RemoteManagement.TrustedHosts.Wildcard | Checks whether the WinRM client TrustedHosts list contains a wildcard ('*') entry. |
| Windows.Security.CredSSP.Configuration | Checks if CredSSP authentication is correctly configured on the local machine. |
| Windows.Storage.VolumeRecommendations.MaxVolumesPerCluster | Checks that the number of volumes in the cluster does not exceed the recommended maximum. |
| Windows.Storage.VolumeRecommendations.MinVolumesPerNode | Checks that the cluster has at least one volume per node. |
| Windows.Storage.VolumeRecommendations.ReserveCapacity | Checks that the storage pool has enough reserve capacity for in-place repairs. |
| Windows.Storage.VolumeRecommendations.VolumeSize | Checks that a volume does not exceed the recommended maximum size. |

#### Insight Remediation

As issues are detected within the Insight framework, we can provide remediation guidance to execute `Invoke-AzsSupportInsightRemediation` commands that run validated, signed remediation scripts. We recommend only running these remediation scripts when insights provide guidance to run them. For the full list of remediations, see [remediations](remediations/README.md).

| New Remediation | Synopsis |
| --- | --- |
| [ClearTrustedHostsWildcard](remediations/ClearTrustedHostsWildcard.md) | Removes the wildcard ('*') entry from the WinRM client TrustedHosts list. |
| [RemoveFailoverClusterApiDll](remediations/RemoveFailoverClusterApiDll.md) | Removes the stray Microsoft.NetworkController.FailoverClusterApi.dll from the HCIOrchestrator profile. |
| [RemoveIncompatibleAzCliExtensions](remediations/RemoveIncompatibleAzCliExtensions.md) | Removes unmanaged (incompatible) Az CLI extensions from the current node so a solution update can proceed. |
| [ResetCredSSPConfiguration](remediations/ResetCredSSPConfiguration.md) | Resets CredSSP authentication configuration to the correct state required for Azure Local operations. |

#### Core Framework

In addition to code and reliability fixes, the following public functions are new in this release.

- [Invoke-AzsSupportScript](functions/Invoke-AzsSupportScript.md): Invokes a signed AzsSupport script shipped with the Support Tools module. For the scripts it can run, see [scripts](scripts/README.md).
- [Test-AzsSupportSolutionInstalled](functions/Test-AzsSupportSolutionInstalled.md): Determines whether the Azure Local solution is present on the current system, so callers can adapt to plain HCI OS environments.

`Invoke-AzsSupportDiagnosticCheck` has been deprecated. A comprehensive list of all functions can be found under [functions](functions/README.md).

#### Detailed Changes

##### Insight Framework & Remediation

- Insight remediation telemetry introduced via a new `InsightRemediationEvent`, capturing remediation outcomes.
- Data emitted through the events channel improved for richer diagnostics.
- Support added for shipping signed scripts alongside the Support Tools module.
- CI Pester testing added for the Insight module, including Storage and Windows.Cluster test coverage.
- Fixed handling of a string-array `Component` parameter for remote `Invoke-AzsSupportInsight`.

##### New Insights Added

- Integrated the `AzStackHci.DiagnosticSettings` module (0.6.8) as an Insights data source. A new `AzStackHci.DiagnosticSettings.NetworkConnectivity` analyzer in [ControlPlaneOperations](insights/ControlPlaneOperations.md) surfaces required-endpoint connectivity, TLS/SSL inspection, Private Link configuration, certificate-revocation (CRL/OCSP) reachability, and per-node Azure connection state. A new `AzStackHci.DiagnosticSettings.OsConfig.ConfigurationConsistency` analyzer in [OperatingSystem](insights/OperatingSystem.md) surfaces cross-node OS configuration consistency checks and health sections, plus per-node Installed Programs and Driver Versions inventory.
- `AzureLocal.LCM.RegistrationStatus` update subscription and registration precheck.
- Cluster Shared Volume block-redirect scoping corrected.
- MAC spoofing detection on SR-IOV VM switch ports.
- Hyper-V VM mounted-ISO detection.
- Windows.Storage analyzers condensed for clarity and performance.
- OSConfig SecuredCore enforcement failure detection.
- Storage volume recommendations analyzer with four new rules.
- Hung `mochostagent` detection rule.
- Incompatible Az CLI extension and non-numeric Az CLI extension version rules.
- WinRM TrustedHosts wildcard detection.
- Windows.RemoteManagement.OpState analyzer covering CredSSP and WinRM.
- DNS resolution check for cluster nodes.
- Cluster-Aware Updating (CAU) failure insight.
- SDN Network Controller Failover Cluster API unsigned-assembly detection (`AzureLocal.KI.SDN.FailoverClusterApi.Unsigned`) for the KnownIssues component on 2601 and later builds, with a paired [RemoveFailoverClusterApiDll](remediations/RemoveFailoverClusterApiDll.md) remediation to remove the stray file.
- Windows.System.OS.Support 23H2 test elevated to a Failure result.

##### Networking

- Fixed an ARB VM VLAN ID validator false positive on SDN / ARC-SDN clusters.
- Removed the `-DnsOnly` parameter from name resolution.
- Updated the set of firewall endpoints probed.

##### AKS Arc / MOC / ARB

- Fixed `ArbApplianceStatus` validator false positives and hardened the check.
- Added the MOC version to the `ErrorCode` for `MocNotOnLatestPatch`.
- Added defensive coding when locating ARB control-plane VMs.
- Updated the Support.AksArc module to 1.3.77.
- Fixed AKS Arc analyzer per-test isolation.

##### Non-Solution (HCI OS) Support

- The module now detects whether the Azure Local solution is installed during import and operates in a reduced `HCI_OS` mode when it is not, recording the platform state (`HCI_OS` or `HCI_OS_AZLOCAL_SOLUTION`) on the module global.
- Added the [Test-AzsSupportSolutionInstalled](functions/Test-AzsSupportSolutionInstalled.md) function, with an optional `-Terminating` switch, so callers can branch on solution presence or fail fast on plain HCI OS.
- Analyzers now declare a `RequireAzLocalSolution` requirement so solution-only checks are skipped, rather than reported as failures, on plain HCI OS systems.
- Gated the `azcmagent` region probe on agent availability instead of solution-installed state.
- Ensured the OS solution is present before running update-validation checks that depend on it.

##### Infrastructure & Modules

- Added a dependency on the `AzStackHci.DiagnosticSettings` module (0.6.8), consuming its structured `-PassThru` connectivity results, OsConfig health/consistency reports, and inventory data, with a non-fatal schema-version guard and race-free per-node detailed report collection on remote nodes.
- Improved loading of the AzStack Disconnected module.
- Introduced a centralized framework for importing and version-checking module dependencies, including a NetworkATC module requirement.
- Added versioning tags and updated the package source.
- Fixed relative path handling in the build pipelines.
- Removed `Add-Type` usage to prevent file locking.
- Added a threat modeling skill and an initial baseline security check.
- Enabled detection of newer support modules.

##### Bug Fixes & Misc

- Deprecated `Invoke-AzsSupportDiagnosticCheck`.
- Fixed missing-disk detection on Hyper-V hosts by including VMBUS SCSI adapters.
- Fixed a null-valued expression error in `Get-AzsSupportPhysicalDisk` and related Missing Disks and DiskHealth analyzer failures.
- Fixed `ManagementEndpoint` not being populated from `context.json`.
- Fixed function examples and parameter definitions, and corrected a Pester test that was failing build validation.

---

### Contact Us

If you are encountering an issue, or need assistance, refer to [questions-or-feedback](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools#questions-or-feedback).
