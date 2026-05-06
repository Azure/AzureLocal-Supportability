# Troubleshoot physical disks not claimed after insertion (`CanPool=False`)

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Storage</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Medium</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Day 2 Operations</strong>: Capacity expansion / Add disk</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>All versions</strong></td>
  </tr>
</table>

## Overview

This guide helps troubleshoot new physical disks that are visible to Windows on an Azure Local cluster but are not added to the Storage Spaces Direct (S2D) pool.

`CanPool=False` does not always mean something is broken. It can mean the disk is already in the pool, still being verified, blocked by hardware or firmware support checks, offline, not healthy, or carrying old metadata.

## Symptoms

**Observable behaviors:**

- New disks were inserted into one or more cluster nodes.
- The disks appear in PowerShell.
- Storage pool capacity did not increase.
- `Get-PhysicalDisk` shows one or more disks with `CanPool=False`.

**Common error indicator:**

```
CanPool : False
CannotPoolReason : <one of the values in the table below>
```

## Root Cause

S2D will not claim a physical disk into its pool unless every gate passes: the disk must be healthy, online, supported by the solution vendor (model + firmware), have completed Health Service verification, and not already belong to another pool. The `CannotPoolReason` field on `Get-PhysicalDisk` reports which gate is failing.

### Common `CannotPoolReason` Values

| CannotPoolReason | Meaning | Action |
|---|---|---|
| `In a Pool` | The disk was already claimed by a storage pool | Confirm pool membership; no fix needed |
| `Verification in progress` | Health Service is checking whether the disk and firmware are approved | Wait and recheck |
| `Verification failed` | Health Service could not complete supportability verification | Check cluster health and vendor support data |
| `Hardware not compliant` | The disk model is not approved by the solution vendor | Contact the hardware vendor |
| `Firmware not compliant` | The disk firmware is not approved by the solution vendor | Contact the hardware vendor |
| `Offline` | The disk is offline | Bring only the intended disk online |
| `Insufficient Capacity` | The disk is too small | Replace with a supported disk |
| `Removable media not supported` | The disk is removable or presented as removable | Replace with supported internal storage |
| Stale metadata suspected | The disk has previous data or pool metadata | Reset only after confirming the disk is safe to wipe |

## Resolution

### Prerequisites

- An elevated PowerShell session on a cluster node.
- Confirmation that the cluster is healthy aside from this issue (no unrelated active rebuild, no node down).
- Vendor support matrix for the disk model and firmware version on hand.

### Steps

#### Step 1: Check the Disk State

Capture the full picture for every physical disk and identify which disks are blocked and why.

```powershell
# Get the full disk picture; CannotPoolReason tells you which gate failed
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, BusType, Size, FirmwareVersion, HealthStatus, Usage, CanPool, CannotPoolReason
```

The most important field is `CannotPoolReason`. Use the value to pick the matching sub-step below.

#### Step 2a: Resolve `In a Pool`

This is usually expected after automatic pooling.

```powershell
# Replace with the new disk's serial number
$serial = '<disk-serial-number>'

# Confirm the disk is in the intended (non-primordial) pool and healthy
Get-StoragePool -IsPrimordial $false |
    Get-PhysicalDisk |
    Where-Object SerialNumber -eq $serial |
    Format-Table DeviceId, FriendlyName, SerialNumber, Usage, HealthStatus, OperationalStatus
```

If the disk is in the intended pool and healthy, no additional action is needed.

#### Step 2b: Resolve `Verification in progress`

Wait several minutes and recheck:

```powershell
# Recheck verification progress
Get-PhysicalDisk |
    Format-Table DeviceId, FriendlyName, SerialNumber, CanPool, CannotPoolReason, HealthStatus
```

> [!WARNING]
> Do not reset or manually add disks while verification is still in progress.

#### Step 2c: Resolve `Verification failed`

Check the cluster and storage state:

```powershell
# Cluster + storage health snapshot
Get-HealthFault
Get-ClusterNode                        | Format-Table Name, State
Get-StorageJob
Get-StoragePool -IsPrimordial $false   | Format-Table FriendlyName, HealthStatus, OperationalStatus
Get-VirtualDisk                        | Format-Table FriendlyName, HealthStatus, OperationalStatus
```

If available, run the Azure Local Support Diagnostic Tool storage checks:

```powershell
# Targeted disk and storage health checks via the Support Diagnostic Tool
Start-AzsSupportStorageDiagnostic -Include 'DiskHealth','StorageHealth'
```

For details on these checks see [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md).

If the disk model or firmware is new to the system, validate supportability with the hardware vendor.

#### Step 2d: Resolve `Hardware not compliant`

The disk model is not approved for this solution.

```powershell
# Capture model + firmware so the vendor can confirm support
Get-PhysicalDisk |
    Format-Table DeviceId, FriendlyName, SerialNumber, FirmwareVersion, MediaType, BusType, CanPool, CannotPoolReason
```

> [!CAUTION]
> Do not bypass hardware validation. Contact the hardware vendor for a supported disk model or an updated solution support package.

