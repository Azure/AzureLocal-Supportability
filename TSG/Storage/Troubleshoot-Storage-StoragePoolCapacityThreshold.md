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
</table>

> **In plain terms:** the storage *pool* — the shared disk capacity behind every
> volume on the cluster — is filling up. Deciding what to do is a capacity task for
> the **cluster / storage administrator**; it is usually not urgent, but if the pool
> is genuinely allowed to fill, virtual machines can pause or go offline. Run the
> **Quick triage** below to find which of two fixes applies.

## At a glance

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 200px;">Business impact</th>
    <td><strong>Usually low</strong> — a reserve-capacity and update-readiness early
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
    maintenance window — slab consolidation can take <strong>hours</strong> on large
    volumes.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Downtime / maintenance window</th>
    <td>Triage and the add-capacity / alert options (A1, A4, A5) are
    <strong>online</strong>. <strong>A2</strong> (convert, then Path B),
    <strong>A3</strong> (evacuate + recreate a volume), and <strong>Path B</strong>
    require data movement or a VM-offline window; Path B's window lasts through slab
    consolidation.</td>
  </tr>
</table>

## Quick triage (start here)

Run this on any cluster node. It shows how full the pool is and, crucially, whether
the volumes are **Fixed** or **Thin** — which decides the entire remediation path:

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
  capacity, convert to thin, or adjust the alert &mdash; go to
  [Path A](#path-a--fixed-provisioned-volumes).
- **`Thin`** &rarr; capacity from deleted data can be reclaimed &mdash; go to
  [Path B](#path-b--thin-provisioned-volumes-reclaim-unused-capacity) (needs a
  maintenance window).

> [!NOTE]
> This is the short form of
> [Step 1](#step-1--determine-the-provisioning-type-required-first), surfaced up top.
> The full guide below explains *why* and covers every option in detail — read on if
> triage alone does not resolve it.

## Overview

This guide explains the Storage Spaces Direct (S2D) **storage pool capacity
threshold warning** and the supported options for resolving it. The warning
fires when pool allocation crosses the configured threshold (the thin
provisioning alert threshold defaults to **70%**).

The warning is **not a false alarm**: S2D needs free pool capacity in reserve so
that storage repair jobs can rebuild resiliency after a drive or node is lost. It
is, however, frequently misunderstood on clusters that use **fixed-provisioned**
volumes, because a fixed volume commits its entire size to the pool the moment it
is created — so the pool can sit above the threshold even when the volume's file
system is mostly empty.

The single most important step is to **determine whether the affected volumes are
fixed or thin provisioned before taking any action**, because the space
reclamation procedure (`Optimize-Volume -SlabConsolidate`, then waiting for the
ReFS background unmap to release the freed slabs) **does nothing on a
fixed-provisioned volume** and only applies to thin-provisioned volumes.

## Terminology

Short definitions for the terms used in this guide:

- **Storage pool** — the cluster-wide set of physical drives that Storage Spaces
  Direct (S2D) manages as one unit. Every volume is carved out of the pool.
- **S2D (Storage Spaces Direct)** — the Azure Local software-defined storage layer
  that pools each server's local drives into shared, resilient storage.
- **CSV (Cluster Shared Volume)** — a volume mounted under `C:\ClusterStorage\` that
  every node can use at once; where VM disks (`.vhdx`) live.
- **ReFS (Resilient File System)** — the file system used for Azure Local volumes.
- **Thin vs Fixed provisioning** — a **thin** volume consumes pool capacity only as
  data is written; a **fixed** volume reserves its full size in the pool the moment
  it is created (see
  [Why fixed-provisioned volumes hit this so easily](#why-fixed-provisioned-volumes-hit-this-so-easily)).
- **Footprint (`FootprintOnPool`)** — how much pool capacity a volume actually
  occupies, *including* its resiliency copies (for example, a three-way mirror uses
  3&times; the written data).
- **Slab** — the 256 MB unit S2D allocates pool capacity in. A slab returns to the
  pool only when every block in it is free.
- **Unmap** — the background ReFS operation that returns emptied slabs to the pool
  after data is deleted or consolidated.
- **Primordial pool** — the built-in pool of drives not yet added to an S2D pool;
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

## What and Why

### Why the warning exists

When a capacity drive (or a whole node) is lost, S2D automatically starts repair
("auto-heal") jobs that re-create the missing copies of your data on the
remaining drives to restore full resiliency. Those repair jobs need somewhere to
write — they consume free pool capacity. If the pool has no reserve, repair jobs
have nowhere to rebuild and remain **suspended** until the failed drive is
physically replaced, leaving the volume running with reduced (or no) redundancy
in the meantime.

For this reason Microsoft recommends keeping free pool capacity in reserve. The
guidance is to reserve **the equivalent of one capacity drive per server, up to a
maximum of four drives** (reserve grows for parity and multi-tier
configurations). See
[Plan volumes — reserve capacity](https://learn.microsoft.com/windows-server/storage/storage-spaces/plan-volumes).

This is especially important on **small clusters (for example, two nodes with a
two-way mirror)**: during an update, nodes are drained and rebooted one at a
time, and a full pool leaves no headroom for the storage layer to keep data
resilient through the drain.

### Why fixed-provisioned volumes hit this so easily

Volumes on Azure Local are either **Thin** or **Fixed** provisioned (thin is the
default for new volumes; the default can be changed at the pool level):

- **Fixed** — the volume reserves its full size in the pool at creation time. A
  fixed volume on an N-way mirror commits **N × the volume size** of pool
  footprint up front, regardless of how much data is actually written into it.
  Deleting data inside the volume does **not** return capacity to the pool.
- **Thin** — the volume consumes pool capacity only as data is written, and unused
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

- **Pool allocation** — how much of the storage *pool* is committed to virtual
  disks. This is what the **thin provisioning alert threshold (default 70%)** and
  the **pool reserve-capacity** check (`System.Storage.StoragePool.CheckPoolReserveCapacity`)
  evaluate. Pool allocation is the subject of this guide.
- **Volume fill** — how full an individual *volume's* file system is. The Health
  Service evaluates this against separate, **volume-level** settings whose defaults
  are `System.Storage.Volume.CapacityThreshold.Warning = 80` and
  `.Critical = 90`
  ([Health service settings](https://learn.microsoft.com/azure/azure-local/manage/health-service-settings)).
  An **80%** or **90%** figure quoted for "capacity" almost always refers to these
  **volume** thresholds, **not** to an automatic pool action.

The pool has **no automatic 80/90/95 capacity ladder and no capacity-based
read-only "block."** At the pool level the platform raises only two advisory,
Warning-class health faults — `StoragePool.PoolCapacityThresholdExceeded` (the
configurable 70% thin-provisioning alert) and `StoragePool.InsufficientReserveCapacityFault`
— and neither takes automatic action. A Storage Spaces pool is set **read-only**
only on **quorum loss** (too many drives offline — operational state `Incomplete`)
or by **administrator policy** (`Policy`), never from a capacity percentage. See
[Storage Spaces and Storage Spaces Direct health and operational states](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states).
What actually happens as a pool approaches full is described next.

### What happens if the pool is allowed to fill

Treat the 70% alert as an **early warning**, not the danger line — the real safety
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
  paused state as the platform reacts to the write failure — an unplanned outage,
  not a graceful, admin-scheduled action.

Act while the alert is still an early warning — do the cheapest, most reversible
things first, and escalate only as needed:

1. **Audit and prune.** Merge or remove stale Hyper-V checkpoints, and find and
   remove orphaned or stale `.vhdx` files. On thin volumes the reclaimed space
   returns to the pool gradually (about 15 minutes; see
   [Path B](#path-b--thin-provisioned-volumes-reclaim-unused-capacity)).
2. **Restrict new provisioning.** Stop creating new virtual disks or volumes on
   the pressured pool.
3. **Freeze automated thin-disk or volume expansion** so background growth cannot
   consume the remaining headroom.
4. **Prepare to expand the pool.** Add OEM-supported physical disks or a node
   ([Option A1](#option-a1--add-capacity-recommended-when-growth-is-expected--low-risk)).
   Adding capacity is the durable fix.

> [!CAUTION]
> **Do not respond to a pool or CSV capacity warning by saving VM state.** Saving a
> VM — `Save-VM`, `Stop-VM -Save`, or the **Save the virtual machine state**
> automatic stop action — writes a saved-state file roughly the size of the VM's
> assigned memory onto its volume (similar to hibernating), consuming the very
> capacity you are short of and potentially pushing a nearly-full CSV or pool over
> the edge. Pausing a VM with `Suspend-VM` writes no file, but it frees no capacity
> and is not a remediation either.
>
> - A VM whose **automatic stop action** is **Save the virtual machine state**
>   (historically the default) writes a saved-state file the size of its memory
>   onto its volume whenever it is stopped **without a live-migration target** —
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

## Step 1 — Determine the provisioning type (required first)

Run this on any cluster node before choosing a remediation:

```powershell
Get-VirtualDisk | Format-Table FriendlyName, ProvisioningType, Size, FootprintOnPool -AutoSize
```

- `ProvisioningType = Fixed` &rarr; follow [Path A](#path-a--fixed-provisioned-volumes).
- `ProvisioningType = Thin` &rarr; follow [Path B](#path-b--thin-provisioned-volumes-reclaim-unused-capacity).

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

## Path A — Fixed-provisioned volumes

On fixed volumes the pool footprint is committed by design. Choose one or more of
the following based on the customer's goal.

### Option A1 — Add capacity (recommended when growth is expected) — [LOW RISK]

Add OEM-supported physical disks so total pool capacity grows and the allocation
percentage drops below the threshold. Follow
[How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md).

### Option A2 — Convert fixed volumes to thin — [MEDIUM RISK]

Converting to thin lets the pool charge only for data actually written, which
usually drops allocation well below the threshold and enables the reclamation
procedure in Path B. Follow the documented procedure:
[Convert fixed to thin provisioned volumes on Azure Local](https://learn.microsoft.com/previous-versions/azure/azure-local/manage/thin-provisioning-conversion).
After conversion, run [Path B](#path-b--thin-provisioned-volumes-reclaim-unused-capacity)
to release the now-unused capacity back to the pool.

> [!IMPORTANT]
> Microsoft publishes **no minimum build** for in-place fixed-to-thin conversion.
> The linked procedure (`Set-VirtualDisk -ProvisioningType Thin` plus a volume
> remount) is documented for Azure Stack HCI 21H2/22H2 and is now archived under
> `/previous-versions/` because of the Azure Stack HCI to Azure Local rename — not
> a documented removal of the feature. However, the current Azure Local 23H2/24H2
> volume docs do not re-publish an in-place conversion procedure, so confirm it is
> still supported on the cluster's current build (against current guidance or with
> the storage team) before recommending it to a customer. If you cannot confirm
> support, create a new thin volume and migrate the data instead, then remove the
> old fixed volume.

### Option A3 — Shrink or remove volumes — [MEDIUM RISK]

Reduce committed footprint by removing volumes that are no longer needed, or by
recreating a volume at a smaller size. Note that **ReFS does not support in-place
volume shrink**, so "shrinking" a fixed ReFS volume means evacuating its data and
recreating it smaller. Plan for data movement and downtime.

### Option A4 — Suppress the capacity alert — [MEDIUM RISK]

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
> capacity threshold alert **cluster-wide — for every pool in the subsystem**, not
> just the affected pool or volume.
>
> Suppressing the alert also hides a **real** safety signal. The underlying capacity
> risk (no reserve for repair jobs after a drive loss) still exists. Only do this
> when the customer has explicitly accepted that risk, and document it.

> [!NOTE]
> Confirm the exact setting name on the live cluster first
> (`Get-StorageSubSystem -FriendlyName Clus* | Get-StorageHealthSetting`) — the
> health-setting namespace can vary by build.

### Option A5 — Raise the alert threshold — [MEDIUM RISK]

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

## Path B — Thin-provisioned volumes (reclaim unused capacity)

On thin volumes, capacity that was written and later deleted can remain committed
to the pool in partially used 256 MB "slabs". A slab is only returned to the pool
once all of its blocks are free. The supported procedure consolidates the live
data into fewer slabs and releases the emptied slabs back to the pool.

> [!NOTE]
> This procedure recovers capacity only when the volume genuinely holds far less
> data than its pool footprint. Confirm there is real interior free space first
> (`Get-Volume` / volume reports show large free space while `FootprintOnPool` is
> close to `Size × resiliency`). If footprint matches the data actually written,
> there is nothing to reclaim.

**Procedure (requires an offline window for VMs on the affected volume; the window lasts through slab consolidation, which can take hours on large volumes):** — [MEDIUM RISK]

1. *(Optional, no downtime)* Merge Hyper-V checkpoints that are no longer needed
   (`Get-VM | Get-VMSnapshot`, then `Remove-VMSnapshot`). Checkpoint files pin
   extra slabs and reduce what consolidation can recover.

2. **Take the VMs on the affected volume offline** so their virtual disk file
   handles are released (required for consolidation). First find where each VM is
   running:

   ```powershell
   Get-ClusterGroup | Where-Object GroupType -eq 'VirtualMachine' |
       Select-Object Name, OwnerNode, State
   ```

   **Prefer a clean guest shutdown**, which releases the file handles **without**
   writing a saved-state file:

   ```powershell
   Stop-VM -Name "<vm name>"   # graceful guest shutdown; run on/target the owner node
   ```

   If a guest will not shut down cleanly (hung, or no integration services), use a
   forced turn-off — `Stop-VM -Name "<vm name>" -TurnOff` — which also releases the
   file handles **without** writing a saved-state file.

   > [!CAUTION]
   > Do **not** substitute `Save-VM` (or the **Save** automatic stop action) or
   > `Suspend-VM` here. **Saving** releases the handles but writes a saved-state
   > file the size of the VM's memory onto the very volume you are trying to free.
   > **Suspending** only *pauses* the VM — its memory stays in host RAM and its
   > virtual disk handles stay **open**, so slab consolidation cannot proceed.
   > Putting the cluster resource into redirected access is likewise **not**
   > sufficient. The VM's file handles must actually be released, which means a
   > shutdown or turn-off.

   > [!IMPORTANT]
   > For **Arc-managed VMs** (Azure Local 23H2+), stop the VM from Azure (portal
   > or CLI) rather than using host tools such as `Stop-VM` or `Suspend-VM`.
   > Driving an Arc VM's power state directly on the host can desynchronize the Arc
   > agent / Arc Resource Bridge view of the VM state. Once workloads on the volume
   > are stopped cluster-wide, proceed with consolidation.

3. **Consolidate slabs** on the volume. Run this on the CSV **owner node**.
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
   > useful — ReFS does not use the NTFS retrim mechanism; it has its own
   > background unmap workitem. (Some older published examples show
   > `-ReTrim -SlabConsolidate` together; for ReFS, use `-SlabConsolidate`
   > alone.) Slab consolidation is the time-consuming step and can take hours on
   > multi-terabyte volumes.

4. **Wait about 15 minutes** after consolidation completes. The capacity is
   returned to the pool by the **ReFS background unmap workitem**, which runs
   after `Optimize-Volume -SlabConsolidate` finishes — this wait, not the next
   step, is what releases the emptied slabs.

   > [!NOTE]
   > VMs only need to stay offline through the consolidation in Step 3. Once
   > Step 3 reports complete, you can bring the VMs back online (Step 6) and run
   > the remaining steps with workloads online, shortening the maintenance window.

5. **(Optional) Rebalance the pool allocation:**

   ```powershell
   Optimize-StoragePool -FriendlyName "<pool name>" -Verbose
   ```

   `Optimize-StoragePool` rebalances Storage Spaces allocations across the pool;
   it is primarily used to spread data onto newly added drives and is a finalize
   step here, not the mechanism that frees the slabs (that already happened in
   Step 4). Monitor with `Get-StorageJob` and wait until no `Optimize` jobs are
   running before re-measuring pool fill. If it finishes in seconds with no jobs,
   that is expected when there is nothing to rebalance — it does **not** mean
   reclamation failed; confirm the result with the pool fill query in
   [Verify](#verify).

6. **Bring the VMs back online:**

   ```powershell
   Start-VM -Name "<vm name>"
   ```

> [!NOTE]
> A consolidation pass can legitimately return little or no capacity — most often
> because the volume's footprint already matches the data actually written (there
> is nothing to reclaim; see the note at the start of Path B), or because slabs
> are still pinned by data in use (confirm every VM on the volume is stopped in
> Step 2 and that stale checkpoints were merged in Step 1). If real interior free
> space exists, all workloads were offline, and checkpoints were merged, but the
> pool still does not drop after the unmap wait (Step 4), open a Microsoft support
> case rather than repeating the procedure.

## Choose the right option

| Volume provisioning | Goal | Use |
|---|---|---|
| Fixed | Grow capacity | A1 — add physical disks |
| Fixed | Reduce committed footprint / enable reclamation | A2 — convert to thin, then Path B |
| Fixed | Remove unneeded volumes | A3 — shrink/remove (ReFS = evacuate + recreate) |
| Fixed | Stop the alert (risk accepted) | A4 — disable the Health Service alert |
| Fixed | Move the alert threshold | A5 — raise `ThinProvisioningAlertThresholds` |
| Thin | Return deleted-data capacity to the pool | Path B — SlabConsolidate + ReFS unmap |

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
capacity finding is resolved or accepted.

## Data to Collect Before Opening a Support Case

Collect the following from the cluster and attach it to the case. It captures which
capacity signal fired, the pool / volume / disk state, and the event-log history of
the threshold crossing and any allocation failures.

**Health faults.** The pool-capacity signals surface as Storage Spaces health
faults. Collect the on-box faults with `Get-HealthFault`, and — for an Arc-connected
cluster — also check the resource's **Resource Health** / Insights health view in
the Azure portal:

```powershell
Get-HealthFault
```

The fault types to look for (both Warning class):

| Fault type | Meaning | Where it surfaces |
|---|---|---|
| `Microsoft.Health.FaultType.StoragePool.InsufficientReserveCapacityFault` | The pool no longer has the minimum reserve (about two drives' worth) needed to repair resiliency after a drive or node loss. | On-box `Get-HealthFault` (documented). |
| `Microsoft.Health.FaultType.StoragePool.PoolCapacityThresholdExceeded` | The storage pool is running out of capacity (the configurable thin-provisioning alert, default 70%). | Azure portal **Resource Health** / Insights health view; the on-box correlate is **EventID 103** below. |

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
firm conditions is met — do not simply re-run the procedure.

**Escalate to the hardware vendor / OEM when:**

- The durable fix is to add capacity
  ([Option A1](#option-a1--add-capacity-recommended-when-growth-is-expected--low-risk)),
  but the OEM-supported drives are unavailable or the drive model is no longer
  supported.
- Physical disks have failed or retired and pool capacity dropped as a result — the
  reserve cannot be restored until the hardware is replaced (a drive replacement is
  an OEM action).

**Escalate to Microsoft support when:**

- **EventID 310 appears, or a thin volume has gone read-only / offline** — the pool
  reached true exhaustion and there is data-path impact. Collect the data above and
  open the case now; do not wait for the pool to recover on its own. (If the pool
  *operational state* is `Incomplete` / read-only from a drive-quorum loss rather
  than capacity, that is a separate, higher-severity problem — escalate immediately.)
- **Path B completed with every precondition met** (confirmed real interior free
  space, every VM on the volume stopped, checkpoints merged) and you waited out the
  ReFS unmap, but pool `AllocatedSize` still does not drop.
- The reserve-capacity fault (`InsufficientReserveCapacityFault`) **persists after**
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

---
