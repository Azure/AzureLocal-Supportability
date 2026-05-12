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
    <td><strong>All Azure Local releases (Storage Spaces Direct)</strong></td>
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

The `CannotPoolReason` column lists values as they appear in `Get-PhysicalDisk` output. A disk carrying stale Storage Spaces metadata from a prior deployment is a sub-case of `In a Pool` (the disk thinks it belongs to a pool that no longer exists) and is handled separately in [Step 2g](#step-2g-resolve-stale-metadata-or-previous-pool-membership).

| CannotPoolReason | Meaning | Action |
|---|---|---|
| `In a Pool` | The disk was already claimed by a storage pool | Confirm pool membership via Step 2a. If `Get-StoragePool \| Get-PhysicalDisk` finds no match for the disk, treat it as stale metadata (Step 2g). |
| `Verification in progress` | Health Service is checking whether the disk and firmware are approved | Wait and recheck |
| `Verification failed` | Health Service could not complete supportability verification | Check cluster health and vendor support data |
| `Hardware not compliant` | The disk model is not approved by the solution vendor | Contact the hardware vendor |
| `Firmware not compliant` | The disk firmware is not approved by the solution vendor | Update firmware to a supported version using OEM update tooling, or contact the hardware vendor |
| `Offline` | The disk is offline | Bring only the intended disk online |
| `Insufficient Capacity` | The disk is too small | Replace with a supported disk |
| `Removable media not supported` | The disk is removable or presented as removable | Replace with supported internal storage |

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

Contact the hardware vendor for firmware alignment or updated support guidance. In most cases, the resolution is to update firmware to a supported version using the OEM update tooling (Dell DSU, HPE SUM, Lenovo XClarity Essentials, etc.). If no supported firmware version exists for this disk model, the model itself may have been deprecated -- escalate to the hardware vendor.

#### Step 2f: Resolve `Offline` or Read-Only Disk State

```powershell
# Identify the exact disk first
Get-Disk | Sort-Object Number |
    Format-Table Number, FriendlyName, SerialNumber, OperationalStatus, IsOffline, IsReadOnly, PartitionStyle
```

After the intended disk is confirmed:

> [!CAUTION]
> Run `Get-StorageJob` first. If a repair, regeneration, or rebalance job is active that involves this disk, let it complete before bringing the disk online -- forcing it online mid-rebuild can cause the rebuild to retry against the newly-online path and extend the impact window.

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

If the disks now show `CanPool=True` but are not automatically claimed, first inspect the current pool and eligible disks:

```powershell
# Inspect the target pool and eligible disks
$pool          = Get-StoragePool -IsPrimordial $false
$eligibleDisks = Get-PhysicalDisk -CanPool $true

$pool          | Format-Table FriendlyName, HealthStatus, OperationalStatus
$eligibleDisks | Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, Size, FirmwareVersion
```

> [!IMPORTANT]
> A healthy Storage Spaces Direct cluster has exactly one non-primordial pool. The snippet below enforces that and requires the operator to enumerate the intended new disks by serial number, so `Add-PhysicalDisk` cannot accidentally claim unintended `CanPool=True` disks.

```powershell
# Defensive: require exactly one non-primordial pool. Abort otherwise.
$pool = Get-StoragePool -IsPrimordial $false
if (@($pool).Count -ne 1) {
    throw "Expected exactly one non-primordial pool. Found $(@($pool).Count). " +
          "Select the target pool explicitly by FriendlyName before continuing."
}

# Operator MUST enumerate the intended new disks by serial number.
# Do NOT pipe Get-PhysicalDisk -CanPool $true directly into Add-PhysicalDisk.
$intendedSerials = @(
    '<serial-number-1>',
    '<serial-number-2>'
)

# Resolve serials to physical disk objects and confirm the count matches the intent.
# Wrap in @() so .Count is reliable when 0 or 1 disk matches.
$disksToAdd = @(Get-PhysicalDisk -CanPool $true |
                Where-Object SerialNumber -in $intendedSerials)
if ($disksToAdd.Count -ne $intendedSerials.Count) {
    throw "Disk count mismatch: $($disksToAdd.Count) eligible disks matched " +
          "the $($intendedSerials.Count) intended serial numbers. Resolve before continuing."
}

# Add only the explicitly identified disks to the target pool.
Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $disksToAdd
```

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
