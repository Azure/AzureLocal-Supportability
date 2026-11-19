# Functions

This folder documents the public functions exported by the `Microsoft.AzLocal.CSSTools` module. Each
page documents the function's parameters, usage, and examples.

## Using the functions

Install and import the module, then call any function directly:

```powershell
Install-Module -Name Microsoft.AzLocal.CSSTools -Force
Import-Module -Name Microsoft.AzLocal.CSSTools -Force
```

Use `Get-Help <FunctionName> -Full` for the complete parameter reference and examples of any command.

## Available functions

| Function | Synopsis |
|----------|----------|
| [Clear-AzsSupportDirectory](./Clear-AzsSupportDirectory.md) | Clears the contents of the directory. |
| [Clear-AzsSupportParentWorkingDirectory](./Clear-AzsSupportParentWorkingDirectory.md) | Clears stale Azs.Support working directory contents across all infrastructure nodes. |
| [Compress-AzsSupportArchive](./Compress-AzsSupportArchive.md) | Creates a zip archive that contains the files and directories from the specified directory. |
| [Confirm-AzsSupportOSVersion](./Confirm-AzsSupportOSVersion.md) | Validates the OS version against a specified version or minimum version. |
| [Convert-AzsSupportStorageAttributes](./Convert-AzsSupportStorageAttributes.md) | Translates the array passed value provided for SBLAttribute, SBLDiskCacheState, SBLCacheUsageCurrent and SBLCacheUsageDesired. |
| [Copy-AzsSupportFileFromComputer](./Copy-AzsSupportFileFromComputer.md) | Copies an item from one location to another using FromSession. |
| [Copy-AzsSupportFileToComputer](./Copy-AzsSupportFileToComputer.md) | Copies an item from local path to a path at remote server. |
| [Disable-AzsSupportInsightLog](./Disable-AzsSupportInsightLog.md) | Disables trace logging to file for AzStack Insights. |
| [Disable-AzsSupportTraceLog](./Disable-AzsSupportTraceLog.md) | Disables trace logging to file for AzStack Support. |
| [Enable-AzsSupportInsightLog](./Enable-AzsSupportInsightLog.md) | Enables trace logging to file for AzStack Insights. |
| [Enable-AzsSupportTraceLog](./Enable-AzsSupportTraceLog.md) | Enables trace logging to file for AzStack Support. |
| [Get-AzsStorageDiskPnpId](./Get-AzsStorageDiskPnpId.md) | Gets PNP information for disks that should be in Storage Spaces. |
| [Get-AzsSupportBlocklistedDisk](./Get-AzsSupportBlocklistedDisk.md) | Gets all blocklisted physical disks from the cluster filter service. |
| [Get-AzsSupportClusterName](./Get-AzsSupportClusterName.md) | Gets the failover cluster name. |
| [Get-AzsSupportClusterUsage](./Get-AzsSupportClusterUsage.md) | Calculate storage usage and capacity for the cluster. |
| [Get-AzsSupportDataIntegrityScanState](./Get-AzsSupportDataIntegrityScanState.md) | Gets the "Data Integrity Check And Scan" scheduled task's state on all reachable nodes from the failover cluster. |
| [Get-AzsSupportDiskSpace](./Get-AzsSupportDiskSpace.md) | Get available disk space on target computers. |
| [Get-AzsSupportDiskSpaceReport](./Get-AzsSupportDiskSpaceReport.md) | Get available disk space report for all infra Hosts. |
| [Get-AzsSupportECECloudDefinitionXml](./Get-AzsSupportECECloudDefinitionXml.md) | Retrieves the cloud definition from ECE and returns it as an XML object. |
| [Get-AzsSupportEceDeploymentDetails](./Get-AzsSupportEceDeploymentDetails.md) | Retrieves ECE deployment details for the current Azure Local cluster. |
| [Get-AzsSupportEceManagementClusterName](./Get-AzsSupportEceManagementClusterName.md) | Retrieves the name of the management cluster recorded in the ECE CloudDefinition. |
| [Get-AzsSupportHostNetworkDiagnosticData](./Get-AzsSupportHostNetworkDiagnosticData.md) | Collects comprehensive network diagnostic data from the local host. |
| [Get-AzsSupportInfrastructureHost](./Get-AzsSupportInfrastructureHost.md) | Gets physical host node information from FailoverClustering. |
| [Get-AzsSupportLcmDeploymentUserName](./Get-AzsSupportLcmDeploymentUserName.md) | Retrieves the username of the Local Configuration Manager (LCM) deployment account for the Azure Local cluster. |
| [Get-AzsSupportPhysicalDisk](./Get-AzsSupportPhysicalDisk.md) | Gets physical disks connected to the specified ComputerName. |
| [Get-AzsSupportPhysicalDiskIndicator](./Get-AzsSupportPhysicalDiskIndicator.md) | To get the physical disks with light indicator on. |
| [Get-AzsSupportProcess](./Get-AzsSupportProcess.md) | Gets processes on a remote computer. |
| [Get-AzsSupportService](./Get-AzsSupportService.md) | Gets services on a specified ComputerName, and sorts them by State, Name. |
| [Get-AzsSupportStampInformation](./Get-AzsSupportStampInformation.md) | Gets common stamp information. |
| [Get-AzsSupportStorageAutoPauseEvents](./Get-AzsSupportStorageAutoPauseEvents.md) | Checks for volume autopause events. |
| [Get-AzsSupportStorageCacheDetails](./Get-AzsSupportStorageCacheDetails.md) | Get detailed information on Cache drives for usage and errors. |
| [Get-AzsSupportStorageDirtyCount](./Get-AzsSupportStorageDirtyCount.md) | Check Dirty Count for Cluster Shared Volumes and if threshold is exceeded. |
| [Get-AzsSupportStorageDiskInfoGraphicDisplay](./Get-AzsSupportStorageDiskInfoGraphicDisplay.md) | Outputs threshold based graphic for easy identification of disk space issues on CSVs. |
| [Get-AzsSupportStorageDiskLatency](./Get-AzsSupportStorageDiskLatency.md) | Checks for disk latency over specified thresholds using version-safe property access from live cluster event logs. |
| [Get-AzsSupportStorageDiskSBLState](./Get-AzsSupportStorageDiskSBLState.md) | Gets SBL state for disks on given computer(s). |
| [Get-AzsSupportStorageFirmwareDrift](./Get-AzsSupportStorageFirmwareDrift.md) | Checks for Firmware Drift in Storage Spaces. |
| [Get-AzsSupportStorageHealthActionDetail](./Get-AzsSupportStorageHealthActionDetail.md) | Gets storage health actions with enhanced object information and filtering options. |
| [Get-AzsSupportStorageHealthFault](./Get-AzsSupportStorageHealthFault.md) | Runs Get-HealthFault against the cluster. |
| [Get-AzsSupportStorageJob](./Get-AzsSupportStorageJob.md) | Gets all active storage jobs from the storage pool and virtual disks. |
| [Get-AzsSupportStorageMissingDisks](./Get-AzsSupportStorageMissingDisks.md) | Checks for Missing Disks in Storage Spaces. |
| [Get-AzsSupportStorageNode](./Get-AzsSupportStorageNode.md) | Gets specified storage node or all nodes if none are provided. |
| [Get-AzsSupportStoragePartitionInfo](./Get-AzsSupportStoragePartitionInfo.md) | Outputs the partition information for disks in a cluster node. |
| [Get-AzsSupportStoragePhysicalExtent](./Get-AzsSupportStoragePhysicalExtent.md) | Gets physical allocations for a virtual disk that is unhealthy. |
| [Get-AzsSupportStoragePool](./Get-AzsSupportStoragePool.md) | Gets specified Storage Pool or all pools if none are provided. |
| [Get-AzsSupportStorageSNV](./Get-AzsSupportStorageSNV.md) | Checks the Storage Node views for non healthy disks. |
| [Get-AzsSupportStorageSubsystem](./Get-AzsSupportStorageSubsystem.md) | Gets specified Storage Subsystem or all subsystems if none are provided. |
| [Get-AzsSupportStorageSupportedComponents](./Get-AzsSupportStorageSupportedComponents.md) | Checks for supported firmware and hardware in Storage Spaces. |
| [Get-AzsSupportStorPortDriverEvents](./Get-AzsSupportStorPortDriverEvents.md) | Checks for StorPort Driver Events. |
| [Get-AzsSupportStorPortOpEvents](./Get-AzsSupportStorPortOpEvents.md) | Checks for Storport Operational Events. |
| [Get-AzsSupportVirtualDisk](./Get-AzsSupportVirtualDisk.md) | Gets all virtual disks and their health states. |
| [Get-AzsSupportVolumeUtilization](./Get-AzsSupportVolumeUtilization.md) | Reports the utilization for all Object Stores. |
| [Get-AzsSupportWinEvent](./Get-AzsSupportWinEvent.md) | Get eventlog entries from a cluster or its node in filtered format. |
| [Get-AzsSupportWorkingDirectory](./Get-AzsSupportWorkingDirectory.md) | Gets the current working directory for AzsSupport tools. |
| [Install-AzsSupportModule](./Install-AzsSupportModule.md) | Install the AzsSupport Module to remote computers if not installed or version mismatch. |
| [Invoke-AzsSupportApplianceEndpoint](./Invoke-AzsSupportApplianceEndpoint.md) | Invokes a REST API call against a specified Azure Stack HCI support appliance endpoint using the provided URL and client certificate. |
| [Invoke-AzsSupportCommand](./Invoke-AzsSupportCommand.md) | Runs commands on local and remote computers. |
| [Invoke-AzsSupportDiagnosticCheck](./Invoke-AzsSupportDiagnosticCheck.md) | Runs a diagnostic check on the health and functionality of the specified Azure Stack HCI product. **(Deprecated)** |
| [Invoke-AzsSupportInsight](./Invoke-AzsSupportInsight.md) | Executes the support insight for a specific component or all components, locally or remotely. |
| [Invoke-AzsSupportInsightRemediation](./Invoke-AzsSupportInsightRemediation.md) | Executes a specified remediation script for Azure Stack Insights. |
| [Invoke-AzsSupportScript](./Invoke-AzsSupportScript.md) | Invokes a signed AzsSupport script shipped with the module. See the [support scripts reference](../scripts/README.md). |
| [New-AzsSupportDataBundle](./New-AzsSupportDataBundle.md) | Creates a support data bundle for Azure Stack HCI. |
| [New-AzsSupportStorageSupportedComponents](./New-AzsSupportStorageSupportedComponents.md) | Checks for supported firmware and hardware in Storage Spaces and suggests new config to support. |
| [Restart-AzsSupportClusterHealthService](./Restart-AzsSupportClusterHealthService.md) | Restarts the cluster health service. |
| [Set-AzsSupportNetworkATCIntentApplyWithTracing](./Set-AzsSupportNetworkATCIntentApplyWithTracing.md) | Applies a Network ATC intent with tracing enabled to capture diagnostic information. |
| [Set-AzsSupportPhysicalDiskIndicator](./Set-AzsSupportPhysicalDiskIndicator.md) | To Enable or Disable physical disk indicator for specific disk based on its serial number. |
| [Show-AzsSupportEceData](./Show-AzsSupportEceData.md) | Show ECE data for the current Azure Stack HCI cluster. |
| [Show-AzsSupportEceDeploymentDetail](./Show-AzsSupportEceDeploymentDetail.md) | Show ECE deployment details for the current Azure Stack HCI cluster. |
| [Show-AzsSupportEceUpdateDetail](./Show-AzsSupportEceUpdateDetail.md) | Show ECE update action plan details for the current Azure Stack HCI cluster. |
| [Show-AzsSupportEnvironmentValidatorSummary](./Show-AzsSupportEnvironmentValidatorSummary.md) | Retrieves and displays a comprehensive summary of environment validator results from the event log. |
| [Show-AzsSupportSDNStateSummary](./Show-AzsSupportSDNStateSummary.md) | Checks the current status of SDN, including if FCNC is deployed and if SDN services are online. |
| [Start-AzsSupportStorageDiagnostic](./Start-AzsSupportStorageDiagnostic.md) | Runs a series of storage specific diagnostic tests and generates a storage report. |
| [Test-AzsSupportSolutionInstalled](./Test-AzsSupportSolutionInstalled.md) | Determines whether the Azure Local solution is present on the current system. |
| [Update-AzsSupportStorageHealthCache](./Update-AzsSupportStorageHealthCache.md) | Refreshes the storage cache and health cluster resources. |
