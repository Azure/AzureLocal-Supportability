# Overview
The Storage Diagnostic cmdlets included with the Azure Local Support Diagnostic Tool. These cmdlets are designed to help operators and CSS to help troubleshoot storage related issues on Azure Local deployments.

For more details regarding how to install this tool and examine other cmdlets available, refer to [Support Tools](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools) for more information.

# Start-AzsSupportStorageDiagnostic
This cmdlet performs an automated analysis of the Storage Spaces Direct feature in Azure Local. It provides results and recommendations for next steps, along with in-depth troubleshooting tools to help identify the root cause of any issues detected.

## Diagnostic Health Checks

The following checks can be run either all at once by default or initiated individually using the `-Include` switch in `Start-AzsSupportStorageDiagnostic`. Each test is detailed below with the corresponding argument for `-Include`.

| Check                                      | Result on detection | Argument                                |
|--------------------------------------------|---------------------|-----------------------------------------|
| Missing Disks from Storage Spaces          | INFO                | [MissingDisks](#missingdisks)           |
| Storage Pool Health Check                  | FAIL                | [StorageHealth](#storagehealth)         |
| Cluster Nodes Health Process Running       | FAIL                | [StorageHealth](#storagehealth)         |
| Storage Job Check                          | WARN                | [StorageHealth](#storagehealth)         |
| Cluster Node Check                         | FAIL                | [StorageHealth](#storagehealth)         |
| Cluster Shared Volumes Check               | FAIL                | [StorageHealth](#storagehealth)         |
| Storage Enclosure Check                    | FAIL                | [StorageHealth](#storagehealth)         |
| Health Service Fault Check                 | WARN                | [StorageHealth](#storagehealth)         |
| Storage Health Action Check                | FAIL                | [StorageHealth](#storagehealth)         |
| Disks Not in Pool Check                    | FAIL                | [StorageHealth](#storagehealth)         |
| Virtual Disk Check                         | FAIL                | [VirtualDisks](#virtualdisks)           |
| Dirty Count                                | FAIL                | [DirtyCount](#dirtycount)               |
| Support Components Change                  | INFO                | [StorageComponents](#storagecomponents) |
| Support Components Missing                 | FAIL                | [StorageComponents](#storagecomponents) |
| Storage Node View Differs                  | FAIL                | [SNV](#snv-storage-node-view)           |
| Firmware Drift                             | INFO                | [FirmwareDrift](#firmwaredrift)         |
| Cluster Nodes SMPHost Running              | FAIL                | [SMPHost](#smphost)                     |
| SMPHost Issue Detected                     | FAIL                | [SMPHostIssue](#smphostissue)           |
| Storage Spaces Partitions Check            | FAIL                | [DiskHealth](#diskhealth)               |
| Disk Health Check                          | FAIL                | [DiskHealth](#diskhealth)               |
| Transient Disk Check                       | FAIL                | [DiskHealth](#diskhealth)               |

Example:
```powershell
# will default and execute all health tests
Start-AzsSupportStorageDiagnostic

# will just execute the health tests you define
Start-AzsSupportStorageDiagnostic -Include 'DiskHealth','StorageHealth','VirtualDisks'
```

### MissingDisks

| Test | Description |
|------|-------------|
|Missing Disks from Storage Spaces | Compares physical disks in non-primordial Storage Pool count against disks detected via Plug and Play (PnP) which are eligible to add to pool.

### StorageHealth

| Test | Description |
|------|-------------|
| Storage Pool Health Check | Checks for any Storage Pool that is not in a healthy state, which is determined by anything other than Health Status of OK.
| Cluster Nodes Health Process Running | Ensures that all Nodes in Cluster are running the Health Service process (HealthPIH.exe).
| Storage Job Check | Looks for any Storage Jobs that are running on the system, in a healthy system the expectation is that there will be no jobs running on the system.
| Cluster Node Check | Gets any Cluster Nodes that are in any other state than “Up”, which would indicate a requirement to review.
| Cluster Shared Volumes Check | Confirms that no Cluster Shared Volumes are present that have a state that is not “Online”.
| Storage Enclosure Check | Checks storage enclosures that have a health status that is not healthy.
| Health Service Fault Check | Checks Health Service faults any active issues detected.
| Storage Health Action Check | Health Service actions that have a state other than succeeded, implying that the automated action has failed.
| Disks Not in Pool Check | Checks if any physical disks in Storage Spaces are not present in the non-primordial pool.

### VirtualDisks

| Test | Description |
|------|-------------|
| Virtual Disk Check | Confirms if any Virtual Disks are in a Health Status other than that of Healthy.

### DirtyCount

| Test | Description |
|------|-------------|
Dirty Count | Checks if the Dirty Region Tracking (DRT) has been exceeded for the disk, as the volume will stay offline until cleared.

### StorageComponents
| Test | Description |
|------|-------------|
| Support Components Change | Checks if the Supported Components Document has been specified and if current results `Get-PhysicalDisk` are not supported by this configuration currently and suggests new configuration if valid to avoid quarantine.
| Support Components Missing | Shows if detected the Physical disks and running firmware in storage spaces are not present in Supported Components Document.

### SNV (Storage Node View)
| Test | Description |
|------|-------------|
| Storage Node View Differs | Checks if Storage Node View differs between Nodes for Physical Disks where Health Status not in a healthy state or Operation Status other than OK.

### FirmwareDrift
| Test | Description |
|------|-------------|
| Firmware Drift | Reviews if there are models of physical disk with different versions of firmware running.

### SMPHost
| Test | Description |
|------|-------------|
| Cluster Nodes SMPHost Running | Confirms if the Storage Management Provider host service is running on all Cluster Nodes.

### SMPHostIssue
| Test | Description |
|------|-------------|
| SMPHost Issue Detected | Checks if Virtual Disks are displaying detached but Cluster Shared Volume shows online.

### DiskHealth
This provides a table view of all disks configured with key information along with the below:

| Test | Description |
|------|-------------|
| Storage Spaces Partitions Check | Checks if Storage Spaces partitions for chosen disk usage are correctly created.
| Disk Health Check | Checks all Physical disks that are not healthy.
| Transient Disk Check | Checks if any Physical are in a health status of “Transient Error”, as this can be a temporary error or indicative of other issues such as partitions not correctly configured for disk usage.


## Diagnostic Information and Configuration
The following arguments provide storage information and configuration rather than running tests.

| Report | Argument |
|--------|-------------|
| Storage Summary | [StorageSummary](#storagesummary) |
| Cluster Shared Volume Usage | [CSVUsage](#csvusage) |

### StorageSummary

| Configuration Check | Description |
|---------------------|-------------|
| Storage Nodes Configuration | Provides information related to the node, serial number, server name, manufacturer, model and last boot time.
| Volume Configuration | Information related to Volumes created from the storage pool.
| Virtual Disk Configuration | Information related to virtual disks created from storage pool.
| Pool Configuration | Information related to non-primordial pool configuration.
| Storage Spaces Direct Configuration | Information related to Storage Spaces configuration.
| Capacity Details | Information related to capacity, cache and supported components.

### CSVUsage

| Configuration Check | Description |
|---------------------|-------------|
| Cluster Shared Volume Usage | Current space consumption

## Additional Analysis
To diagnose physical extent issues causing unexpected states of Virtual Disks, use the `-PhysicalExtentCheck` parameter and specify the friendly name of the drive. This will attempt to identify the root cause of the disk problem.

Example:
```powershell
Start-AzsSupportStorageDiagnostic -PhysicalExtentCheck 'NAME'
```
