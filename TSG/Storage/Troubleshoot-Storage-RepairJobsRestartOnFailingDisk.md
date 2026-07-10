# Troubleshoot storage repair jobs that restart and never complete (failing high-latency disk)

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Storage</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>High</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Day 2 Operations</strong>: Storage health / Disk failure / Volume stuck at No Redundancy</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>All Azure Local releases (Storage Spaces Direct)</strong></td>
  </tr>
</table>

## Overview

On a Storage Spaces Direct (S2D) cluster, a virtual disk (CSV volume) can become stuck in a state where its `Repair` and `Regeneration` storage jobs start, make little or no progress, then restart from the beginning and never converge to zero. The affected volume commonly reports `OperationalStatus = No Redundancy` and `HealthStatus = Unhealthy`, which is a data-at-risk condition.

The usual contributing factor is a single physical disk that is failing with extremely high latency and a high I/O error rate, but which the health service has not yet marked as failed (it still reports `HealthStatus = Healthy` with `OperationalStatus = "OK, Abnormal Latency"`). Because S2D still considers the drive usable, every repair attempt that must read from or write to that drive times out, and the job requeues. The volume cannot restore redundancy because the healthy copies cannot be rebuilt through the dying drive.

The same failing drive can also hang the storage completion path under heavy write I/O and trip a `DPC_WATCHDOG_VIOLATION` (bugcheck `0x133`) on the node that hosts the drive, so a node crash and the stuck repair are often two symptoms of one underlying disk fault.

An important trap: this scenario is frequently misread as a capacity problem, because the pool is often also over its capacity warning threshold. Freeing space does not resolve the stuck repair, and on thin volumes deleting data does not quickly return capacity to the pool. The failing disk is the actual blocker.

## Symptoms

- `Get-StorageJob` shows one or more `<Volume>-Repair` and `<Volume>-Regeneration` jobs that reset: `PercentComplete` returns to `0`, `BytesTotal` shrinks or changes between samples, and the job's elapsed time resets. Job count never drops to zero.
- `Get-VirtualDisk` shows a volume at `OperationalStatus = {No Redundancy, InService}` and `HealthStatus = Unhealthy`.
- `Get-PhysicalDisk` shows one drive with `OperationalStatus = "OK, Abnormal Latency"` while `HealthStatus` is still `Healthy`.
- `Get-HealthFault` reports a combination of:
  - `Microsoft.Health.FaultType.PhysicalDisk.HighLatency.Outlier.AverageIO` (average latency thousands to millions of times the peer drives).
  - `Microsoft.Health.FaultType.PhysicalDisk.HighErrorCount.Outlier.AverageIO` (I/O error count far above peer drives).
  - `Microsoft.Health.FaultType.VirtualDisks.NoRedundancy` (Critical) and `Microsoft.Health.FaultType.VirtualDisks.LastCopy` (Warning).
  - Often also `Microsoft.Health.FaultType.StoragePool.PoolCapacityThresholdExceeded` and `Microsoft.Health.FaultType.Server.Storage.Degraded`.
- Windows event log on the node that hosts the failing drive:
  - Source `disk`, Event ID **153**: "The IO operation at logical block address ... was retried." (often hundreds per hour).
  - Source `Microsoft-Windows-StorageSpaces-Driver`, Event IDs **203** ("failed an IO operation. Return Code: STATUS_DEVICE_NOT_CONNECTED"), **205** ("Windows lost communication with physical disk"), **207** ("Physical disk ... arrived", indicating the drive is flapping), **209** ("failed a Read IO operation. Return Code: The I/O device reported an I/O error").
  - Event ID **312** ("Virtual disk ... has failed a write operation to all its copies") and **302** ("pool disks hosting space meta-data ... failed a space meta-data update"), which accompany the No Redundancy state.
  - Event IDs **304** ("virtual disk ... is in a degraded state") and, after resolution, **305** ("Virtual disk ... is now healthy").
- Optional and correlated: a node bugcheck `0x00000133 DPC_WATCHDOG_VIOLATION` under heavy write I/O, with the faulting stack in the storage completion path (`storport` / `CLASSPNP` / the S2D cluster block filter), on the same node that hosts the failing drive. In the System log this appears as BugCheck (Event ID 1001) and Kernel-Power 41.

## Where the failing disk shows up (detection by surface)

The same failing drive is visible through several tools. Use whichever the admin has in front of them.

### PowerShell (most authoritative)

