<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "how-to",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Add-PhysicalDisk"
  },
  "validation": {
    "fidelity_level": "L3",
    "technical_grade": null,
    "reproduction_substrate": "either",
    "automation_status": "ready",
    "last_validated": "2026-08-17",
    "spec_ref": "AzLocal_Storage_AddPhysicalDisksToS2DPool"
  }
}
-->

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

## At a Glance

**Bottom line:** Insert the same number of supported disks into each node, then let Storage Spaces Direct (S2D) claim them. On a healthy cluster, S2D automatically claims eligible disks within a few minutes (about 3 minutes in lab validation). Confirm the pool grew, then verify health. Volume expansion, if it is needed at all, waits until storage jobs finish.

- **Impact:** Online capacity expansion. Running VMs stay online; no downtime or live migration is expected. Background redistribution jobs may add storage latency until they settle.
- **Owner:** The cluster storage administrator runs the procedure. Involve the hardware OEM for disk seating, supported models, and firmware. Escalate to Microsoft CSS if disks stay `CanPool=False` or the pool is unhealthy.
- **Duration:** The add itself takes minutes. Background redistribution and optimization jobs can run for hours to days on large or HDD-heavy pools; this is expected and is not downtime.
- **Skip this guide for:** replacing failed disks, adding nodes, recovering an unhealthy pool, or unsupported disk models or firmware. See [When to Use This Guide](#when-to-use-this-guide).

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
> Some hardware OEMs publish hardware-lifecycle wizards as Windows Admin Center (WAC) extensions that include guided disk-add flows, for example **Dell OpenManage Integration with Microsoft Windows Admin Center (OMIMSWAC)**, with similar tooling available from other major Azure Local OEMs. These extensions can be a more convenient alternative to the PowerShell sequence below.
>
> Caveats:
> - OEM WAC extensions are only supported on **standalone (on-premises)** installations of Windows Admin Center, not the WAC instance embedded in the Azure portal. See [Manage Azure Local clusters using Windows Admin Center in Azure](https://learn.microsoft.com/windows-server/manage/windows-admin-center/azure/manage-hci-clusters) for the supported scope of the embedded WAC.
> - The PowerShell flow in this TSG remains the canonical path when an OEM wizard is unavailable, fails, or finer-grained control is needed (for example, when troubleshooting `CanPool=False`).

## Key Terms

Short definitions for readers new to Storage Spaces Direct:

- **Storage Spaces Direct (S2D):** the Azure Local software that pools the local disks from every node into one shared, resilient storage pool.
- **Storage pool:** the collection of physical disks that S2D draws capacity from. A healthy cluster has exactly one usable pool.
- **Primordial pool and non-primordial pool:** the primordial pool is the built-in list of disks not yet added to storage; the non-primordial pool is the real, in-use S2D pool. This guide always targets the non-primordial pool.
- **`CanPool`:** a true or false property on each physical disk. `CanPool=True` means the disk is eligible to be added to the pool; `CanPool=False` means it is not, for example because it is already `In a Pool`.
- **Storage job:** a background task (rebuild, regeneration, optimize, or rebalance) that S2D runs to move or repair data. Wait for jobs to finish before making more changes.
- **Rebuild reserve:** spare pool capacity kept free so S2D can rebuild data if a disk fails. Do not consume it.
- **Thin and fixed provisioning:** a thin volume grows on demand and usually needs no manual expansion; a fixed volume is sized up front and may need a manual resize to use new capacity.

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

- [At a Glance](#at-a-glance)
- [Overview](#overview)
- [What and Why](#what-and-why)
- [Key Terms](#key-terms)
- [Prerequisites](#prerequisites)
- [Pre-check Commands](#pre-check-commands)
- [Add Disks](#add-disks)
- [Monitor Redistribution and Storage Jobs](#monitor-redistribution-and-storage-jobs)
- [Confirm Added Capacity](#confirm-added-capacity)
- [Expand Volumes](#expand-volumes)
- [Verification](#verification)
- [Evidence and Escalation](#evidence-and-escalation)
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

Each node should have the same count for each combination of media type and size used by the cluster. Grouping by media type alone can hide a capacity mismatch, where disks of the same media type but different sizes pass as symmetric and later strand capacity.

```powershell
# Per-node disk counts grouped by media type AND size; counts should match across nodes
Get-StorageNode | ForEach-Object {
    $node = $_
    Get-PhysicalDisk -StorageNode $node |
        Group-Object MediaType, Size |
        ForEach-Object {
            [PSCustomObject]@{
                Node      = $node.Name
                MediaType = $_.Group[0].MediaType
                SizeGB    = [math]::Round($_.Group[0].Size / 1GB, 0)
                Count     = $_.Count
            }
        }
} | Sort-Object Node, MediaType, SizeGB | Format-Table
```

> [!WARNING]
> Adding disks asymmetrically, whether a different count per node or a different size for the same media type, can strand capacity and reduce resiliency. Match the count per media type and per size across all nodes before adding the new disks to the pool.

## Add Disks

### Step 1: Insert Disks Symmetrically

Add the same number of supported disks to each node. Keep slot placement consistent across nodes if the hardware platform supports a consistent slot layout.

> [!NOTE]
> Do not reboot nodes as part of this procedure unless the hardware vendor explicitly requires it.

> [!NOTE]
> Hardware end-state for an OEM field engineer: after seating the disks, confirm each one is a supported model and firmware and is visible to Windows in `Get-PhysicalDisk`, then hand back to the cluster storage administrator, who owns the pooling steps that follow. Seating the disks and their firmware are the hardware boundary; pooling a disk into S2D is the Azure Local boundary. This is a hardware add, not an Azure Local software fault.

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
- An eligible new disk reports `CanPool=True` with an empty `CannotPoolReason`. After Storage Spaces Direct claims the disk, `CanPool` becomes `False` and `CannotPoolReason` reads `In a Pool`.

> [!NOTE]
> `CanPool` is a true or false property, whereas `In a Pool` is a `CannotPoolReason` value; they are separate fields, so do not read them as interchangeable states. Immediately after insertion a disk can be briefly ineligible while Storage Spaces verifies it, so wait a few minutes and re-run the inventory before deciding anything. In a mixed-media pool, S2D assigns each disk to the cache or capacity tier by its `MediaType`, so confirm `MediaType` matches the plan. A nested or virtual disk can report `MediaType` `Unspecified` until it is claimed, after which it resolves, for example to `HDD`.

> [!NOTE]
> Reused disks that were previously part of another pool can arrive with a `CannotPoolReason` and report `CanPool=False` rather than being immediately eligible. Do not force them in; follow the companion guide [Troubleshoot - Physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md).

> [!CAUTION]
> If the disks do not appear, check hardware visibility (slot, cabling, vendor management UI) first. Do **not** run storage reset commands for disks that are not visible or not identified.

### Step 3: Wait for Automatic Pooling

Storage Spaces Direct normally claims eligible disks and adds them to the pool automatically. Allow roughly 5 to 10 minutes for this to happen; in lab validation S2D claimed an eligible disk in about 3 minutes. Only move to the manual step below if the disks still report `CanPool=True` after that window.

```powershell
# Look for unclaimed eligible disks
Get-PhysicalDisk -CanPool $true |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, Size, FirmwareVersion
```

If this returns no rows and the new disks show `CannotPoolReason = In a Pool`, the disks were claimed automatically.

### Step 4: Manually Add Disks Only When Needed

[MEDIUM RISK] Manual add changes storage pool membership. It is appropriate when automatic pooling does not claim eligible disks, the target pool is known, and the disks show `CanPool=True`.

First, inspect the current pool and eligible disks:

```powershell
# Inspect the target pool and the eligible disks
$pool          = Get-StoragePool -IsPrimordial $false
$eligibleDisks = Get-PhysicalDisk -CanPool $true

$pool          | Format-Table FriendlyName, HealthStatus, OperationalStatus
$eligibleDisks | Format-Table DeviceId, FriendlyName, UniqueId, SerialNumber, MediaType, Size, FirmwareVersion
```

> [!IMPORTANT]
> A healthy Storage Spaces Direct cluster has exactly one non-primordial pool. The snippet below enforces that and requires the operator to enumerate the intended new disks by `UniqueId`, so `Add-PhysicalDisk` cannot accidentally claim unintended `CanPool=True` disks. `UniqueId` is the stable key; `SerialNumber` is only a human cross-check, because nested and virtual data disks frequently report an empty `SerialNumber` and so cannot be selected on it reliably.

```powershell
# Defensive: require exactly one non-primordial pool. Abort otherwise.
$pool = Get-StoragePool -IsPrimordial $false
if (@($pool).Count -ne 1) {
    throw "Expected exactly one non-primordial pool. Found $(@($pool).Count). " +
          "Select the target pool explicitly by FriendlyName before continuing."
}

# Operator MUST enumerate the intended new disks by UniqueId (the stable key).
# SerialNumber is only a human cross-check; nested and virtual data disks
# frequently report an EMPTY SerialNumber, so it is NOT a safe selector.
# Do NOT pipe Get-PhysicalDisk -CanPool $true directly into Add-PhysicalDisk.
$intendedUniqueIds = @(
    '<unique-id-1>',
    '<unique-id-2>'
)

# Resolve UniqueIds to physical disk objects and confirm the count matches the intent.
# Wrap in @() so .Count is reliable when 0 or 1 disk matches.
$disksToAdd = @(Get-PhysicalDisk -CanPool $true |
                Where-Object UniqueId -in $intendedUniqueIds)
if ($disksToAdd.Count -ne $intendedUniqueIds.Count) {
    throw "Disk count mismatch: $($disksToAdd.Count) eligible disks matched " +
          "the $($intendedUniqueIds.Count) intended UniqueIds. Resolve before continuing."
}

# Human cross-check: review the exact disks that will be added.
$disksToAdd | Format-Table UniqueId, SerialNumber, DeviceId, FriendlyName, MediaType, Size

# Preview the operation first. -WhatIf makes no change.
Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $disksToAdd -WhatIf

# Require explicit operator confirmation before the real add.
$confirm = Read-Host "Add the $($disksToAdd.Count) disk(s) above to pool '$($pool.FriendlyName)'? Type YES to proceed"
if ($confirm -ne 'YES') {
    throw "Operator did not confirm. No disks were added."
}

# Confirmed: add only the explicitly identified disks to the target pool.
Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $disksToAdd
```

## Monitor Redistribution and Storage Jobs

After disks are added, Storage Spaces Direct may run background jobs to optimize and redistribute data.

> [!NOTE]
> Running VMs stay online throughout the add and the redistribution that follows, and no live migration is required. Workloads may see some extra storage latency while jobs run, easing as the jobs complete.

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

## Evidence and Escalation

For a Microsoft CSS engineer guiding this remotely, collect the following so the outcome is provable and any handoff is clean:

- The pre-check baseline and the final `Get-PhysicalDisk` inventory (Pre-check Step 3 and Verification), so the added serial numbers are documented.
- `Get-StoragePool`, `Get-VirtualDisk`, `Get-StorageJob`, `Get-HealthFault`, and `Get-ClusterNode` output from before and after the change.
- A storage diagnostics bundle: run `Start-AzsSupportStorageDiagnostic` with the `StorageSummary` and `StorageHealth` collectors. See [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md).
- Relevant event logs: the `Microsoft-Windows-StorageSpaces-Driver` operational log and the Health Service events on the node where the disk was inserted.

Escalate as follows:

- To the hardware OEM when a disk is not visible to Windows, stays `CanPool=False` for a hardware or firmware reason, or the model or firmware is not supported. Confirm seating, cabling, model, and firmware first.
- To the Microsoft product group when the disk is visible and supported, health and jobs are clean, yet the pool still does not claim or grow after the checks above. Attach the diagnostics bundle and the before and after inventory.

### Where the add is and is not visible

- **Node PowerShell:** the primary surface. `Get-PhysicalDisk` and `Get-StoragePool` show the new disk and the pool growth, and are used throughout this guide.
- **Azure portal:** shows increased capacity after redistribution, not the add as a discrete event.
- **Windows event logs:** no single event marks the add; the `Microsoft-Windows-StorageSpaces-Driver` operational log and the Health Service events on the target node are the closest signal.
- **Cluster logs (`Get-ClusterLog`):** do not record the add itself; they help only for correlating storage-job activity.
- **Windows Failover Cluster Manager:** does not show the add; use it only for node and CSV state.
- **Component and tool log files:** no dedicated on-disk log file records the add; if you run `Start-AzsSupportStorageDiagnostic` (collectors `StorageSummary` and `StorageHealth`), its output bundle is the on-disk report, otherwise none is written for the add itself.

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
