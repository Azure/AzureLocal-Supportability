<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "reference",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Start-AzsSupportStorageDiagnostic"
  },
  "validation": {
    "fidelity_level": "L1",
    "technical_grade": null,
    "reproduction_substrate": "either",
    "automation_status": "ready",
    "last_validated": "2026-08-17",
    "spec_ref": "AzLocal_Storage_SupportStorageDiagnostic"
  }
}
-->

# Start-AzsSupportStorageDiagnostic storage diagnostics reference

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Component</th>
    <td><strong>Storage</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Topic</th>
    <td><strong>Azure Local Support Diagnostic Tool</strong>: storage diagnostic cmdlet reference for <code>Start-AzsSupportStorageDiagnostic</code></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Document type</th>
    <td><strong>Reference</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Audience</th>
    <td>Azure Local operators, Microsoft CSS support engineers, systems integrators, and OEM support engineers who need to capture storage evidence safely.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Informational</strong>: this article documents read-only diagnostics. Follow the linked troubleshooting guide for the specific failure that the diagnostic output identifies.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Highest action classification</th>
    <td><strong>Read-only diagnostic</strong>: the examples gather command output and write diagnostic artifacts only.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Workload impact</th>
    <td>No VM or storage workload disruption is expected from the documented commands. The checks read storage and cluster state and add only light, transient query load, so running VMs are not paused, live migrated, or measurably slowed. The cmdlet may take several minutes and writes a transcript in the tool working directory.</td>
  </tr>
</table>

## Table of contents

