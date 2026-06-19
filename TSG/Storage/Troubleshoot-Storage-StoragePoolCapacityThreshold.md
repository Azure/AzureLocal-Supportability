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
> In-place conversion of an existing fixed volume to thin requires **Azure Local
> 23H2 (build 2311.2) or later**. On earlier releases, do not attempt the
> conversion — instead create a new thin volume and migrate the data, then remove
> the old fixed volume. Always confirm the conversion path is supported on the
> cluster's current build before recommending it to a customer.

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

**Procedure (requires a VM suspend window on the affected volume):** — [MEDIUM RISK]

1. *(Optional, no downtime)* Merge Hyper-V checkpoints that are no longer needed
   (`Get-VM | Get-VMSnapshot`, then `Remove-VMSnapshot`). Checkpoint files pin
   extra slabs and reduce what consolidation can recover.

2. **Suspend the VMs running on the affected volume** so their virtual disk file
   handles are released (required for consolidation). First find where each VM is
   running, because a VM must be suspended on its owner node:

   ```powershell
   Get-ClusterGroup | Where-Object GroupType -eq 'VirtualMachine' |
       Select-Object Name, OwnerNode, State
   ```

   ```powershell
   Suspend-VM -Name "<vm name>"   # run on (or target) the VM's owner node
   ```

   Each suspended VM writes a saved-state file roughly the size of its assigned
   memory, so confirm there is enough free space on the volume first. Putting the
   cluster resource into redirected access is **not** sufficient — the VMs must
   actually be suspended (or stopped).

   > [!IMPORTANT]
   > For **Arc-managed VMs** (Azure Local 23H2+), stop the VM from Azure
   > (portal or CLI) rather than using `Suspend-VM` on the host. Suspending an
   > Arc VM directly on the host can desynchronize the Arc agent / Arc Resource
   > Bridge view of the VM state. Once workloads on the volume are stopped or
   > suspended cluster-wide, proceed with consolidation.

3. **Consolidate slabs** on the volume. For a cluster shared volume (CSV),
   address it by path and run on the CSV owner node — `-FileSystemLabel` resolves
   against the local node's volume cache and can miss or mismatch a CSV owned by
   another node:

   ```powershell
   # Identify the CSV owner node
   Get-ClusterSharedVolume | Select-Object Name, OwnerNode

   # On the owner node, consolidate by path
   Optimize-Volume -Path "C:\ClusterStorage\<volume>" -SlabConsolidate -Verbose
   ```

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
   > VMs only need to stay suspended through the consolidation in Step 3. Once
   > Step 3 reports complete, you can resume the VMs (Step 6) and run the
   > remaining steps with workloads online, shortening the maintenance window.

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

6. **Resume the VMs:**

   ```powershell
   Resume-VM -Name "<vm name>"
   ```

> [!NOTE]
> In some cases, even after a correct consolidation pass with workloads suspended,
> a final batch of slabs may remain committed and the pool does not drop as far as
> expected. If the pool stays above the threshold after a clean consolidation
> pass, open a Microsoft support case rather than repeating the procedure.

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

---