```powershell
# 1. The drive itself: Healthy but "Abnormal Latency".
Get-PhysicalDisk | Select-Object FriendlyName, SerialNumber, Usage, HealthStatus, OperationalStatus, PhysicalLocation

# 2. Health faults with reasons (latency and error outliers, plus the volume state).
Get-HealthFault | Select-Object FaultType, PerceivedSeverity, Reason, FaultingObjectDescription

# 3. Reliability counters: the hard evidence. On a real failing drive you see read/write
#    error totals in the thousands to millions and max latency in seconds, not milliseconds.
Get-PhysicalDisk -SerialNumber <SerialNumber> | Get-StorageReliabilityCounter |
  Select-Object ReadErrorsTotal, ReadErrorsUncorrected, WriteErrorsTotal, ReadLatencyMax, WriteLatencyMax, PowerOnHours
```

Example from a real case: `ReadErrorsTotal = 1,252,510`, `ReadLatencyMax = 11,708` ms (healthy peers are under ~20 ms), `PowerOnHours = 32,273` (about 3.7 years). In that case `ReadErrorsUncorrected = 0`, which is why the rebuild recovered all data. A drive with non-zero *uncorrected* errors that also holds the last copy is the data-loss case to worry about.

### Windows event log (on the node hosting the drive)

- `disk` **153** "The IO operation ... was retried" (leading indicator, often hundreds per hour).
- `Microsoft-Windows-StorageSpaces-Driver` **203** (failed IO / STATUS_DEVICE_NOT_CONNECTED), **205** (lost communication), **207** (drive "arrived" repeatedly, meaning it is flapping), **209** (failed Read IO / I/O device error).
- `Microsoft-Windows-StorageSpaces-Driver` **312** (write failed to all copies), **302** (space metadata update failed), **304** and **305** (virtual disk degraded, then healthy).

```powershell
Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='disk'; Id=153; StartTime=(Get-Date).AddHours(-24) } |
  Group-Object Id | Select-Object Name, Count
Get-WinEvent -LogName 'Microsoft-Windows-StorageSpaces-Driver/Operational' -MaxEvents 200 |
  Group-Object Id | Sort-Object Count -Descending
```

### Cluster log

The cluster log captures the health service and storage subsystem entries. Generate it and search the per-node logs for the drive's object ID and I/O status codes:

```powershell
Get-ClusterLog -Destination C:\Temp -TimeSpan 120
Select-String -Path C:\Temp\*_cluster.log -Pattern 'STATUS_IO_TIMEOUT','STATUS_DEVICE_NOT_CONNECTED','Abnormal Latency','NoRedundancy'
```

### Azure portal

For an Arc-connected Azure Local cluster, the physical-disk and virtual-disk health faults surface as **alerts** on the cluster resource (the Monitoring / Alerts area and the resource Health blade), and in Azure Monitor if it is configured. The `PhysicalDisk.HighLatency` / `HighErrorCount` and `VirtualDisks.NoRedundancy` faults appear there with the same fault text. The portal is good for noticing the condition; retirement itself is done from PowerShell or Windows Admin Center.

### Failover Cluster Manager and Windows Admin Center

- **Failover Cluster Manager** shows the cluster and CSV state. A degraded volume appears under Storage with the CSV in an online-degraded or warning state. FCM does not surface per physical-disk latency well.
- **Windows Admin Center** (the recommended GUI for S2D) shows per-drive health under the cluster Drives view, including the Warning status and latency, and offers Retire and Locate actions directly.

## What and Why

Storage Spaces Direct keeps three copies of three-way mirror data spread across three fault domains (nodes). When a drive begins to fail slowly, its SMART and health state can still read as `Healthy`, so S2D keeps scheduling I/O to it. Repair and regeneration jobs that touch slabs on that drive issue reads and writes that never complete within the storage timeout, the job is aborted and requeued, and you observe the restart loop. If the failing drive holds the only currently readable copy of a region, that region shows as `No Redundancy` and appears in `Get-PhysicalDisk -NoRedundancy` for the affected volume.

Under heavy write I/O, the same non-completing drive can leave a storage completion routine holding the processor dispatch level too long, which trips the DPC watchdog and bugchecks the node. That is why a node crash and a stuck repair frequently share one cause.

Why capacity is a red herring here:

- The pool capacity warning (`PoolCapacityThresholdExceeded`) is a `Minor` fault and is usually incidental. A repair that only needs to resync a few gigabytes is not blocked by a pool that is 85 percent full when there is still free reserve capacity.
- On thin-provisioned volumes, deleting files frees space inside the volume but does not immediately return the freed slabs to the pool. `Optimize-Volume -ReTrim` issues the unmap but pool reclaim can still lag. Do not expect deleting data to create rebuild headroom quickly.

## Resolution

