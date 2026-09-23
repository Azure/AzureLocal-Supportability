<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Get-HealthFault"
  },
  "validation": {
    "fidelity_level": "L3",
    "technical_grade": null,
    "reproduction_substrate": "hardware",
    "automation_status": "ready",
    "last_validated": "2026-08-17",
    "spec_ref": "AzStackHci_Storage_StoragePoolCapacityThreshold"
  }
}
-->

# Troubleshoot the storage pool capacity threshold warning (fixed vs thin volumes)

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
    <td><strong>Day 2 Operations</strong>: Capacity management / Update readiness</td>
  </tr>
  <tr>
    <th style="text-align:left;">Affected Versions</th>
    <td><strong>All Azure Local releases (Storage Spaces Direct)</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Article Type</th>
    <td><strong>Troubleshooting guide</strong></td>
  </tr>
  <tr>
    <th style="text-align:left;">Validation Scope</th>
    <td><strong>Use read-only checks first.</strong> Do not validate this by filling a production pool. If lab validation is needed, use an isolated scratch volume on physical S2D hardware.</td>
  </tr>
</table>

> **In plain terms:** the storage *pool*, the shared disk capacity behind every
> volume on the cluster, is filling up. Deciding what to do is a capacity task for
> the **cluster / storage administrator**; it is usually not urgent, but if the pool
> is genuinely allowed to fill, virtual machines can pause or go offline. Run the
> **Quick triage** below to find which of two fixes applies.

## At a glance

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Business impact</th>
    <td><strong>Usually low</strong>: a reserve-capacity and update-readiness early
    warning. (The page severity <em>Medium</em> reflects the signal, not day-to-day
    impact.) <strong>High only if the pool is allowed to fill</strong>: thin-volume
    writes can then fail and affected VMs can pause or go offline (unplanned outage).</td>
  </tr>
  <tr>
    <th style="text-align:left;">Who owns this</th>
    <td>The customer's <strong>cluster / storage administrator</strong> (capacity
    management). It is <strong>not</strong> a networking issue, and not an OEM issue
    unless you are adding or replacing physical disks.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Typical time to resolve</th>
    <td>Triage: minutes. Adding disks (A1) or adjusting the alert (A4/A5): low and
    online. Converting fixed&rarr;thin (A2) or the thin reclaim (Path B): a
    maintenance window; slab consolidation can take <strong>hours</strong> on large
    volumes. If whole VMs or files were simply deleted, Path B's no-downtime
    pre-branch may resolve it in about 15 minutes with no window at all.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Downtime / maintenance window</th>
    <td>Triage and the add-capacity / alert options (A1, A4, A5) are
    <strong>online</strong>. <strong>A2</strong> (convert, then Path B) and
    <strong>A3</strong> (evacuate + recreate a volume) require data movement.
    <strong>Path B</strong> is conditional: reclaiming capacity from
    <strong>deleted whole files</strong> is automatic and needs
    <strong>no downtime</strong>; only <strong>interior fragmentation</strong>
    requires slab consolidation and a VM-offline window.</td>
  </tr>
</table>

## Quick triage (start here)

Run this on any cluster node. It shows how full the pool is and, crucially, whether
the volumes are **Fixed** or **Thin**, which decides the entire remediation path:

```powershell
# 1) How full is the pool? (allocation vs total size)
Get-StoragePool | Where-Object IsPrimordial -eq $false |
    Format-Table FriendlyName, Size, AllocatedSize,
        @{N='UsedPct';E={[math]::Round(100*$_.AllocatedSize/$_.Size,1)}} -AutoSize

# 2) Are the volumes Fixed or Thin? (this decides the fix)
Get-VirtualDisk | Format-Table FriendlyName, ProvisioningType, Size, FootprintOnPool -AutoSize

# 3) Any active storage health faults?
Get-HealthFault
```

Then branch on `ProvisioningType`:

- **`Fixed`** &rarr; the pool footprint is committed by design; the fix is to add
  capacity, convert to thin, or adjust the alert. Go to
  [Path A](#path-a-fixed-provisioned-volumes).
- **`Thin`** &rarr; capacity from deleted data can be reclaimed. Go to
  [Path B](#path-b-thin-provisioned-volumes-reclaim-unused-capacity). If whole VMs
  or files were deleted, its no-downtime pre-branch may be all you need; only
  interior fragmentation needs a maintenance window.

> [!NOTE]
> This is the short form of
> [Step 1](#step-1-determine-the-provisioning-type-required-first), surfaced up top.
> The full guide below explains *why* and covers every option in detail. Read on if
> triage alone does not resolve it.

> [!NOTE]
> **Running this across many nodes or sites.** Pool allocation and provisioning
> type are cluster-wide, so the triage above is run once per cluster from any
> node. To check several clusters at once, wrap the same read-only block in
> `Invoke-Command -ComputerName <one-node-per-cluster> { ... }`; it is safe to
> script across identical sites. The capacity event log (EventIDs 103, 104, and
> 310) is the exception: collect it on **every node**, because the pool owner
> logs it and ownership can move (see
> [Data to Collect](#data-to-collect-before-opening-a-support-case)).

## Overview

This guide explains the Storage Spaces Direct (S2D) **storage pool capacity
threshold warning** and the supported options for resolving it. The warning
fires when pool allocation crosses the configured threshold (the thin
provisioning alert threshold defaults to **70%**).

The warning is **not a false alarm**: S2D needs free pool capacity in reserve so
that storage repair jobs can rebuild resiliency after a drive or node is lost. It
is, however, frequently misunderstood on clusters that use **fixed-provisioned**
volumes, because a fixed volume commits its entire size to the pool the moment it
is created, so the pool can sit above the threshold even when the volume's file
system is mostly empty.

The single most important step is to **determine whether the affected volumes are
fixed or thin provisioned before taking any action**, because the space
reclamation procedure (`Optimize-Volume -SlabConsolidate`, then waiting for the
ReFS background unmap to release the freed slabs) **does nothing on a
fixed-provisioned volume** and only applies to thin-provisioned volumes.

## Terminology

Short definitions for the terms used in this guide:

- **Storage pool:** the cluster-wide set of physical drives that Storage Spaces
  Direct (S2D) manages as one unit. Every volume is carved out of the pool.
- **S2D (Storage Spaces Direct):** the Azure Local software-defined storage layer
  that pools each server's local drives into shared, resilient storage.
- **CSV (Cluster Shared Volume):** a volume mounted under `C:\ClusterStorage\` that
  every node can use at once; where VM disks (`.vhdx`) live.
- **ReFS (Resilient File System):** the file system used for Azure Local volumes.
- **Thin vs Fixed provisioning:** a **thin** volume consumes pool capacity only as
  data is written; a **fixed** volume reserves its full size in the pool the moment
  it is created (see
  [Why fixed-provisioned volumes hit this so easily](#why-fixed-provisioned-volumes-hit-this-so-easily)).
- **Footprint (`FootprintOnPool`):** how much pool capacity a volume actually
  occupies, *including* its resiliency copies (for example, a three-way mirror uses
  3&times; the written data).
- **Slab:** the 256 MB unit S2D allocates pool capacity in. A slab returns to the
  pool only when every block in it is free.
- **Unmap:** the background ReFS operation that returns emptied slabs to the pool
  after data is deleted or consolidated.
- **Primordial pool:** the built-in pool of drives not yet added to an S2D pool;
  filter it out with `Where-Object IsPrimordial -eq $false`.

## Symptoms

**Observable behaviors:**

- A storage pool capacity / threshold health fault is raised against the pool
  (surfaced in Windows Admin Center and by the cluster Health Service).
- `Get-StoragePool` shows the pool allocated at or above the threshold
  (commonly 70%+), even though volumes report significant free space inside.
- Solution update (upgrade) readiness checks flag a storage pool capacity warning.
  This is a bypassable warning, but addressing it before an update is strongly
  recommended (see [What and why](#what-and-why)).
- On Azure Local 23H2+ with Arc VMs, new virtual disk creation may fail with an
  out-of-capacity error from the underlying virtualization layer once the pool is
  near full, even though the volume looks fine in Windows Admin Center.

## Where this appears, and where it does not

Use these surfaces to orient the customer before choosing Path A or Path B:

| Surface | What to expect |
|---|---|
| PowerShell on a node | `Get-StoragePool`, `Get-VirtualDisk`, and `Get-HealthFault` show the pool allocation, provisioning type, and active storage health faults. |
| Azure portal | The Azure Local cluster's Resource Health, Insights health view, or update-readiness surface can show the pool-capacity warning on an Arc-connected cluster. |
| Windows event logs | `Microsoft-Windows-StorageSpaces-Driver/Operational` carries the provider-scoped events listed in [Data to Collect Before Opening a Support Case](#data-to-collect-before-opening-a-support-case). |
| Cluster logs | `Get-ClusterLog` can help Microsoft Support correlate ownership moves, storage jobs, and cluster resource state around the capacity event. |
| Windows Admin Center on a standalone host | The Storage and health views can show the storage pool capacity warning and current pool utilization. |
| Windows Admin Center in the Azure portal | No separate WAC-in-portal signal is expected for this warning. Use the Azure portal health and update-readiness views instead. |
| Failover Cluster Manager | No dedicated Failover Cluster Manager signal is expected for a capacity-threshold warning by itself. Use it only to confirm VM or CSV state if capacity pressure has already caused workload impact. |
| Component / tool log files on disk | No separate tool-specific on-disk log or diagnostic log file is written for this capacity threshold. Collect the Storage Spaces event log, `Get-HealthFault`, storage cmdlet output, and the cluster log instead. |

## What and Why

### Why the warning exists

When a capacity drive (or a whole node) is lost, S2D automatically starts repair
("auto-heal") jobs that re-create the missing copies of your data on the
remaining drives to restore full resiliency. Those repair jobs need somewhere to
write; they consume free pool capacity. If the pool has no reserve, repair jobs
have nowhere to rebuild and remain **suspended** until the failed drive is
physically replaced, leaving the volume running with reduced (or no) redundancy
in the meantime.

For this reason Microsoft recommends keeping free pool capacity in reserve. The
guidance is to reserve **the equivalent of one capacity drive per server, up to a
maximum of four drives** (reserve grows for parity and multi-tier
configurations). See
[Plan volumes, reserve capacity](https://learn.microsoft.com/windows-server/storage/storage-spaces/plan-volumes).

This is especially important on **small clusters (for example, two nodes with a
two-way mirror)**: during an update, nodes are drained and rebooted one at a
time, and a full pool leaves no headroom for the storage layer to keep data
resilient through the drain.

### Why fixed-provisioned volumes hit this so easily

Volumes on Azure Local are either **Thin** or **Fixed** provisioned (thin is the
default for new volumes; the default can be changed at the pool level):

- **Fixed:** the volume reserves its full size in the pool at creation time. A
  fixed volume on an N-way mirror commits **N × the volume size** of pool
  footprint up front, regardless of how much data is actually written into it.
  Deleting data inside the volume does **not** return capacity to the pool.
- **Thin:** the volume consumes pool capacity only as data is written, and unused
  capacity can (with the procedure below) be returned to the pool.

So a large fixed volume can push the pool over the threshold purely by design.
That is customer-chosen over-provisioning, not a stranded-capacity defect, and it
is not recoverable by the thin reclamation procedure.

### Two different threshold controls (do not confuse them)

- The **thin provisioning alert threshold** (default 70%) is the percentage the
  Health Service evaluates the pool against. Change it with
  `Set-StoragePool -ThinProvisioningAlertThresholds`.
- The **Health Service pool capacity alert** is a master on/off switch over that
  evaluation, toggled with `Set-StorageHealthSetting`
  (`System.Storage.StoragePool.ThresholdAlert.Enabled`).

These are layered, not alternatives: raising the threshold (Option A5) has no
effect if the Health Service alert has already been disabled (Option A4), and
disabling the alert silences it regardless of the threshold value. Decide which
layer you intend to act on before changing anything.

### Pool capacity is not the same as volume capacity (do not confuse the signals)

Two different capacity signals exist, and they are frequently conflated:

- **Pool allocation:** how much of the storage *pool* is committed to virtual
  disks. This is what the **thin provisioning alert threshold (default 70%)** and
  the **pool reserve-capacity** check (`System.Storage.StoragePool.CheckPoolReserveCapacity`)
  evaluate. Pool allocation is the subject of this guide.
- **Volume fill:** how full an individual *volume's* file system is. The Health
  Service evaluates this against separate, **volume-level** settings whose defaults
  are `System.Storage.Volume.CapacityThreshold.Warning = 80` and
  `.Critical = 90`
  ([Health service settings](https://learn.microsoft.com/azure/azure-local/manage/health-service-settings)).
  An **80%** or **90%** figure quoted for "capacity" almost always refers to these
  **volume** thresholds, **not** to an automatic pool action.

The pool has **no automatic 80/90/95 capacity ladder and no capacity-based
read-only "block."** At the pool level the platform raises only two advisory,
Warning-class health faults: `StoragePool.PoolCapacityThresholdExceeded` (the
configurable 70% thin-provisioning alert) and `StoragePool.InsufficientReserveCapacity`.
Neither takes automatic action. A Storage Spaces pool is set **read-only**
only on **quorum loss** (too many drives offline, operational state `Incomplete`)
or by **administrator policy** (`Policy`), never from a capacity percentage. See
[Storage Spaces and Storage Spaces Direct health and operational states](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states).
What actually happens as a pool approaches full is described next.

### What happens if the pool is allowed to fill

Treat the 70% alert as an **early warning**, not the danger line. The real safety
floor is the reserve (the equivalent of one capacity drive per server, up to four).
As pool allocation climbs past the reserve toward full, risk escalates:

- **Repair headroom shrinks, then disappears.** After a drive or node loss, the
  auto-repair jobs that rebuild resiliency need free pool capacity to write into.
  With no reserve, those jobs stay **suspended** until the failed hardware is
  replaced, leaving volumes running with reduced or no redundancy.
- **At true exhaustion, writes fail.** When a **thin** volume's backing pool
  capacity is exhausted, new allocations fail (on Azure Local 23H2+ with Arc VMs
  this surfaces as an out-of-capacity error from the underlying virtualization
  layer). The volume can be taken offline and the affected VMs can stop or enter a
  paused state as the platform reacts to the write failure. That is an unplanned
  outage, not a graceful, admin-scheduled action.

Act while the alert is still an early warning. Do the cheapest, most reversible
things first, and escalate only as needed:

1. **Audit and prune.** Merge or remove stale Hyper-V checkpoints, and find and
   remove orphaned or stale `.vhdx` files. On thin volumes the reclaimed space
   returns to the pool gradually (about 15 minutes; see
   [Path B](#path-b-thin-provisioned-volumes-reclaim-unused-capacity)).
2. **Restrict new provisioning.** Stop creating new virtual disks or volumes on
   the pressured pool.
3. **Freeze automated thin-disk or volume expansion** so background growth cannot
   consume the remaining headroom.
4. **Prepare to expand the pool.** Add OEM-supported physical disks or a node
   ([Option A1](#option-a1-add-capacity-recommended-when-growth-is-expected-low-risk)).
   Adding capacity is the durable fix.

> [!CAUTION]
> **Do not respond to a pool or CSV capacity warning by saving VM state.** Saving a
> VM, `Save-VM`, `Stop-VM -Save`, or the **Save the virtual machine state**
> automatic stop action, writes a saved-state file roughly the size of the VM's
> assigned memory onto its volume (similar to hibernating), consuming the very
> capacity you are short of and potentially pushing a nearly-full CSV or pool over
> the edge. Pausing a VM with `Suspend-VM` writes no file, but it frees no capacity
> and is not a remediation either.
>
> - A VM whose **automatic stop action** is **Save the virtual machine state**
>   (historically the default) writes a saved-state file the size of its memory
>   onto its volume whenever it is stopped **without a live-migration target**,
>   for example during a full-cluster `Stop-Cluster`, or a host OS shutdown of a
>   non-HA VM. (A node *drain* is space-safe: it live-migrates VMs, copying memory
>   over the network and leaving the VHDX on the CSV.) A cluster-wide stop can
>   therefore trigger a wave of save-state writes into an already-constrained CSV.
>   For VMs on capacity-constrained volumes, set the automatic stop action to
>   **Shut down the guest operating system** instead. For Arc VMs, stop the VM
>   **from Azure**, not with host tools.
> - Focus remediation on **pool and physical-disk utilization**, not just CSV or
>   volume free space. Extending a thin volume or CSV to create file-system free
>   space does **not** add pool capacity and can make pool pressure worse.

## Step 1: Determine the provisioning type (required first)

Run this on any cluster node before choosing a remediation:

```powershell
Get-VirtualDisk | Format-Table FriendlyName, ProvisioningType, Size, FootprintOnPool -AutoSize
```

- `ProvisioningType = Fixed` &rarr; follow [Path A](#path-a-fixed-provisioned-volumes).
- `ProvisioningType = Thin` &rarr; follow [Path B](#path-b-thin-provisioned-volumes-reclaim-unused-capacity).

> [!IMPORTANT]
> Do **not** run `Optimize-Volume -SlabConsolidate` or `Optimize-StoragePool` to
> "free space" on a fixed-provisioned volume. There are no unused slabs to
> consolidate on a fixed volume, so the procedure returns no capacity and can
> waste a maintenance window.

Also capture the current pool fill level so you can confirm the result later:

```powershell
Get-StoragePool | Where-Object IsPrimordial -eq $false |
    Format-Table FriendlyName, Size, AllocatedSize,
        @{N='UsedPct';E={[math]::Round(100*$_.AllocatedSize/$_.Size,1)}} -AutoSize
```

## Path A: Fixed-provisioned volumes

On fixed volumes the pool footprint is committed by design. Choose one or more of
the following based on the customer's goal.

### Option A1: Add capacity (recommended when growth is expected) [LOW RISK]

Add OEM-supported physical disks so total pool capacity grows and the allocation
percentage drops below the threshold. Follow
[How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md).

### Option A2: Convert fixed volumes to thin [MEDIUM RISK]

Converting to thin lets the pool charge only for data actually written, which
usually drops allocation well below the threshold and enables the reclamation
procedure in Path B. Follow the documented procedure:
[Convert fixed to thin provisioned volumes on Azure Local](https://learn.microsoft.com/previous-versions/azure/azure-local/manage/thin-provisioning-conversion).
After conversion, run [Path B](#path-b-thin-provisioned-volumes-reclaim-unused-capacity)
to release the now-unused capacity back to the pool.

> [!IMPORTANT]
> Microsoft publishes **no minimum build** for in-place fixed-to-thin conversion.
> The linked procedure (`Set-VirtualDisk -ProvisioningType Thin` plus a volume
> remount) is documented for Azure Stack HCI 21H2/22H2 and is now archived under
> `/previous-versions/` because of the Azure Stack HCI to Azure Local rename, not
> a documented removal of the feature. However, the current Azure Local 23H2/24H2
> volume docs do not re-publish an in-place conversion procedure, so confirm it is
> still supported on the cluster's current build (against current guidance or with
> the storage team) before recommending it to a customer. If you cannot confirm
> support, create a new thin volume and migrate the data instead, then remove the
> old fixed volume.

### Option A3: Shrink or remove volumes [MEDIUM RISK]

Reduce committed footprint by removing volumes that are no longer needed, or by
recreating a volume at a smaller size. Note that **ReFS does not support in-place
volume shrink**, so "shrinking" a fixed ReFS volume means evacuating its data and
recreating it smaller. Plan for data movement and downtime.

### Option A4: Suppress the capacity alert [MEDIUM RISK]

If the customer accepts the capacity posture and wants to stop the alert, the
Health Service threshold alert can be disabled:

```powershell
# Inspect current setting
Get-StorageSubSystem -FriendlyName Clus* |
    Get-StorageHealthSetting -Name "System.Storage.StoragePool.ThresholdAlert.Enabled"

# Disable the alert
Get-StorageSubSystem -FriendlyName Clus* |
    Set-StorageHealthSetting -Name "System.Storage.StoragePool.ThresholdAlert.Enabled" -Value $false
```

> [!WARNING]
> This setting is applied at the **storage subsystem level**
> (`Get-StorageSubSystem ... | Set-StorageHealthSetting`), so it suppresses the
> capacity threshold alert **cluster-wide, for every pool in the subsystem**, not
> just the affected pool or volume.
>
> Suppressing the alert also hides a **real** safety signal. The underlying capacity
> risk (no reserve for repair jobs after a drive loss) still exists. Only do this
> when the customer has explicitly accepted that risk, and document it.

> [!NOTE]
> Confirm the exact setting name on the live cluster first
> (`Get-StorageSubSystem -FriendlyName Clus* | Get-StorageHealthSetting`); the
> health-setting namespace can vary by build.

### Option A5: Raise the alert threshold [MEDIUM RISK]

If the goal is to move the threshold rather than silence the alert entirely:

```powershell
# Inspect the current threshold(s)
Get-StoragePool -FriendlyName "<pool name>" |
    Select-Object FriendlyName, ThinProvisioningAlertThresholds

# Raise the threshold (value is a percentage integer; the parameter takes an array)
Set-StoragePool -FriendlyName "<pool name>" -ThinProvisioningAlertThresholds @(80)
```

> [!WARNING]
> Raising the threshold reduces the early-warning margin before the pool runs out
> of repair headroom. The same capacity risk applies as in Option A4.

## Path B: Thin-provisioned volumes (reclaim unused capacity)

> [!IMPORTANT]
> **Ownership gate (read before starting).** Capacity work on a production volume
> is owned by the customer's cluster or storage administrator. The read-only Quick
> triage and the [Verify](#verify) queries are always safe to run. Everything else
> here changes state: the no-downtime branch below asks you to **delete orphaned
> virtual disk files**, which is irreversible, and the **numbered consolidation
> steps** are a scheduled maintenance-window procedure that takes VMs offline. If
> you are not that administrator, or you are unsure whether you are authorized to
> delete those files or take these workloads offline, stop here and hand off.

On thin volumes, capacity that was written and later deleted can remain committed
to the pool in partially used 256 MB "slabs". A slab is only returned to the pool
once all of its blocks are free. Deleting a whole file frees its slabs outright and
they are returned automatically; when live data still occupies part of a slab,
consolidation is needed to move that data into fewer slabs so the emptied ones can
be released.

### Before you start: is consolidation even the right tool?

Two different mechanisms return capacity to the pool, and **only one of them needs
an offline window**. Identify which case you are in before scheduling anything.

- **Whole files were deleted** (VMs deleted, VHDX removed, ISOs purged). The slabs
  those files occupied become entirely free, and ReFS returns them to the pool
  **on its own**, with no `Optimize-Volume` and **no downtime**. Microsoft
  documents this as a gradual process that takes *"15 minutes or so after the
  files are deleted"*, and notes that *"if there are many workloads running on the
  system, it may take longer for all of the space to be returned to the pool"*
  ([thin provisioning FAQ][thin-prov]). Running workloads **slow this down; they
  do not block it**.
- **Interior fragmentation** (data deleted from *inside* a VHDX or a guest file
  system). Blocks are freed inside slabs that still hold other live data, so no
  whole slab frees and automatic reclamation returns nothing. This is the only
  case that needs slab consolidation, and therefore the only case that needs the
  offline window.

**If you deleted whole VMs or files, start here. This path needs no downtime
unless you find orphaned disks that have to be removed:**

1. **Confirm the virtual disk files are actually gone, not just the VMs.**
   `Remove-VM` "deletes the virtual machine's configuration file, but does not
   delete any virtual hard drives" ([Remove-VM][remove-vm]), so disks left behind
   still occupy their slabs and no amount of waiting will reclaim them.

   Build the in-use set from **every node in the cluster**, not just the one you
   are signed in to. A VM running on another node holds its disks open exactly the
   same way, and a single-node listing will not show that:

   ```powershell
   # Disks in use anywhere on the cluster, including checkpoint disks
   $inUse = Get-ClusterNode | ForEach-Object {
       Get-VM -ComputerName $_.Name | ForEach-Object {
           $_ | Get-VMHardDiskDrive | Select-Object -ExpandProperty Path
           $_ | Get-VMSnapshot | Get-VMHardDiskDrive | Select-Object -ExpandProperty Path
       }
   } | Sort-Object -Unique

   # Files on the volume that nothing on the cluster references
   Get-ChildItem "C:\ClusterStorage\<volume>" -Recurse -Include *.vhdx,*.avhdx,*.vhds |
       Where-Object { $_.FullName -notin $inUse } |
       Select-Object FullName, @{N='GB';E={[math]::Round($_.Length/1GB,1)}}, LastWriteTime
   ```

   That output is a list of **candidates, not a list of garbage.** Before removing
   anything, rule out all three of the following:

   - **Arc-managed disks and images.** For Azure Local VMs enabled by Arc the disk
     is an Azure resource, and one that exists but is not currently attached to a
     VM is invisible to a host-side listing while still being live customer data.
     Check Azure as well as the host: `az stack-hci-vm disk list`,
     `az stack-hci-vm image list`, and `az stack-hci-vm storagepath list` for the
     paths in use on this volume.
   - **Templates, golden images, ISOs, and backup targets**, which legitimately
     have no attached VM and are still needed.
   - **Checkpoint disks.** Never delete an `.avhdx` directly. It is a differencing
     disk, and removing it breaks the chain and can destroy the VM's data. Merge
     checkpoints through Hyper-V instead (`Get-VM | Get-VMSnapshot`, then
     `Remove-VMSnapshot`), which collapses the `.avhdx` into its parent and frees
     the space properly.

   Delete only what you have positively accounted for on all three counts.
   **[HIGH RISK]**

   > [!WARNING]
   > **Deleting a virtual disk file is irreversible and destroys whatever it
   > contains.** A file that looks unreferenced from one node may be attached on
   > another node, attached in Azure, or the parent of a checkpoint chain. If you
   > cannot positively account for a file, leave it in place and open a support
   > case. Reclaiming capacity is never worth deleting a disk you could not
   > identify.

   For **Arc VMs**, delete the VM through Azure rather than with host tools.
2. Wait at least 15 minutes; longer on a busy cluster.
3. Re-measure with the [Verify](#verify) queries.

If the pool has dropped below threshold, **you are done, with no maintenance
window**. Continue to the consolidation procedure only if the pool is still above
threshold *and* the volume genuinely shows large interior free space.

> [!CAUTION]
> **Moving VM disks to another volume does not relieve pool pressure, and can
> break Arc management.** Every CSV on the cluster draws from the **same storage
> pool** (Azure Local uses [one pool per cluster][s2d-overview]), so relocating a
> VHDX from one CSV to another moves the data without returning a single byte to
> the pool. It is motion with no benefit for this problem.
>
> For **Arc-managed Azure Local VMs (23H2+)** it is also actively harmful. Moving
> a VHD/VHDX to another CSV with host-side tools (`Move-VMStorage`, Failover
> Cluster Manager, or a manual file move) is *storage live migration*, which
> Microsoft lists among operations that *"can lead to Azure Local VMs becoming
> unmanageable from the Azure portal"* ([unsupported VM operations][unsupported-ops]).
> Azure tracks each disk's location through a **storage path**
> (`Microsoft.AzureStackHCI/storagecontainers`) resource; a host-side move leaves
> that resource pointing at the old volume, and the VM, disk, and
> network-interface resources can be left stale and undeletable.
>
> There is **no supported in-place move** of an existing Arc VM disk between
> volumes: a storage path is selected at **creation** time. To place a workload on
> a different volume, create the disk or VM against a storage path on that volume
> through Azure, rather than moving files on the host.
>
> This restriction applies to **Arc-managed** VMs. For traditional (non-Arc)
> clustered Hyper-V VMs, `Move-VMStorage` with the cluster resource updated
> accordingly remains supported, though the same one-pool point applies: it still
> will not free pool capacity.
>
> Live-migrating a VM to a **different node** does not help either. The CSV is
> cluster-shared, so the virtual disk file stays on the same volume and stays in
> use, just from another node. Stopping the workload is the only action that makes
> its slabs movable.

> [!NOTE]
> This procedure recovers capacity only when the volume genuinely holds far less
> data than its pool footprint. Confirm there is real interior free space first
> (`Get-Volume` / volume reports show large free space while `FootprintOnPool` is
> close to `Size × resiliency`). If footprint matches the data actually written,
> there is nothing to reclaim.

> [!TIP]
> **Cheapest checks first. A consolidation pass is not a cheap probe.** The steps
> above cost seconds and can make the maintenance window unnecessary: enumerate
> the virtual disk files, confirm the provisioning type, rule out the stop
> conditions, and if whole files were deleted just wait and re-measure.
>
> Running consolidation with the workload still up, to see what it recovers before
> committing to a window, is a reasonable probe. It is non-destructive, it
> relocates data rather than deleting any, it runs at low priority, and a
> disappointing result costs time rather than data. Two things to weigh before
> doing it:
>
> - On a multi-terabyte volume it is **hours** of back-end relocation I/O, and
>   because every volume shares the one pool, that load is felt by workloads on
>   other volumes. It is cheap in risk, not in cost.
> - On a pool that is already **close to full**, be more careful. ReFS allocates
>   on write, so relocating live data writes the new copy before releasing the
>   old. Whether that transiently raises pool allocation on a nearly-full pool is
>   not established here either way, and pool exhaustion is the one failure in
>   this article that takes VMs offline. On a pool with comfortable headroom this
>   is not a concern; near the limit, do the read-only checks above first.
>
> A probe that recovers little is not proof the procedure does not work. It is
> the expected result when the workload is still holding its files.

**Procedure for interior fragmentation (requires an offline window for VMs on the affected volume; the window lasts through slab consolidation, which can take hours on large volumes):** [MEDIUM RISK]

> [!TIP]
> **Preparation (optional, no downtime, do this before the window).** Merge
> Hyper-V checkpoints that are no longer needed (`Get-VM | Get-VMSnapshot`, then
> `Remove-VMSnapshot`). Checkpoint files hold live data that pins extra slabs and
> reduces what consolidation can recover. This is preparation, not part of the
> maintenance window.

1. **Take the VMs on the affected volume offline.** Consolidation works by
   relocating live data out of partially used slabs so whole slabs can be freed,
   and it cannot relocate data belonging to files that are actively in use. Those
   slabs are reported as "pinned unmovable" and skipped, which is the main reason
   a pass run against a live volume recovers far less than one run against a
   quiesced volume. Stopping the workload is what makes that data movable. First
   find where each VM is running:

   ```powershell
   Get-ClusterGroup | Where-Object GroupType -eq 'VirtualMachine' |
       Select-Object Name, OwnerNode, State
   ```

   **Prefer a clean guest shutdown**, which releases the VM's files **without**
   writing a saved-state file:

   ```powershell
   Stop-VM -Name "<vm name>"   # graceful guest shutdown; run on/target the owner node
   ```

   If a guest will not shut down cleanly (hung, or no integration services), a
   forced turn-off also releases the VM's files **without** writing a
   saved-state file, but only as a last resort **[HIGH RISK]**:

   ```powershell
   Stop-VM -Name "<vm name>" -TurnOff   # hard power-off; last resort only
   ```

   > [!WARNING]
   > **`-TurnOff` is a hard power-off, the equivalent of pulling the power cord.**
   > It can lose unsaved in-guest data and can leave the guest file system dirty.
   > Try a graceful `Stop-VM` (in-guest shutdown) first, and force `-TurnOff` only
   > after the workload owner has approved it for that specific VM.

   > [!CAUTION]
   > Do **not** substitute `Save-VM`, or the **Save** automatic stop action, here.
   > **Saving** writes a saved-state file roughly the size of the VM's memory onto
   > the very volume you are trying to free, consuming the capacity you are trying
   > to recover.
   >
   > `Suspend-VM` (pause) writes no state file, but it leaves the virtual disk
   > files open and the guest's memory resident on the host, so it is not a
   > reliable substitute for a shutdown. Putting the cluster resource into
   > redirected access is **not** a substitute either, because the VMs keep running
   > and their files stay in use. To make a file's slabs movable, the workload
   > holding it has to be stopped.

   > [!IMPORTANT]
   > For **Arc-managed VMs** (Azure Local 23H2+), stop the VM from Azure (portal
   > or CLI) rather than using host tools such as `Stop-VM` or `Suspend-VM`.
   > Driving an Arc VM's power state directly on the host can desynchronize the Arc
   > agent / Arc Resource Bridge view of the VM state. Once workloads on the volume
   > are stopped cluster-wide, proceed with consolidation.

2. **Consolidate slabs** on the volume. Run this on the CSV **owner node**.
   Resolve the CSV's `C:\ClusterStorage\<volume>` path to its volume object with
   `Get-Volume -FilePath`, confirm it is the volume you intend, then pipe it to
   `Optimize-Volume`:

   ```powershell
   # Identify the CSV owner node, and run the rest on that node
   Get-ClusterSharedVolume | Select-Object Name, OwnerNode

   $csv = "C:\ClusterStorage\<volume>"
   $vol = Get-Volume -FilePath $csv
   $vol | Format-List FileSystemLabel, Size, SizeRemaining, Path   # confirm this is the intended CSV
   $vol | Optimize-Volume -SlabConsolidate -Verbose
   ```

   > [!IMPORTANT]
   > Resolve the CSV with `Get-Volume -FilePath`. Do **not** pass the CSV mount to
   > `Optimize-Volume -Path "C:\ClusterStorage\<volume>"`: `-Path` matches a
   > volume's own device path, not a CSV mount/access path, so it fails with
   > `No MSFT_Volume objects found with property 'Path' equal to
   > 'C:\ClusterStorage\<volume>'`. Other selectors (`-DriveLetter`,
   > `-FileSystemLabel`) are also unreliable for a CSV mount. `Get-Volume
   > -FilePath` returns the correct volume object and pipes it straight into
   > `Optimize-Volume`.

   > [!IMPORTANT]
   > Do **not** add `-ReTrim`. On thin-provisioned ReFS, `-ReTrim` does nothing
   > useful; ReFS does not use the NTFS retrim mechanism. It has its own
   > background unmap workitem. (Some older published examples show
   > `-ReTrim -SlabConsolidate` together; for ReFS, use `-SlabConsolidate`
   > alone.) Slab consolidation is the time-consuming step and can take hours on
   > multi-terabyte volumes.

   > [!NOTE]
   > **Consolidation runs at low priority by default.** `Optimize-Volume`
   > documents `-NormalPriority` as running the operation at normal priority, and
   > states that *"By default, the priority is low"*
   > ([Optimize-Volume](https://learn.microsoft.com/powershell/module/storage/optimize-volume)),
   > matching `defrag /h` (*"Runs the operation at normal priority (default is
   > low)"*). The pass therefore yields to workload I/O rather than competing with
   > it. Note that this governs *scheduling priority*, not total cost: on a
   > multi-terabyte volume, consolidation still performs hours of back-end data
   > relocation, and the pool's physical disks are shared by **every** volume in
   > the pool, so sustained relocation I/O can be felt by workloads on other
   > volumes. Prefer a low-usage window on large or busy systems.

   > [!NOTE]
   > **Substrate matters if you are validating in a lab.** The reclaim is only
   > observable on **physical S2D hardware**. On a nested or VM-based cluster,
   > `Optimize-Volume -SlabConsolidate` reports every purgable slab pinned
   > unmovable and returns 0 bytes to the pool even when real interior free
   > space exists, and the footprint stays flat. That is a substrate limitation,
   > not a failure of the procedure and not a defect in the volume. Grade this
   > remediation only on physical S2D, never on a nested or VM cluster.

3. **Wait about 15 minutes** after consolidation completes. The capacity is
   returned to the pool by the **ReFS background unmap workitem**, which runs
   after `Optimize-Volume -SlabConsolidate` finishes. This wait, not the next
   step, is what releases the emptied slabs.

   > [!NOTE]
   > VMs only need to stay offline through the consolidation in Step 2. Once
   > Step 2 reports complete, you can bring the VMs back online (Step 5) and run
   > the remaining steps with workloads online, shortening the maintenance window.

4. **(Optional) Rebalance the pool allocation:**

   ```powershell
   Optimize-StoragePool -FriendlyName "<pool name>" -Verbose
   ```

   `Optimize-StoragePool` rebalances Storage Spaces allocations across the pool;
   it is primarily used to spread data onto newly added drives and is a finalize
   step here, not the mechanism that frees the slabs (that already happened in
   Step 3). Monitor with `Get-StorageJob` and wait until no `Optimize` jobs are
   running before re-measuring pool fill. If it finishes in seconds with no jobs,
   that is expected when there is nothing to rebalance; it does **not** mean
   reclamation failed; confirm the result with the pool fill query in
   [Verify](#verify).

5. **Bring the VMs back online.** For **traditional non-Arc Hyper-V VMs**, start
   them on the host:

   ```powershell
   Start-VM -Name "<vm name>"   # non-Arc Hyper-V VMs only
   ```

   > [!IMPORTANT]
   > For **Arc-enabled Azure Local VMs (23H2+)**, start or restart the VM
   > **through Azure** (the VM resource in the portal or CLI), not with host
   > `Start-VM`. Driving an Arc VM's power state directly on the host bypasses the
   > control plane and can desynchronize the Arc agent and Arc Resource Bridge
   > view of the VM state; this mirrors the stop-side boundary in Step 1.

> [!NOTE]
> A consolidation pass can legitimately return little or no capacity. The most
> common reasons, in order: the volume's footprint already matches the data
> actually written, so there is nothing to reclaim (see the note at the start of
> this procedure); ReFS delete notification has been explicitly disabled, so
> freed slabs are never returned; or slabs are still pinned by data in use (confirm every VM on the volume is stopped
> in Step 1 and that stale checkpoints were merged in the preparation step). Note
> that some slabs report "pinned unmovable" even on a fully quiesced volume, so a
> partial reclaim is not by itself a failure. If real interior free space exists,
> ReFS delete notification is not explicitly disabled, all workloads were
> offline, and
> checkpoints were merged, but the pool still does not drop after the unmap wait
> (Step 3), open a Microsoft support case rather than repeating the procedure.

## Choose the right option

| Volume provisioning | Goal | Use |
|---|---|---|
| Fixed | Grow capacity | A1: add physical disks |
| Fixed | Reduce committed footprint / enable reclamation | A2: convert to thin, then Path B |
| Fixed | Remove unneeded volumes | A3: shrink/remove (ReFS = evacuate + recreate) |
| Fixed | Stop the alert (risk accepted) | A4: disable the Health Service alert |
| Fixed | Move the alert threshold | A5: raise `ThinProvisioningAlertThresholds` |
| Thin | Return capacity from **deleted whole files/VMs** | Path B pre-branch: confirm the disk files are gone, wait, re-measure (no downtime) |
| Thin | Return capacity stranded by **interior fragmentation** | Path B: SlabConsolidate + ReFS unmap (offline window) |

## Verify

After remediation, confirm the pool dropped below the threshold and the warning
cleared:

```powershell
# Pool fill level
Get-StoragePool | Where-Object IsPrimordial -eq $false |
    Format-Table FriendlyName, Size, AllocatedSize,
        @{N='UsedPct';E={[math]::Round(100*$_.AllocatedSize/$_.Size,1)}} -AutoSize

# Any in-flight storage jobs
Get-StorageJob

# Active health faults across the cluster
Get-HealthFault
```

For an upgrade, re-run the solution update readiness check and confirm the
capacity finding is resolved or accepted. When you are clearing the same warning
across many sites, treat this readiness re-run as the per-site validation loop:
remediate, re-run readiness, confirm resolved or accepted, then move to the next
site.

## Data to Collect Before Opening a Support Case

Collect the following from the cluster and attach it to the case. It captures which
capacity signal fired, the pool / volume / disk state, and the event-log history of
the threshold crossing and any allocation failures.

**Health faults.** The pool-capacity signals surface as Storage Spaces health
faults. Collect the on-box faults with `Get-HealthFault`, and, for an Arc-connected
cluster, also check the resource's **Resource Health** / Insights health view in
the Azure portal:

```powershell
Get-HealthFault
```

The fault types to look for (both Warning class):

| Fault type | Meaning | Where it surfaces |
|---|---|---|
| `StoragePool.InsufficientReserveCapacity` | The pool no longer has the minimum reserve (the equivalent of one capacity drive per server, up to a maximum of four drives) needed to repair resiliency after a drive or node loss. | On-box `Get-HealthFault`. |
| `StoragePool.PoolCapacityThresholdExceeded` | The storage pool is running out of capacity (the configurable thin-provisioning alert, default 70%). | Azure portal **Resource Health** / Insights health view; the on-box correlate is **EventID 103** below. |

> [!NOTE]
> The strings above (`StoragePool.InsufficientReserveCapacity` and
> `StoragePool.PoolCapacityThresholdExceeded`) are the exact on-box
> `Get-HealthFault` `FaultType` values to match on. The full internal fault id
> carries an additional `Microsoft.Health.FaultType.` prefix (for example
> `Microsoft.Health.FaultType.StoragePool.PoolCapacityThresholdExceeded`), so
> match on the `StoragePool.` name when guiding a customer through their on-box
> output.

**Event log.** Collect these Storage Spaces events from
`Microsoft-Windows-StorageSpaces-Driver/Operational` on **every node** (the pool
owner logs them, and ownership can move between nodes):

| EventID | Level | Meaning |
|---|---|---|
| **103** | Error | Pool capacity consumption exceeded the threshold set on the pool (the alert firing). |
| **104** | Information | Pool capacity consumption dropped back below the threshold (the alert clearing). |
| **310** | Error | An allocation for a virtual disk failed for lack of pool capacity; the disk can be taken offline / read-only until capacity is added. |

> [!NOTE]
> These IDs are read from the Storage Spaces provider's own event manifest (confirm
> on the build with `wevtutil gp Microsoft-Windows-StorageSpaces-Driver /ge /gm:true`);
> they are not enumerated in public documentation and can vary by build. Do not
> confuse **310** with the documented **311** (*"virtual disk ... requires a data
> integrity scan"*), which is unrelated to capacity.

```powershell
# Storage Spaces pool-capacity events (run on each node)
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-StorageSpaces-Driver/Operational'
    Id      = 103, 104, 310
} -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Format-Table -AutoSize -Wrap
```

**Pool, volume, and disk state, plus the cluster log:**

```powershell
Get-StoragePool -IsPrimordial $false |
    Format-List FriendlyName, Size, AllocatedSize, ThinProvisioningAlertThresholds, OperationalStatus, HealthStatus, ReadOnlyReason
Get-VirtualDisk  | Format-List FriendlyName, ProvisioningType, Size, FootprintOnPool, OperationalStatus, HealthStatus
Get-PhysicalDisk | Format-Table FriendlyName, MediaType, Size, HealthStatus, Usage -AutoSize
Get-StorageJob

# Last 2 hours of cluster log to C:\Temp
Get-ClusterLog -Destination C:\Temp -TimeSpan 120
```

Also capture: the pool name and node count; whether the alert settings were changed
from default (`System.Storage.StoragePool.ThresholdAlert.Enabled`,
`System.Storage.StoragePool.CheckPoolReserveCapacity.Enabled`, and the pool's
`ThinProvisioningAlertThresholds`); and, for deeper analysis, the
[Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)
storage report.

## When to escalate

Most capacity warnings are resolved by the paths above. Escalate when one of these
firm conditions is met. Do not simply re-run the procedure.

**Escalate to the hardware vendor / OEM when:**

- The durable fix is to add capacity
  ([Option A1](#option-a1-add-capacity-recommended-when-growth-is-expected-low-risk)),
  but the OEM-supported drives are unavailable or the drive model is no longer
  supported.
- Physical disks have failed or retired and pool capacity dropped as a result. The
  reserve cannot be restored until the hardware is replaced (a drive replacement is
  an OEM action).

**Escalate to Microsoft support when:**

- **EventID 310 appears, or a thin volume has gone read-only / offline**. The pool
  reached true exhaustion and there is data-path impact. Collect the data above and
  open the case now; do not wait for the pool to recover on its own. (If the pool
  *operational state* is `Incomplete` / read-only from a drive-quorum loss rather
  than capacity, that is a separate, higher-severity problem. Escalate immediately.)
- **Path B completed with every precondition met** (confirmed real interior free
  space, ReFS delete notification not explicitly disabled, every VM on the volume
  stopped, checkpoints merged) and you waited out the
  ReFS unmap, but pool `AllocatedSize` still does not drop.
- The reserve-capacity fault (`InsufficientReserveCapacity`) **persists after**
  you have added capacity or reduced footprint.

Include the data-collection output above with any Microsoft support case.

## Related Issues

- [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md)
- [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)

## References

- [Thin provisioning on Azure Local](https://learn.microsoft.com/previous-versions/azure/azure-local/manage/thin-provisioning)
- [Convert fixed to thin provisioned volumes on Azure Local](https://learn.microsoft.com/previous-versions/azure/azure-local/manage/thin-provisioning-conversion)
- [Plan volumes (capacity and reserve)](https://learn.microsoft.com/windows-server/storage/storage-spaces/plan-volumes)
- [Optimize-Volume](https://learn.microsoft.com/powershell/module/storage/optimize-volume)
- [Optimize-StoragePool](https://learn.microsoft.com/powershell/module/storage/optimize-storagepool)
- [Troubleshoot Storage Spaces Direct health and operational states](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states)
- [Azure Local Health Service settings (volume and pool capacity thresholds)](https://learn.microsoft.com/azure/azure-local/manage/health-service-settings)
- [Azure Local Health Service faults reference (`Get-HealthFault` fault types)](https://learn.microsoft.com/azure/azure-local/manage/health-service-faults)
- [Set-VM (automatic stop action)](https://learn.microsoft.com/powershell/module/hyper-v/set-vm)
- [Storage thin provisioning in Azure Local (reclamation behavior and FAQ)](https://learn.microsoft.com/azure/azure-local/manage/manage-thin-provisioning-23h2)
- [Supported and unsupported operations for Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/virtual-machine-operations)
- [Create a storage path for Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/create-storage-path)

[thin-prov]: https://learn.microsoft.com/azure/azure-local/manage/manage-thin-provisioning-23h2
[unsupported-ops]: https://learn.microsoft.com/azure/azure-local/manage/virtual-machine-operations
[remove-vm]: https://learn.microsoft.com/powershell/module/hyper-v/remove-vm
[s2d-overview]: https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-direct-overview

---
