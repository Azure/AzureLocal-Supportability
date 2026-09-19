---
ArticleType: "TSG"
Article_ID: "20260917143653"
Title: "AzStackHci_Hardware_PhysicalDisk"
Status: "Active"
Audience: ["Engineering", "CSS", "OEM Partners", "External"]
LastUpdated: "2026-09-17"
Region: ["All"]
AppliesTo:
  Product: "Azure Local"
  DeploymentType: ["Hyperconverged", "Disaggregated", "Multi-Rack", "Disconnected", "Microsoft 365 Local"]
  OEM: ["All"]
  OS: ["23H2", "24H2"]
  SolutionMinorBuild: []
  ExtensionName: ""
  ExtensionVersion: []
Component: "Environment Validator"
Engineering_ID:
  - Source: "ADO PR"
    ID: 16230858
  - Source: "ADO PR"
    ID: 16676534
Tags: ["Validation", "Physical Disk", "Disks"]
---
[[_TOC_]]

# Revision History

| Date | Description |
| --- | --- |
| 2026-09-17 | Updated current result names and branches, added safe diagnostics and remediation gates, live-validated the disposable minimum-count loop, and adopted mandatory publication metadata and layout. |

# AzStackHci_Hardware_PhysicalDisk

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Hardware_PhysicalDisk</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validator / test</th>
    <td><strong>Test-PhysicalDisk</strong>, run by <code>Invoke-AzStackHciHardwareValidation</code></td>
  </tr>
  <tr>
    <th style="text-align:left;">Component</th>
    <td>Candidate-host data disks and storage controllers</td>
  </tr>
  <tr>
    <th style="text-align:left;">Severity</th>
    <td><strong>Critical</strong>: the pending lifecycle operation remains blocked until the candidate host meets the disk requirements.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable scenarios</th>
    <td>Deployment, Add Node, and Repair Node validation of a candidate host. SAN-backed storage excludes this local physical-disk validator.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Primary owner</th>
    <td>Azure Local deployment administrator, with the OEM hardware or storage owner when a controller, firmware, cabling, or drive replacement is required.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Risk summary</th>
    <td>Diagnosis is read-only. Hardware remediation can require a maintenance window and may be destructive if the wrong disk is selected.</td>
  </tr>
</table>

> [!IMPORTANT]
> Run the diagnostic steps first. Do not use `Clear-Disk`, `Reset-PhysicalDisk`, `Remove-PhysicalDisk`, `Set-PhysicalDisk -Usage Retired`, or controller reconfiguration as a generic response to this validator. Those actions can destroy data or reduce storage resiliency.

## Summary

This check validates the disks that a candidate host can contribute to Azure Local. It verifies that the disk inventory can be read, identifies supported data disks, checks required properties and minimum counts, and checks per-type counts. A single-node candidate also receives an all-flash check.

Most cases take 15 to 30 minutes to classify with the read-only commands below. Replacing a drive, changing a controller from RAID to HBA or pass-through mode, updating firmware, or correcting cabling requires the OEM procedure and a maintenance window. Do not guess an OEM command or change a deployed cluster member from this article alone.

## Current and legacy result names

Current Environment Checker builds aggregate the actionable details into:

- `AzStackHci_Hardware_PhysicalDisk`

Single-node validation can also emit:

- `AzStackHci_Hardware_Test_PhysicalDisk_AllFlash`

The following names can appear in older reports and support cases:

- `AzStackHci_Hardware_Test_PhysicalDisk`
- `AzStackHci_Hardware_Test_PhysicalDisk_Minimum_Count`
- `AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count`
- `AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count_ByGroup`

Current builds no longer emit the FriendlyName-based group-consistency and instance-count-by-group results. Those checks were removed because identical disk models and identical cross-node group layouts are not required for Add Node or Repair Node. Do not replace healthy disks merely to make `FriendlyName` values identical.

## What the current check evaluates

The aggregate result can fail for one or more of these branches:

