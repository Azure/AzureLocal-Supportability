# How to add physical disks to an existing Azure Local cluster

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Storage</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td><strong>Storage Spaces Direct</strong>: Add physical disks to an existing pool for online capacity expansion</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Applicable Scenarios</th>
    <td><strong>Day 2 Operations</strong>: Capacity expansion / Add disk</td>
  </tr>
</table>

## Overview

This guide describes the safe sequence for adding physical disks to an existing Azure Local cluster that uses Storage Spaces Direct (S2D).

The intended path is online capacity expansion, but a disk add is still a storage-infrastructure change. Complete the health checks first, add disks symmetrically, and wait for storage jobs to complete before expanding volumes or performing more maintenance.

## What and Why

### What This Guide Covers

The end-to-end procedure to add OEM-supported physical disks to an existing S2D storage pool on a healthy Azure Local cluster, including the pre-checks, the insert-and-claim flow, monitoring redistribution jobs, and final validation.

### When to Use This Guide

Use this guide when:

- The cluster is healthy.
- New OEM-supported disks are being added for capacity expansion.
- The goal is to add the disks to the existing Storage Spaces Direct pool.

Do **not** use this guide for:

- Replacing failed disks.
- Adding cluster nodes.
- Recovering from an unhealthy pool.
- Adding unsupported disk models or firmware.
- Changing cache/capacity tier design.