- [At a glance](#at-a-glance)
- [Overview](#overview)
- [Scope and safety boundary](#scope-and-safety-boundary)
- [Prerequisites](#prerequisites)
- [Parameters](#parameters)
- [Fast path](#fast-path)
- [Allowed Include tokens](#allowed-include-tokens)
- [Diagnostic check labels and result levels](#diagnostic-check-labels-and-result-levels)
- [Diagnostic information reports](#diagnostic-information-reports)
- [Physical extent analysis](#physical-extent-analysis)
- [Where this appears](#where-this-appears)
- [Verify and capture the diagnostic run](#verify-and-capture-the-diagnostic-run)
- [Glossary](#glossary)
- [Routing after you have output](#routing-after-you-have-output)
- [Related documentation](#related-documentation)

## At a glance

**Bottom line:** Run `Start-AzsSupportStorageDiagnostic -Include 'StorageHealth','DiskHealth','VirtualDisks'`, read the `PASS`, `INFO`, `WARN`, or `FAIL` result next to each check label, then use the [Routing after you have output](#routing-after-you-have-output) table to open the correct downstream guide. Do not run any repair command from this reference.

| Question | Answer |
|----------|--------|
| Workload impact | None expected. Every documented command is read-only and does not move, restart, or reconfigure VMs, disks, or the cluster. |
| Owner | The operator or the Microsoft CSS engineer runs the capture. Each finding then routes to the owner named in the [Routing after you have output](#routing-after-you-have-output) table: a downstream storage TSG, the OEM or vendor for firmware and Supported Components findings, or the product group for an all-`PASS` case that still reproduces. |
| Duration | Usually several minutes for the full run. A single `-Include` token is faster. |
| Maintenance window | Not required, because this is read-only evidence capture. |

> [!NOTE]
> New to Azure Local? Every command in this article only reads status and writes a log file that you can share with support. Running these commands cannot change the cluster, delete data, retire a disk, or restart a node. If a result tells you to run a repair command, stop and open the linked guide for that finding first.

## Overview

`Start-AzsSupportStorageDiagnostic` is part of the Azure Local Support Diagnostic Tool. It runs storage-focused checks for Storage Spaces Direct (S2D), prints check labels with `PASS`, `INFO`, `WARN`, or `FAIL`, and writes a diagnostic transcript for support evidence.

Use this article as a reference for the cmdlet parameters, supported `-Include` tokens, source check labels, and safe evidence capture. For details on installing or updating the Support Diagnostic Tool, see [Support Tool for Azure Local Hyperconverged Deployments](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools).

## Scope and safety boundary

### In scope

- Running `Start-AzsSupportStorageDiagnostic` with no `-Include` value, which runs all storage checks.
- Running targeted checks with the exact source `-Include` tokens listed in this article.
- Capturing module version, command output, and the tool transcript path for CSS or product group review.
- Selecting a virtual disk FriendlyName for `-PhysicalExtentCheck` when a virtual disk has an unexpected state.

### Out of scope

- Repairing storage health, retiring disks, restarting the Health Service, or changing cluster resource parameters.
- Deciding whether a `CanPool=False` disk should be added to the pool. Use the general decision-tree router in [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md).
- Repairing persistent disk verification stuck behind a wedged Health Service. That scenario is delegated to the dedicated `AzLocal_Storage_PhysicalDiskVerificationStuck` validation spec and its public guidance, not to this reference article.

> [!IMPORTANT]
> The commands in this article are diagnostic. If the diagnostic output recommends a state-changing command, do not run that command from this reference alone. Open the specific linked troubleshooting guide for that finding, confirm its safety gates, and capture a fresh backup of the evidence first.

## Prerequisites

- Run PowerShell as Administrator on an Azure Local node, or use a management host that can reach the cluster through PowerShell remoting.
- Use an account with administrative access to the Azure Local nodes.
- Install or import the `Microsoft.AzLocal.CSSTools` module that contains `Start-AzsSupportStorageDiagnostic`.
- Confirm PowerShell remoting works to the cluster nodes if you use `-ClusterName` or `-Credential`.
- If you plan to use `-PhysicalExtentCheck`, identify the virtual disk FriendlyName first with `Get-VirtualDisk`.

```powershell
$ErrorActionPreference = 'Stop'

Get-Module Microsoft.AzLocal.CSSTools -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object Name, Version, Path -First 1

Get-Command Start-AzsSupportStorageDiagnostic |
    Select-Object Name, ModuleName, Version, Source
```

## Parameters

| Parameter | Type | Required | Purpose | Notes |
|-----------|------|----------|---------|-------|
| `-ClusterName` | `String` | No | Runs diagnostics against the named cluster. | If omitted, the cmdlet attempts to resolve the local cluster name. |
| `-Credential` | `PSCredential` | No | Supplies credentials for remote computers. | If omitted, the current user context is used. |
| `-PhysicalExtentCheck` | `String` | No | Runs physical extent analysis for one virtual disk FriendlyName. | Use the virtual disk FriendlyName from `Get-VirtualDisk`, not a drive letter and not a physical disk name. |
| `-Include` | `String[]` | No | Limits the run to one or more supported storage diagnostic tokens. | If omitted, all storage checks and information reports run. |
| `-ProgressAction` and common parameters | `ActionPreference` and common parameter types | No | Standard PowerShell common-parameter behavior. | `-ProgressAction` is generated by PowerShell help and is not a diagnostic selector. |

## Fast path

Use the fast path when you need to unblock a remote support session quickly.

1. Capture module identity and command source with the prerequisite commands above.
2. Run the broad storage health slice first.
3. Add a narrower token only after the broad slice points to that area.
4. Save the console output and the cmdlet transcript path before starting any remediation guide.

```powershell
# Run the full storage diagnostic set.
Start-AzsSupportStorageDiagnostic

# Run the common first support slice only.
Start-AzsSupportStorageDiagnostic -Include 'StorageHealth','DiskHealth','VirtualDisks'

# Run against a named cluster with explicit credentials when needed.
Start-AzsSupportStorageDiagnostic -ClusterName '<cluster-name>' -Credential (Get-Credential) -Include 'StorageHealth'
```

## Allowed Include tokens

The source implementation accepts exactly these `-Include` tokens.

| Include token | Runs |
|---------------|------|
| `CSVUsage` | Cluster Shared Volume usage report. |
| `DiskHealth` | Per-disk table plus Storage Spaces partition, disk health, and transient disk checks. |
| `StorageSummary` | Storage node, volume, virtual disk, pool, S2D, capacity, cache, and supported-components summary. |
| `StorageComponents` | Supported Components Document comparison and missing component checks. |
| `DirtyCount` | Dirty Region Tracking threshold check. |
| `VirtualDisks` | Virtual disk health check. |
| `MissingDisks` | PnP disk count compared with disks in Storage Spaces. |
| `SNV` | Storage Node View difference check. |
| `FirmwareDrift` | Firmware version drift by physical disk model. |
| `SMPHost` | Storage Management Provider host process check. |
| `SMPHostIssue` | Detached virtual disk with online CSV mismatch check. |
| `StorageHealth` | Storage pool, cluster node, CSV, enclosure, Health Service fault, storage health action, disks-not-in-pool, HealthPIH, and storage job checks. |

## Diagnostic check labels and result levels

The source behavior is: Prints `PASS` when a check finds no matching data. When data is detected, the source assigns the result level shown below.

| Source output label | Result when detected | Include token | What the check looks for |
|---------------------|----------------------|---------------|--------------------------|
| Missing Disks From Storage Spaces | INFO | `MissingDisks` | Difference between disks visible through Plug and Play and disks in Storage Spaces. |
| Storage Pool Health Check | FAIL | `StorageHealth` | Non-primordial storage pool health is not healthy. |
| Cluster Nodes Health Process Running | FAIL | `StorageHealth` | `HealthPIH.exe` is not running on every cluster node. |
| Storage Job Check | WARN | `StorageHealth` | A storage job is not completed, excluding format volume jobs. |
| Cluster Node Check | FAIL | `StorageHealth` | One or more cluster nodes are not `Up`. |
| Cluster Shared Volumes Check | FAIL | `StorageHealth` | One or more Cluster Shared Volumes are not `Online`. |
| Storage Enclosure Check | FAIL | `StorageHealth` | One or more storage enclosures are not healthy. |
| Health Service Fault Check | WARN | `StorageHealth` | Active Health Service storage faults are present. |
| Storage Health Action Check | FAIL | `StorageHealth` | A storage health action is not in the `Succeeded` state. |
| Disks Not In Pool Check | FAIL | `StorageHealth` | Disks visible to the cluster are not present in the non-primordial pool. |
| Virtual Disk Check | FAIL | `VirtualDisks` | A virtual disk health state is not healthy. |
| Dirty Count | FAIL | `DirtyCount` | Dirty Region Tracking count is greater than the threshold. |
| Support Components Change | INFO | `StorageComponents` | The current physical disk and firmware inventory differs from the Supported Components Document and a new supported-components document can be suggested. |
| Support Components Missing | FAIL | `StorageComponents` | Physical disks or firmware versions in Storage Spaces are missing from the Supported Components Document. |
| Storage Node View Differs | FAIL | `SNV` | A physical disk health or operational problem is not seen consistently by all nodes. |
| Firmware Drift | INFO | `FirmwareDrift` | Same physical disk model has more than one firmware version. |
| SMPHost Check | FAIL | `SMPHost` | The Storage Management Provider host service is not running on all nodes. |
| SMPHost Issue Check | FAIL | `SMPHostIssue` | A virtual disk is detached while the related Cluster Shared Volume is still online. |
| Storage Spaces Partitions Check | FAIL | `DiskHealth` | Storage Spaces partitions are missing or do not match expected protective partition patterns. |
| Disk Health Check | FAIL | `DiskHealth` | A physical disk health status is not healthy. |
| Transient Disk Check | FAIL | `DiskHealth` | A physical disk operational status is `Transient Error`. |

Expected console output shape:

```text
Storage Pool Health Check                       [ PASS ]
Storage Job Check                               [ WARN ]
Virtual Disk Check                              [ FAIL ]
Firmware Drift                                  [ INFO ]
```

The rows above are the source labels and result levels. Your live output may contain a different mix of `PASS`, `INFO`, `WARN`, and `FAIL` based on the cluster state at the time of the run.

## Diagnostic information reports

These `-Include` tokens produce inventory or capacity information rather than a failure check.

| Report | Include token | Output areas |
|--------|---------------|--------------|
| Storage Summary | `StorageSummary` | Storage Nodes Configuration, Volume Configuration, Virtual Disk Configuration, Pool Configuration, Storage Spaces Direct Configuration, and Capacity Details. |
| Cluster Shared Volume Usage | `CSVUsage` | Cluster Shared Volume space consumption view. |

## Physical extent analysis

Use `-PhysicalExtentCheck` only when you need to inspect non-active physical extents for a virtual disk with an unexpected state. The value is the virtual disk FriendlyName.

```powershell
# List candidate virtual disk names first.
Get-VirtualDisk |
    Format-Table FriendlyName, HealthStatus, OperationalStatus

# Replace the placeholder with the virtual disk FriendlyName from Get-VirtualDisk.
$virtualDiskName = 'replace-with-virtual-disk-FriendlyName'
Start-AzsSupportStorageDiagnostic -PhysicalExtentCheck $virtualDiskName
```

Under the hood, `-PhysicalExtentCheck` calls `Get-AzsSupportStoragePhysicalExtent` for the named virtual disk and reports its non-active physical extents. Expect one of three shapes:

- Non-active extents found: a virtual disk object plus `Extents`, `UniqueDisks`, and `Disks` details.
- No non-active extents found on a healthy virtual disk: the additional section is empty.
- No physical disks present to enumerate, for example on a nested or VM-based cluster: the check reports `No PNP device with class DiskDrive found on <cluster>` and returns no extent details. This is expected on virtualized substrates and does not indicate a virtual disk fault. This exact message was observed on a nested VM cluster during validation.

## Where this appears

`Start-AzsSupportStorageDiagnostic` is an on-device PowerShell diagnostic. Its own output appears in the console and in the tool transcript. Underlying storage problems may also appear in other tools, but this article does not claim that every surface shows the diagnostic output.

| Admin surface | How this diagnostic appears | Operator note |
|---------------|-----------------------------|---------------|
| PowerShell on an Azure Local node | Shown by `Start-AzsSupportStorageDiagnostic` console output. | Primary surface for this reference. Capture the exact command, module version, and output. |
| Azure portal | Does not appear in Azure portal as this tool's output. | The portal may show the underlying storage alert, but it does not show this cmdlet's check table. |
| Windows event logs | Does not appear in Windows event logs as this tool's output. | Investigate event logs from the specific downstream TSG only after a check points there. |
| Cluster logs (`Get-ClusterLog`) | Does not appear in Get-ClusterLog as this tool's output. | Cluster logs can help with the underlying storage condition, not with the Support Diagnostic Tool run itself. |
| Windows Failover Cluster Manager | Does not appear in Failover Cluster Manager as this tool's output. | Use Failover Cluster Manager only to inspect an underlying cluster role, CSV, or node state that a check identifies. |
| Windows Admin Center on a standalone host | Does not appear in Windows Admin Center as this tool's output. | WAC may show the underlying storage health, not the cmdlet output. |
| Windows Admin Center in the Azure portal | Does not appear in Windows Admin Center in the Azure portal as this tool's output. | Use the PowerShell output and transcript as the evidence package. |
| Component / tool log files (on disk) | Shown in the Support Diagnostic Tool transcript file named `Start-AzsSupportStorageDiagnostic_TraceOutput_<yyyyMMdd>.csv` in the tool working directory. | Preserve this transcript with the console output. |

## Verify and capture the diagnostic run

The goal is to prove the command ran, preserve its output, and keep the run reproducible. The following example writes a local evidence folder on the node or management host. It does not change cluster configuration.

```powershell
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $env:USERPROFILE "AzLocalStorageDiagnostic_$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$module = Get-Module Microsoft.AzLocal.CSSTools -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object Name, Version, Path -First 1

[pscustomobject]@{
    TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
    ModuleName = $module.Name
    ModuleVersion = $($module.Version.ToString())
    ModulePath = $module.Path
    Command = "Start-AzsSupportStorageDiagnostic -Include 'StorageHealth','DiskHealth','VirtualDisks'"
} | ConvertTo-Json | Out-File -FilePath (Join-Path $outDir 'run-metadata.json') -Encoding utf8

Start-AzsSupportStorageDiagnostic -Include 'StorageHealth','DiskHealth','VirtualDisks' *>&1 |
    Tee-Object -FilePath (Join-Path $outDir 'storage-diagnostic-output.txt')

# The tool transcript name carries the date only, so copy it out under a time-stamped
# name before any second run today, otherwise the next same-day run overwrites it.
$workingDir = Get-AzsSupportWorkingDirectory
$transcript = Get-ChildItem -Path $workingDir -Filter 'Start-AzsSupportStorageDiagnostic_TraceOutput_*.csv' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if ($transcript) {
    Copy-Item -Path $transcript.FullName -Destination (Join-Path $outDir "StorageDiagnostic_TraceOutput_$stamp.csv")
}

Get-ChildItem -Path $outDir
```

Verify the diagnostic run before you interpret it:

- The command completed without a PowerShell error.
- `storage-diagnostic-output.txt` contains the source output labels from this article.
- `run-metadata.json` contains the module version, module path, timestamp, and exact command.
- The Support Diagnostic Tool transcript is named `Start-AzsSupportStorageDiagnostic_TraceOutput_<yyyyMMdd>.csv`, which carries a date-only stamp, and is written to the tool working directory. Locate that directory with the module cmdlet `Get-AzsSupportWorkingDirectory`, then list the transcript with `Get-ChildItem -Path (Get-AzsSupportWorkingDirectory) -Filter 'Start-AzsSupportStorageDiagnostic_TraceOutput_*.csv'`. Because the name carries the date only, a second run on the same day overwrites it, so copy each run's transcript out immediately under a name that includes a time stamp such as `HHmmss` before you start the next run, exactly as the capture example above does.
- Every `INFO`, `WARN`, or `FAIL` row is routed to a specific troubleshooting guide before any state-changing action is attempted.

For a single run the cmdlet already queries every node in the cluster, so cross-node checks such as `Storage Node View Differs`, `SMPHost Check`, and `Firmware Drift` compare all nodes in one pass. For repeat deployments across sites, run the same `-Include` slice on each cluster and keep a per-site `run-metadata.json`. After a downstream guide remediates a finding, re-run the same `-Include` token and confirm the check returns `PASS` to close the loop.

## Glossary

| Term | Meaning |
|------|---------|
| S2D | Storage Spaces Direct, the clustered storage technology used by Azure Local. |
| CSV | Cluster Shared Volume, a cluster volume path such as `C:\ClusterStorage\...` that can host workloads. |
| DRT | Dirty Region Tracking, metadata that tracks regions that need repair or synchronization. |
| SNV | Storage Node View, the view of physical disks from each cluster node. Differences can point to visibility or fabric issues. |
| SMPHost | Storage Management Provider host service. The diagnostic source label is `SMPHost Check`. |
| Supported Components Document | Vendor support data used to decide whether disk model and firmware combinations are supported. |
| Physical extent | A physical allocation backing a virtual disk. In this cmdlet, `-PhysicalExtentCheck` starts from a virtual disk FriendlyName. |
| Primordial pool | The built-in pool that lists disks which are available but not yet added to Storage Spaces Direct. The non-primordial pool is the actual S2D pool that backs your volumes, so a healthy cluster serves storage from the non-primordial pool. |
| Protective partition | A reserved partition pattern that Storage Spaces places on a pooled disk. A missing or unexpected pattern can mean a disk is not correctly claimed by the pool. |
| Detached virtual disk | A virtual disk that is no longer attached to the storage stack, so its Cluster Shared Volume cannot be served even when the pool itself is present. |
| PnP | Plug and Play, the Windows device layer that enumerates physical disks. A difference between the PnP disk count and the disks in Storage Spaces points to a disk that hardware can see but the pool cannot. |
| Health Service | The Azure Local cluster service that reports storage faults and runs storage health actions. |
| HealthPIH.exe | The per-node Health Service process. The `Cluster Nodes Health Process Running` check confirms it is running on every cluster node. |

## Routing after you have output

Use the diagnostic result to route the next action. Do not treat this reference as a repair procedure.

| Diagnostic evidence | Route |
|---------------------|-------|
| `CanPool=False` or a `CannotPoolReason` value | Start with [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md). That guide remains the general decision-tree router. |
| Persistent `Verification in progress` or `Verification failed` that does not clear, especially with Health Service provider evidence | Use the dedicated PhysicalDiskVerificationStuck guidance tracked by spec `AzLocal_Storage_PhysicalDiskVerificationStuck`. This reference intentionally does not repair Health Service provider configuration. |
| `FirmwareDrift`, `Support Components Change`, or `Support Components Missing` | Capture disk model, firmware, serial number, and the Supported Components output. The Supported Components output names the expected supported model and firmware set, so use it as the comparison baseline, then hand off to the OEM or vendor support path and confirm the target firmware version against the OEM qualified-firmware list. |
| `Storage Node View Differs` or `Storage Enclosure Check` FAIL | A physical disk or enclosure is seen inconsistently across nodes. This can be a storage fabric, cabling, SAS or enclosure, or node network visibility problem, so capture the check output and involve the fabric, network, or hardware owner alongside the downstream storage TSG. |
| `Storage Job Check`, `Virtual Disk Check`, `Dirty Count`, or `Disk Health Check` | Preserve output and transcript, then select the downstream storage TSG for that exact check and confirm its safety gates before any state-changing action. |
| Only `PASS` rows and the issue is still present | Capture the evidence package and escalate through your support path to the product group, because this cmdlet did not detect the reported condition. A Microsoft CSS engineer escalates to the product group with the symptom timeline; a customer or partner opens or updates a support request. |

## Related documentation

- [Support Tool for Azure Local Hyperconverged Deployments](https://learn.microsoft.com/en-us/azure/azure-local/manage/support-tools)
- [Troubleshoot physical disks not claimed after insertion (`CanPool=False`)](./Troubleshoot-Storage-PhysicalDiskCanPoolFalse.md)