1. **Inventory unavailable**: the PhysicalDisk CIM data cannot be read or no supported data-disk candidate is found.
2. **Unsupported disk properties**: a candidate disk has an unsupported bus or media type, is a boot or system disk, is unhealthy, or is not pool-eligible for the current lifecycle scenario.
3. **Minimum count**: the candidate host has fewer supported data disks than the validator requires for the detected hardware class and scenario.
4. **Per-type count**: the supported SSD, NVMe, SCM, or HDD population does not meet the check's count rules.
5. **Single-node all-flash**: a single-node deployment contains rotating media when the single-node rule requires flash.

The failure's `AdditionalData.Detail` is authoritative for the branch and expected count on that build. Do not copy a threshold from another cluster or an older report.

Some builds render the minimum-count detail as `Total number of PhysicalDisk ''. Expected at least '<n>'`, with the disk-type label blank. Treat this as the total supported data-disk count branch. Use the expected number in the same detail and confirm the actual supported disks with `Get-PhysicalDiskSupport`; do not invent a media type from the empty label.

## Terms

| Term | Meaning |
| --- | --- |
| Candidate host | The machine being evaluated for deployment, Add Node, or Repair Node. |
| Data disk | A non-boot disk intended for Storage Spaces Direct. |
| `CanPool` | Whether Storage Spaces currently considers the disk eligible to join a pool. |
| `CannotPoolReason` | The product-reported reason that `CanPool` is false. |
| Bus type | The storage transport reported by Windows, such as SAS, SATA, NVMe, or SCM. |
| Media type | HDD, SSD, or storage-class memory. |
| CIM | The Windows management interface used by the validator to enumerate disk state. |
| `PsSession` | A PowerShell remoting session used to query one or more candidate hosts. |

## Before you start

- Run the commands from an elevated Windows PowerShell session.
- Confirm that you are targeting the candidate host named in the validator result.
- Record the current lifecycle operation: Deployment, Add Node, or Repair Node.
- Do not apply candidate-host disk instructions to a healthy deployed member without a separate storage repair plan.
- If the host is already a deployed cluster member, stop before any physical or controller change. Confirm all nodes are Up, all virtual disks and CSVs are healthy, no storage job is running, and workloads have an approved evacuation plan.
- For OEM controller mode, firmware, backplane, cabling, or drive replacement, use the qualified OEM procedure for the exact model.

## Where this failure appears

| Administrator surface | What to expect |
| --- | --- |
| PowerShell on the candidate host | `Invoke-AzStackHciHardwareValidation -Include Test-PhysicalDisk -PassThru`, `Get-PhysicalDisk`, and `Get-PhysicalDiskSupport` show the actionable disk state. |
| Azure portal | A deployment or lifecycle validation failure can show this check as blocking. Portal data can lag until the next full validation run. |
| Windows event logs | The `AzStackHciEnvironmentChecker` log can contain Event ID 17205 with the serialized result. Read `AdditionalData.Status` and `AdditionalData.Detail`. |
| Cluster logs (`Get-ClusterLog`) | This candidate-host validator does not normally appear as a failover-cluster event. Use cluster logs only when a separate cluster or storage fault is also present. |
| Failover Cluster Manager | The validator result does not normally appear as a role or resource. Use it only to confirm deployed-member and CSV state before a maintenance action. |
| Windows Admin Center, standalone | The exact validator result is not consistently exposed. OEM extensions can show hardware inventory, but they do not replace the validator output. |
| Windows Admin Center in Azure | The exact validator result is not consistently exposed. Use the Azure Local lifecycle result and on-node evidence. |
| Component or tool log files | The account that ran Environment Checker can have `%USERPROFILE%\.AzStackHci\AzStackHciEnvironmentChecker.log` and `AzStackHciEnvironmentReport.json` or `.xml`. Preserve timestamps and the matching result. |

### Read the newest Event ID 17205 result