> [!NOTE]
> Some hardware OEMs publish hardware-lifecycle wizards as Windows Admin Center (WAC) extensions that include guided disk-add flows -- for example, **Dell OpenManage Integration with Microsoft Windows Admin Center (OMIMSWAC)**, with similar tooling available from other major Azure Local OEMs. These extensions can be a more convenient alternative to the PowerShell sequence below.
>
> Caveats:
> - OEM WAC extensions are only supported on **standalone (on-premises)** installations of Windows Admin Center, not the WAC instance embedded in the Azure portal. See [Manage Azure Local clusters using Windows Admin Center in Azure](https://learn.microsoft.com/windows-server/manage/windows-admin-center/azure/manage-hci-clusters) for the supported scope of the embedded WAC.
> - The PowerShell flow in this TSG remains the canonical path when an OEM wizard is unavailable, fails, or finer-grained control is needed (for example, when troubleshooting `CanPool=False`).

## Prerequisites

Before inserting disks, confirm all of the following:

- All cluster nodes are up.
- No active health faults.
- No active storage jobs.
- The pool and virtual disks are healthy.
- The disk model and firmware are supported by the system vendor.
- The same number and type of disks will be added to each node (drive symmetry).
- Backups are current.

> [!IMPORTANT]
> Do not add disks while repair, rebuild, regeneration, rebalance, or optimization jobs are active. Adding disks under load can amplify rebuild work and extend the impact window.

## Table of Contents

- [Overview](#overview)
- [What and Why](#what-and-why)
- [Prerequisites](#prerequisites)
- [Pre-check Commands](#pre-check-commands)
- [Add Disks](#add-disks)
- [Monitor Redistribution and Storage Jobs](#monitor-redistribution-and-storage-jobs)
- [Confirm Added Capacity](#confirm-added-capacity)
- [Expand Volumes](#expand-volumes)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Pre-check Commands

Run all commands from an elevated PowerShell session on a cluster node.

### Step 1: Check Cluster Health

Confirm there are no active health faults and that all nodes are up before any storage change.

```powershell
# List active health faults across the cluster
Get-HealthFault

# Confirm every cluster node is in the Up state
Get-ClusterNode | Sort-Object Name | Format-Table Name, State
```

Expected result:

- No health faults returned.
- All nodes show `Up`.

### Step 2: Check Storage Health

Confirm the pool, virtual disks, and storage jobs are in the expected state before adding new disks.

```powershell
# Pool health and capacity
Get-StoragePool -IsPrimordial $false |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize

# Virtual disk health and footprint
Get-VirtualDisk |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, ProvisioningType, Size, FootprintOnPool

# Active storage jobs (must be empty before proceeding)
Get-StorageJob
```

Expected result:

- Storage pool and virtual disks are healthy.
- No active storage jobs are running.

### Step 3: Capture Current Disk Inventory

Take a baseline so the new disks can be identified by serial number after insertion.

```powershell
# Save the current physical disk inventory; compare after insertion
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, BusType, Size, FirmwareVersion, HealthStatus, Usage, CanPool, CannotPoolReason
```

Save the output so it can be compared after the new disks are added.

### Step 4: Check Disk Symmetry

Each node should have the same count for each disk type used by the cluster.

```powershell
# Per-node disk counts grouped by media type; counts should match across nodes
Get-StorageNode | ForEach-Object {
    $node = $_
    Get-PhysicalDisk -StorageNode $node |
        Group-Object MediaType |
        ForEach-Object {
            [PSCustomObject]@{
                Node      = $node.Name
                MediaType = $_.Name
                Count     = $_.Count
            }
        }
} | Sort-Object Node, MediaType | Format-Table
```

> [!WARNING]
> Adding disks asymmetrically (different counts per node) can strand capacity and reduce resiliency. Correct asymmetry before adding the new disks to the pool.

## Add Disks

### Step 1: Insert Disks Symmetrically

Add the same number of supported disks to each node. Keep slot placement consistent across nodes if the hardware platform supports a consistent slot layout.

> [!NOTE]
> Do not reboot nodes as part of this procedure unless the hardware vendor explicitly requires it.

### Step 2: Confirm Windows Sees the New Disks

After insertion, wait a few minutes and re-run the inventory command.

```powershell
# Re-inventory; new serial numbers should appear
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, BusType, Size, FirmwareVersion, HealthStatus, Usage, CanPool, CannotPoolReason
```

Expected result:

- New disks are visible.
- Disk model, firmware, media type, and size match the plan.
- New disks show `CanPool=True`, `Verification in progress`, or `In a Pool`.

> [!CAUTION]
> If the disks do not appear, check hardware visibility (slot, cabling, vendor management UI) first. Do **not** run storage reset commands for disks that are not visible or not identified.

### Step 3: Wait for Automatic Pooling

Storage Spaces Direct normally claims eligible disks and adds them to the pool automatically.

```powershell
# Look for unclaimed eligible disks
Get-PhysicalDisk -CanPool $true |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, Size, FirmwareVersion
```

If this returns no rows and the new disks show `CannotPoolReason = In a Pool`, the disks were claimed automatically.

### Step 4: Manually Add Disks Only When Needed

Manual add is appropriate when automatic pooling does not claim eligible disks, the target pool is known, and the disks show `CanPool=True`.

First, inspect the current pool and eligible disks:

```powershell
# Inspect the target pool and the eligible disks
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

## Monitor Redistribution and Storage Jobs

After disks are added, Storage Spaces Direct may run background jobs to optimize and redistribute data.

```powershell
# Track active storage jobs (rebuild, regeneration, optimize, rebalance)
Get-StorageJob
```

While storage jobs are active, avoid:

- Rebooting nodes.
- Applying updates.
- Putting nodes into maintenance mode.
- Adding more disks.
- Expanding volumes.
- Cancelling storage jobs.

> [!NOTE]
> Storage jobs can run for hours or days depending on pool size, media type, and workload.

## Confirm Added Capacity

```powershell
# Raw pool size should reflect the added disks
Get-StoragePool -IsPrimordial $false |
    Format-List FriendlyName, Size, AllocatedSize, HealthStatus, OperationalStatus
```

Usable capacity may not appear immediately if the system is restoring rebuild reserve or redistributing data.

## Expand Volumes

> [!IMPORTANT]
> Hard gate: do not expand volumes while storage jobs are active.

```powershell
# Storage jobs MUST be empty before expansion
Get-StorageJob
```

Expected result: no active jobs.

```powershell
# Decide whether expansion is required
Get-VirtualDisk | Format-Table FriendlyName, ProvisioningType, Size, FootprintOnPool
Get-Volume      | Sort-Object SizeRemaining | Format-Table FileSystemLabel, HealthStatus, Size, SizeRemaining
```

For thin-provisioned volumes, manual expansion may not be needed immediately. If fixed volumes need expansion, use Windows Admin Center or the standard PowerShell resize flow.

> [!WARNING]
> Do not consume all pool capacity. Preserve operational free space and rebuild reserve.

## Verification

```powershell
# Final cluster + storage health snapshot
Get-HealthFault
Get-ClusterNode | Sort-Object Name | Format-Table Name, State
Get-StorageJob

# Pool, virtual disk, and volume health
Get-StoragePool -IsPrimordial $false |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize
Get-VirtualDisk |
    Format-Table FriendlyName, HealthStatus, OperationalStatus
Get-Volume |
    Format-Table FileSystemLabel, HealthStatus, Size, SizeRemaining

# Final physical disk inventory; compare against the pre-check baseline
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, Size, FirmwareVersion, HealthStatus, Usage, CanPool, CannotPoolReason
```

Expected result:

- No health faults.
- All nodes are up.
- New disks are in the intended pool and healthy.
- Pool and virtual disks are healthy.
- No unexpected storage jobs remain.

## Troubleshooting

### Disks show `CanPool=False`

**Symptoms:** New disks are visible to Windows but `Get-PhysicalDisk` reports `CanPool=False` and pool capacity did not increase.
**Solution:** Follow the companion troubleshooting guide: [Troubleshoot - Physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md).

### Storage jobs run for an unexpectedly long time

**Symptoms:** `Get-StorageJob` continues to show active rebuild, regeneration, or optimize jobs for a long period after the add.
**Solution:** Long jobs are expected on large pools and HDD capacity tiers. Do not cancel storage jobs. Validate cluster health (`Get-HealthFault`, `Get-ClusterNode`) and let the jobs complete. Consult the storage diagnostics tool: [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md).

### Asymmetric disk distribution detected after insertion

**Symptoms:** The per-node symmetry check shows different disk counts per node after the add.
**Solution:** Stop further changes. Insert the missing disks on the asymmetric nodes to restore symmetry before any further pool changes or volume expansion.

## References

- [Adding servers or drives to Storage Spaces Direct](https://learn.microsoft.com/windows-server/storage/storage-spaces/add-nodes#adding-drives)
- [Troubleshoot Storage Spaces and Storage Spaces Direct health and operational states](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states)
- [Drive symmetry considerations](https://learn.microsoft.com/azure/azure-local/concepts/drive-symmetry-considerations)
- [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)

---
