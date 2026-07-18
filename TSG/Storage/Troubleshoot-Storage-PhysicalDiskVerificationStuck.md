# Troubleshoot physical disks stuck in verification and never claimed into the pool (`CanPool=False`)

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

## At a glance

| Question | Answer |
| --- | --- |
| **What is broken?** | New, clean disks are not claimed into the pool, so capacity does not grow. Running VMs, CSV volumes, and existing data are not affected. |
| **What kind of issue is this?** | A cluster **Health Service** / **Storage Spaces Direct** condition. It is **not** a networking fault, and **not** a disk hardware or firmware fault. |
| **Who fixes it?** | The cluster administrator, or Microsoft CSS. Involve the hardware vendor only if the [companion guide](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md) shows `Hardware not compliant` or `Firmware not compliant`. |
| **Downtime?** | None. Diagnosis is read-only, and the first remediation (failing the Health Service over) is transparent to running workloads. |
| **Fastest first step** | [Step A: reinitialize the Health Service](#step-a-reinitialize-the-health-service-least-risk-try-first), then re-check `CanPool`. |

New to the terms below (S2D, pool, Health Service, SDDC Group, `CanPool`)? See the [Glossary](#glossary).

## Overview

New, clean, vendor-supported disks are inserted for capacity expansion, but Storage Spaces Direct (S2D) never claims them. `Get-PhysicalDisk` shows the disks as healthy with `CanPool=False`, and `CannotPoolReason` stays on `Verification in progress` (or `Verification failed`) and never clears, even after hours or days. The strongest clue is that the **same physical disk pools normally when moved to a different, healthy cluster**.

This guide covers the specific sub-case where the block is the **cluster Health Service**, not the disk. The Health Service is the component that verifies each new disk against supportability gates before S2D is allowed to claim it. When the Health Service is wedged or its provider configuration is incomplete, that verification never completes, so the disk is held at `CanPool=False` indefinitely. Repairing the Health Service releases the disk.

> [!IMPORTANT]
> Start with the general decision tree in [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md). That guide resolves the common `CannotPoolReason` values (`In a Pool`, `Insufficient Capacity`, `Hardware not compliant`, `Firmware not compliant`, stale metadata, and so on). Use **this** guide only when the disk is confirmed clean and supported, but `Verification in progress` or `Verification failed` never clears.

## Symptoms

**Observable behaviors:**

- New disks were inserted into one or more cluster nodes for capacity expansion.
- The disks are visible to Windows and appear in `Get-PhysicalDisk`.
- Storage pool capacity did not increase; the disks were never auto-claimed.
- `Get-PhysicalDisk` shows the disks healthy and online, but with `CanPool=False`.
- `CannotPoolReason` is stuck on `Verification in progress` or `Verification failed` and does not change over a long period (well beyond the few minutes a normal verification takes).

**Key discriminator (cluster-side, not disk-side):**

- The identical disk, moved to a **different** Azure Local / S2D cluster, is claimed into that cluster's pool normally.
- Wiping the disk (clearing partitions and any stale pool signature) does not change the outcome on the affected cluster.

```
CanPool          : False
CannotPoolReason : Verification in progress
HealthStatus     : Healthy
```

## How this failure appears across admin surfaces

Knowing where this shows up (and where it does not) saves time.

| Surface | What you see |
| --- | --- |
| **PowerShell on a cluster node** | Primary signal. `Get-PhysicalDisk` shows the new disks `CanPool=False` with `CannotPoolReason = Verification in progress` / `Verification failed` that never clears. `Get-ClusterResource Health` and `Get-ClusterGroup` may show the Health Service resource or its group not cleanly online, and `Get-HealthFault` may report a Health Service or storage fault. |
| **Cluster logs (`Get-ClusterLog`)** | The cluster log records the Health Service (SDDC) resource state transitions and storage provider activity, showing verification not completing. |
| **Component / tool log files (on disk)** | The node storage and deployment logs under the log directory (for example `C:\MASLogs`) capture the storage subsystem and Health Service activity around the stalled verification. |
| **Windows Failover Cluster Manager** | The **SDDC Group** that owns the **Health** resource may show as not fully online, failed, or moving between nodes. A cleanly online Health resource here is a useful negative signal (it points you back to the disk-side checks in the companion guide). |
| **Windows event logs** | Not surfaced as a dedicated signal: there is no single "verification stuck" event ID, so rely on `CannotPoolReason` and the cluster log rather than an event channel. |
| **Azure portal** | Not evident. Capacity simply fails to grow after the disk add; the portal does not surface a stuck disk-verification state for this condition. |
| **Windows Admin Center on a standalone host** | Not evident for this specific condition. WAC shows the pool and disk inventory, but does not call out that Health Service verification is stalled; use node PowerShell for the authoritative `CannotPoolReason`. |
| **Windows Admin Center in the Azure portal** | Not evident, the same as the standalone experience; use node PowerShell for the authoritative `CannotPoolReason`. |

## Root Cause

Before S2D claims a physical disk, the disk must pass every pooling gate: healthy, online, not already in a pool, sufficient capacity, and supported by the solution vendor (model and firmware). The Health Service performs the supportability verification and reports progress through `CannotPoolReason = Verification in progress`. While that verification is outstanding, the disk stays `CanPool=False`.

The Health Service runs as the cluster resource named **Health** (resource type **Health Service**), hosted in the **SDDC Group**. It is driven by a set of internal health **providers**, tracked in the resource's `Providers` cluster parameter. When the Health Service is wedged, when its group is not cleanly online, or when its `Providers` list is incomplete, the verification pipeline stalls: the disk never advances past `Verification in progress` (or lands on `Verification failed`), and pooling is blocked indefinitely.

Because this gate lives on the cluster and not on the disk, the same disk verifies and pools normally on a healthy cluster. That contrast strongly indicates a cluster-side cause, but it does not by itself prove the Health Service specifically. Before concluding the Health Service is at fault, exclude the other cluster-side possibilities in the diagnosis below: a different node, disk slot, or HBA path; an asymmetric add; or a stale storage provider cache.

## Diagnosis

Run all commands from an elevated PowerShell session on a cluster node.

### Step 1: Confirm the disk is genuinely stuck in verification

```powershell
# CannotPoolReason is the deciding field
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, MediaType, Size, FirmwareVersion, HealthStatus, CanPool, CannotPoolReason
```

- If `CannotPoolReason` is anything other than `Verification in progress` or `Verification failed` (for example `In a Pool`, `Insufficient Capacity`, `Hardware not compliant`, `Firmware not compliant`), stop here and follow the matching step in the companion guide: [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md).
- If the reason is `Verification in progress` or `Verification failed`, note the time and re-check after several minutes. Normal verification completes quickly. Continue to Step 2 only if it does not clear.

> [!WARNING]
> Do not reset (`Reset-PhysicalDisk`) or manually add disks while verification is legitimately still in progress. Only proceed once you have confirmed it is genuinely stuck (unchanged over a long period).

### Step 2: Confirm the block is cluster-side, not disk-side

Rule out the disk itself so you do not repair the Health Service unnecessarily. These checks are read-only:

```powershell
# Read-only: identity, health, and why each blocked disk cannot pool
Get-PhysicalDisk | Where-Object { -not $_.CanPool } |
    Format-Table FriendlyName, SerialNumber, UniqueId, HealthStatus, Size, CannotPoolReason
```

- Confirm the disk model and firmware are on the vendor support matrix for this solution.
- Confirm the disk is genuinely clean (no partitions and no foreign pool signature). If it is carrying stale metadata, that shows as a different `CannotPoolReason` (`In a Pool`); resolve it with the gated, destructive `Reset-PhysicalDisk` path in Step 2g of the companion guide, not here.
- If you have **already** observed the same disk pool normally in a different cluster (for example during an earlier swap), treat that as strong evidence the media is fine and the local cluster is the problem. Do **not** move a disk into another **production** cluster just to test: a clean, eligible disk can be auto-claimed there, which writes pool metadata and can start a redistribution. If you need this confirmation, use a spare or non-production cluster.
- Confirm the disks are added symmetrically (same count and type on each node). The Health Service evaluates the cluster as a whole; an asymmetric add can leave a disk unverified.

> [!WARNING]
> Do not run `Reset-PhysicalDisk` as a first move. It is destructive (it wipes the disk) and does not fix a Health Service stall. Use it only for a disk confirmed to be carrying stale metadata, following the gated path in the companion guide.

### Step 3: Inspect the Health Service

```powershell
# Health Service resource and the group that hosts it
$hs = Get-ClusterResource -Name 'Health'
$hs | Format-List Name, State, OwnerGroup, ResourceType

# State of the group that owns the Health resource (commonly 'SDDC Group')
Get-ClusterGroup -Name $hs.OwnerGroup | Format-Table Name, OwnerNode, State

# Active health faults across the cluster
Get-HealthFault

# Health Service reporting for the clustered storage subsystem
Get-StorageSubSystem |
    Where-Object FriendlyName -like '*Cluster*' |
    Get-StorageHealthReport
```

Expected on a healthy cluster: the `Health` resource is `Online`, its group is `Online` on a single owner node, `Get-HealthFault` returns nothing storage-related, and the storage health report returns metrics rather than errors. A deviation here (the resource or group not cleanly online, or the commands below hanging or returning empty) is evidence to correlate with the stuck disk verification, not proof on its own.

> [!NOTE]
> `Get-HealthFault` and `Get-StorageHealthReport` query the very Health Service you suspect is wedged. If either command hangs or returns nothing on a cluster that clearly has a problem, treat that unresponsive or empty result as a positive signal that the Health Service is impaired, not as a clean bill of health.

### Step 4: Check the Health Service provider configuration

The Health Service is driven by a set of providers recorded in the `Providers` cluster parameter. An incomplete list correlates with stalled verification.

```powershell
# Read the current provider list and count
$providers = (Get-ClusterResource -Name 'Health' | Get-ClusterParameter -Name Providers).Value
$providers
"Provider count: $(@($providers).Count)"
```

Find this cluster's build so you can pick a valid comparison peer:

```powershell
# Capture the OS build; also note the Azure Local solution version so the peer matches
Get-ComputerInfo -Property OsName, OsVersion, OsBuildNumber
```

Compare the provider count and values against a **healthy cluster of the same Azure Local build**. If this cluster reports fewer providers than that peer, the provider list is incomplete and is the likely cause of the stall. Record what you see for the remediation and for any support case.

> [!NOTE]
> The exact provider set is build specific (different builds ship different provider counts), so do not assume a fixed number and do not hard-code a list. The reliable check is a comparison against a healthy peer cluster on the **same build**. Each provider is a brace-wrapped GUID (for example `{00000000-0000-0000-0000-000000000000}`); when you capture a reference value, copy the **full** set exactly, without reformatting, wrapping, or dropping entries.

## Resolution

Apply the least invasive step first and re-check after each one.

### Step A: Reinitialize the Health Service (least risk, try first)

Reinitializing the Health Service clears most stalled verifications without any configuration change. On a multi-node cluster you do this by failing the Health Service group over to another node, which is transparent to running VMs, CSV volumes, and data (it moves only the infrastructure Health role).

Run the block below as a whole. It is one continuous procedure: it inspects cluster state, refuses to proceed if a node is down or a storage job is running, then reinitializes and verifies the outcome.

```powershell
# 1. Inspect, then GATE: refuse to proceed unless all nodes are Up and no storage job is running.
Get-ClusterNode | Format-Table Name, State
Get-StorageJob
$hs            = Get-ClusterResource -Name 'Health'
$originalOwner = (Get-ClusterGroup -Name $hs.OwnerGroup).OwnerNode.Name
$upNodes       = @(Get-ClusterNode | Where-Object State -eq 'Up')
$downNodes     = @(Get-ClusterNode | Where-Object State -ne 'Up')
$activeJobs    = @(Get-StorageJob  | Where-Object JobState -ne 'Completed')
if ($downNodes.Count -gt 0) {
    throw "Refusing to reinitialize: node(s) not Up ($($downNodes.Name -join ', ')). Resolve first."
}
if ($activeJobs.Count -gt 0) {
    throw "Refusing to reinitialize: $($activeJobs.Count) active storage job(s). Let them finish first."
}

# 2. Refresh the storage providers' view of the disks.
Update-StorageProviderCache -DiscoveryLevel Full
Update-HostStorageCache

# 3. Reinitialize: multi-node fails the group over; single-node restarts the resource in place.
if ($upNodes.Count -gt 1) {
    Move-ClusterGroup -Name $hs.OwnerGroup          # Failover Clustering picks the target node
} else {
    Stop-ClusterResource  -Name 'Health'            # no failover target on a single node
    Start-ClusterResource -Name 'Health'
}

# 4. Confirm the outcome: the group is Online, and (multi-node) the owner actually changed.
$grp = Get-ClusterGroup -Name $hs.OwnerGroup
$grp | Format-Table Name, OwnerNode, State
if ($upNodes.Count -gt 1 -and $grp.OwnerNode.Name -eq $originalOwner) {
    Write-Warning "Health group did not move off $originalOwner. Retry with an explicit target (Move-ClusterGroup -Name '$($hs.OwnerGroup)' -Node <other-node>) or investigate why the move failed before continuing."
}
```

If the group does not come `Online`, or the resource does not restart cleanly, do not proceed to Step B; treat that as a Health Service failure in its own right and collect the data in [Data to Collect](#data-to-collect-before-opening-a-support-case).

Wait a few minutes, then re-check pool eligibility:

```powershell
Get-PhysicalDisk |
    Format-Table DeviceId, FriendlyName, SerialNumber, CanPool, CannotPoolReason, HealthStatus
```

If the disks now show `CanPool=True`, skip to [Step C](#step-c-claim-the-now-eligible-disks).

### Step B: Repair the Health Service provider list (support-assisted; only when confirmed incomplete)

> [!CAUTION]
> **Stop and read.** This step edits `Providers`, an internal cluster resource parameter. A wrong value can impair the Health Service cluster-wide. Do **not** perform it yourself unless you can satisfy every precondition below with a captured, complete reference value. If you cannot, engage Microsoft Support (see [Escalation](#escalation)) and do not guess.

Preconditions (all must be true):

1. Step A did not clear the stall.
2. Step 4 showed this cluster's `Providers` list is incomplete relative to a healthy peer on the **same build**.
3. You have captured the **full** provider array from that healthy same-build peer.

First back up the current value on the affected cluster so you can roll back:

```powershell
# Back up the current (incomplete) Providers value before changing anything
$backupPath = 'C:\Temp\Health-Providers-backup.txt'
New-Item -ItemType Directory -Path (Split-Path $backupPath) -Force | Out-Null
$backup = (Get-ClusterResource -Name 'Health' | Get-ClusterParameter -Name Providers).Value
$backup | Set-Content -Path $backupPath -ErrorAction Stop
# Verify the backup actually wrote a rollback copy before continuing
if (-not (Test-Path $backupPath) -or @(Get-Content $backupPath).Count -lt @($backup).Count) {
    throw "Backup to $backupPath failed or is incomplete. Do NOT continue without a verified rollback copy."
}
"Backed up $(@($backup).Count) provider(s) to $backupPath"
```

Capture the reference list from the healthy peer, then restore it on the affected cluster. Read the peer's provider **count** independently and record it below: completeness is proven by matching that recorded count, not by being larger than the broken cluster's set. The block hard-stops unless the pasted set matches the recorded peer count exactly, contains no placeholders, and every entry is a unique GUID, so a partial or placeholder list cannot be written:

```powershell
# Run on the HEALTHY same-build peer to read the full reference value AND its count:
#   $peer = (Get-ClusterResource -Name 'Health' | Get-ClusterParameter -Name Providers).Value
#   $peer; "Peer provider count: $(@($peer).Count)"

# Independently record the count you read on the healthy peer (type it here):
$expectedPeerCount = 0   # <-- set to the provider COUNT read on the healthy same-build peer

# Paste the FULL captured array here (every GUID from the peer, in full):
$referenceProviders = @(
    # '{guid-1}', '{guid-2}', ...   <-- replace with the real captured values
)

# Hard stops: refuse to write unless the set is placeholder-free, all-unique-GUID, and complete.
$guidPattern = '^\{[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\}$'
if (@($referenceProviders).Count -eq 0 -or ($referenceProviders -join '') -match '<|guid-\d') {
    throw "Refusing to write: paste the real, complete provider array captured from the healthy peer first."
}
if ($expectedPeerCount -lt 1) {
    throw "Refusing to write: set `$expectedPeerCount to the provider count you read on the healthy peer."
}
$normalized = @($referenceProviders | ForEach-Object { "$_".Trim() })
if (@($normalized | Where-Object { $_ -notmatch $guidPattern }).Count -gt 0) {
    throw "Refusing to write: every entry must be a brace-wrapped GUID (for example {00000000-0000-0000-0000-000000000000})."
}
if (@($normalized | Sort-Object -Unique).Count -ne $normalized.Count) {
    throw "Refusing to write: the reference set contains duplicate GUIDs."
}
if ($normalized.Count -ne $expectedPeerCount) {
    throw "Refusing to write: pasted $($normalized.Count) providers but the peer has $expectedPeerCount. Re-capture the FULL set."
}

Get-ClusterResource -Name 'Health' | Set-ClusterParameter -Name Providers -Value $normalized

# Round-trip verify the write took exactly the intended value
$after = (Get-ClusterResource -Name 'Health' | Get-ClusterParameter -Name Providers).Value
"Providers now: $(@($after).Count) (expected $expectedPeerCount)"
```

Reinitialize so the restored providers take effect by **re-running the full guarded procedure in [Step A](#step-a-reinitialize-the-health-service-least-risk-try-first)** (its pre-move gate that confirms all nodes are Up and no storage job is running, its node-count-aware failover, and its post-move outcome check). Cluster state can change between steps, so do not use a shortened failover here.

Wait a few minutes, then re-check `CanPool` as in Step A. If verification still does not complete, do not iterate further on the provider list; roll back to the backup (`Set-ClusterParameter -Name Providers -Value $backup`), collect diagnostics, and escalate.

### Step C: Claim the now-eligible disks

Once the disks show `CanPool=True`, add them to the pool. On a standard single-pool Azure Local cluster, eligible disks are usually claimed automatically within a short time. If they are not, add them explicitly.

> [!IMPORTANT]
> Identify the intended disks by serial number and use `-PhysicalDisks`. Do not pipe `Get-PhysicalDisk -CanPool $true` directly into `Add-PhysicalDisk`, and do not rely on the pipeline form (it does not bind reliably). This block enforces a single non-primordial pool and verifies every intended serial matched exactly one eligible disk before adding. For more background see Step 3 of the companion guide: [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md#step-3-manual-add-when-disks-are-eligible).

```powershell
$pool = Get-StoragePool -IsPrimordial $false
if (@($pool).Count -ne 1) {
    throw "Expected exactly one non-primordial pool. Found $(@($pool).Count). Select the target pool by FriendlyName."
}

# Enumerate the intended new disks by serial number (each serial listed once)
$intendedSerials = @('<serial-1>', '<serial-2>')
if (@($intendedSerials | Sort-Object -Unique).Count -ne @($intendedSerials).Count) {
    throw "Duplicate serial numbers in the intended list. List each serial exactly once."
}

# Gate: each intended serial must match EXACTLY ONE eligible disk (checked per serial, not in aggregate)
$disksToAdd = foreach ($sn in $intendedSerials) {
    $match = @(Get-PhysicalDisk -CanPool $true | Where-Object SerialNumber -eq $sn)
    if ($match.Count -ne 1) {
        throw "Serial '$sn' matched $($match.Count) eligible disks (expected exactly 1). Resolve before continuing."
    }
    $match[0]
}
$disksToAdd = @($disksToAdd)

Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $disksToAdd
```

Then rebalance so existing data spreads onto the new disks:

```powershell
# Rebalance the pool onto the new disks
Optimize-StoragePool -FriendlyName $pool.FriendlyName
```

> [!NOTE]
> `Optimize-StoragePool` starts a pool rebalance that runs in the background and can be I/O intensive and long running on a full pool. Confirm no other storage job is running first (`Get-StorageJob`), monitor progress with `Get-StorageJob`, and prefer off-peak hours. It is safe to defer: the new capacity is already usable once the disks are added.

### Step D: Verify the fix

```powershell
# New disks are in the pool, healthy, and no longer blocked
Get-PhysicalDisk | Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, Usage, HealthStatus, CanPool, CannotPoolReason

# Pool capacity increased and the pool is healthy
Get-StoragePool -IsPrimordial $false |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize

# Rebalance job progressing (or none), and no new faults
Get-StorageJob
Get-HealthFault
```

Expected result:

- The new disks show `Usage = Auto-Select` (or the intended usage), `CanPool = False` **because they are now in the pool** (confirm via `Get-StoragePool -IsPrimordial $false | Get-PhysicalDisk`), and `HealthStatus = Healthy`.
- Pool `Size` reflects the added capacity.
- Any `Optimize` job is progressing or complete, and no new storage faults are active.

## Prevention

- Validate disk model and firmware against the OEM solution support matrix **before** insertion, so verification passes cleanly.
- Add disks symmetrically (same count and type per node).
- Keep the cluster healthy before a disk add: run the pre-checks in [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md), and resolve any existing Health Service faults first.
- Do not reuse disks from a prior deployment without confirming they are wiped of stale pool metadata.
- If you operate several clusters of the same build, the same Health Service condition can affect more than one; when you see this symptom on one cluster, check the others with Step 4.

## Data to Collect Before Opening a Support Case

```powershell
# Cluster + storage + Health Service snapshot
Get-HealthFault
Get-ClusterNode                        | Format-Table Name, State
Get-ClusterResource -Name 'Health'     | Format-List Name, State, OwnerGroup, ResourceType
Get-ClusterGroup                       | Format-Table Name, OwnerNode, State
(Get-ClusterResource -Name 'Health' | Get-ClusterParameter -Name Providers).Value
Get-StorageJob
Get-StoragePool -IsPrimordial $false   | Format-List *
Get-VirtualDisk                        | Format-List *
Get-PhysicalDisk                       | Format-List *

# Last 60 minutes of cluster log to C:\Temp
Get-ClusterLog -Destination C:\Temp -TimeSpan 60
```

Also collect:

- Disk serial numbers and unique IDs, and node/slot mapping.
- Disk model and firmware version, with the vendor support matrix or written confirmation.
- Confirmation of whether the same disk pools in a different cluster.
- The Health Service `Providers` value from both the affected cluster and a healthy same-build peer, if available.

## Escalation

If verification remains stuck after Step A, and either the `Providers` list cannot be confirmed against a healthy same-build peer or Step B did not resolve it, collect the data above and open (or continue) a support case. Repairing the Health Service provider configuration on an incompletely understood cluster is a support-assisted action; do not iterate on `Set-ClusterParameter -Name Providers` beyond a single confirmed restore.

## Related Issues

- [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md)
- [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md)
- [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)

## Glossary

| Term | Meaning |
| --- | --- |
| **Storage Spaces Direct (S2D)** | The Azure Local software-defined storage feature that pools the local disks across cluster nodes into one shared pool. |
| **Storage pool** | The collection of physical disks S2D manages as one unit; volumes are created from its free space. |
| **Primordial / non-primordial pool** | The *primordial* pool lists disks that are present but not yet claimed; the *non-primordial* pool is the real S2D pool in use. A healthy Azure Local cluster has exactly one non-primordial pool. |
| **`CanPool` / `CannotPoolReason`** | Properties on `Get-PhysicalDisk`. `CanPool=True` means the disk is eligible to be added to the pool; when `False`, `CannotPoolReason` says why. |
| **Health Service** | The cluster component that monitors storage health and verifies each new disk against supportability rules before S2D claims it. It runs as the cluster resource named **Health**. |
| **SDDC Group** | The cluster group that hosts the **Health** resource (and other software-defined datacenter management resources). |
| **Cluster resource / cluster parameter** | A cluster-managed object (like **Health**) and one of its configuration settings (like `Providers`), read and set with `Get-ClusterResource` / `Get-ClusterParameter` / `Set-ClusterParameter`. |
| **Provider** | One of the internal health modules the Health Service loads, identified by a GUID and listed in the Health resource's `Providers` parameter. |
| **Wedged** | Informal term for a service that is running but stuck, so it never finishes its work (here, never completes disk verification). |

## References

- [Health Service overview (Supported Components Document, verification, and enforcement)](https://learn.microsoft.com/azure/azure-local/manage/health-service-overview)
- [Modify Health Service settings](https://learn.microsoft.com/azure/azure-local/manage/health-service-settings)
- [Troubleshoot Storage Spaces and Storage Spaces Direct health and operational states (`CannotPoolReason`)](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states)
- [Adding servers or drives to Storage Spaces Direct](https://learn.microsoft.com/windows-server/storage/storage-spaces/add-nodes#adding-drives)

---