```powershell
$currentNames = @(
    'AzStackHci_Hardware_PhysicalDisk',
    'AzStackHci_Hardware_Test_PhysicalDisk',
    'AzStackHci_Hardware_Test_PhysicalDisk_Minimum_Count',
    'AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count',
    'AzStackHci_Hardware_Test_PhysicalDisk_Instance_Consistency_Count_ByGroup'
)

Get-WinEvent -LogName AzStackHciEnvironmentChecker `
    -FilterXPath '*[System[(EventID=17205)]]' -MaxEvents 2000 |
    ForEach-Object {
        try { $_.Message | ConvertFrom-Json } catch { $null }
    } |
    Where-Object {
        $_ -and (
            $currentNames -contains $_.Name -or
            $_.Name -like '*PhysicalDisk*'
        )
    } |
    Select-Object -First 1 `
        Name,
        @{n='Status';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}},
        Remediation,
        Timestamp
```

If no fresh record exists, run the direct validation in the next section. A missing event is a data gap, not a passing result.

## Diagnosis

### 1. Run the targeted validator on the candidate host

```powershell
Import-Module AzStackHci.EnvironmentChecker -Force

$result = Invoke-AzStackHciHardwareValidation `
    -Include Test-PhysicalDisk `
    -PassThru

$result |
    Where-Object { $_.Name -like '*PhysicalDisk*' } |
    Select-Object Name, Status, Severity, Description, Remediation,
        @{n='DetailStatus';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}} |
    Format-List
```

Expected failure shape on current builds:

- `Name` is `AzStackHci_Hardware_PhysicalDisk`.
- `Status` or `AdditionalData.Status` is `FAILURE`.
- `AdditionalData.Detail` names the failed branch, node, observed count or property, and expected state.

If the command returns no PhysicalDisk result, confirm the module version, inspect `ExcludeTests.txt`, and verify that the lifecycle scenario runs the Hardware validator. SAN-backed configurations intentionally exclude the local PhysicalDisk check.

### 2. Record the module version and disk identity

```powershell
Get-Module -ListAvailable AzStackHci.EnvironmentChecker |
    Sort-Object Version -Descending |
    Select-Object -First 1 Name, Version, ModuleBase

Get-Disk |
    Select-Object Number, FriendlyName, SerialNumber, UniqueId, IsBoot, IsSystem,
        BusType, PartitionStyle, OperationalStatus, HealthStatus |
    Sort-Object Number |
    Format-Table -AutoSize

Get-PhysicalDisk |
    Select-Object DeviceId, FriendlyName, SerialNumber, UniqueId, PhysicalLocation,
        HealthStatus, OperationalStatus, Usage, CanPool, CannotPoolReason,
        BusType, MediaType, Size |
    Sort-Object DeviceId |
    Format-Table -AutoSize
```

Use `UniqueId`, `SerialNumber`, `PhysicalLocation`, and the OEM slot label together. Do not select a disk for remediation by `DeviceId` alone because numbering can change after a reboot or hardware rescan.

### 3. Run the support classifier

For one candidate host:

```powershell
$session = New-PSSession -ComputerName '<candidate-host>' -Credential (Get-Credential)

try {
    Import-Module 'C:\Program Files\WindowsPowerShell\Modules\AzStackHci.EnvironmentChecker\AzStackHciHardware\AzStackHci.Hardware.Diagnostic.Helpers.psm1' -Force

    Get-PhysicalDiskSupport -PsSession $session |
        Select-Object -ExpandProperty DiskData |
        Select-Object HCISupported, ServerName, PhysicalLocation, UniqueId,
            SerialNumber, HCISupportedData |
        Format-List
}
finally {
    Remove-PSSession $session -ErrorAction SilentlyContinue
}
```

For several candidate hosts, create one session per host and pass the array to `Get-PhysicalDiskSupport`. Do not leave stale sessions open after evidence collection.

### 4. Classify the result