The fix is to mark the failing drive `Retired` so S2D stops using it and rebuilds its data onto the remaining healthy drives, then physically replace it after the rebuild completes.

### Prerequisites

- Run all commands in an elevated PowerShell session on a cluster node.
- Confirm all cluster nodes are up: `Get-ClusterNode`. Do not start disk maintenance while a node is down, because that reduces the fault domains available for the rebuild.
- Understand the reserve-capacity model before you retire anything (see Step 3). You do **not** need a spare drive to recover.

### Before you retire: pre-checks and gotchas

Run through this list before Step 4. Most stuck or unsafe retires trace back to skipping one of these.

- **All nodes up.** Confirm `Get-ClusterNode` shows every node `Up`. Retiring a drive while a node is down removes a fault domain and can block the rebuild or drop below resiliency.
- **Only one fault domain affected.** Confirm no other drive is already `Retired`, failed, or `Lost Communication` on a *different* node: `Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne 'Healthy' -or $_.Usage -eq 'Retired' }`. Retiring a second drive in a second fault domain while a three-way mirror is already degraded can cause data loss.
- **Enough free reserve (Step 3).** Pool free must exceed the drive's used capacity, with reserve left over. Do not rely on deleting data to create it at the last minute; thin reclaim is slow.
- **Check for last-copy data.** Run `Get-VirtualDisk -FriendlyName <VolumeName> | Get-PhysicalDisk -NoRedundancy`. If the failing drive is returned, some regions have no other copy; retiring is still correct but is a data-at-risk operation (see the Step 4 caveat). Also check `ReadErrorsUncorrected` on the drive: non-zero uncorrected read errors on a last-copy drive is the worst case.
- **Not during an update or CAU run.** Do not retire a drive while a solution update, Cluster-Aware Updating run, or node maintenance is in progress. Wait for a quiet window so the rebuild is not competing with reboots and storage maintenance.
- **Expect node instability if the same drive is crashing the node.** If the failing drive is also tripping `DPC_WATCHDOG_VIOLATION` bugchecks, the hosting node may reboot during triage. Retiring the drive is what stops that, but plan for the node to bounce until it is retired.
- **Do not `Remove-PhysicalDisk` before the rebuild finishes.** Removing (as opposed to retiring) pulls the drive from the pool; doing it before evacuation completes can lose data still on the drive. Retire first (Step 4), let the jobs drain (Step 5), then remove (Step 6).
- **Have a replacement on order.** You do not need the spare to recover, but order a supported-model drive so you can physically replace the retired one and restore the full drive count.

### Steps

#### Step 1: Confirm the restart loop and the affected volume

```powershell
# Sample twice, ~60 seconds apart. A stuck repair shows PercentComplete resetting
# toward 0 and BytesTotal changing between samples, and the count never reaches 0.
Get-StorageJob | Select-Object Name, JobState, PercentComplete, BytesProcessed, BytesTotal

# The affected volume reports No Redundancy / Unhealthy.
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, OperationalDetails
```

#### Step 2: Identify the failing physical disk

```powershell
# Authoritative reasons. Look for HighLatency / HighErrorCount on a physical disk,
# plus VirtualDisks.NoRedundancy / LastCopy on the volume.
Get-HealthFault | Select-Object FaultType, PerceivedSeverity, Reason, FaultingObjectDescription

# The failing drive: Healthy but "Abnormal Latency".
Get-PhysicalDisk | Where-Object { ($_.OperationalStatus -join ',') -match 'Abnormal Latency' } |
  Select-Object FriendlyName, SerialNumber, UniqueId, PhysicalLocation, HealthStatus, OperationalStatus

# Corroborate with the reliability counters (read/write error totals, latency).
Get-PhysicalDisk -SerialNumber <SerialNumber> | Get-StorageReliabilityCounter |
  Select-Object DeviceId, ReadErrorsTotal, WriteErrorsTotal, ReadLatencyMax, WriteLatencyMax

# Confirm whether this drive holds the LAST copy of any region of the volume.
# If it returns this drive, retiring it is a last-copy operation (see Step 4 caveat).
Get-VirtualDisk -FriendlyName <VolumeName> | Get-PhysicalDisk -NoRedundancy |
  Select-Object FriendlyName, SerialNumber, OperationalStatus
```

Record the drive's `UniqueId`; you will use it in Step 4 and Step 6.

#### Step 3: Confirm there is enough reserve capacity to rebuild (no spare required)

S2D does not use dedicated hot spares. It rebuilds a retired or failed drive's data into free **reserve capacity** distributed across the remaining drives and nodes. You do not need a replacement drive in hand to recover redundancy. What you need is enough free capacity in the surviving fault domains, with the general guidance being to keep roughly one capacity drive's worth of space free per server (up to four).

