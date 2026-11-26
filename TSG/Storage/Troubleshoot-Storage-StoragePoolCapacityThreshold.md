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
    "last_validated": "2026-10-07",
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

Stretched clusters are not supported in Azure Local
([stretched clusters][stretched]), and this guide does not cover them.

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

1. **Audit and prune.** Merge the Hyper-V checkpoints that their workload owners
   confirm are no longer needed, and remove the leftover virtual disks of VMs you
   deleted (see [Path B](#path-b-thin-provisioned-volumes-reclaim-unused-capacity)
   for how to do both safely). On thin volumes the reclaimed space returns to the
   pool gradually (about 15 minutes).
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
> here changes state: the no-downtime branch below can end in **deleting leftover
> virtual disks**, which is irreversible, the optional preparation can **remove
> checkpoints**, which is also irreversible, and the **numbered consolidation
> steps** are a scheduled maintenance-window procedure that takes VMs offline. If
> you are not that administrator, or you are unsure whether you are authorized to
> delete those disks or take these workloads offline, stop here and hand off.

> [!NOTE]
> Stretched clusters are not supported in Azure Local
> ([stretched clusters][stretched]), and Path B does not cover them.

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

**If you deleted whole VMs or files, start here. This path needs no downtime:**

1. **Confirm the virtual disk files are actually gone, not just the VMs.**
   Removing a VM does not always remove its disks, and a leftover disk keeps its
   capacity no matter how long you wait. What to do depends on how the VMs were
   created and removed:

   - **Azure Local VMs (managed in Azure).** *"Deleting a VM doesn't delete all the
     resources associated with the VM. For example, it doesn't delete the data disks
     and the network interfaces associated with the VM. You need to locate and delete
     these resources separately"* ([Delete a VM][delete-vm]). In the Azure portal, open
     the resource group the VM was in, select **Show hidden types**, and delete the
     data disks that belonged to the VMs you removed. **[HIGH RISK]** A deleted disk
     cannot be recovered, so delete only disks you can attribute to a VM you removed.
     Do not delete Azure Local disk or image files from the host: deleting a data disk
     is one of the operations Microsoft says to perform *"only via the Azure portal or
     the Azure CLI"* ([supported operations][unsupported-ops]), and a file removed on
     the host leaves its Azure resource behind.
   - **Unmanaged Hyper-V VMs removed with local tools** (`Remove-VM`, Hyper-V Manager,
     Failover Cluster Manager, or Windows Admin Center). `Remove-VM` *"deletes the
     virtual machine's configuration file, but does not delete any virtual hard
     drives"* ([Remove-VM][remove-vm]), so the disk files stay on the volume. Check
     each one with the steps below before you remove it.
   - **Anything else**, including an Azure Local VM that was removed with local tools,
     or a file you cannot attribute to a VM you removed: leave it in place and open a
     support case.

   **Check an unmanaged VM's leftover disks before you remove them.** **[READ-ONLY]**
   Paste this function once into an elevated PowerShell session (**Run as
   administrator**) on a cluster node, at its console or over Remote Desktop. Do not
   paste it into an `Enter-PSSession` session: from there it cannot reach the other
   nodes, so it stops with an error. It only reads; it changes nothing.

   ```powershell
   function Test-UnusedVirtualDisk {
       [CmdletBinding()]
       param(
           [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
           [Alias('FullName')]
           [string[]]$Path
       )
       begin {
           # Read-only. Any error while collecting stops the function before it returns a verdict.
           $ErrorActionPreference = 'Stop'
           # Ignore default parameter values set in the session, so none of them can hide an error.
           $PSDefaultParameterValues = @{}
           $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
               throw 'Run this in an elevated PowerShell session (Run as administrator).'
           }
           $nodes = @(Get-ClusterNode | ForEach-Object { $_.Name })
           if ($nodes.Count -eq 0) { throw 'Get-ClusterNode returned no nodes.' }
           # Files are checked only under a Cluster Shared Volume, and every path is compared in one standard form.
           $csvRoots = @(Get-ClusterSharedVolume | ForEach-Object { $_.SharedVolumeInfo } | ForEach-Object { [IO.Path]::GetFullPath($_.FriendlyVolumeName).TrimEnd('\') + '\' })
           if ($csvRoots.Count -eq 0) { throw 'Get-ClusterSharedVolume returned no volumes.' }
           # Folders that Azure Local manages: VM images, and the disks and settings of Azure Local VMs.
           try {
               # Get-MocContainer returns its results as one array object; ForEach-Object unrolls it.
               $containers = @(Get-MocContainer -location (Get-MocConfig).cloudLocation | ForEach-Object { $_ })
           } catch {
               throw "Could not read the Azure Local storage folders. $($_.Exception.Message)"
           }
           $managed = @($containers | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $_.properties.path $_.ID)).TrimEnd('\') + '\' })
           if ($managed.Count -eq 0) { throw 'No Azure Local storage folders were returned.' }
           foreach ($folder in $managed) {
               if (-not (Test-Path -LiteralPath $folder)) { throw "Azure Local storage folder not found: $folder" }
           }
           # Every disk that a VM on any node uses, and every parent of it, read on that VM's node.
           $inUse = @{}
           $inUseId = @{}
           $seenVm = @{}
           foreach ($node in $nodes) {
               try { $vms = @(Get-VM -ComputerName $node) }
               catch { throw "Could not list the VMs on node $node. Every node must respond. $($_.Exception.Message)" }
               foreach ($vm in $vms) {
                   $seenVm["$($vm.Id)"] = $true
                   try { $drives = @($vm | Get-VMHardDiskDrive) + @($vm | Get-VMSnapshot | Get-VMHardDiskDrive) }
                   catch { throw "Could not read the disks of VM '$($vm.Name)' on node $node. $($_.Exception.Message)" }
                   foreach ($drive in $drives) {
                       if ($null -ne $drive.DiskNumber) { continue }
                       if (-not $drive.Path) { throw "VM '$($vm.Name)' on node $node has a virtual disk with no path." }
                       $p = $drive.Path
                       $depth = 0
                       while ($p) {
                           $why = "Used by VM '$($vm.Name)' on node $node."
                           if ($depth -gt 0) { $why = "Parent of a disk used by VM '$($vm.Name)' on node $node." }
                           $inUse[[IO.Path]::GetFullPath($p).ToLowerInvariant()] = $why
                           if ($p -like '*.vhds') { break }
                           try { $vhd = Get-VHD -ComputerName $node -Path $p }
                           catch { throw "Could not read '$p' (VM '$($vm.Name)' on node $node). $($_.Exception.Message)" }
                           if ($vhd.DiskIdentifier) { $inUseId["$($vhd.DiskIdentifier)"] = $why }
                           $p = $vhd.ParentPath
                           $depth++
                           if ($depth -gt 64) { throw "The parent chain of '$($drive.Path)' is longer than 64 disks." }
                       }
                   }
               }
           }
           # Every clustered VM must have been seen, so a VM that moved between nodes during the check is not missed.
           foreach ($vm in @(Get-ClusterGroup | Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' } | Get-VM)) {
               if (-not $seenVm.ContainsKey("$($vm.Id)")) { throw "Clustered VM '$($vm.Name)' was not found on any node. Run the check again." }
           }
           $reasonFor = {
               param([string]$File)
               $lower = $File.ToLowerInvariant()
               $onCsv = $false
               foreach ($root in $csvRoots) { if ($lower.StartsWith($root.ToLowerInvariant())) { $onCsv = $true } }
               if (-not $onCsv) { return 'Not a full path under a Cluster Shared Volume (C:\ClusterStorage\<volume>\). Give the path in that form.' }
               if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { return 'File not found.' }
               if ([IO.Path]::GetExtension($lower) -notin '.vhd', '.vhdx') { return 'Not a .vhd or .vhdx file. Checkpoint (.avhdx, .avhd) and VHD Set (.vhds) files are never cleared by this check.' }
               foreach ($folder in $managed) {
                   if ($lower.StartsWith($folder.ToLowerInvariant())) { return 'Inside an Azure Local storage folder. Manage it through Azure, not from the host.' }
               }
               if ($lower -match '\\mocarb\\' -or $lower -match '^[a-z]:\\clusterstorage\\infrastructure_\d+\\') { return 'Azure Local infrastructure data.' }
               if ($inUse.ContainsKey($lower)) { return $inUse[$lower] }
               # Ask every node, so the reason names the node that has the file attached.
               $unread = $null
               foreach ($node in $nodes) {
                   try { $v = Get-VHD -ComputerName $node -Path $File }
                   catch { if (-not $unread) { $unread = $node }; continue }
                   if ($v.Attached) { return "Attached on node $node." }
                   if ($v.DiskIdentifier -and $inUseId.ContainsKey("$($v.DiskIdentifier)")) { return 'Same disk identifier as a disk in use. ' + $inUseId["$($v.DiskIdentifier)"] }
               }
               if ($unread) { return "Node $unread could not read it. It may be in use on another node, or it may not be a valid virtual disk." }
               return $null
           }
       }
       process {
           foreach ($item in $Path) {
               $file = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($item))
               $reason = & $reasonFor $file
               $verdict = 'Keep'
               if (-not $reason) {
                   $verdict = 'NoReferenceFound'
                   $reason = 'No VM on any node uses it or depends on it, and no node has it attached. Remove it only if it belonged to a VM you removed.'
               }
               $size = $null
               if (Test-Path -LiteralPath $file -PathType Leaf) { $size = [math]::Round((Get-Item -LiteralPath $file).Length / 1GB, 2) }
               [pscustomobject]@{ Path = $file; SizeGB = $size; Verdict = $verdict; Reason = $reason }
           }
       }
   }
   ```

   The function reads every node in the cluster. If anything prevents a complete
   answer, it stops with an error and returns no verdicts: a node that does not
   respond, a VM disk or parent disk it cannot read, Azure Local storage information
   it cannot read, or a clustered VM it did not find. For example, when a node does
   not answer, it stops with `Could not list the VMs on node NODE02. Every node must
   respond.` In that case nothing was checked. Fix the condition the error names and
   run it again, or open a support case. Do not work around it.

   Run it on the disk files of the VMs you removed. To check every virtual disk in a
   folder those VMs used:

   ```powershell
   Get-ChildItem -LiteralPath 'C:\ClusterStorage\<volume>\<folder the removed VMs used>' -Recurse -File |
       Where-Object { $_.Extension -in '.vhd', '.vhdx' } |
       Test-UnusedVirtualDisk | Format-List Path, SizeGB, Verdict, Reason
   ```

   Example output (the names and sizes are examples):

   ```text
   Path    : C:\ClusterStorage\<volume>\old-vms\old-app01.vhdx
   SizeGB  : 41.5
   Verdict : NoReferenceFound
   Reason  : No VM on any node uses it or depends on it, and no node has it attached. Remove it only if it belonged to a VM you removed.

   Path    : C:\ClusterStorage\<volume>\old-vms\base-image.vhdx
   SizeGB  : 12.2
   Verdict : Keep
   Reason  : Parent of a disk used by VM 'vm-web01' on node NODE02.
   ```

   Each file gets a `Verdict`:

   - `Keep`: do not remove it. `Reason` says why: a VM on a named node uses it or
     depends on it as a parent disk, a node has it attached or cannot read it, it is
     inside an Azure Local storage folder (manage it through Azure instead), it is a
     checkpoint or VHD Set file (see the note below), or the path is not a full path
     under `C:\ClusterStorage\`.
   - `NoReferenceFound`: no VM on any node uses it or depends on it, no node has it
     attached, and it is not in an Azure Local storage folder. The function cannot see
     templates, golden images, ISO libraries, or backup copies, which legitimately
     have no VM. Remove the file only if you can attribute it to a VM you removed.

   > [!NOTE]
   > The check always returns `Keep` for checkpoint files (`.avhdx`, `.avhd`) and VHD
   > Set files (`.vhds`). Do not delete either kind by hand.
   >
   > - **Checkpoints** are differencing disks in a chain that Hyper-V owns. To free
   >   space held by checkpoints of a VM that still exists, merge them through
   >   Hyper-V, and only the ones that the workload owner approves (see the
   >   checkpoint preparation in the consolidation procedure below). When
   >   `Remove-VM` deletes a VM, its checkpoints *"are deleted and merged into the
   >   virtual hard disk files after the virtual machine is deleted"*
   >   ([Remove-VM][remove-vm]), so a checkpoint file that outlives its VM means that
   >   merge did not finish. Open a support case.
   > - **A VHD Set** is shared storage for a guest cluster. The VM configuration names
   >   the `.vhds` file, but the data is in a companion file (named
   >   `<name>_<GUID>.avhdx` when Hyper-V creates the set) that no VM configuration
   >   names. Open a support case rather than deleting VHD Set files.

   > [!WARNING]
   > **Deleting a virtual disk file is irreversible and destroys whatever it
   > contains.** `NoReferenceFound` means no VM on this cluster uses the file; it does
   > not mean nothing else needs it. If you cannot attribute a file to a VM you
   > removed, leave it in place and open a support case. Reclaiming capacity is never
   > worth deleting a disk you could not identify.

   **Remove each file in two stages: rename it first, delete it later.** For each
   file with the verdict `NoReferenceFound`, run the following. It runs the whole
   check again at that moment and renames the file only if the verdict is still
   `NoReferenceFound`. **[MEDIUM RISK]**

   ```powershell
   $file = '<full path of one file with the verdict NoReferenceFound>'
   $check = $null
   $check = Test-UnusedVirtualDisk -Path $file
   if ($check.Verdict -eq 'NoReferenceFound') { Rename-Item -LiteralPath $file -NewName ((Split-Path $file -Leaf) + '.pending-delete') -ErrorAction Stop; "Renamed to $file.pending-delete" } else { "Not renamed. $($check.Reason)" }
   ```

   The rename frees no capacity yet, and you can undo it. If a VM fails to start, or
   an application or backup job reports a missing file, put the name back:

   ```powershell
   Rename-Item -LiteralPath '<full path>.pending-delete' -NewName '<original file name>'
   ```

   When nothing has reported the file missing (start any stopped VMs you still need,
   and let one backup cycle complete), delete it. **[HIGH RISK]**

   ```powershell
   Remove-Item -LiteralPath '<full path>.pending-delete'
   ```
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
> above cost little and can make the maintenance window unnecessary: remove the
> leftover disks of VMs you deleted, confirm the provisioning type, and if whole
> files were deleted just wait and re-measure.
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

**Before the window: list the VMs that use the affected volume.** **[READ-ONLY]**
Consolidation can only move data that no running VM holds open, so the window has
to stop exactly the VMs that have files on the affected volume, whichever node they
run on. A VM counts if the volume holds its configuration files, one of its virtual
disks, a parent disk that one of its virtual disks is built on (the parent can be
on a different volume from the VM), or an ISO in its DVD drive. A VM that is not in
the list keeps none of those files on the volume and can keep running.

Paste this function once into an elevated PowerShell session (**Run as
administrator**) on a cluster node, at its console or over Remote Desktop. Do not
paste it into an `Enter-PSSession` session: from there it cannot reach the other
nodes, so it stops with an error. It only reads; it changes nothing.

```powershell
function Get-VirtualMachineOnVolume {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Volume
    )
    # Read-only. Any error while collecting stops the function before it lists any VM.
    $ErrorActionPreference = 'Stop'
    # Ignore default parameter values set in the session, so none of them can hide an error.
    $PSDefaultParameterValues = @{}
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this in an elevated PowerShell session (Run as administrator).'
    }
    # Every path is compared in one standard form: a full path, without a \\?\ prefix, in lower case.
    # A path in any other form stops the function, so a VM is never left out because its path was not understood.
    $csvBase = $env:SystemDrive.ToLowerInvariant() + '\clusterstorage\'
    $norm = {
        param([string]$P)
        $s = $P.Trim()
        if ($s.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) { $s = '\\' + $s.Substring(8) }
        if ($s.StartsWith('\\?\', [StringComparison]::Ordinal) -or $s.StartsWith('\\.\', [StringComparison]::Ordinal)) { $s = $s.Substring(4) }
        if ($s -notmatch '^[A-Za-z]:\\' -and $s -notmatch '^\\\\[^\\]+\\') { throw "Unexpected path form: '$P'." }
        $s = [IO.Path]::GetFullPath($s).ToLowerInvariant()
        if ($s -match '^\\\\[^\\]+\\clusterstorage\$\\') { $s = $csvBase + $s.Substring($Matches[0].Length) }
        $s
    }
    $nodes = @(Get-ClusterNode | ForEach-Object { $_.Name })
    if ($nodes.Count -eq 0) { throw 'Get-ClusterNode returned no nodes.' }
    $csvRoots = @(Get-ClusterSharedVolume | ForEach-Object { $_.SharedVolumeInfo } | ForEach-Object { (& $norm $_.FriendlyVolumeName).TrimEnd('\') + '\' })
    if ($csvRoots.Count -eq 0) { throw 'Get-ClusterSharedVolume returned no volumes.' }
    $target = (& $norm $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Volume)).TrimEnd('\') + '\'
    if ($csvRoots -notcontains $target) { throw "'$Volume' is not a Cluster Shared Volume. Give its path in the form C:\ClusterStorage\<volume>." }
    # Folders that Azure Local manages: VM images, and the disks and settings of Azure Local VMs.
    try {
        # Get-MocContainer returns its results as one array object; ForEach-Object unrolls it.
        $containers = @(Get-MocContainer -location (Get-MocConfig).cloudLocation | ForEach-Object { $_ })
    } catch {
        throw "Could not read the Azure Local storage folders. $($_.Exception.Message)"
    }
    $managed = @($containers | ForEach-Object { (& $norm (Join-Path $_.properties.path $_.ID)).TrimEnd('\') + '\' })
    if ($managed.Count -eq 0) { throw 'No Azure Local storage folders were returned.' }
    $found = @{}
    $seenVm = @{}
    foreach ($node in $nodes) {
        try { $vms = @(Get-VM -ComputerName $node) }
        catch { throw "Could not list the VMs on node $node. Every node must respond. $($_.Exception.Message)" }
        foreach ($vm in $vms) {
            $seenVm["$($vm.Id)"] = $true
            if (-not $vm.ConfigurationLocation) { throw "VM '$($vm.Name)' on node $node has no configuration location." }
            # The files a VM uses: its configuration, its virtual disks and every parent they are built on, and any ISO.
            $files = @([pscustomobject]@{ Path = $vm.ConfigurationLocation.TrimEnd('\') + '\'; Use = 'configuration' })
            try { $drives = @($vm | Get-VMHardDiskDrive); $dvds = @($vm | Get-VMDvdDrive) }
            catch { throw "Could not read the drives of VM '$($vm.Name)' on node $node. $($_.Exception.Message)" }
            foreach ($dvd in $dvds) { if ("$($dvd.DvdMediaType)" -ne 'PassThrough' -and $dvd.Path) { $files += [pscustomobject]@{ Path = $dvd.Path; Use = 'ISO' } } }
            foreach ($drive in $drives) {
                if ($null -ne $drive.DiskNumber) { continue }
                if (-not $drive.Path) { throw "VM '$($vm.Name)' on node $node has a virtual disk with no path." }
                $p = $drive.Path
                $use = 'virtual disk'
                $depth = 0
                while ($p) {
                    $files += [pscustomobject]@{ Path = $p; Use = $use }
                    if ($p -like '*.vhds') { break }
                    try { $vhd = Get-VHD -ComputerName $node -Path $p }
                    catch { throw "Could not read '$p' (VM '$($vm.Name)' on node $node). $($_.Exception.Message)" }
                    $p = $vhd.ParentPath
                    $use = 'parent disk'
                    $depth++
                    if ($depth -gt 64) { throw "The parent chain of '$($drive.Path)' is longer than 64 disks." }
                }
            }
            $uses = @()
            $azure = $false
            $infra = $false
            foreach ($f in $files) {
                $n = & $norm $f.Path
                if ($n.StartsWith($target, [StringComparison]::Ordinal) -and $uses -notcontains $f.Use) { $uses += $f.Use }
                # Where an ISO is stored says nothing about who manages the VM, so only the VM's own files decide StopFrom.
                if ($f.Use -eq 'ISO') { continue }
                if ($n -match '\\mocarb\\' -or $n -match '^[a-z]:\\clusterstorage\\infrastructure_\d+\\') { $infra = $true }
                foreach ($folder in $managed) { if ($n.StartsWith($folder, [StringComparison]::Ordinal)) { $azure = $true } }
            }
            if ($uses.Count -eq 0) { continue }
            $stopFrom = 'Host'
            if ($azure) { $stopFrom = 'Azure' }
            if ($infra) { $stopFrom = 'DoNotStop' }
            $found["$($vm.Id)"] = [pscustomobject]@{ VM = $vm.Name; Node = $node; State = "$($vm.State)"; StopFrom = $stopFrom; Uses = $uses -join ', '; Id = $vm.Id }
        }
    }
    # Every clustered VM must have been seen, so a VM that moved between nodes during the check is not missed.
    foreach ($vm in @(Get-ClusterGroup | Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' } | Get-VM)) {
        if (-not $seenVm.ContainsKey("$($vm.Id)")) { throw "Clustered VM '$($vm.Name)' was not found on any node. Run the check again." }
    }
    $list = @($found.Values | Sort-Object VM)
    Write-Host "Checked $($seenVm.Count) VMs on $($nodes.Count) nodes. $($list.Count) of them use $Volume."
    $list
}
```

Then list the VMs that use the volume you are going to consolidate. Run this when
you plan the window, to see which workloads it affects, and again in Step 1: at the
start of the window, and after you stop the VMs.

```powershell
$vmList = $null
$vmList = Get-VirtualMachineOnVolume -Volume 'C:\ClusterStorage\<volume>'
$vmList | Format-List VM, Node, State, StopFrom, Uses, Id
```

The first line clears any list from an earlier run, so if the function stops with an
error, no old list is shown in its place. The list shows each VM's full `Id`, which
Step 1 uses to stop the VM.

Expected output (the names and Ids are examples):

```text
Checked 17 VMs on 2 nodes. 3 of them use C:\ClusterStorage\<volume>.

VM       : vm-app01
Node     : NODE01
State    : Running
StopFrom : Host
Uses     : configuration, virtual disk
Id       : 00000000-0000-0000-0000-000000000001

VM       : vm-db01
Node     : NODE02
State    : Running
StopFrom : Azure
Uses     : configuration, virtual disk
Id       : 00000000-0000-0000-0000-000000000002

VM       : vm-web01
Node     : NODE01
State    : Off
StopFrom : Host
Uses     : parent disk
Id       : 00000000-0000-0000-0000-000000000003
```

- `StopFrom` says how to stop each VM. `Host` is a Hyper-V VM that you stop on the
  host in Step 1. `Azure` means its files are in an Azure Local storage folder, so
  Azure manages it: stop it from Azure, not from the host, and if you cannot find
  it in Azure (for example, a node of an AKS cluster), do not stop it with host
  tools; open a support case. `DoNotStop` means Azure Local infrastructure, such
  as the Arc Resource Bridge. If any VM in the list shows `DoNotStop`, do not
  continue; open a support case.
- `Uses` says what the volume holds for that VM.
- If the list taken at the start of the window says that 0 VMs use the volume,
  nothing needs to be stopped. Go to Step 2.
- The function reads every node. If anything prevents a complete answer, it stops
  with an error and lists no VMs: a node that does not respond, a VM drive, disk or
  parent disk it cannot read, Azure Local storage information it cannot read, or a
  clustered VM it did not find. For example, when a node does not answer, it stops
  with `Could not list the VMs on node NODE02. Every node must respond.` In that
  case nothing was checked. Fix the condition the error names and run it again, or
  open a support case. Do not stop VMs from a list you put together another way.

**Preparation (optional, no downtime, before the window): merge only the
checkpoints that the workload owner approves.** **[MEDIUM RISK]** Checkpoint files
hold data that pins extra slabs and reduces what consolidation can recover.
Removing a checkpoint deletes it. Hyper-V then merges, deletes, or keeps the
differencing disks (`.avhdx`) involved, depending on the VM's other checkpoints (see
below); it does not revert the VM. **This cannot be undone:** the checkpoint is
gone, and the only recovery is to restore the VM from a backup, which returns it to
the time of that backup, not to the checkpoint. For Azure Local VMs (`StopFrom` set
to `Azure`), Microsoft lists checkpoints with local tools as supported on Azure
Local 2504 and later ([supported operations][unsupported-ops]); on an earlier
release, open a support case instead.

- **List** the checkpoints of the VMs that use the volume. **[READ-ONLY]**

  ```powershell
  $checkpoints = $null
  $checkpoints = @($vmList | Where-Object Id | ForEach-Object { Get-VM -ComputerName $_.Node -Id $_.Id | Get-VMSnapshot })
  $checkpoints | Format-List VMName, Name, SnapshotType, CreationTime, Id
  ```

  Remove only checkpoints whose `SnapshotType` is `Standard`. Any other type belongs
  to a backup or replication product; leave it to that product and its
  administrator.

- **Approve.** For each checkpoint you want to remove, get confirmation from the
  workload owner that it is no longer needed, and that a backup of the VM exists
  from a point in time they would accept going back to. Record who approved it.
  Remove nothing without that approval.
- **Select** one approved checkpoint by its `Id` from the list. Only a `Standard`
  checkpoint can be selected. The VM must be `Running` or `Off`, with nothing else
  in progress, and the removal step checks that again right before it removes
  anything. Microsoft's checkpoint troubleshooting checklist says to *"Verify that
  the VM isn't in the "saved," "creating checkpoint," or "stopping" state"*
  ([Hyper-V checkpoint troubleshooting][ckpt-ts]). **[READ-ONLY]**

  ```powershell
  $c = @($checkpoints | Where-Object { $_.Id -eq '<Id of one approved checkpoint>' -and "$($_.SnapshotType)" -eq 'Standard' }); "Selected $($c.Count) checkpoint(s). $($c.VMName) $($c.Name)"
  ```

- **Work out what the removal writes, and check that there is room for it.**
  **[READ-ONLY]** Removing a checkpoint does not always merge that checkpoint's own
  differencing disk. Hyper-V works it out from all of the VM's checkpoints: a disk
  that nothing needs any more is merged with the one disk built on it, deleted when
  no disk is built on it, and kept while two or more are. When the VM's checkpoints
  branch (someone applied an older checkpoint and kept the newer ones), removing one
  checkpoint can delete a file and merge a disk of another branch. In a lab test,
  removing the checkpoint at the end of one branch also merged the VM's current disk
  into its base disk.

  Paste these two functions once into the elevated session that you used for the VM
  list. `Test-CheckpointRemoval` only reads. `Remove-ApprovedCheckpoint` removes the
  checkpoint, and only after you confirm.

  ```powershell
  function Test-CheckpointRemoval {
      [CmdletBinding()]
      param(
          [Parameter(Mandatory = $true)]
          [AllowNull()]
          [AllowEmptyCollection()]
          [object[]]$Checkpoint,
          [switch]$Quiet
      )
      # Read-only. Works out what Hyper-V writes when this one checkpoint is removed. Any error stops the function.
      $ErrorActionPreference = 'Stop'
      # Ignore default parameter values set in the session, so none of them can hide an error.
      $PSDefaultParameterValues = @{}
      $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this in an elevated PowerShell session (Run as administrator).' }
      $sel = @($Checkpoint | Where-Object { $_ })
      if ($sel.Count -ne 1) { throw 'Select exactly one approved Standard checkpoint first.' }
      $s = $sel[0]
      $vm = Get-VM -ComputerName $s.ComputerName -Id $s.VMId
      if (@($vm.OperationalStatus) -contains 'MergingDisks') { throw "VM '$($vm.Name)' is still merging disks. Wait until that merge has finished." }
      $snaps = @(Get-VMSnapshot -VM $vm)
      if (@($snaps | Where-Object { "$($_.Id)" -eq "$($s.Id)" }).Count -ne 1) { throw 'The selected checkpoint no longer exists. List and select again.' }
      # Paths are compared as full paths in lower case. Only disk files on Cluster Shared Volumes are covered.
      $csvBase = $env:SystemDrive.ToLowerInvariant() + '\clusterstorage\'
      $norm = {
          param([string]$P)
          $x = $P.Trim()
          if ($x.StartsWith('\\?\', [StringComparison]::Ordinal)) { $x = $x.Substring(4) }
          if ($x -notmatch '^[A-Za-z]:\\') { throw "'$P' is not a disk file on this cluster. A VM with this disk is not covered here." }
          $x = [IO.Path]::GetFullPath($x).ToLowerInvariant()
          if (-not $x.StartsWith($csvBase, [StringComparison]::Ordinal)) { throw "'$P' is not on a Cluster Shared Volume. A VM with this disk is not covered here." }
          if ($x.EndsWith('.vhds')) { throw "'$P' is a VHD Set. A VM with this disk is not covered here." }
          $x
      }
      # Follow the disks of the VM and of every checkpoint up to the first disk that is not a checkpoint differencing
      # disk (.avhdx). $use counts what still uses each disk once the selected checkpoint is gone.
      $vhd = @{}; $par = @{}; $kids = @{}; $use = @{}; $start = @()
      $owners = @(@{ Sel = $false; Drives = @(Get-VMHardDiskDrive -VM $vm) }) + @($snaps | ForEach-Object { @{ Sel = ("$($_.Id)" -eq "$($s.Id)"); Drives = @(Get-VMHardDiskDrive -VMSnapshot $_) } })
      foreach ($o in $owners) {
          foreach ($d in $o.Drives) {
              $k = & $norm "$($d.Path)"
              if ($o.Sel) { $start += $k } else { $use[$k] = 1 + [int]$use[$k] }
              $p = "$($d.Path)"
              while ($p) {
                  $pk = & $norm $p
                  if ($vhd.ContainsKey($pk)) { break }
                  $v = Get-VHD -ComputerName $s.ComputerName -Path $p
                  $vhd[$pk] = $v; $par[$pk] = ''; $p = ''
                  if ($pk -match '\.avhdx?$') {
                      if (-not $v.ParentPath) { throw "'$($v.Path)' has no parent disk." }
                      $par[$pk] = & $norm $v.ParentPath
                      $p = "$($v.ParentPath)"
                  }
              }
          }
      }
      foreach ($k in @($vhd.Keys)) { $kids[$k] = @() }
      foreach ($k in @($vhd.Keys)) { if ($par[$k]) { $kids[$par[$k]] += $k } }
      $rootOf = { param([string]$K) while ($par[$K]) { $K = $par[$K] }; $K }
      $roots = @($owners[0].Drives | ForEach-Object { & $rootOf (& $norm "$($_.Path)") })
      foreach ($k in $start) { if ($roots -notcontains (& $rootOf $k)) { throw "The checkpoint has a disk that the VM no longer uses ('$($vhd[$k].Path)'). This is not covered here." } }
      foreach ($k in @($vhd.Keys)) { if ([int]$use[$k] -eq 0 -and $start -notcontains $k -and @($kids[$k]).Count -eq 1) { throw "No checkpoint uses '$($vhd[$k].Path)' any more, but a disk is still built on it, so this check cannot tell what Hyper-V merges next. Remove no checkpoints of this VM; open a support case." } }
      # Remove the checkpoint on paper, the way Hyper-V does it: a disk that nothing uses any more is deleted when no disk
      # is built on it, merged with the disk built on it when there is one, and kept while two or more are built on it.
      $rows = New-Object System.Collections.ArrayList
      $todo = New-Object System.Collections.Queue
      foreach ($k in $start) { $todo.Enqueue($k) }
      $steps = 0
      while ($todo.Count -gt 0) {
          if (++$steps -gt 1000) { throw 'Could not work out what the removal does.' }
          $x = $todo.Dequeue()
          if (-not $vhd.ContainsKey($x) -or [int]$use[$x] -gt 0) { continue }
          $kx = @($kids[$x])
          if ($kx.Count -ge 2) { [void]$rows.Add([pscustomobject]@{ Action = 'Keep'; Disk = $vhd[$x].Path; Removed = ''; Data = 0.0; Need = 0.0; Volume = '' }); continue }
          if ($kx.Count -eq 0) {
              if ($x -notmatch '\.avhdx?$') { throw "Could not tell what Hyper-V does with '$($vhd[$x].Path)'." }
              [void]$rows.Add([pscustomobject]@{ Action = 'Delete'; Disk = $vhd[$x].Path; Removed = $vhd[$x].Path; Data = 0.0; Need = 0.0; Volume = '' })
              $p = $par[$x]
              $vhd.Remove($x)
              if ($p) { $kids[$p] = @($kids[$p] | Where-Object { $_ -ne $x }); $todo.Enqueue($p) }
              continue
          }
          $y = $kx[0]; $t = $vhd[$x]; $f = $vhd[$y]
          if ($f.BlockSize -le 0 -or ("$($t.VhdType)" -ne 'Fixed' -and $t.BlockSize -le 0)) { throw "Could not read the block size of '$($f.Path)' or '$($t.Path)'." }
          # Each block of the merged disk (2 MB) can add a whole block (32 MB on a dynamic disk) to the disk it goes into.
          $grow = 0.0
          if ("$($t.VhdType)" -ne 'Fixed') { $grow = [Math]::Min([Math]::Ceiling([double]$f.FileSize / $f.BlockSize) * $t.BlockSize, [Math]::Max(0.0, [double]$t.Size - [double]$t.FileSize)) }
          [void]$rows.Add([pscustomobject]@{ Action = 'Merge'; Disk = $t.Path; Removed = $f.Path; Data = [double]$f.FileSize; Need = [double]$f.FileSize + $grow; Volume = '' })
          $use[$x] = [int]$use[$y]
          $kids[$x] = @($kids[$y])
          foreach ($g in @($kids[$y])) { $par[$g] = $x }
          $vhd.Remove($y)
          $todo.Enqueue($x)
      }
      if ($rows.Count -eq 0) { throw 'Could not work out what the removal does.' }
      # For each volume a merge writes to: its free space, and how its virtual disk grows in the pool. A thin virtual
      # disk takes pool space in whole allocation units (unit size times columns, for each copy).
      $vols = @{}
      foreach ($r in @($rows | Where-Object { $_.Need -gt 0 })) {
          $v = Get-Volume -FilePath $r.Disk -ErrorAction Stop
          $id = "$($v.UniqueId)"
          if (-not $vols.ContainsKey($id)) {
              $vd = @($v | Get-Partition -ErrorAction Stop | Get-Disk -ErrorAction Stop | Get-VirtualDisk -ErrorAction Stop)
              if ($vd.Count -ne 1) { throw "Could not find the virtual disk of the volume that holds '$($r.Disk)'." }
              $parts = @($vd[0]) + @(Get-StorageTier -VirtualDisk $vd[0] -ErrorAction Stop)
              $copies = ($parts | ForEach-Object { [Math]::Max([int]$_.NumberOfDataCopies, 1 + [int]$_.PhysicalDiskRedundancy) } | Measure-Object -Maximum).Maximum
              $unit = ($parts | ForEach-Object { [double]$_.AllocationUnitSize * [int]$_.NumberOfColumns } | Measure-Object -Maximum).Maximum
              $thin = "$($vd[0].ProvisioningType)" -ne 'Fixed'
              if ($thin -and $unit -le 0) { throw "Could not read the allocation unit of virtual disk '$($vd[0].FriendlyName)'." }
              $pool = Get-StoragePool -VirtualDisk $vd[0] -ErrorAction Stop
              $vols[$id] = [pscustomobject]@{ Volume = $v.FileSystemLabel; Free = [double]$v.SizeRemaining; Keep = [Math]::Max(0.05 * $v.Size, 10GB); Need = 0.0; Copies = [int]$copies; Unit = [double]$unit; Thin = $thin; Pool = $pool }
          }
          $vols[$id].Need += $r.Need
          $r.Volume = $vols[$id].Volume
      }
      # The pool keeps a reserve free for repairs: the size of one capacity drive per server, up to four.
      $pools = @($vols.Values | Group-Object { $_.Pool.UniqueId } | ForEach-Object {
          $pl = $_.Group[0].Pool
          $big = (@(Get-PhysicalDisk -StoragePool $pl -ErrorAction Stop | Where-Object { "$($_.Usage)" -ne 'Journal' }) | Measure-Object Size -Maximum).Maximum
          if (-not ($big -gt 0)) { throw "Could not read the capacity drives of pool '$($pl.FriendlyName)'." }
          $need = 0.0
          foreach ($o in @($_.Group | Where-Object Thin)) { $need += ([Math]::Ceiling($o.Need / $o.Unit) + 1) * $o.Unit * $o.Copies }
          [pscustomobject]@{ Name = $pl.FriendlyName; Free = [double]$pl.Size - [double]$pl.AllocatedSize; Need = $need; Keep = [double]$big * [Math]::Min(4, @(Get-ClusterNode).Count) }
      })
      # A merge that is already running elsewhere in the cluster uses the same free space.
      $merging = @(Get-ClusterNode | ForEach-Object { Get-VM -ComputerName $_.Name } | Where-Object { @($_.OperationalStatus) -contains 'MergingDisks' } | ForEach-Object { $_.Name })
      $room = $vols.Count -eq 0 -or $merging.Count -eq 0
      foreach ($o in @($vols.Values) + $pools) { if ($o.Need -gt 0 -and $o.Free - $o.Need -lt $o.Keep) { $room = $false } }
      $state = "$($vm.State)"
      $busy = (@($vm.OperationalStatus) | ForEach-Object { "$_" }) -join ', '
      if (-not $Quiet) {
          foreach ($o in $vols.Values) { Write-Host ('Volume {0}: {1:N1} GB free. The merge can need up to {2:N1} GB, and the volume should keep {3:N1} GB free.' -f $o.Volume, ($o.Free / 1GB), ($o.Need / 1GB), ($o.Keep / 1GB)) }
          foreach ($o in $pools) { Write-Host ('Pool {0}: {1:N1} GB free. The merge can need up to {2:N1} GB, and the pool should keep {3:N1} GB free as its reserve.' -f $o.Name, ($o.Free / 1GB), ($o.Need / 1GB), ($o.Keep / 1GB)) }
          if ($vols.Count -eq 0) { Write-Host 'Nothing is merged, so this removal needs no free space.' }
          if ($merging.Count -and $vols.Count) { Write-Host "Another merge is running (VM $($merging -join ', ')). Wait until it has finished." }
          if ($room) { Write-Host 'There is room for this removal.' } else { Write-Host 'NOT ENOUGH ROOM. Do not remove this checkpoint now.' }
          if (($state -ne 'Running' -and $state -ne 'Off') -or $busy -ne 'Ok') { Write-Host "VM '$($vm.Name)' is $state ($busy). The removal step refuses until it is Running or Off with nothing else in progress (Ok)." }
      }
      $rows | ForEach-Object { [pscustomobject]@{ Action = $_.Action; Disk = $_.Disk; Removed = $_.Removed; DataGB = [Math]::Round($_.Data / 1GB, 1); NeedGB = [Math]::Round($_.Need / 1GB, 1); Volume = $_.Volume; Room = $room } }
  }
  function Remove-ApprovedCheckpoint {
      [CmdletBinding()]
      param(
          [Parameter(Mandatory = $true)]
          [AllowNull()]
          [AllowEmptyCollection()]
          [object[]]$Checkpoint
      )
      # Asks first. Then reads the checkpoint, the room for the merge and the VM state again, and removes the checkpoint
      # only if all of them still allow it. Any error stops the function before it removes anything. Returns the plan.
      $ErrorActionPreference = 'Stop'
      $PSDefaultParameterValues = @{}
      $sel = @($Checkpoint | Where-Object { $_ })
      if ($sel.Count -ne 1) { throw 'Nothing was removed. Select exactly one approved Standard checkpoint first.' }
      $s = $sel[0]
      $choices = [Management.Automation.Host.ChoiceDescription[]]@('&Yes', '&No')
      $answer = $Host.UI.PromptForChoice('Remove checkpoint', "Remove checkpoint '$($s.Name)' of VM '$($s.VMName)'? This cannot be undone.", $choices, 1)
      if ($answer -ne 0) { Write-Host 'Nothing was removed.'; return }
      $fresh = Get-VMSnapshot -ComputerName $s.ComputerName -Id $s.Id
      if ("$($fresh.SnapshotType)" -ne 'Standard') { throw 'Nothing was removed. The checkpoint is not a Standard checkpoint.' }
      $plan = @(Test-CheckpointRemoval -Checkpoint @($fresh) -Quiet)
      if (-not $plan[0].Room) { throw 'Nothing was removed. There is not enough room for the merge. Run Test-CheckpointRemoval to see why.' }
      $vm = Get-VM -ComputerName $s.ComputerName -Id $s.VMId
      $state = "$($vm.State)"
      $busy = (@($vm.OperationalStatus) | ForEach-Object { "$_" }) -join ', '
      if (($state -ne 'Running' -and $state -ne 'Off') -or $busy -ne 'Ok') { throw "Nothing was removed. VM '$($s.VMName)' is $state ($busy). Remove a checkpoint only while its VM is Running or Off with nothing else in progress (Ok)." }
      Remove-VMSnapshot -VMSnapshot $fresh -Confirm:$false -WhatIf:$false
      Write-Host "Removal of checkpoint '$($s.Name)' of VM '$($s.VMName)' started. Wait for the merge to finish."
      $plan
  }
  ```

  Then work out what removing the selected checkpoint does:

  ```powershell
  $plan = $null
  $plan = Test-CheckpointRemoval -Checkpoint $c
  $plan | Format-List Action, Disk, Removed, DataGB, NeedGB, Volume
  ```

  Each entry is one thing that Hyper-V does:

  - `Merge`: writes the disk in `Removed` into `Disk`, then deletes `Removed`.
  - `Delete`: deletes `Disk`, and writes nothing.
  - `Keep`: keeps `Disk`, because two or more disks are built on it. Nothing is
    written now. It can be merged later, when only one disk is still built on it.

  `NeedGB` is the most that a merge can add to the volume that holds `Disk`, and it
  can be much more than `DataGB`, the size of the disk being merged. A checkpoint
  disk stores changes in 2 MB blocks, and each of them can add a whole 32 MB block to
  a dynamic disk. In a lab test, merging 0.3 GB of scattered changes grew the dynamic
  disk they went into by 4 GB. The function reports room only when, after the most
  that the merges can add:

  - each volume that a merge writes to still has 5% of its size free, and at least
    10 GB;
  - the pool still has its reserve free: the size of one capacity drive per server,
    up to four. A thin volume takes pool space in whole allocation units of its
    virtual disk (allocation unit size times columns), so for each thin volume the
    function rounds up to whole units, adds one more, and counts every copy that the
    volume keeps (for a parity volume, more than parity uses). A fixed volume
    already holds all of its pool space, so its merges add nothing to the pool;
  - no other VM in the cluster is merging disks, because that merge uses the same
    free space. This does not apply when the removal merges nothing.

  Remove the checkpoint only if the function reports room. If it stops with an
  error or reports `NOT ENOUGH ROOM`, do not remove the checkpoint now. If another
  merge is running, wait for it and check again; otherwise add capacity first
  ([Option A1](#option-a1-add-capacity-recommended-when-growth-is-expected-low-risk))
  or open a support case. The estimate assumes the worst case, so it can refuse a
  merge that would have fitted. Microsoft's guidance is to make sure that
  *"sufficient free space exists for merges (ideally, space equal to the disk
  size)"* ([Hyper-V checkpoint troubleshooting][ckpt-ts]).
- **Remove** the selected checkpoint. Paste this block on its own: the function
  asks you to confirm, and a line pasted after it would be read as the answer.

  ```powershell
  $plan = $null
  $plan = Remove-ApprovedCheckpoint -Checkpoint $c
  ```

  After you answer, the function reads the checkpoint, the room for the merge, and
  the VM again. It removes the checkpoint only if there is still room, the VM is
  still `Running` or `Off`, and nothing else is in progress on it:
  `OperationalStatus` must be just `Ok`. Hyper-V reports another status while a VM
  is creating, applying or deleting a checkpoint, merging disks, exporting or
  migrating ([VM operational status][vm-status]). Otherwise it stops and removes
  nothing. Do not remove checkpoints with `Remove-VMSnapshot` directly: by VM, by
  name, or with `-IncludeAllChildSnapshots`, it removes checkpoints that nobody
  approved, and it skips these checks. If the function printed `Nothing was removed`
  or stopped with an error, nothing changed: skip the next step.
- **Wait for the merge to finish, and check that it did,** before you remove the
  next checkpoint, and before the window starts. The merge continues after the
  command returns, and it can take a moment to show. This checks the VM every 30
  seconds, printing its state, and stops when two checks in a row show no merge
  (`MergingDisks`), then shows the result: **[READ-ONLY]**

  ```powershell
  $vm = Get-VM -ComputerName $c[0].ComputerName -Id $c[0].VMId
  $idle = 0; while ($idle -lt 2 -and "$($vm.State)" -notlike '*Critical') { Start-Sleep -Seconds 30; $vm = Get-VM -ComputerName $c[0].ComputerName -Id $c[0].VMId; if (@($vm.OperationalStatus) -contains 'MergingDisks') { $idle = 0 } else { $idle++ }; '{0}  {1}  {2}' -f (Get-Date -Format T), $vm.State, $vm.Status }
  $vm | Format-List Name, State, Status, OperationalStatus
  "Checkpoints left: $(@($vm | Get-VMSnapshot).Count)"
  ```

  Then check that each disk that the removal was to merge or delete is gone:
  **[READ-ONLY]**

  ```powershell
  if (-not $plan) { 'Nothing was removed.' }; $plan | Where-Object Removed | ForEach-Object { '{0}  {1}' -f $(if (-not (Test-Path -LiteralPath (Split-Path -Parent $_.Removed))) { 'CANNOT CHECK' } elseif (Test-Path -LiteralPath $_.Removed) { 'STILL THERE' } elseif ($_.Action -eq 'Merge' -and -not (Test-Path -LiteralPath $_.Disk)) { 'TARGET MISSING' } else { 'gone' }), $_.Removed }
  ```

  The merge finished when `OperationalStatus` no longer lists `MergingDisks`, the
  state does not end in `Critical`, the VM has one checkpoint fewer, and each disk
  listed is `gone` (a `Keep` entry has nothing to check). Otherwise the merge did not
  finish: remove no more checkpoints, do not start the window, and open a support
  case. A merge that cannot finish can also leave the VM unable to start
  ([Can't power on Hyper-V VM and merge operations fail][ckpt-poweron]), which
  matters here because the window stops and starts these VMs.
- **If a removal turns out to be wrong,** restore the VM from the backup. That
  returns the VM to the time of the backup; a removed checkpoint cannot be brought
  back.

1. **Take the VMs in the list offline.** Consolidation works by
   relocating live data out of partially used slabs so whole slabs can be freed,
   and it cannot relocate data belonging to files that are actively in use. Those
   slabs are reported as "pinned unmovable" and skipped, which is the main reason
   a pass run against a live volume recovers far less than one run against a
   quiesced volume. Stopping the workload is what makes that data movable.

   At the start of the window, run the three lines of the list block above again,
   because VMs can start, stop, or move to another node after you planned the
   window. Use this new list for the rest of the procedure.

   Stop each VM in the list that shows `Running`, the way its `StopFrom` value
   says, and write down which ones you stop: Step 5 starts only those. Use the VM's
   `Node` and `Id` from the list, so the command cannot reach another VM with the
   same name. For a `Host` VM, **prefer a clean guest shutdown**, which releases the
   VM's files **without** writing a saved-state file:

   ```powershell
   Get-VM -ComputerName '<Node>' -Id '<Id>' | Stop-VM   # graceful guest shutdown
   ```

   If a guest will not shut down cleanly (hung, or no integration services), a
   forced turn-off also releases the VM's files **without** writing a
   saved-state file, but only as a last resort **[HIGH RISK]**:

   ```powershell
   Get-VM -ComputerName '<Node>' -Id '<Id>' | Stop-VM -TurnOff   # hard power-off; last resort only
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
   > For **Arc-managed VMs** (Azure Local 23H2+), which the list shows with
   > `StopFrom` set to `Azure`, stop the VM from Azure (portal or CLI) rather than
   > using host tools such as `Stop-VM` or `Suspend-VM`. Driving an Arc VM's power
   > state directly on the host can desynchronize the Arc agent / Arc Resource
   > Bridge view of the VM state.

   Then run the three lines of the list block again. Continue to Step 2 only when
   every VM in the list shows `Off` or `Saved`.

   - `Off` or `Saved`: nothing more to do. A saved VM is not running and its virtual
     disks are closed. Leave it saved, and do not start it in Step 5.
   - `Running`: the VM still holds its files open, so its slabs stay pinned. Stop it
     as above.
   - `Paused`: the VM still holds its files open. Ask its owner whether it can be
     resumed and shut down.
   - A state that ends in `Critical`, for example `PausedCritical`: the VM has lost
     access to its storage. A VM on a Cluster Shared Volume that runs out of space
     is paused this way
     ([VMs enter the paused state due to low disk space][paused-critical]). Do not
     continue; open a support case.
   - Any other state, for example `Stopping`: wait a minute and run the three lines of the list block again.

2. **Consolidate slabs** on the volume. Run this on the CSV **owner node**.
   Resolve the CSV's `C:\ClusterStorage\<volume>` path to its volume object with
   `Get-Volume -FilePath`, confirm it is the volume you intend, then pipe it to
   `Optimize-Volume`:

   ```powershell
   # Identify the CSV owner node, and run the rest on that node.
   # Path is the C:\ClusterStorage\... folder; Name is the cluster resource name, not a path.
   Get-ClusterSharedVolume |
       Select-Object Name, OwnerNode, @{N = 'Path'; E = { @($_.SharedVolumeInfo)[0].FriendlyVolumeName }}

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

5. **Bring the VMs back online.** Start only the VMs that you wrote down as stopped
   in Step 1. A VM that was off or saved before the window stays that way. For
   **traditional non-Arc Hyper-V VMs** (`StopFrom` set to `Host`), start them on the
   host:

   ```powershell
   Get-VM -ComputerName '<Node>' -Id '<Id>' | Start-VM   # non-Arc Hyper-V VMs only
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
> this procedure); or slabs are still pinned by data in use (confirm every VM in
> the list was off or saved after Step 1, and that the checkpoints the owners
> approved were merged in the preparation step). Note that some slabs report
> "pinned unmovable" even on a fully quiesced volume, so a partial reclaim is not
> by itself a failure. If real interior free space exists, all workloads were
> offline, and the approved checkpoints were merged, but the pool still does not
> drop after the unmap wait (Step 3), open a Microsoft support case rather than
> repeating the procedure.

> [!IMPORTANT]
> **Do not use `fsutil behavior query DisableDeleteNotify` to decide whether this
> guide applies, and do not change that setting as part of it.** A reading of
> `ReFS DisableDeleteNotify = 1` does not mean capacity cannot be returned. On a
> healthy two-node Azure Local cluster that reported `ReFS DisableDeleteNotify = 1`,
> deleting 32 GB of files from a thin two-way mirror volume returned all 72 GB of
> pool allocation they had added within about a minute, while 17 VMs were running.

## Choose the right option

| Volume provisioning | Goal | Use |
|---|---|---|
| Fixed | Grow capacity | A1: add physical disks |
| Fixed | Reduce committed footprint / enable reclamation | A2: convert to thin, then Path B |
| Fixed | Remove unneeded volumes | A3: shrink/remove (ReFS = evacuate + recreate) |
| Fixed | Stop the alert (risk accepted) | A4: disable the Health Service alert |
| Fixed | Move the alert threshold | A5: raise `ThinProvisioningAlertThresholds` |
| Thin | Return capacity from **deleted whole files/VMs** | Path B pre-branch: remove leftover disks (through Azure for Azure Local VMs, after the check for unmanaged VMs), wait, re-measure (no downtime) |
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
  space, every VM in the list off or saved, the approved checkpoints merged) and
  you waited out the ReFS unmap, but pool `AllocatedSize` still does not drop.
- **A leftover disk cannot be removed safely with the steps in Path B**: a file you
  cannot attribute to a VM you removed, a disk of an Azure Local VM that was removed
  with local tools, a checkpoint or VHD Set file that outlived its VM, or a
  `Test-UnusedVirtualDisk` error you cannot fix. Leave the files in place.
- **Path B cannot start, or its window cannot continue**:
  `Get-VirtualMachineOnVolume` stops with an error you cannot fix, a VM in the list
  shows `DoNotStop`, a VM with `StopFrom` set to `Azure` cannot be found in Azure, a
  VM's state ends in `Critical`, or a checkpoint merge does not finish.
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
- [Manage Azure Local VMs (delete a VM and its leftover resources)](https://learn.microsoft.com/azure/azure-local/manage/manage-arc-virtual-machines#delete-a-vm)
- [Create a storage path for Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/create-storage-path)
- [Stretched clusters overview (Azure Stack HCI 22H2 article; stretched clusters are not supported in Azure Local)](https://learn.microsoft.com/azure/azure-local/concepts/stretched-clusters)
- [Can't power on Hyper-V VM and merge operations fail (insufficient free space)](https://learn.microsoft.com/troubleshoot/windows-server/virtualization/cannot-power-on-hyper-v-vm)
- [Virtual machines enter the paused state due to low disk free space](https://learn.microsoft.com/troubleshoot/windows-server/virtualization/virtual-machines-enter-paused-state-low-disk-free)
- [Hyper-V checkpoint troubleshooting (merge failures, including insufficient disk space)](https://learn.microsoft.com/troubleshoot/windows-server/virtualization/hyper-v-snapshots-checkpoints-differencing-disks)

[thin-prov]: https://learn.microsoft.com/azure/azure-local/manage/manage-thin-provisioning-23h2
[unsupported-ops]: https://learn.microsoft.com/azure/azure-local/manage/virtual-machine-operations
[delete-vm]: https://learn.microsoft.com/azure/azure-local/manage/manage-arc-virtual-machines#delete-a-vm
[remove-vm]: https://learn.microsoft.com/powershell/module/hyper-v/remove-vm
[s2d-overview]: https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-direct-overview
[stretched]: https://learn.microsoft.com/azure/azure-local/concepts/stretched-clusters
[ckpt-ts]: https://learn.microsoft.com/troubleshoot/windows-server/virtualization/hyper-v-snapshots-checkpoints-differencing-disks
[ckpt-poweron]: https://learn.microsoft.com/troubleshoot/windows-server/virtualization/cannot-power-on-hyper-v-vm
[vm-status]: https://learn.microsoft.com/windows/win32/hyperv_v2/msvm-computersystem
[paused-critical]: https://learn.microsoft.com/troubleshoot/windows-server/virtualization/virtual-machines-enter-paused-state-low-disk-free

---