| Evidence | Meaning | Next action |
| --- | --- | --- |
| `IsBootDevice=True` | The disk is the boot or system device and is not eligible as a data disk. | No disk repair. Exclude it from the supported data-disk count. |
| Unsupported `BusType` | The controller presents the disk through an unsupported transport, commonly RAID virtual-disk mode. | Engage the OEM owner to verify the qualified HBA or pass-through configuration. |
| Unsupported `MediaType` | Windows cannot classify the media as HDD, SSD, or SCM, or the device is not qualified. | Verify firmware, driver, controller presentation, and the qualified hardware catalog with the OEM. |
| `CanPool=False`, `CannotPoolReason=In a Pool` | The disk already belongs to a Storage Spaces pool. On a deployed member this can be expected. | Do not clear or reset it. Confirm that the validator is running against the intended candidate-host scenario. |
| `CanPool=False`, `CannotPoolReason=Insufficient Capacity` | The device is too small for pooling or represents a boot/system device, reserved media, or another capacity-limited device. | Correlate `Size`, `IsBoot`, and `IsSystem`; replace or reconfigure only through the qualified hardware plan. |
| `HealthStatus` is not Healthy or `OperationalStatus` is not OK | Windows reports a disk or path health problem. | Stop the lifecycle operation and follow the storage or OEM failure procedure. |
| Detail reports fewer disks than expected | The number of supported candidate data disks is below the build's requirement. | Verify missing slots, power, cabling, controller visibility, firmware, and whether a disk was intentionally removed. |
| Detail reports a per-type count failure | The supported HDD, SSD, NVMe, or SCM population does not meet the current check. | Use the exact expected and observed counts in `AdditionalData.Detail`; do not infer a threshold from another cluster. |
| Only model or `FriendlyName` values differ across otherwise supported disks | Current builds do not enforce the removed FriendlyName group-consistency checks. | Do not replace disks solely to make model strings identical. Verify current module version and current result name. |

## Remediation

### Path A: the wrong host or lifecycle context was validated

1. Confirm the target computer in `AdditionalData.Detail`.
2. Confirm whether this is Deployment, Add Node, or Repair Node.
3. If a deployed member was evaluated without the expected lifecycle context and its data disks are correctly `In a Pool`, do not reset the disks.
4. Re-run the intended lifecycle validation against the correct candidate host.

### Path B: a disk is missing from Windows

1. Compare the validator detail with the OEM inventory and physical slot map.
2. Confirm power, seating, cabling, backplane state, and controller visibility.
3. Use the OEM's qualified procedure to reseat or replace the exact disk.
4. Rescan storage or reboot only when the OEM procedure requires it.
5. Re-run the read-only inventory before restarting the lifecycle operation.

### Path C: the controller presents disks in RAID mode

Azure Local requires qualified direct disk presentation. RAID virtual disks, shared SAN paths, multipath storage, and shared SAS enclosures are not interchangeable with supported local Storage Spaces Direct media.

1. Stop before changing controller mode on a deployed member.
2. Confirm the exact server, controller, firmware, and qualified configuration with the OEM.
3. For a new candidate host with no customer data, follow the OEM procedure to configure HBA or pass-through mode.
4. Confirm that Windows now reports each physical data disk directly with a supported bus type.
5. Run the validator again.

### Path D: `CanPool=False`

Do not use `Clear-Disk` or `Reset-PhysicalDisk` until the disk's identity, ownership, and data disposition are proven.

- `In a Pool`: do not reset the disk. Verify lifecycle context and existing pool membership.
- `Insufficient Capacity`: verify disk size and boot/system status. Replace undersized media through the hardware plan.
- `Offline` or `Read-only`: first prove the disk is the intended non-boot, non-pooled candidate. Then use the Storage Spaces drive-state guidance.
- `Verification in progress` or `Verification failed`: allow the normal verification interval and collect storage diagnostics if it persists.
- Hardware or firmware noncompliance: use the OEM and qualified configuration guidance.

### Path E: the supported disk count is too low

1. Use the exact observed and expected count from `AdditionalData.Detail`.
2. Confirm which disks were excluded and why with `Get-PhysicalDiskSupport`.
3. Restore visibility or replace unsupported or missing media through the OEM procedure.
4. For Add Node or Repair Node, do not require identical `FriendlyName` strings when the current check no longer enforces that removed condition.
5. Re-run the targeted validator.

### Path F: single-node all-flash requirement