```powershell
# 1. How much data must be rebuilt elsewhere equals the USED (allocated) capacity of the
#    failing drive. A retire evacuates the drive's whole allocated content, not just a
#    "dirty" delta. Read this BEFORE you retire; afterward it drops toward zero.
Get-PhysicalDisk -UniqueId <DiskUniqueId> |
  Select-Object FriendlyName,
    @{n='UsedGB';e={[math]::Round($_.AllocatedSize/1e9,1)}},
    @{n='SizeGB';e={[math]::Round($_.Size/1e9,1)}}

# 2. Pool free space and fill level.
Get-StoragePool -FriendlyName <PoolName> |
  Select-Object FriendlyName, HealthStatus,
    @{n='UsedPct';e={[math]::Round(100*$_.AllocatedSize/$_.Size,1)}},
    @{n='FreeTB';e={[math]::Round(($_.Size-$_.AllocatedSize)/1e12,2)}}

# 3. Per-drive fill. No single healthy capacity drive should be at or near 100 percent,
#    and the surviving nodes must have room to take the rebuilt copies.
Get-PhysicalDisk | Where-Object Usage -eq 'Auto-Select' |
  Select-Object FriendlyName,
    @{n='PctAlloc';e={[math]::Round(100*$_.AllocatedSize/$_.Size,1)}} |
  Sort-Object PctAlloc -Descending | Select-Object -First 5
```

The check: **pool free space must exceed the failing drive's used capacity**, and you should still have reserve left afterward (about one capacity drive per node). Because three-way mirror places copies across three nodes, the free space also has to be distributed so the surviving nodes can each hold their share. If one node's drives are all near 100 percent, the rebuild for slabs that need that node stalls even when the pool total looks fine.

Worked example from a real case: the failing 2.4 TB drive held about 2.0 TB of data (its used capacity), and the pool had about 10.8 TB free (roughly 86 percent full). Free space (10.8 TB) comfortably exceeded both the ~2.0 TB that had to be rebuilt and the ~9.6 TB reserve target (one 2.4 TB drive per node across four nodes), so the retire was safe and the rebuild completed.

If the pool has essentially no free reserve (for example above roughly 95 percent with no per-node headroom), retiring the drive can leave S2D with nowhere to rebuild and the volume stays degraded. In that case add capacity or reduce data first, then retire. Remember that on thin volumes, deleting data does not free pool space quickly, so plan the reserve ahead of time rather than deleting at the last minute.

#### Step 4: Retire the failing drive  [MEDIUM RISK]

```powershell
# Marks the drive do-not-use and starts the evacuation/rebuild onto healthy drives.
Set-PhysicalDisk -UniqueId <DiskUniqueId> -Usage Retired

# Verify.
Get-PhysicalDisk -UniqueId <DiskUniqueId> | Select-Object FriendlyName, Usage, OperationalStatus
```

Caveat when the drive is a last-copy holder (Step 2 returned it under `-NoRedundancy`): retiring forces S2D to read those regions off the dying drive to rebuild them. Any region the drive can no longer read cannot be rebuilt and that data is lost. Retiring is still the correct action, because it triggers the evacuation while the drive is at least partly alive; leaving the drive in service guarantees the volume stays at No Redundancy. Retire sooner rather than later to maximize what can be salvaged.

#### Step 5: Monitor the rebuild

Retiring the drive starts an evacuation. You will see a pair of jobs, `<Volume>-Repair` and `<Volume>-Regeneration`, for **every** virtual disk that had data on the retired drive (typically all of the UserStorage volumes plus the small `Infrastructure_1` and `ClusterPerformanceHistory` volumes). `Repair` restores resiliency and `Regeneration` rebuilds the missing copies. They run in parallel, should climb monotonically toward 100 percent, then disappear as the job count drops to zero. This is the opposite of the reset loop in Step 1: real, increasing `BytesProcessed` against a stable `BytesTotal`.

```powershell
# Repair/Regeneration jobs should now show a real, monotonically climbing scope
# (not the reset loop), then drain to zero.
Get-StorageJob | Select-Object Name, JobState, PercentComplete, BytesProcessed, BytesTotal

# The volume returns to Healthy / OK and the NoRedundancy fault clears.
Get-VirtualDisk -FriendlyName <VolumeName> | Select-Object HealthStatus, OperationalStatus
Get-HealthFault | Select-Object FaultType, PerceivedSeverity
```

If no repair jobs start within a few minutes of retiring the drive, trigger one explicitly:

```powershell
Repair-VirtualDisk -FriendlyName <VolumeName>
```

