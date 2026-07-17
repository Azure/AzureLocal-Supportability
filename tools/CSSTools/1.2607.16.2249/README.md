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

The [release notes](./ReleaseNotes.md) record changes for this version. Folder indexes provide focused
references for [functions](./functions/README.md), [insights](./insights/README.md),
[remediations](./remediations/README.md) and [support scripts](./scripts/README.md).
