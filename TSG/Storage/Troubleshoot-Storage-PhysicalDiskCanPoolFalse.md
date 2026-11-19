<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local", "Storage Spaces Direct"],
  "detector": {
    "type": "command",
    "signal": "Get-PhysicalDisk | Select-Object DeviceId,FriendlyName,SerialNumber,UniqueId,HealthStatus,OperationalStatus,Usage,CanPool,CannotPoolReason"
  },
  "validation": {
    "fidelity_level": "L1",
    "technical_grade": null,
    "reproduction_substrate": "either",
    "automation_status": "ready",
    "last_validated": "2026-08-17",
    "spec_ref": "AzLocal_Storage_PhysicalDiskCanPoolFalseGeneral"
  }
}
-->

# Troubleshoot physical disks not claimed after insertion (`CanPool=False`)

## Table of contents

- [Article metadata](#article-metadata)
- [Executive triage summary](#executive-triage-summary)
- [Symptoms and scope](#symptoms-and-scope)
- [Terms](#terms)
- [Where this failure appears](#where-this-failure-appears)
- [Preconditions and stop gates](#preconditions-and-stop-gates)
- [Common `CannotPoolReason` values](#common-cannotpoolreason-values)
- [Diagnosis and mitigation](#diagnosis-and-mitigation)
- [Support Diagnostics collection](#support-diagnostics-collection)
- [Verification](#verification)
- [Rollback](#rollback)
- [Escalation and evidence package](#escalation-and-evidence-package)
- [Prevention and monitoring](#prevention-and-monitoring)
- [Future test automation metadata](#future-test-automation-metadata)
- [Related documentation](#related-documentation)

## Article metadata

| Field | Value |
| --- | --- |
| Component | Storage |
| Applicable products | Azure Local, Storage Spaces Direct |
| Supported versions | All Azure Local releases that use Storage Spaces Direct |
| Audience | Customer IT admin, Microsoft Customer Support Services (CSS), OEM field engineer, partner or systems integrator |
| Applicable scenarios | Day 2 capacity expansion, add disk, physical disk replacement |
| Severity | Medium, because the cluster can stay online but capacity expansion or replacement is blocked |
| Customer impact | Pool capacity does not grow. Workloads normally stay online unless the cluster also has active storage health faults, node failures, or degraded redundancy |
| Primary owner | Customer IT for safe diagnosis and disk identity, OEM for model and firmware supportability, Microsoft CSS for inconclusive or Health Service cases |
| Execution surface | on-device |
| Risk summary | Diagnosis is read-only. Bringing a disk online is medium risk. `Reset-PhysicalDisk` is high risk and destroys Storage Spaces metadata on the target disk |

## Executive triage summary

| Question | Answer |
| --- | --- |
| What is broken? | A newly inserted physical disk is visible to Windows, but `Get-PhysicalDisk` reports `CanPool=False` and Storage Spaces Direct does not claim it. |
| Who should act? | A cluster administrator with local administrator rights on an Azure Local node. Engage the OEM for hardware, firmware, or supported configuration findings. |
| Fastest safe next action | Run the read-only `Get-PhysicalDisk` inventory in [Step 1](#step-1-capture-disk-identity-and-reason), then branch on the exact `CannotPoolReason`. |
| Estimated duration | 10 to 20 minutes for source diagnosis. Persistent Health Service verification adds about 10 to 15 minutes of waiting before you escalate. Firmware and OEM cases depend on the vendor support SLA and can run from hours to days. |
| Downtime or workload risk | None for diagnosis. No node drain, reboot, or live migration is required, so VMs stay online. Disk state changes, manual pool add, firmware updates, and destructive reset carry maintenance risk. A manual pool add starts background rebalance I/O that can run for minutes to hours depending on data volume. |
| Escalate immediately if | Cluster quorum is at risk, a virtual disk is detached or degraded, the disk may contain data, the model or firmware is not vendor-approved, or verification stays stuck after the normal wait of about 10 to 15 minutes. |

`CanPool=False` is not automatically a fault. It can be an expected transitional state while Health Service verifies a disk, or it can mean the disk is already in a pool. This guide is the general decision-tree router for all documented `CannotPoolReason` values. It delegates the persistent Health Service verification-stuck branch to the dedicated `AzLocal_Storage_PhysicalDiskVerificationStuck` TSG and PR 333 ownership path.

> [!NOTE]
> Scope: this is a storage disk-eligibility issue. It is not a networking or fabric problem, and it is not an OEM hardware or firmware problem unless `CannotPoolReason` is `Hardware Not Compliant` or `Firmware Not Compliant`. If you own networking only, hand this to the storage or cluster administrator.

## Symptoms and scope

Use this guide when all of the following are true:

- New or replacement disks were inserted into one or more Azure Local cluster nodes.
- The disks appear in PowerShell.
- Storage pool capacity did not increase as expected.
- `Get-PhysicalDisk` shows one or more candidate disks with `CanPool=False`.

Common indicator:

```text
CanPool          : False
CannotPoolReason : <documented reason>
```

This guide does not repair a wedged Health Service provider configuration. If `CannotPoolReason` is `Verification In Progress` or `Verification Failed` and the status does not clear after the normal wait of about 10 to 15 minutes, stop this guide and use the dedicated Health Service verification-stuck TSG from PR 333 or spec `AzLocal_Storage_PhysicalDiskVerificationStuck`.

## Terms

| Term | Plain-language definition | Why it matters |
| --- | --- | --- |
| Storage Spaces Direct (S2D) | The Azure Local storage layer that pools local disks across cluster nodes. | S2D owns the disk claim, health, repair, and pool-add behavior in this guide. |
| `CanPool` | A `Get-PhysicalDisk` property that says whether Storage Spaces can claim the disk into a pool. | `False` means at least one eligibility gate is blocking the disk. |
| `CannotPoolReason` | The `Get-PhysicalDisk` reason string that names the blocking gate. | The exact string chooses the safe branch in this article. |
| Primordial pool | The operating system's unclaimed disk collection. | A disk can be eligible for pooling only when it is not already in a non-primordial pool. |
| Non-primordial pool | The real S2D storage pool that contains claimed capacity disks. | Commands that add or check pool membership must target this pool explicitly. |
| `UniqueId` | A disk identity value used by Storage cmdlets. | Use it with `Reset-PhysicalDisk` because names and serial numbers are not always unique. |
| Stale metadata | Old Storage Spaces pool metadata left on a reused disk. | Clearing it with `Reset-PhysicalDisk` destroys disk metadata and must be gated carefully. |
| Supported Components Document | Health Service supportability data for approved physical disks and firmware. | `Hardware Not Compliant` and `Firmware Not Compliant` are driven by vendor-approved supportability data. |
| Cluster Shared Volume (CSV) | A clustered volume that every node can access at once for running VMs. | A candidate disk that backs an active CSV must never be reset or removed. |
| Quorum | The cluster's voting majority that keeps it running safely. | Losing quorum can take the cluster offline, so stop if quorum is at risk. |
| Repair, regeneration, or rebalance job | Background Storage Spaces work that restores redundancy or spreads data evenly across disks. | Changing disk state during one of these jobs can extend the impact window. |
| Enclosure and slot | The physical bay location that identifies exactly which disk you are touching. | Correct enclosure and slot prevent acting on the wrong disk. |

## Where this failure appears

| Admin surface | Status | Evidence to capture |
| --- | --- | --- |
| PowerShell on an Azure Local node | shown | `Get-PhysicalDisk` shows `CanPool=False` and the exact `CannotPoolReason`. Capture `DeviceId`, `FriendlyName`, `SerialNumber`, `UniqueId`, `FirmwareVersion`, `HealthStatus`, `OperationalStatus`, `Usage`, `CanPool`, and `CannotPoolReason`. |
| Azure portal | not-evident | The Azure portal does not appear to show the exact `CannotPoolReason` value for a candidate disk. It can show unchanged pool capacity or broader storage health alerts, but use node PowerShell for the reason string. |
| Windows event logs | not-evident | No single event log carries an authoritative signal for the general `CanPool=False` decision tree. As supporting evidence, collect the storage and clustering operational channels: `Microsoft-Windows-StorageSpaces-Driver/Operational`, `Microsoft-Windows-StorageSpaces-Driver/Diagnostic`, and `Microsoft-Windows-FailoverClustering/Operational`, plus `Get-HealthFault` for current Health Service state. |
| Cluster logs using `Get-ClusterLog` | not-evident | Cluster logs do not appear to show the exact `CannotPoolReason`. Collect them when Health Service, SDDC Group, storage provider, or cluster resource state needs correlation. |
| Windows Failover Cluster Manager | not-evident | Windows Failover Cluster Manager does not appear to show the exact `CannotPoolReason`. It can help confirm cluster group, resource, and node state before risky actions. |
| Windows Admin Center on a standalone host | not-evident | Windows Admin Center does not appear to expose the exact `CannotPoolReason` string. Treat it as a supporting health surface only. |
| Windows Admin Center in the Azure portal | not-evident | Windows Admin Center in the Azure portal does not appear to expose the exact `CannotPoolReason` string. Use PowerShell for disk eligibility and use the portal only for broader health context. |
| Component or tool log files on disk | shown | `Start-AzsSupportStorageDiagnostic` output and saved artifacts can capture the storage health analysis. Store the transcript file, diagnostic log file, and report files with the support evidence package. |

## Preconditions and stop gates

Complete these checks before any state-changing action.

| Gate | Pre-check | Expected result | Stop condition | Owner |
| --- | --- | --- | --- | --- |
| Permissions | Run an elevated PowerShell session on a cluster node. | Local administrator rights are available. | Required rights are missing. | Customer IT |
| Cluster health | `Get-ClusterNode`, `Get-StorageJob`, `Get-VirtualDisk`, and `Get-HealthFault`. | Nodes are up, no unrelated storage job is active, virtual disks are healthy, and no quorum or redundancy risk exists. | Node down, quorum risk, detached virtual disk, degraded redundancy, or unrelated critical storage fault. | Cluster admin or CSS |
| Disk identity | Capture `DeviceId`, `SerialNumber`, `UniqueId`, node, enclosure, and slot. | One intended disk is identified unambiguously. | The candidate disk cannot be distinguished from active pool disks. | Customer IT and OEM |
| Workload impact | Confirm whether a repair, regeneration, rebalance, or update is in progress. | No active job conflicts with the intended action. | A job is active and could be extended or restarted by changing disk state. | Cluster admin |
| OEM readiness | Compare model, firmware, and support package with the OEM-approved Azure Local solution guidance. | The model and firmware are approved or the branch does not require OEM action. | Supportability is unclear or not approved. | OEM or partner |
| Destructive reset | Confirm the disk is not in any non-primordial pool and its data can be destroyed. | The disk is stale media intended to be wiped. | Any chance remains that the disk belongs to an active pool or contains data to preserve. | CSS, customer IT, and OEM as needed |

## Common `CannotPoolReason` values

The `CannotPoolReason` column uses the exact title-case strings that `Get-PhysicalDisk` prints, as defined by the `MSFT_PhysicalDisk` storage class and confirmed on a live Azure Local node, for example `In a Pool` and `Insufficient Capacity`. PowerShell matching with `-eq` and `-in` is case-insensitive, so these branches still match if a specific build prints a slightly different case. Treat disk operational states such as `Lost Communication`, `Abnormal Latency`, or `Transient Error` as supporting evidence, not as substitutes for the `CannotPoolReason` string.

| `CannotPoolReason` | Meaning | Safe branch |
| --- | --- | --- |
| `In a Pool` | The disk is already claimed by a storage pool, or it carries old Storage Spaces metadata from a prior pool. | Use [Step 2a](#step-2a-resolve-in-a-pool). Use [Step 2h](#step-2h-resolve-stale-metadata-or-previous-pool-membership) only after active pool membership is disproven. |
| `Not Healthy` | The disk health state is not healthy. | Use [Step 2b](#step-2b-resolve-not-healthy). Do not add or reset the disk until health is understood. |
| `Removable Media` | The disk is presented as removable media. | Use [Step 2g](#step-2g-resolve-insufficient-capacity-or-removable-media). Replace with supported internal storage. |
| `In Use by Cluster` | The disk is owned or reserved by cluster storage. | Use [Step 2c](#step-2c-resolve-in-use-by-cluster). Do not reset the disk until cluster ownership is understood. |
| `Offline` | The disk is offline to Windows. | Use [Step 2f](#step-2f-resolve-offline-or-read-only-disk-state). |
| `Insufficient Capacity` | The disk does not have enough usable free capacity. This can be because the disk is too small for Azure Local, or because partitions consume the free space. | Use [Step 2g](#step-2g-resolve-insufficient-capacity-or-removable-media). |
| `Verification In Progress` | Health Service is checking whether the disk and firmware are approved for the solution. | Use [Step 2d](#step-2d-resolve-verification-in-progress-or-verification-failed). Wait, then recheck. |
| `Verification Failed` | Health Service could not complete supportability verification. | Use [Step 2d](#step-2d-resolve-verification-in-progress-or-verification-failed). Escalate persistent cases to Microsoft Support (CSS). |
| `Firmware Not Compliant` | The disk firmware is not approved by the solution vendor support data. | Use [Step 2e](#step-2e-resolve-hardware-not-compliant-or-firmware-not-compliant). |
| `Hardware Not Compliant` | The disk model is not approved by the solution vendor support data. | Use [Step 2e](#step-2e-resolve-hardware-not-compliant-or-firmware-not-compliant). |

## Diagnosis and mitigation

### Step 1: Capture disk identity and reason

[READ-ONLY] Capture the full disk picture for every physical disk.

```powershell
# Get the full disk picture. CannotPoolReason tells you which gate failed.
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, MediaType, BusType, Size, FirmwareVersion, HealthStatus, OperationalStatus, Usage, CanPool, CannotPoolReason
```

Fastest safe path:

1. Find the candidate disk by serial number and `UniqueId`.
2. Match the exact `CannotPoolReason` to the table above.
3. Run only the branch that matches the reason.
4. Stop before any state-changing command if cluster health, disk identity, or supportability is unclear.

> [!NOTE]
> `Get-PhysicalDisk`, `Get-StoragePool`, `Get-VirtualDisk`, `Get-StorageJob`, and `Get-HealthFault` report cluster-wide, so you can run them from any one node. `Get-Disk`, `Set-Disk`, and online or read-only changes are node-local, so run them on the node that physically holds the disk. When you add disks across many nodes or sites, repeat the matching branch on each node and re-run verification per node.

### Step 2a: Resolve `In a Pool`

[READ-ONLY] This is expected when automatic pooling already claimed the disk.

```powershell
# Replace with the new disk's serial number.
$serial = '<disk-serial-number>'

# Confirm the disk is in the intended non-primordial pool.
Get-StoragePool -IsPrimordial $false |
    Get-PhysicalDisk |
    Where-Object SerialNumber -eq $serial |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, Usage, HealthStatus, OperationalStatus
```

If the disk is in the intended pool and healthy, no additional action is needed. If this returns nothing but the candidate disk still reports `In a Pool`, treat it as possible stale metadata and continue to [Step 2h](#step-2h-resolve-stale-metadata-or-previous-pool-membership).

### Step 2b: Resolve `Not Healthy`

[READ-ONLY] A disk that is not healthy is not a safe pool-add candidate.

```powershell
# Capture disk health and any supporting storage faults.
Get-PhysicalDisk |
    Where-Object CannotPoolReason -eq 'Not Healthy' |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, HealthStatus, OperationalStatus, Usage

Get-HealthFault
Get-StorageJob
Get-VirtualDisk | Format-Table FriendlyName, HealthStatus, OperationalStatus
```

Stop here if the disk has `Lost Communication`, `Abnormal Latency`, high error counts, transient errors, or any unresolved virtual disk redundancy issue. Collect the evidence package and engage CSS or the OEM before adding or resetting the disk.

### Step 2c: Resolve `In Use by Cluster`

[READ-ONLY] Confirm whether the cluster already owns or references the disk.

```powershell
# Replace with the candidate disk UniqueId from Step 1.
$uniqueId = '<unique-id>'

Get-StoragePool -IsPrimordial $false |
    Get-PhysicalDisk |
    Where-Object UniqueId -eq $uniqueId |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, Usage, HealthStatus, OperationalStatus

Get-ClusterResource | Format-Table Name, ResourceType, State, OwnerGroup, OwnerNode
Get-StorageJob
```

Do not reset a disk that is still in use by cluster storage. If cluster ownership is unclear, collect the evidence package and escalate.

### Step 2d: Resolve `Verification In Progress` or `Verification Failed`

[READ-ONLY] Health Service verification can take time after disk insertion.

```powershell
# Recheck verification progress.
Get-PhysicalDisk |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, CanPool, CannotPoolReason, HealthStatus, OperationalStatus
```

[READ-ONLY] If the state does not clear after about 10 to 15 minutes, capture cluster and storage context.

```powershell
Get-HealthFault
Get-ClusterNode                      | Format-Table Name, State
Get-StorageJob
Get-StoragePool -IsPrimordial $false | Format-Table FriendlyName, HealthStatus, OperationalStatus
Get-VirtualDisk                      | Format-Table FriendlyName, HealthStatus, OperationalStatus
```

> [!WARNING]
> Do not reset or manually add disks while verification is still in progress or failed. If `Verification In Progress` or `Verification Failed` remains unchanged after the normal wait of about 10 to 15 minutes and the disk is clean, supported, online, and symmetric, stop this decision tree and use the dedicated Health Service verification-stuck guide, [Troubleshoot physical disks stuck in verification (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskVerificationStuck.md) (spec `AzLocal_Storage_PhysicalDiskVerificationStuck`), which owns Health resource, SDDC Group, and provider-list repair. If that guide is not yet present in your copy of this repo, engage Microsoft Support (CSS) for the Health Service / SDDC provider-list repair rather than editing the `Providers` cluster parameter yourself.

### Step 2e: Resolve `Hardware Not Compliant` or `Firmware Not Compliant`

[READ-ONLY] Capture model and firmware so the OEM can confirm whether the disk is supported by the validated Azure Local solution.

```powershell
Get-PhysicalDisk |
    Sort-Object FriendlyName, FirmwareVersion |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, FirmwareVersion, MediaType, BusType, HealthStatus, CanPool, CannotPoolReason
```

> [!CAUTION]
> Do not bypass hardware or firmware validation. Use the OEM-approved update method for the validated Azure Local solution, or replace the disk with an OEM-supported model. If the OEM does not list a supported firmware for this model and solution, replace the disk or escalate to the OEM.

Firmware update tools and support packages are vendor-owned. Follow the OEM's official Azure Local solution guidance and maintenance requirements. Do not flash firmware as part of this TSG unless the OEM procedure, customer maintenance plan, and rollback plan are approved.

The exact approved model and firmware revisions come from the Health Service Supported Components Document and the OEM's validated Azure Local solution matrix. Expected end-state: after the disk matches an approved model and firmware, Health Service re-verifies it and `Get-PhysicalDisk` reports `CanPool=True`, at which point you can continue to [Step 3](#step-3-manually-add-disks-only-when-they-are-eligible).

### Step 2f: Resolve `Offline` or read-only disk state

[READ-ONLY] Identify the exact disk first.

```powershell
Get-Disk |
    Sort-Object Number |
    Format-Table Number, FriendlyName, SerialNumber, UniqueId, OperationalStatus, IsOffline, IsReadOnly, PartitionStyle
```

Before changing the disk state:

```powershell
# Stop if repair, regeneration, or rebalance work is active.
Get-StorageJob
```

> [!CAUTION]
> [MEDIUM RISK] Bring only the intended disk online. If a repair, regeneration, or rebalance job is active and involves this disk, let it complete first. Forcing the disk online mid-rebuild can extend the impact window.

After the intended disk is confirmed and no stop condition is present:

```powershell
# Replace <disk-number> with the Number value from Get-Disk above.
Set-Disk -Number <disk-number> -IsOffline  $false
Set-Disk -Number <disk-number> -IsReadOnly $false
```

Recheck `Get-PhysicalDisk` afterward.

### Step 2g: Resolve `Insufficient Capacity` or `Removable Media`

[READ-ONLY] `Insufficient Capacity` can mean the disk is below the Azure Local data-drive requirement, or that existing partitions consume the usable free space.

```powershell
# Review the candidate disk's size, partitioning, and bus presentation.
Get-Disk |
    Sort-Object Number |
    Format-Table Number, FriendlyName, SerialNumber, UniqueId, BusType, Size, PartitionStyle, IsOffline, IsReadOnly

Get-PhysicalDisk |
    Where-Object { $_.CannotPoolReason -in @('Insufficient Capacity','Removable Media') } |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, MediaType, BusType, Size, CanPool, CannotPoolReason
```

For `Insufficient Capacity`, replace the disk if it does not meet Azure Local requirements. If partitions or old configuration consume the disk, treat it as stale media and use [Step 2h](#step-2h-resolve-stale-metadata-or-previous-pool-membership) only when the disk is intended to be wiped.

For `Removable Media`, replace the disk with supported internal storage. Do not try to force removable media into the S2D pool.

### Step 2h: Resolve stale metadata or previous pool membership

> [!WARNING]
> [HIGH RISK] `Reset-PhysicalDisk` is destructive. It removes Storage Spaces pool configuration and data from the target disk. Use this path only for disks that are intended to be wiped.

> [!NOTE]
> If you are new to Storage Spaces Direct, do NOT run `Reset-PhysicalDisk` yourself. Confirm every hard-stop item below with a senior cluster administrator or Microsoft CSS first, because a reset on the wrong disk cannot be undone.

Hard stop checklist before reset:

- The candidate disk is identified by `UniqueId`, `SerialNumber`, `DeviceId`, node, enclosure, and slot.
- The disk does not appear in any active non-primordial pool.
- The disk is not required for any virtual disk, CSV, repair, regeneration, or rebalance job.
- The customer confirms the disk has no data to preserve.
- The reset target is a replacement or reused disk, not an active pool member.
- If there is any uncertainty, collect the evidence package and escalate before resetting.

[READ-ONLY] Confirm the candidate identity and active pool membership.

```powershell
# Replace with the candidate disk UniqueId from Step 1.
$uniqueId = '<unique-id>'

# Inspect the candidate disk.
Get-PhysicalDisk -UniqueId $uniqueId | Format-List *

# Confirm it is NOT a member of any active non-primordial pool. This should return nothing.
Get-StoragePool -IsPrimordial $false |
    Get-PhysicalDisk |
    Where-Object UniqueId -eq $uniqueId |
    Format-List *

# Confirm no storage job is active before any reset.
Get-StorageJob
```

Only if every hard stop check passes:

```powershell
# Destructive: clears Storage Spaces metadata from the target disk.
Reset-PhysicalDisk -UniqueId $uniqueId
```

Wait several minutes and recheck:

```powershell
Get-PhysicalDisk -UniqueId $uniqueId |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, CanPool, CannotPoolReason, HealthStatus, Usage
```

### Step 3: Manually add disks only when they are eligible

[MEDIUM RISK] Manual pool add changes storage pool membership. Use it only after the disks show `CanPool=True`, cluster health is stable, and automatic pooling has not claimed them.

Workload impact: adding disks can start storage jobs and rebalance work. Schedule the action when the cluster can tolerate background I/O and monitor `Get-StorageJob` until it drains.

```powershell
# Inspect the target pool and eligible disks.
$pool = Get-StoragePool -IsPrimordial $false
$eligibleDisks = Get-PhysicalDisk -CanPool $true

$pool | Format-Table FriendlyName, HealthStatus, OperationalStatus
$eligibleDisks | Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, MediaType, Size, FirmwareVersion
```

> [!IMPORTANT]
> A healthy Storage Spaces Direct cluster has exactly one non-primordial pool. The snippet below enforces that and requires the operator to enumerate the intended new disks by `UniqueId`, so `Add-PhysicalDisk` cannot accidentally claim unintended `CanPool=True` disks. `UniqueId` is the stable key: nested and virtual data disks frequently report an empty `SerialNumber`, confirmed on nested virtual data disks, so serial number is only an optional human cross-check.

```powershell
# Defensive: require exactly one non-primordial pool. Abort otherwise.
$pool = Get-StoragePool -IsPrimordial $false
if (@($pool).Count -ne 1) {
    throw "Expected exactly one non-primordial pool. Found $(@($pool).Count). Select the target pool explicitly by FriendlyName before continuing."
}

# Operator MUST enumerate the intended new disks by UniqueId (the stable key).
# SerialNumber is unreliable: nested and virtual data disks frequently report an empty SerialNumber.
# Do not pipe Get-PhysicalDisk -CanPool $true directly into Add-PhysicalDisk.
$intendedUniqueIds = @(
    '<unique-id-1>',
    '<unique-id-2>'
)

# Resolve UniqueIds to physical disk objects and confirm the count matches the intent.
# Wrap in @() so .Count is reliable when 0 or 1 disk matches.
$disksToAdd = @(Get-PhysicalDisk -CanPool $true |
                Where-Object UniqueId -in $intendedUniqueIds)
if ($disksToAdd.Count -ne $intendedUniqueIds.Count) {
    throw "Disk count mismatch: $($disksToAdd.Count) eligible disks matched the $($intendedUniqueIds.Count) intended UniqueIds. Resolve before continuing."
}

# Optional human cross-check. SerialNumber may be blank on nested or virtual disks; UniqueId is authoritative.
$disksToAdd | Format-Table UniqueId, FriendlyName, SerialNumber, Size, MediaType

# Preview the add with no changes.
Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $disksToAdd -WhatIf

# Require an explicit typed confirmation before the real add.
$confirm = Read-Host "Type ADD to claim the $($disksToAdd.Count) disk(s) above into pool '$($pool.FriendlyName)'"
if ($confirm -ne 'ADD') {
    throw "Confirmation not received. Aborting before Add-PhysicalDisk."
}

# Add only the explicitly identified disks to the target pool.
Add-PhysicalDisk -StoragePoolFriendlyName $pool.FriendlyName -PhysicalDisks $disksToAdd
```

Monitor the resulting storage jobs:

```powershell
Get-StorageJob
Get-StoragePool -IsPrimordial $false | Format-Table FriendlyName, HealthStatus, OperationalStatus, AllocatedSize, Size
```

## Support Diagnostics collection

The Azure Local Support Diagnostic Tool is a read-only evidence collection path in this article. The commands below write output files under `C:\Temp`, but they do not change cluster storage state.

The exact `Start-AzsSupportStorageDiagnostic` source tokens used by this article are:

| Source label | Token or parameter |
| --- | --- |
| Missing Disks from Storage Spaces | `MissingDisks` |
| Storage Pool Health Check, Cluster Nodes Health Process Running, Storage Job Check, Cluster Node Check, Cluster Shared Volumes Check, Storage Enclosure Check, Health Service Fault Check, Storage Health Action Check, Disks Not in Pool Check | `StorageHealth` |
| Storage Spaces Partitions Check, Disk Health Check, Transient Disk Check | `DiskHealth` |
| Support Components Change, Support Components Missing | `StorageComponents` |
| Firmware Drift | `FirmwareDrift` |
| Storage Summary | `StorageSummary` |
| Cluster Shared Volume Usage | `CSVUsage` |
| Physical extent analysis | `-PhysicalExtentCheck <virtual-disk-friendly-name>` |

[READ-ONLY] Capture output and artifacts for the support package.

```powershell
# Local artifact folder for this read-only collection.
$evidenceRoot = "C:\Temp\PhysicalDiskCanPoolFalse-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

# Note: Start-AzsSupportStorageDiagnostic stops any outer Start-Transcript when it runs,
# so do not rely on Start-Transcript to capture this cmdlet. Redirect all streams instead.
# Record the tool's own working directory (where AzsSupport writes its native transcript, for
# example Start-AzsSupportStorageDiagnostic_TraceOutput_*.csv) and a start time so that transcript
# can be copied out. Fall back to the current directory only if the cmdlet is unavailable.
$diagWorkingDir = try { Get-AzsSupportWorkingDirectory } catch { (Get-Location).Path }
$runStart = Get-Date

# Capture ALL streams (success, error, warning, verbose, host, and information) with no ConvertTo-Json.
Start-AzsSupportStorageDiagnostic -Include 'MissingDisks','DiskHealth','StorageHealth','StorageComponents','FirmwareDrift','StorageSummary','CSVUsage' *>&1 |
    Tee-Object -FilePath (Join-Path $evidenceRoot 'Start-AzsSupportStorageDiagnostic.txt')

# Copy the native tool transcript the cmdlet writes in its own working directory into the evidence package.
Get-ChildItem -Path $diagWorkingDir -Recurse -File |
    Where-Object { $_.LastWriteTime -ge $runStart -and $_.Extension -in '.txt','.log','.etl','.zip','.csv' } |
    ForEach-Object { Copy-Item -Path $_.FullName -Destination $evidenceRoot -Force }
```

[READ-ONLY] Use `-PhysicalExtentCheck` only when a virtual disk is degraded, detached, or otherwise unexpected. The parameter takes a virtual disk `FriendlyName`, not a physical disk serial number or drive letter.

```powershell
# Replace with a Get-VirtualDisk FriendlyName, for example UserStorage_1.
$virtualDiskFriendlyName = '<virtual-disk-friendly-name>'

$extentStart = Get-Date
Start-AzsSupportStorageDiagnostic -PhysicalExtentCheck $virtualDiskFriendlyName *>&1 |
    Tee-Object -FilePath (Join-Path $evidenceRoot 'PhysicalExtentCheck.txt')

# Copy the native tool transcript for this run into the evidence package as well.
Get-ChildItem -Path $diagWorkingDir -Recurse -File |
    Where-Object { $_.LastWriteTime -ge $extentStart -and $_.Extension -in '.txt','.log','.etl','.zip','.csv' } |
    ForEach-Object { Copy-Item -Path $_.FullName -Destination $evidenceRoot -Force }
```

For tool installation and full reference information, see [Support Tools](https://learn.microsoft.com/azure/azure-local/manage/support-tools) and [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md).

## Verification

Verify both the original disk reason and the broader cluster state.

```powershell
# Confirm the candidate disk state.
Get-PhysicalDisk |
    Sort-Object DeviceId |
    Format-Table DeviceId, FriendlyName, SerialNumber, UniqueId, Usage, HealthStatus, OperationalStatus, CanPool, CannotPoolReason

# Confirm the pool, jobs, and health state.
Get-StoragePool -IsPrimordial $false |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize
Get-VirtualDisk | Format-Table FriendlyName, HealthStatus, OperationalStatus
Get-StorageJob
Get-HealthFault
```

Expected result:

- Intended new disks are in the non-primordial pool, or are clearly blocked by the correct non-poolable reason.
- New disks are healthy.
- No unintended `CanPool=True` disks remain.
- No unexpected storage jobs or faults are active.
- If jobs started after manual add, they are progressing and eventually drain to zero.

If this issue was found during deployment or capacity expansion, re-run the same validation that first flagged it after remediation, not just the `Get-PhysicalDisk` recheck:

```powershell
# Re-run failover cluster storage validation after the disks are claimed.
Test-Cluster -Include "Storage Spaces Direct", "Inventory", "Storage"
```

For a deployment that tripped the Azure Local environment validation, re-run the Environment Checker or the deployment validation step your process uses, and confirm it now passes.

## Rollback

| Action | Rollback |
| --- | --- |
| `Set-Disk -IsOffline $false` or `Set-Disk -IsReadOnly $false` | If the wrong disk was targeted or impact appears, stop and escalate. Do not toggle states repeatedly without CSS guidance. Capture `Get-Disk`, `Get-PhysicalDisk`, and `Get-StorageJob`. |
| `Reset-PhysicalDisk` | No in-place rollback. This is why the reset gate requires proof that the disk is stale disposable media. If reset was run on the wrong disk, stop all further actions and contact CSS immediately. |
| `Add-PhysicalDisk` | Do not remove an added disk unless CSS or the OEM confirms it is safe. Storage may have already allocated data to the disk. Capture pool and job state before any corrective action. |
| Local evidence collection files | Delete the local `C:\Temp\PhysicalDiskCanPoolFalse-*` folder after the support case no longer needs the artifacts. |

## Escalation and evidence package

Escalate to Microsoft CSS, the OEM, or the partner when diagnosis is inconclusive, a stop gate is met, mitigation risk is unacceptable, or the guide points to vendor or Health Service ownership.

Collect these artifacts before opening or updating a support case:

```powershell
# Local artifact folder for command output.
$evidenceRoot = "C:\Temp\PhysicalDiskCanPoolFalse-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

Get-HealthFault                         | Tee-Object -FilePath (Join-Path $evidenceRoot 'Get-HealthFault.txt')
Get-ClusterNode                         | Format-Table Name, State | Tee-Object -FilePath (Join-Path $evidenceRoot 'Get-ClusterNode.txt')
Get-StorageJob                          | Tee-Object -FilePath (Join-Path $evidenceRoot 'Get-StorageJob.txt')
Get-StoragePool -IsPrimordial $false    | Format-List * | Out-File -FilePath (Join-Path $evidenceRoot 'Get-StoragePool.txt') -Encoding utf8
Get-VirtualDisk                         | Format-List * | Out-File -FilePath (Join-Path $evidenceRoot 'Get-VirtualDisk.txt') -Encoding utf8
Get-PhysicalDisk                        | Format-List * | Out-File -FilePath (Join-Path $evidenceRoot 'Get-PhysicalDisk.txt') -Encoding utf8
Get-Disk                                | Format-List * | Out-File -FilePath (Join-Path $evidenceRoot 'Get-Disk.txt') -Encoding utf8

# Last 60 minutes of cluster log.
Get-ClusterLog -Destination $evidenceRoot -TimeSpan 60
```

Also collect:

- Disk serial numbers, unique IDs, enclosure, slot, and node mapping.
- Disk model and firmware version.
- Hardware vendor support matrix or written confirmation for the disk model and firmware.
- Whether automatic pooling is expected or intentionally disabled.
- Whether the issue started after insertion, firmware change, node maintenance, or a solution update.
- Support Diagnostic Tool output from [Support Diagnostics collection](#support-diagnostics-collection).

## Prevention and monitoring

- Validate disk model and firmware against the OEM-approved Azure Local solution before insertion.
- Add disks symmetrically, same count and type per node, to avoid stranded capacity.
- Run the [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md) pre-checks before insertion.
- Avoid reusing disks from prior deployments without confirming they are wiped of stale pool metadata.
- Record serial, slot, firmware, and node mapping before and after each physical disk change.
- Watch `Get-StorageJob`, `Get-HealthFault`, and pool allocated size after manual add until the cluster settles.

## Future test automation metadata

| Field | Value |
| --- | --- |
| Detector type | `command` |
| Detector signal | `Get-PhysicalDisk` with `CanPool` and `CannotPoolReason` |
| Inject strategy | VM-first scratch VHD slices for offline, read-only, insufficient-capacity, and stale-metadata behavior; hardware fallback only for OEM compliance, removable media, and physical disk health cases |
| Mitigation selector | Branch-specific command markers: `Set-Disk`, `Reset-PhysicalDisk`, `Add-PhysicalDisk`, and Support Diagnostics read-only collection |
| Safety floor | No reset unless the disk is confirmed outside every active non-primordial pool and intended to be wiped |
| Rollback check | Re-run `Get-PhysicalDisk`, `Get-StoragePool`, `Get-VirtualDisk`, `Get-StorageJob`, and `Get-HealthFault` |
| Reproduction substrate | `either`, VM first with hardware fallback |
| Fidelity level | `L1`, live read-only validation complete for the observed reasons |
| Technical grade | JSON `null` until TSG-FORGE live evidence completes |
| Automation status | `ready` |
| Spec reference | `AzLocal_Storage_PhysicalDiskCanPoolFalseGeneral` |
| Last validated | `2026-08-17`, live-observed reasons `In a Pool` and `Insufficient Capacity` on a nested Storage Spaces Direct lab cluster |

## Related documentation

- [Adding servers or drives to Storage Spaces Direct](https://learn.microsoft.com/windows-server/storage/storage-spaces/add-nodes#adding-drives)
- [Troubleshoot Storage Spaces and Storage Spaces Direct health and operational states](https://learn.microsoft.com/windows-server/storage/storage-spaces/storage-spaces-states)
- [Azure Local system requirements](https://learn.microsoft.com/azure/azure-local/concepts/system-requirements-23h2)
- [Health Service overview](https://learn.microsoft.com/azure/azure-local/manage/health-service-overview)
- [Health Service settings](https://learn.microsoft.com/azure/azure-local/manage/health-service-settings)
- [Support Tools](https://learn.microsoft.com/azure/azure-local/manage/support-tools)
- [How to add physical disks to an existing Azure Local cluster](./HowTo-Storage-AddPhysicalDisksToS2DPool.md)
- [Troubleshooting Storage With Support Diagnostics Tool](./Troubleshooting-Storage-With-Support-Diagnostics-Tool.md)