#### Step 2e: Resolve `Firmware not compliant`

The disk firmware is not approved for this solution.

```powershell
# Compare firmware on the new vs existing disks of the same model
Get-PhysicalDisk |
    Sort-Object FriendlyName, FirmwareVersion |
    Format-Table DeviceId, FriendlyName, SerialNumber, FirmwareVersion, HealthStatus, CanPool, CannotPoolReason
```

Contact the hardware vendor for firmware alignment or updated support guidance.

#### Step 2f: Resolve `Offline` or Read-Only Disk State

```powershell
# Identify the exact disk first
Get-Disk | Sort-Object Number |
    Format-Table Number, FriendlyName, SerialNumber, OperationalStatus, IsOffline, IsReadOnly, PartitionStyle
```

After the intended disk is confirmed:

```powershell
# Replace <disk-number> with the Number value from Get-Disk above
Set-Disk -Number <disk-number> -IsOffline   $false
Set-Disk -Number <disk-number> -IsReadOnly  $false
```

Recheck `Get-PhysicalDisk` afterward.

#### Step 2g: Resolve Stale Metadata or Previous Pool Membership

> [!WARNING]
> `Reset-PhysicalDisk` is destructive. Do not run it on a disk that belongs to an active pool or contains data that must be preserved. Use this path **only** for disks that are intended to be wiped.

Before reset, confirm the disk identity and that it is not in any pool:

```powershell
# Inspect the candidate disk
Get-PhysicalDisk -UniqueId '<unique-id>' | Format-List *

# Confirm it is NOT a member of any active pool (this should return nothing)
Get-StoragePool -IsPrimordial $false |
    Get-PhysicalDisk |
    Where-Object UniqueId -eq '<unique-id>' |
    Format-List *
```

Only if the disk is confirmed to be unused stale media and the data can be destroyed:

```powershell
# Destructive: clears storage pool metadata from the disk
Reset-PhysicalDisk -UniqueId '<unique-id>'
```

Wait several minutes and recheck:

```powershell
# Verify the disk is now eligible
Get-PhysicalDisk -UniqueId '<unique-id>' |
    Format-Table DeviceId, FriendlyName, SerialNumber, CanPool, CannotPoolReason, HealthStatus, Usage
```

#### Step 3: Manual Add When Disks Are Eligible

If the disks now show `CanPool=True` but are not automatically claimed, review the target pool and exact disk list:

```powershell
# Identify the target pool and eligible disks
$pool          = Get-StoragePool -IsPrimordial $false
$eligibleDisks = Get-PhysicalDisk -CanPool $true

$pool          | Format-Table FriendlyName, HealthStatus, OperationalStatus
$eligibleDisks | Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, Size, FirmwareVersion
```

If there is exactly one non-primordial pool and the eligible disks are the intended disks:

```powershell
# Manually add the eligible disks to the target pool
Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $eligibleDisks
```

> [!IMPORTANT]
> If multiple non-primordial pools exist, select the intended pool and disks explicitly. Do not pipe `Get-StoragePool` directly into `Add-PhysicalDisk`.

#### Step 4: Verify Resolution

```powershell
# Confirm the new disks are in the pool, healthy, with no surprise jobs or faults
Get-PhysicalDisk | Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, Usage, HealthStatus, CanPool, CannotPoolReason
Get-StoragePool -IsPrimordial $false |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize
Get-StorageJob
Get-HealthFault
```

Expected result:

- New disks are in the intended pool.
- New disks are healthy.
- No unintended `CanPool=True` disks remain.
- No new storage faults are active.
- Any expected storage jobs are progressing.

## Prevention

- Always validate disk model and firmware against the OEM solution support matrix **before** insertion.
- Add disks symmetrically (same count and type per node) to avoid stranded capacity.
- Run the [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md) pre-checks before any insertion.
- Avoid reusing disks from prior deployments without confirming they are wiped of stale pool metadata.

## Data to Collect Before Opening a Support Case

```powershell
# Cluster + storage state snapshot
Get-HealthFault
Get-ClusterNode                        | Format-Table Name, State
Get-StorageJob
Get-StoragePool -IsPrimordial $false   | Format-List *
Get-VirtualDisk                        | Format-List *
Get-PhysicalDisk                       | Format-List *

# Last 60 minutes of cluster log to C:\Temp
Get-ClusterLog -Destination C:\Temp -TimeSpan 60
```

Also collect:

- Disk serial numbers and unique IDs.
- Node and slot mapping.
- Disk model and firmware version.
- Hardware vendor support matrix or written confirmation for the disk model and firmware.
- Whether automatic pooling is expected or intentionally disabled.

## Related Issues

- [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md)
- [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)

## References

- [Adding servers or drives to Storage Spaces Direct](https://learn.microsoft.com/windows-server/storage/storage-spaces/add-nodes#adding-drives)
- [Troubleshoot Storage Spaces and Storage Spaces Direct health and operational states](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states)

---