During evacuation the pool used percentage rises briefly as replacement copies are written, then settles as the retired drive's slabs are released. This is expected.

The rebuild is complete when all of the following are true: `Get-StorageJob` returns nothing, every volume is `HealthStatus = Healthy` / `OperationalStatus = OK`, the `VirtualDisks.NoRedundancy` and `LastCopy` faults have cleared, and the retired drive's used capacity (`AllocatedSize`) has dropped to near zero because its data now lives elsewhere. Only then proceed to Step 6.

#### Step 6: Physically replace and remove the drive  [MEDIUM RISK]

Only after the rebuild jobs reach zero and the volumes are Healthy:

```powershell
# Turn on the location indicator (if supported) to find the drive in the chassis.
Get-PhysicalDisk -UniqueId <DiskUniqueId> | Enable-PhysicalDiskIndication

# Remove the retired drive from the pool, then physically swap it.
Remove-PhysicalDisk -UniqueId <DiskUniqueId> -StoragePoolFriendlyName <PoolName>
```

A replacement drive of a supported model is claimed automatically (or add it manually per the Add-Physical-Disks TSG). No manual repair trigger is normally required; S2D rebalances onto the new drive.

## Prevention

- Keep reserve capacity free at all times, roughly one capacity drive per server (up to four). This is what lets you retire or lose a drive and rebuild in place without a spare, and without hitting the capacity wall mid-rebuild.
- Treat the `PhysicalDisk.HighLatency.Outlier.AverageIO` and `PhysicalDisk.HighErrorCount.Outlier.AverageIO` health faults as early warnings. A drive that is Healthy but showing "Abnormal Latency" is a retire candidate before it stalls a repair or bugchecks a node.
- Watch for repeated `disk` Event ID 153 ("was retried") and Storage Spaces Event IDs 203/205/209 against a single drive. A rising count on one drive is the leading indicator.
- Do not rely on deleting data to create rebuild headroom in a hurry. On thin volumes the freed space is not returned to the pool immediately even after `Optimize-Volume -ReTrim`. Plan reserve capacity in advance instead.

## Data to Collect Before Opening a Support Case

```powershell
# Cluster + storage state snapshot
Get-ClusterNode | Select-Object Name, State
Get-StoragePool -FriendlyName <PoolName> | Select-Object FriendlyName, HealthStatus, Size, AllocatedSize
Get-VirtualDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, ProvisioningType
Get-PhysicalDisk | Select-Object FriendlyName, SerialNumber, MediaType, Usage, HealthStatus, OperationalStatus
Get-StorageJob | Select-Object Name, JobState, PercentComplete, BytesProcessed, BytesTotal
Get-HealthFault | Select-Object FaultType, PerceivedSeverity, Reason, FaultingObjectDescription

# Reliability counters for the suspect drive
Get-PhysicalDisk -SerialNumber <SerialNumber> | Get-StorageReliabilityCounter

# Event logs from the node hosting the drive
Get-WinEvent -FilterHashtable @{ LogName='System'; Id=153; StartTime=(Get-Date).AddHours(-24) } |
  Select-Object TimeCreated, Id, Message -First 50
Get-WinEvent -LogName 'Microsoft-Windows-StorageSpaces-Driver/Operational' -MaxEvents 200

# Last 60 minutes of cluster log to C:\Temp
Get-ClusterLog -Destination C:\Temp -TimeSpan 60
```

## Related Issues

- Troubleshoot the storage pool capacity threshold warning (fixed vs thin volumes): `TSG/Storage/Troubleshoot-Storage-StoragePoolCapacityThreshold.md`. Use this when the primary problem is capacity rather than a failing drive.
- Troubleshoot physical disks not claimed after insertion (`CanPool=False`): `TSG/Storage/Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md`. Use this when claiming the replacement drive in Step 6.
- Troubleshooting storage with the Support Diagnostics Tool: `TSG/Storage/Troubleshooting-Storage-With-Support-Diagnostics-Tool.md`.

## References

- Replace drives in Storage Spaces Direct (retire with `Set-PhysicalDisk -Usage Retired`, then `Remove-PhysicalDisk`): https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/replace-drives
- Plan volumes and reserve capacity for repairs: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/plan-volumes#reserve-capacity
- Storage Spaces and Storage Spaces Direct health and operational states: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/storage-spaces-states
- Fault tolerance and storage efficiency in Storage Spaces Direct: https://learn.microsoft.com/en-us/windows-server/storage/storage-spaces/fault-tolerance
- `Remove-PhysicalDisk` PowerShell reference: https://learn.microsoft.com/en-us/powershell/module/storage/remove-physicaldisk