If the separate single-node all-flash result fails, replace rotating media with qualified flash media according to the supported single-node configuration. Do not suppress the check or mix unsupported media tiers.

## Workload and maintenance impact

- The diagnostic commands in this article are read-only and do not require a drain.
- A new, not-yet-deployed candidate host has no cluster workload to evacuate.
- A deployed member requires a separate maintenance plan before a controller change, disk removal, firmware update, or reboot.
- Before work on a deployed member, verify cluster quorum, node state, virtual-disk health, CSV state, and storage jobs. Live migrate or stop workloads according to the approved maintenance procedure.
- Do not continue when redundancy is degraded, a storage job is active, quorum is at risk, or the intended disk cannot be identified unambiguously.

## Verify the fix

### 1. Re-run the targeted validator

```powershell
Import-Module AzStackHci.EnvironmentChecker -Force

$result = Invoke-AzStackHciHardwareValidation `
    -Include Test-PhysicalDisk `
    -PassThru

$result |
    Where-Object { $_.Name -like '*PhysicalDisk*' } |
    Select-Object Name, Status, Severity,
        @{n='DetailStatus';e={$_.AdditionalData.Status}},
        @{n='Detail';e={$_.AdditionalData.Detail}} |
    Format-List
```

The fix is verified only when:

- a PhysicalDisk result is present and fresh;
- the current aggregate is `AzStackHci_Hardware_PhysicalDisk`, or a documented legacy name is present on an older module;
- `Status` and `AdditionalData.Status` report success for the blocking branch;
- the supported-disk count and per-type details meet the expected values;
- no new unsupported, unhealthy, or ambiguous disk appears.

### 2. Re-run the lifecycle validation

Run the same deployment, Add Node, or Repair Node validation that originally failed. A direct targeted pass does not by itself prove that the full lifecycle workflow refreshed its persisted health result.

### 3. Confirm deployed-cluster health when applicable

```powershell
Get-ClusterNode
Get-StoragePool -IsPrimordial $false |
    Select-Object FriendlyName, HealthStatus, OperationalStatus, IsReadOnly
Get-VirtualDisk |
    Select-Object FriendlyName, HealthStatus, OperationalStatus
Get-StorageJob
Get-ClusterSharedVolume |
    Select-Object Name, State, OwnerNode
```

All nodes must be Up, non-primordial pools and virtual disks must be healthy, CSVs must be Online, and no unexpected storage job may remain.

## Escalation

Escalate to the OEM hardware owner when:

- the controller mode, firmware, backplane, cabling, or drive qualification is uncertain;
- a disk is missing from the OEM inventory or Windows;
- a physical drive reports a health or operational error;
- replacement or firmware work is required.

Escalate to Azure Local support or the Environment Validator owner when:

- the current module emits a removed legacy group-consistency result;
- the direct inventory and `Get-PhysicalDiskSupport` output are healthy but the current aggregate still fails after a fresh validation;
- the validator returns no PhysicalDisk result outside a documented SAN exclusion;
- the expected count or branch conflicts with the current module's behavior.

Attach:

- Environment Checker module version and path;
- lifecycle operation and hardware class;
- fresh `AzStackHci_Hardware_PhysicalDisk` result with `AdditionalData.Detail`;
- Event ID 17205 record and timestamps;
- `Get-Disk`, `Get-PhysicalDisk`, and `Get-PhysicalDiskSupport` output;
- OEM controller, firmware, slot, and drive inventory;
- cluster health output when the target is already deployed.

## References

- [Azure Local physical deployment storage requirements](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-direct-hardware-requirements#physical-deployments)
- [Azure Local machine and storage requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements-23h2#machine-and-storage-requirements)
- [Azure Local low-capacity device requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements-small-23h2#device-requirements)
- [Storage Spaces drive states and pooling reasons](https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-states)

::: audience-css

# Source Articles

- Azure Local Environment Validator source history for removal of the PhysicalDisk grouping-by-friendly-name test.
- Azure Local Environment Validator source history for PhysicalDisk count details and JSON-safe localized strings.

:::
