<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "how-to",
  "products": ["Azure Local"],
  "detector": {
    "type": "manual",
    "signal": "Planned Network ATC storage-intent change between iWARP and RoCEv2"
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": "A",
    "reproduction_substrate": "none",
    "automation_status": "manual",
    "last_validated": "2026-10-01",
    "spec_ref": ""
  }
}
-->

# How to change the storage RDMA transport between iWARP and RoCEv2 on Azure Local

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 220px;">Document type</th>
    <td><strong>How-To</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Purpose</th>
    <td>Change an existing Network ATC storage intent from RoCEv2 to iWARP, or from iWARP to RoCEv2, while the workloads and storage stack are fully quiesced.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Business impact</th>
    <td>This procedure causes a full planned outage for virtual machines (VMs), Cluster Shared Volumes (CSVs), Azure Local VM management, and storage until the transport change is validated and the platform is restored.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Audience</th>
    <td>Azure Local administrators working with the workload owner, network team, original equipment manufacturer (OEM), and Microsoft Customer Support Services (CSS).</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Component</th>
    <td>Host networking, Network ATC, SMB Direct, Failover Clustering, and Storage Spaces Direct.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Applicable products</th>
    <td>Azure Local hyperconverged deployments that use Network ATC and RDMA for host storage traffic.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Supported versions</th>
    <td>Azure Local 2311.2 and later, where the installed OEM solution and network adapters support the selected target transport. Confirm the exact supported configuration with the OEM before the maintenance window.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Estimated duration</th>
    <td>Plan a multi-hour maintenance window. The exact duration depends on workload shutdown, Network ATC convergence, storage recovery, and validation under representative load.</td>
  </tr>
  <tr>
    <th style="text-align:left; width: 220px;">Overall action type and risk</th>
    <td><strong>[HIGH RISK]</strong>: This procedure intentionally takes customer workloads, CSVs, the Storage Spaces Direct pool, and Azure Local VM management offline.</td>
  </tr>
</table>

## At a glance

> [!WARNING]
> This is a planned-outage procedure, not a live or rolling change. Do not start until the workload owner, network team, OEM, and change approver have accepted the outage and the rollback plan.

The safe dependency order is:

1. Confirm target transport support and capture a complete baseline.
2. Gracefully shut down customer VMs and the Azure Local VM management appliance.
3. Stop the MOC Cloud Agent clustered resource.
4. Offline workload CSVs, then the infrastructure CSV.
5. Offline the exact clustered Storage Pool resource.
6. Preserve the existing Network ATC adapter overrides and change only `NetworkDirectTechnology`.
7. Wait for Network ATC to converge on every node while storage remains offline.
8. Online the storage pool and any recorded manual-attach virtual-disk resource.
9. Online the infrastructure CSV, MOC, the appliance VM, then workload CSVs.
10. Hold a clean platform state for five continuous minutes.
11. Return workload startup to the application owner.
12. Validate the target transport under an approved representative workload.

Rollback uses the same quiesce and recovery sequence with the original transport as the target.

## Scope and support boundary

Use this guide only when all of the following are true:

- The deployment is hyperconverged and uses RDMA for Storage Spaces Direct traffic.
- The existing storage network is managed by Network ATC.
- Every storage adapter on every node supports the selected target transport.
- The OEM confirms that the adapter, driver, firmware, and target transport combination is supported.
- The network team confirms that the physical fabric is ready before a change to RoCEv2.
- A full application outage is approved.
- The cluster, storage, and network are healthy before the change.

Do not use this guide for:

- Disaggregated Azure Local deployments, where storage uses a separate SAN.
- A cluster with a down node, unhealthy quorum, active storage repair, detached virtual disk, or active solution update.
- A mixed transport design. All RDMA peers in the storage fabric must use the same transport.
- Adapter, driver, firmware, switch, or cabling remediation.
- Recreating Network ATC intents, virtual switches, storage VLANs, or storage IP addresses.
- Storage repair, pool recreation, CSV recreation, or metadata cleanup.

> [!IMPORTANT]
> If a pool, virtual disk, CSV, MOC resource, or appliance VM does not return to its recorded state, stop and contact Microsoft Support. Do not run `Disable-ClusterStorageSpacesDirect`, `Repair-ClusterStorageSpacesDirect`, remove a CSV, recreate a virtual disk, or force storage metadata changes as part of this procedure.

## Where to observe this change

Use the command-line checks in this guide as the authoritative go/no-go gates. Other administrator surfaces are useful for orientation and evidence, but they do not replace the Network ATC and storage checks.

| Surface | What it can show | How to use it |
| --- | --- | --- |
| Node PowerShell | Network ATC intent and convergence, adapter transport, RDMA capability, cluster resources, CSVs, storage health, and SBL connections. | This is the primary execution and verification surface for this guide. |
| Failover Cluster Manager | Clustered VM roles, MOC, the Storage Pool resource, CSV state, owner node, and pending or failed resource transitions. | Use it as a second read-only view. Do not select similarly named resources from the GUI instead of the sealed identities. |
| Windows Admin Center on a standalone host | High-level cluster, server, VM, network, and storage health. | Useful for situational awareness. The target RDMA transport and Network ATC convergence may not be fully exposed, so do not use Windows Admin Center alone as the completion gate. |
| Windows Admin Center in the Azure portal | The Azure Local cluster and server extension can show high-level health and management symptoms. | This procedure has not characterized transport-override or per-adapter convergence evidence in this surface. Use the PowerShell gates in this guide as the required authority. |
| Azure portal | Azure Local resource connectivity and Azure Local VM management symptoms. | Use it to observe management-plane recovery after MOC and the appliance return. It is not the transport or storage recovery authority. |
| Windows Event Viewer | Network ATC, failover-clustering, SMB, Hyper-V, and storage events near the change window. | Review relevant operational logs when a state transition or convergence check fails. Save the event time, provider, ID, and message in the support package. |
| Cluster logs | Resource arbitration and state transitions across the maintenance window. | If escalation is required, run `Get-ClusterLog -UseLocalTime -TimeSpan 60 -Destination $EvidenceRoot` before logs age out. |
| Component and tool log files on disk | The operator transcript, phase checkpoints, manifests, hashes, Network ATC snapshots, event extracts, and validation output are written under the local `$EvidenceRoot` directory. OEM NIC, switch, driver, and firmware logs are vendor-specific. | Preserve the on-disk transcript file and evidence directory. Ask the OEM and network team which additional component logs and counters are authoritative for the installed solution. |

## Transport requirements

| Target | Network and host readiness required before the change |
| --- | --- |
| iWARP | The OEM confirms iWARP support on every storage adapter. The built-in inbound iWARP firewall rule is present, enabled, inbound, and allows traffic on every node. |
| RoCEv2 | The OEM confirms RoCEv2 support on every storage adapter. The network team confirms end-to-end Data Center Bridging (DCB), including Priority Flow Control (PFC), Enhanced Transmission Selection (ETS), and Explicit Congestion Notification (ECN), on every host-facing and inter-switch path used by storage. The NIC and driver configuration must react to congestion notifications by reducing the sending rate according to the OEM-supported congestion-control profile. |

PFC protects the selected lossless priority from drops, but PFC alone does not provide fine-grained sender rate control. For RoCEv2, ECN-capable switches use a congestion-marking policy such as Weighted Random Early Detection (WRED) before queues overflow. The receiving endpoint returns a congestion notification, and the sending NIC reduces its rate. The endpoint behavior is commonly implemented by a mechanism such as Data Center Quantized Congestion Notification (DCQCN).

> [!CAUTION]
> Do not enable switch-side ECN or copy vendor tuning values without confirming that the NIC, driver, firmware, and switch configuration use one OEM-supported end-to-end profile. A switch cannot make a non-ECN-capable sender react to congestion. Engage the network team and OEM for the fabric and endpoint settings.

See the existing [QoS policy configuration](../Top-Of-Rack-Switch/Reference-TOR-QOS-Policy-Configuration.md), [ECN reference](../Top-Of-Rack-Switch/Reference-TOR-Explicit-Congestion-Notification.md), and [RoCEv2 PFC troubleshooting guide](../Top-Of-Rack-Switch/Troubleshoot-TOR-LLDP-DCBX-PFC-RoCEv2.md). This guide does not duplicate vendor-specific switch configuration.

### Recognize an over-paused or stalled RoCEv2 path

In a correctly classified design, storage RDMA and cluster heartbeat traffic use distinct priorities and queues. A PFC pause on the storage priority should not indefinitely block cluster heartbeat traffic. If heartbeat loss occurs at the same time as heavy PFC activity, investigate incorrect priority classification, DCBX inconsistency, shared-buffer or head-of-line blocking, pause storms, driver or firmware stalls, and broader link loss. Do not conclude that PFC caused the outage from a Windows event alone.

Windows can show the consequence of a stalled path:

| Windows signal | Meaning in this investigation | Causality limit |
| --- | --- | --- |
| Failover Clustering event 5120 | A CSV entered a paused or unavailable state, commonly with an I/O timeout or connection-disconnected status. | Shows CSV or SMB path impact. It does not identify PFC as the cause. |
| Failover Clustering event 5142 | A CSV is no longer accessible from the reporting node. | Shows a severe CSV connectivity outcome, not the fabric mechanism. |
| Failover Clustering event 1135 | A node was removed from active cluster membership after communication was lost or delayed. | Shows heartbeat loss. It does not distinguish PFC, link loss, CPU starvation, driver stall, or another network failure. |
| Failover Clustering events 1069 or 1177 | A clustered resource failed, or the cluster lost the connectivity needed for quorum. | Shows downstream resource or quorum impact. |
| SMB Client and SMB Server events whose message contains `RDMA` | An RDMA interface, connection, or SMB Direct operation reported a warning or error. | Event IDs vary by failure and build. Review the message and timeline instead of relying on one hard-coded event ID. |
| SBL RDMA sessions disappear, become unselected, or fall back to TCP | The storage data path is no longer using the expected RDMA connections. | Confirms a data-path symptom, not the reason for the loss. |

Collect a bounded, synchronized Windows timeline from every node:

```powershell
$Cluster = Get-Cluster -ErrorAction Stop
$Nodes = @(Get-ClusterNode -ErrorAction Stop | Sort-Object Name)
$EvidenceRoot = Join-Path $env:SystemDrive (
    "AzureLocal-RdmaTransport-Preflight-{0}" -f
    (Get-Date -Format 'yyyyMMdd-HHmmss')
)
New-Item -ItemType Directory -Path $EvidenceRoot `
    -ErrorAction Stop | Out-Null

$EventStart = (Get-Date).AddMinutes(-30)

$ClusterEvents = Invoke-Command -ComputerName $Nodes.Name `
    -ArgumentList $EventStart -ScriptBlock {
        param($StartTime)
        Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Microsoft-Windows-FailoverClustering'
            Id = 1069, 1135, 1177, 5120, 5142
            StartTime = $StartTime
        } -ErrorAction SilentlyContinue |
            Select-Object MachineName, TimeCreated, Id, LevelDisplayName, Message
    }

$SmbRdmaEvents = Invoke-Command -ComputerName $Nodes.Name `
    -ArgumentList $EventStart -ScriptBlock {
        param($StartTime)
        foreach ($Log in @(Get-WinEvent -ListLog '*SMB*' -ErrorAction SilentlyContinue |
            Where-Object IsEnabled)) {
            Get-WinEvent -FilterHashtable @{
                LogName = $Log.LogName
                StartTime = $StartTime
            } -ErrorAction SilentlyContinue |
                Where-Object { "$($_.Message)" -match '(?i)RDMA' } |
                Select-Object MachineName, LogName, TimeCreated, Id,
                    LevelDisplayName, Message
        }
    }

$ClusterEvents | Sort-Object TimeCreated |
    Export-Csv -NoTypeInformation -Path (Join-Path $EvidenceRoot 'cluster-events.csv')
$SmbRdmaEvents | Sort-Object TimeCreated |
    Export-Csv -NoTypeInformation -Path (Join-Path $EvidenceRoot 'smb-rdma-events.csv')
```

The decisive correlation is a common UTC interval that includes both:

- Windows impact, such as an RDMA-session change, event 5120 or 5142, event 1135, a resource failure, or quorum loss.
- Fabric or endpoint evidence on the exact affected ports, such as increasing PFC pause frames or pause duration, ECN marks, queue occupancy, drops, DCBX operational-state change, NIC congestion notifications, or a driver or firmware event.

For RoCEv2, require the network and OEM evidence package below before the window and again during representative load:

| Evidence | Required fields |
| --- | --- |
| Physical path map | Node, adapter name, adapter MAC address, switch, switch port, storage VLAN, priority, and traffic class. |
| DCBX state | Host and switch DCBX mode, peer TLVs, operational PFC priorities, and operational ETS mapping. |
| PFC | Per-priority receive and transmit pause frames, pause duration when available, pause storm indicators, and the observation interval. |
| ETS | Traffic-class bandwidth allocation and queue-to-priority mapping. |
| ECN/WRED | Marking threshold profile, per-queue ECN-mark count, queue occupancy, and drop count. |
| Endpoint response | OEM-supported congestion-control mode, NIC firmware and driver, ECN-capable traffic confirmation, and congestion-notification or rate-reduction counters when the OEM exposes them. |
| Time alignment | Switch, host, and evidence-collector clocks synchronized closely enough to correlate the same incident interval. |

Zero ECN marks on an uncongested port prove nothing. High PFC counts without duration, queue, drop, and workload context also do not prove a pause storm.

## Prerequisites

Complete every item before the approved change window.

| Prerequisite | Required condition | Stop condition |
| --- | --- | --- |
| Permissions | Elevated Windows PowerShell on a cluster node, local administrator rights on every node, and rights to manage Hyper-V and Failover Clustering. | Stop if remoting or administration fails on any node. |
| Change approval | The outage, sequence, rollback decision owner, and customer communication cadence are documented. | Stop if any owner or approver is missing. |
| OEM approval | The target transport is supported on the installed adapter, driver, firmware, and Azure Local solution. | Stop if support is unknown or mixed across nodes. |
| Network approval | The fabric configuration matches the target transport. RoCEv2 readiness includes PFC, ETS, ECN, and endpoint congestion response. | Stop if the network team cannot provide the readiness evidence. |
| Cluster health | All nodes are `Up`, quorum is healthy, no solution update is active, and no unrelated cluster maintenance is in progress. | Stop on any degraded or changing state. |
| Storage health | The pool and every virtual disk are healthy, every CSV is online, and `Get-StorageJob` returns no active jobs. | Stop on any storage fault, repair, rebuild, regeneration, or optimization job. |
| Network ATC health | One storage intent exists and every node reports successful, completed provisioning with no error or retry debt. | Stop on any intent error, retry count, or incomplete state. |
| Recovery material | The exact source transport, explicit adapter overrides, resource identities, VM identities, and pre-change output are saved outside the CSVs that will be offlined. | Stop if the rollback evidence is incomplete or stored only on cluster storage. |

## Change-control checkpoints

Use these checkpoints in the customer communication plan. Record the named decision owner in the change record before the window.

| Checkpoint | Approximate timing | Go criteria | No-go or rollback trigger | Decision owner |
| --- | --- | --- | --- | --- |
| Readiness review | At least one business day before the outage | OEM support, fabric evidence, workload plan, baseline health, and rollback evidence are complete. | Any unknown support status, unhealthy cluster, missing owner, or incomplete evidence. | Change approver |
| Workload outage accepted | Start of window | Application owners confirm shutdown can begin and identify validation contacts. | A critical workload cannot stop or its owner is unavailable. | Workload owner |
| Platform quiesced | After customer VMs, appliance, MOC, CSVs, and pool are offline | Every sealed object is in the expected offline state. | Identity drift, unexpected resource transition, or incomplete shutdown. | Cluster administrator |
| Point of no return | Immediately before `Set-NetIntent` | The full offline state is verified and the rollback transport and fabric remain available. | Any disagreement between the sealed manifest and live state. | Change approver and cluster administrator |
| Transport accepted | After Network ATC convergence | Every node converged once, and every storage adapter reads back the target transport. | Timeout, retry debt, Network ATC error, mixed transport, or adapter failure. | Cluster administrator and network lead |
| Service restoration | After platform recovery and first five-minute clean hold | Pool, virtual disks, CSVs, MOC, appliance, and Network ATC remain clean. | Any storage, cluster, or management-plane fault. | Cluster administrator |
| Customer validation | After application startup and representative load | Application checks, active RDMA checks, Windows events, and fabric counters remain clean. | Application error, TCP fallback, RDMA-session loss, new cluster or CSV event, pause storm, or drop increase. | Workload owner, network lead, and change approver |
| Change closure | After final five-minute clean hold | Evidence package is complete and all owners accept the result. | Any unresolved warning or missing evidence. | Change approver |

Send service-status updates at minimum when the outage begins, the platform is fully quiesced, the target transport converges, infrastructure service is restored, workload validation begins, and the change closes or rolls back.

## Glossary

- **Network ATC intent:** The desired-state definition that configures and continuously reconciles host networking.
- **Storage intent:** The Network ATC intent whose `IsStorageIntentSet` property is true.
- **CSV:** A Cluster Shared Volume that provides shared storage to clustered workloads.
- **Infrastructure CSV:** The CSV that stores the Azure Local VM management appliance.
- **MOC Cloud Agent:** The clustered resource used by Azure Local VM management.
- **Storage Pool resource:** The clustered `Storage Pool` resource that represents the Storage Spaces Direct pool.
- **SBL:** The Storage Bus Layer SMB instance used for node-to-node Storage Spaces Direct traffic.
- **Representative load:** A customer-approved workload that causes real storage traffic without intentionally saturating or fault-injecting the production fabric.

## Prepare variables and evidence storage

Run all commands from an elevated Windows PowerShell session on one cluster node.

**Action type:** [READ-ONLY]

Set the change direction and create an evidence folder on a local system drive. Do not place the evidence folder on a CSV.

```powershell
$PreviousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Stop'

$TargetTransport = 'iWARP' # Use either 'iWARP' or 'RoCEv2'
$TransportValues = @{
    iWARP  = 1
    RoCEv2 = 4
}

if ($TargetTransport -notin $TransportValues.Keys) {
    throw "TargetTransport must be iWARP or RoCEv2."
}

$Operation = 'Forward'
$DesiredTransport = $TargetTransport
$DesiredTransportValue = [int]$TransportValues[$DesiredTransport]

$ChangeId = Get-Date -Format 'yyyyMMdd-HHmmss'
$EvidenceRoot = Join-Path $env:SystemDrive `
    "AzureLocal-RdmaTransport-$ChangeId"
$ActivePointer = Join-Path $env:SystemDrive `
    'AzureLocal-RdmaTransport-Active.txt'

if (Test-Path -LiteralPath $ActivePointer) {
    $ExistingEvidenceRoot = "$(Get-Content -LiteralPath $ActivePointer -Raw)".Trim()
    $PointerTarget = if ($ExistingEvidenceRoot) {
        "'$ExistingEvidenceRoot'"
    } else {
        'an empty target'
    }
    throw (
        "The active RDMA transport pointer already exists and records " +
        "$PointerTarget. Resume, recover, or explicitly disposition that " +
        "operation before starting another change. A missing pointer target " +
        "is not permission to overwrite the pointer."
    )
}

New-Item -ItemType Directory -Path $EvidenceRoot -ErrorAction Stop | Out-Null
try {
    $PointerStream = [System.IO.File]::Open(
        $ActivePointer,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $PointerBytes = [System.Text.UTF8Encoding]::new($false).
            GetBytes($EvidenceRoot)
        $PointerStream.Write($PointerBytes, 0, $PointerBytes.Length)
        $PointerStream.Flush($true)
    } finally {
        $PointerStream.Dispose()
    }
} catch [System.IO.IOException] {
    throw (
        "The active RDMA transport pointer could not be created atomically. " +
        "Another operation may have claimed it, or the pointer path is " +
        "unavailable. Stop and reconcile the pointer before continuing."
    )
}

$InitialStatePath = Join-Path $EvidenceRoot 'phase-state.json'
$InitialTempPath = "$InitialStatePath.tmp"
try {
    [pscustomobject]@{
        ChangeId = $ChangeId
        Phase = 'Initialized'
        UpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        TargetTransport = $TargetTransport
        Operation = $Operation
        DesiredTransport = $DesiredTransport
        DesiredTransportValue = $DesiredTransportValue
        ActiveValidationStartUtc = ''
        RollbackOriginPhase = ''
    } | ConvertTo-Json |
        Set-Content -LiteralPath $InitialTempPath -ErrorAction Stop
    Move-Item -LiteralPath $InitialTempPath `
        -Destination $InitialStatePath -Force -ErrorAction Stop
}
catch {
    Remove-Item -LiteralPath $InitialTempPath -Force `
        -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $ActivePointer -Force `
        -ErrorAction SilentlyContinue
    throw (
        "The initial phase state could not be persisted. The active pointer " +
        "was removed so the operation can be started again safely. " +
        "$($_.Exception.Message)"
    )
}

Start-Transcript -Path (Join-Path $EvidenceRoot 'operator-transcript.txt') -ErrorAction Stop

$Cluster = Get-Cluster -ErrorAction Stop
$Nodes = @(Get-ClusterNode -ErrorAction Stop | Sort-Object Name)

function Assert-IntentStatusCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Status,

        [Parameter(Mandatory)]
        [object[]]$ClusterNodes,

        [Parameter(Mandatory)]
        [string]$IntentName
    )

    $ExpectedHosts = @($ClusterNodes | ForEach-Object {
        "$($_.Name)".Split('.')[0].ToUpperInvariant()
    } | Sort-Object -Unique)
    $ActualRows = @($Status | ForEach-Object {
        [pscustomobject]@{
            Host = "$($_.Host)".Split('.')[0].ToUpperInvariant()
            IntentName = "$($_.IntentName)"
        }
    })
    $ActualHosts = @($ActualRows.Host)
    $MissingHosts = @($ExpectedHosts | Where-Object { $_ -notin $ActualHosts })
    $UnknownHosts = @($ActualHosts | Where-Object { $_ -notin $ExpectedHosts })
    $DuplicateHosts = @($ActualHosts | Group-Object | Where-Object Count -ne 1)
    $WrongIntent = @($ActualRows | Where-Object IntentName -ne $IntentName)

    if (
        $Status.Count -ne $ExpectedHosts.Count -or
        $MissingHosts.Count -gt 0 -or
        $UnknownHosts.Count -gt 0 -or
        $DuplicateHosts.Count -gt 0 -or
        $WrongIntent.Count -gt 0
    ) {
        throw (
            "Network ATC status coverage is incomplete or ambiguous. " +
            "Expected hosts: $($ExpectedHosts -join ','); " +
            "returned hosts: $($ActualHosts -join ',')."
        )
    }
}

function Set-ChangePhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'Initialized',
            'BaselineSealed',
            'WorkloadsOff',
            'PlatformOff',
            'CsvsOff',
            'PoolOff',
            'IntentSubmissionPending',
            'IntentSubmitted',
            'IntentConverged',
            'TargetReadbackVerified',
            'PoolOnline',
            'PlatformOnline',
            'StorageHoldPassed',
            'RollbackApproved',
            'ActiveValidationStarted',
            'ActiveAssertionsPassed',
            'ActiveValidationPassed',
            'Completed'
        )]
        [string]$Phase,

        [string]$ActiveValidationStartUtc = '',

        [string]$RollbackOriginPhase = '',

        [switch]$ClearActiveValidationStart
    )

    $StatePath = Join-Path $EvidenceRoot 'phase-state.json'
    $TempPath = "$StatePath.tmp"
    $PersistedValidationStart = ''
    $PersistedRollbackOrigin = ''
    $ExistingPhase = ''
    $ExistingOperation = ''
    if (Test-Path -LiteralPath $StatePath) {
        $ExistingState = Get-Content -LiteralPath $StatePath -Raw |
            ConvertFrom-Json
        $PersistedValidationStart = "$($ExistingState.ActiveValidationStartUtc)"
        $PersistedRollbackOrigin = "$($ExistingState.RollbackOriginPhase)"
        $ExistingPhase = "$($ExistingState.Phase)"
        $ExistingOperation = "$($ExistingState.Operation)"
    }

    $AllowedTransitions = @{
        Initialized = @('BaselineSealed')
        BaselineSealed = @('WorkloadsOff')
        WorkloadsOff = @('PlatformOff')
        PlatformOff = @('CsvsOff')
        CsvsOff = @('PoolOff')
        PoolOff = @('IntentSubmissionPending')
        IntentSubmissionPending = @('IntentSubmitted')
        IntentSubmitted = @('IntentConverged')
        IntentConverged = @('TargetReadbackVerified')
        TargetReadbackVerified = @('PoolOnline')
        PoolOnline = @('PlatformOnline')
        PlatformOnline = @('StorageHoldPassed')
        StorageHoldPassed = @('ActiveValidationStarted')
        RollbackApproved = @('WorkloadsOff')
        ActiveValidationStarted = @('ActiveAssertionsPassed')
        ActiveAssertionsPassed = @('ActiveValidationPassed')
        ActiveValidationPassed = @('Completed')
        Completed = @()
    }
    $RollbackOrigins = @(
        'TargetReadbackVerified',
        'PoolOnline',
        'PlatformOnline',
        'StorageHoldPassed',
        'ActiveValidationStarted',
        'ActiveAssertionsPassed',
        'ActiveValidationPassed'
    )
    if ([string]::IsNullOrWhiteSpace($ExistingPhase)) {
        if ($Phase -ne 'Initialized' -or $Operation -ne 'Forward') {
            throw "The first durable phase must be Forward/Initialized."
        }
    } elseif ($ExistingOperation -ne $Operation) {
        if (
            $ExistingOperation -ne 'Forward' -or
            $Operation -ne 'Rollback' -or
            $Phase -ne 'RollbackApproved' -or
            $ExistingPhase -notin $RollbackOrigins
        ) {
            throw (
                "Invalid operation transition from " +
                "'$ExistingOperation/$ExistingPhase' to '$Operation/$Phase'."
            )
        }
    } elseif (
        $Phase -ne $ExistingPhase -and
        $Phase -notin @($AllowedTransitions[$ExistingPhase])
    ) {
        throw "Invalid phase transition from '$ExistingPhase' to '$Phase'."
    }
    if (
        $ExistingOperation -eq 'Forward' -and
        $Operation -eq 'Rollback' -and
        $Phase -eq 'RollbackApproved'
    ) {
        if (
            $RollbackOriginPhase -ne $ExistingPhase -or
            $RollbackOriginPhase -notin $RollbackOrigins
        ) {
            throw "Rollback approval must persist the exact forward origin phase."
        }
        $PersistedRollbackOrigin = $RollbackOriginPhase
    } elseif ($Operation -eq 'Rollback') {
        if ([string]::IsNullOrWhiteSpace($PersistedRollbackOrigin)) {
            throw "Rollback state is missing its durable origin phase."
        }
        if (
            -not [string]::IsNullOrWhiteSpace($RollbackOriginPhase) -and
            $RollbackOriginPhase -ne $PersistedRollbackOrigin
        ) {
            throw "Rollback origin phase does not match durable state."
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($RollbackOriginPhase)) {
        throw "Forward operation state cannot carry a rollback origin phase."
    }
    if ($ClearActiveValidationStart) {
        $PersistedValidationStart = ''
    } elseif (-not [string]::IsNullOrWhiteSpace($ActiveValidationStartUtc)) {
        $PersistedValidationStart = [datetime]::Parse(
            $ActiveValidationStartUtc
        ).ToUniversalTime().ToString('o')
    }
    $NextState = [pscustomobject]@{
        ChangeId = $ChangeId
        Phase = $Phase
        UpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        TargetTransport = $TargetTransport
        Operation = $Operation
        DesiredTransport = $DesiredTransport
        DesiredTransportValue = $DesiredTransportValue
        ActiveValidationStartUtc = $PersistedValidationStart
        RollbackOriginPhase = $PersistedRollbackOrigin
    }
    try {
        $NextState | ConvertTo-Json |
            Set-Content -LiteralPath $TempPath -ErrorAction Stop
        Move-Item -LiteralPath $TempPath -Destination $StatePath `
            -Force -ErrorAction Stop

        $PersistedState = Get-Content -LiteralPath $StatePath -Raw `
            -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (
            "$($PersistedState.ChangeId)" -ne $ChangeId -or
            "$($PersistedState.Phase)" -ne $Phase -or
            "$($PersistedState.Operation)" -ne $Operation -or
            "$($PersistedState.DesiredTransport)" -ne $DesiredTransport -or
            [int]$PersistedState.DesiredTransportValue -ne
                $DesiredTransportValue -or
            "$($PersistedState.ActiveValidationStartUtc)" -ne
                $PersistedValidationStart -or
            "$($PersistedState.RollbackOriginPhase)" -ne
                $PersistedRollbackOrigin
        ) {
            throw "The persisted phase state does not match the requested transition."
        }
    }
    catch {
        Remove-Item -LiteralPath $TempPath -Force `
            -ErrorAction SilentlyContinue
        throw "Failed to persist phase '$Phase': $($_.Exception.Message)"
    }
}

function Write-MutationFailureEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$MutationError,

        [Parameter(Mandatory)]
        [scriptblock]$ReadAuthoritativeState,

        [Parameter(Mandatory)]
        [string]$StopGuidance
    )

    $CapturedUtc = (Get-Date).ToUniversalTime()
    $SafeOperationName = $OperationName -replace '[^A-Za-z0-9_-]', '-'
    $EvidencePath = Join-Path $EvidenceRoot (
        'mutation-failure-{0}-{1}.json' -f
        $SafeOperationName,
        $CapturedUtc.ToString('yyyyMMddTHHmmssfffZ')
    )

    $Phase = ''
    $PhaseReadError = ''
    try {
        $Phase = "$(
            (Get-Content -LiteralPath (
                Join-Path $EvidenceRoot 'phase-state.json'
            ) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).Phase
        )"
    }
    catch {
        $PhaseReadError = "$($_.Exception.Message)"
    }

    $StateReadError = ''
    try {
        $AuthoritativeState = @(& $ReadAuthoritativeState)
    }
    catch {
        $AuthoritativeState = @()
        $StateReadError = "$($_.Exception.Message)"
    }

    $FailureRecord = [pscustomobject]@{
        ChangeId = $ChangeId
        Operation = $Operation
        DesiredTransport = $DesiredTransport
        Phase = $Phase
        PhaseReadError = $PhaseReadError
        FailedOperation = $OperationName
        CapturedUtc = $CapturedUtc.ToString('o')
        MutationError = "$($MutationError.Exception.Message)"
        StateReadError = $StateReadError
        AuthoritativeState = $AuthoritativeState
    }

    try {
        $FailureRecord | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $EvidencePath -ErrorAction Stop
    }
    catch {
        throw (
            "$StopGuidance The mutation failed with " +
            "'$($MutationError.Exception.Message)', and failure evidence " +
            "could not be written: $($_.Exception.Message)"
        )
    }

    throw (
        "$StopGuidance The mutation failed with " +
        "'$($MutationError.Exception.Message)'. Authoritative post-failure " +
        "state was captured in '$EvidencePath'."
    )
}

Set-ChangePhase -Phase Initialized
}
finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
}
```

Expected result:

- `$TargetTransport` contains the approved target.
- `$EvidenceRoot` is on the local system drive.
- Every later command is captured in the transcript.

Stop if the evidence directory cannot be created or the transcript cannot start.

## Capture and seal the current configuration

### Step 1: Identify the storage intent and preserve explicit adapter overrides

**Action type:** [READ-ONLY]

```powershell
$StorageIntents = @(Get-NetIntent -ClusterName $Cluster.Name -ErrorAction Stop |
    Where-Object { $_.IsStorageIntentSet })

if ($StorageIntents.Count -ne 1) {
    throw "Expected exactly one storage Network ATC intent. Found $($StorageIntents.Count)."
}

$StorageIntent = $StorageIntents[0]
$AdapterNames = @($StorageIntent.NetAdapterNamesAsList | ForEach-Object {
    "$_".Trim()
} | Where-Object { $_ })

if ($AdapterNames.Count -lt 1) {
    throw "The storage intent has no adapter names."
}

$DefaultAdapterOverride = New-NetIntentAdapterPropertyOverrides
$ExplicitAdapterOverrides = [ordered]@{}
$CurrentAdapterOverride = $StorageIntent.AdapterAdvancedParametersOverride

if ($null -eq $CurrentAdapterOverride) {
    throw "The storage intent did not return AdapterAdvancedParametersOverride. Stop and recover the deployed override configuration before continuing."
}

foreach ($Property in @($CurrentAdapterOverride.PSObject.Properties | Sort-Object Name)) {
    if ($Property.Name -in @('InstanceId', 'ObjectVersion')) {
        continue
    }

    $DefaultProperty = $DefaultAdapterOverride.PSObject.Properties[$Property.Name]
    if ($null -eq $DefaultProperty) {
        throw (
            "Current override property '$($Property.Name)' cannot be " +
            "represented by New-NetIntentAdapterPropertyOverrides on this " +
            "node. Stop before the outage and engage Microsoft Support."
        )
    }

    $CurrentJson = $Property.Value | ConvertTo-Json -Depth 8 -Compress
    $DefaultJson = $DefaultProperty.Value | ConvertTo-Json -Depth 8 -Compress
    if ($CurrentJson -ne $DefaultJson) {
        $ExplicitAdapterOverrides[$Property.Name] = $Property.Value
    }
}

[pscustomobject]@{
    ChangeId = $ChangeId
    ClusterName = $Cluster.Name
    ClusterNodes = @($Nodes.Name)
    IntentName = $StorageIntent.IntentName
    AdapterNames = $AdapterNames
    ExplicitAdapterOverrides = $ExplicitAdapterOverrides
} | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath (
        Join-Path $EvidenceRoot 'network-atc-baseline.json'
    ) -ErrorAction Stop

$ExplicitAdapterOverrides
```

Expected result: the current non-default adapter overrides are saved before any mutation.

Stop if the storage intent is ambiguous, has no adapters, or the existing override object cannot be read. Do not replace an unknown override object with a new object that contains only `NetworkDirectTechnology`.

### Step 2: Verify target support and record the current transport

**Action type:** [READ-ONLY]

```powershell
$AdapterState = @(Invoke-Command -ComputerName $Nodes.Name `
    -ArgumentList ($AdapterNames -join ','), $TransportValues[$TargetTransport] `
    -ScriptBlock {
        param($AdapterCsv, $TargetValue)

        $Names = @($AdapterCsv -split ',' | ForEach-Object { $_.Trim() })
        foreach ($Name in $Names) {
            $Adapter = Get-NetAdapter -Name $Name -ErrorAction Stop
            $Rdma = Get-NetAdapterRdma -Name $Name -ErrorAction Stop
            $Transport = Get-NetAdapterAdvancedProperty -Name $Name `
                -RegistryKeyword '*NetworkDirectTechnology' -ErrorAction Stop

            [pscustomobject]@{
                Node = $env:COMPUTERNAME
                Adapter = $Name
                Status = "$($Adapter.Status)"
                InterfaceDescription = "$($Adapter.InterfaceDescription)"
                DriverProvider = "$($Adapter.DriverProvider)"
                DriverVersion = "$($Adapter.DriverVersion)"
                RdmaEnabled = [bool]$Rdma.Enabled
                CurrentTransportValue = [int]$Transport.RegistryValue[0]
                TargetSupported = @($Transport.ValidRegistryValues) -contains $TargetValue
                ValidTransportValues = @($Transport.ValidRegistryValues) -join ','
                ValidTransportNames = @($Transport.ValidDisplayValues) -join ','
            }
        }
    } -ErrorAction Stop)

$AdapterState |
    Sort-Object Node, Adapter |
    Tee-Object -FilePath (Join-Path $EvidenceRoot 'adapter-baseline.txt') |
    Format-Table -AutoSize

$CurrentValues = @($AdapterState.CurrentTransportValue | Sort-Object -Unique)
if ($CurrentValues.Count -ne 1) {
    throw "Storage adapters do not have one consistent source transport."
}

$SourceTransportValue = [int]$CurrentValues[0]
$SourceTransportEntries = @($TransportValues.GetEnumerator() | Where-Object {
    [int]$_.Value -eq $SourceTransportValue
})
if ($SourceTransportEntries.Count -ne 1) {
    throw "The source transport must be supported iWARP value 1 or RoCEv2 value 4."
}
$SourceTransport = "$($SourceTransportEntries[0].Key)"
if ($SourceTransportValue -eq $TransportValues[$TargetTransport]) {
    throw "The target transport is already configured. Do not run a no-op change."
}

$Unsupported = @($AdapterState | Where-Object {
    $_.Status -ne 'Up' -or -not $_.RdmaEnabled -or -not $_.TargetSupported
})
if ($Unsupported.Count -gt 0) {
    $Unsupported | Format-Table -AutoSize
    throw "At least one storage adapter is not ready for the target transport."
}
```

Expected result:

- Every storage adapter is `Up`.
- RDMA is enabled on every storage adapter.
- Every adapter reports the target value as supported.
- All adapters start on one source transport.

Stop if any node or adapter differs. Do not proceed with a partial or mixed-transport change.

### Step 3: Verify Network ATC, cluster, storage, and iWARP firewall state

**Action type:** [READ-ONLY]

```powershell
$IntentStatus = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
    -Name $StorageIntent.IntentName -ErrorAction Stop)
$IntentStatus |
    Format-Table Host, IntentName, ConfigurationStatus, ProvisioningStatus, RetryCount, Error

$BadIntentStatus = @($IntentStatus | Where-Object {
    "$($_.ConfigurationStatus)" -ne 'Success' -or
    "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
    [int]$_.RetryCount -gt 0 -or
    -not [string]::IsNullOrWhiteSpace("$($_.Error)")
})
Assert-IntentStatusCoverage -Status $IntentStatus `
    -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
if ($BadIntentStatus.Count -gt 0) {
    throw "Network ATC is not clean on every node."
}

$ClusterNodes = @(Get-ClusterNode -ErrorAction Stop)
$BadNodes = @($ClusterNodes | Where-Object State -ne 'Up')
$ClusterNodes | Format-Table Name, State
if ($BadNodes.Count -gt 0) {
    throw "Every cluster node must be Up before the change."
}

$SolutionUpdates = @(Get-SolutionUpdate -ErrorAction Stop)
$ActiveSolutionUpdates = @($SolutionUpdates | Where-Object {
    "$($_.State)" -in @('Downloading', 'Installing')
})
$ActiveUpdateRuns = @($SolutionUpdates | ForEach-Object {
    @($_ | Get-SolutionUpdateRun -ErrorAction Stop |
        Where-Object { "$($_.State)" -eq 'InProgress' })
})
if ($ActiveSolutionUpdates.Count -gt 0 -or $ActiveUpdateRuns.Count -gt 0) {
    throw "An Azure Local solution update is active. Do not begin this change."
}
$ActiveCauRuns = @(Get-CauRun -ClusterName $Cluster.Name -ErrorAction Stop)
if ($ActiveCauRuns.Count -gt 0) {
    throw "A Cluster-Aware Updating run is active. Do not begin this change."
}

$Quorum = Get-ClusterQuorum -ErrorAction Stop
$Quorum | Format-List *
if (-not [string]::IsNullOrWhiteSpace("$($Quorum.QuorumResource)")) {
    $QuorumResource = @(Get-ClusterResource `
        -Name "$($Quorum.QuorumResource)" -ErrorAction Stop)
    if (
        $QuorumResource.Count -ne 1 -or
        "$($QuorumResource[0].State)" -ne 'Online'
    ) {
        throw "The configured quorum witness resource is not Online."
    }
}

$HealthFaults = @(Get-HealthFault -ErrorAction Stop)
$HealthFaults
if ($HealthFaults.Count -gt 0) {
    throw "Active health faults require disposition before this change."
}

$NonPrimordialPools = @(Get-StoragePool -IsPrimordial $false `
    -ErrorAction Stop)
$NonPrimordialPools |
    Format-Table FriendlyName, HealthStatus, OperationalStatus, Size, AllocatedSize
if (
    $NonPrimordialPools.Count -ne 1 -or
    "$($NonPrimordialPools[0].HealthStatus)" -ne 'Healthy' -or
    "$($NonPrimordialPools[0].OperationalStatus)" -notmatch 'OK'
) {
    throw "Expected exactly one healthy non-primordial storage pool."
}

$VirtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
$VirtualDisks |
    Format-Table FriendlyName, UniqueId, IsManualAttach, HealthStatus, OperationalStatus
$BadVirtualDisks = @($VirtualDisks | Where-Object {
    "$($_.HealthStatus)" -ne 'Healthy' -or
    "$($_.OperationalStatus)" -notmatch 'OK'
})
if ($VirtualDisks.Count -lt 1 -or $BadVirtualDisks.Count -gt 0) {
    throw "Every virtual disk must be healthy and operational before the change."
}
$MissingVirtualDiskIds = @($VirtualDisks | Where-Object {
    [string]::IsNullOrWhiteSpace("$($_.UniqueId)")
})
$DuplicateVirtualDiskIds = @($VirtualDisks.UniqueId | Group-Object |
    Where-Object Count -ne 1)
if (
    $MissingVirtualDiskIds.Count -gt 0 -or
    $DuplicateVirtualDiskIds.Count -gt 0
) {
    throw "Every virtual disk must have one unique, nonempty UniqueId."
}

$StorageJobs = @(Get-StorageJob -ErrorAction Stop)
$StorageJobs
if ($StorageJobs.Count -gt 0) {
    throw "Active storage jobs block this change."
}

$Csvs = @(Get-ClusterSharedVolume -ErrorAction Stop)
$Csvs |
    Format-Table Name, State, OwnerNode
if (
    $Csvs.Count -lt 1 -or
    @($Csvs | Where-Object State -ne 'Online').Count -gt 0
) {
    throw "Every CSV must be Online before the change."
}

if ($SourceTransport -eq 'iWARP' -or $TargetTransport -eq 'iWARP') {
    $FirewallState = @(Invoke-Command -ComputerName $Nodes.Name -ScriptBlock {
        $Rules = @(Get-NetFirewallRule -Name 'FPSSMBD-iWARP-In-TCP' `
            -ErrorAction SilentlyContinue)
        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            Count = $Rules.Count
            Enabled = @($Rules.Enabled | Sort-Object -Unique) -join ','
            Direction = @($Rules.Direction | Sort-Object -Unique) -join ','
            Action = @($Rules.Action | Sort-Object -Unique) -join ','
        }
    } -ErrorAction Stop)

    $FirewallState | Format-Table -AutoSize
    $BadFirewall = @($FirewallState | Where-Object {
        $_.Count -lt 1 -or $_.Enabled -ne 'True' -or
        $_.Direction -ne 'Inbound' -or $_.Action -ne 'Allow'
    })
    if ($BadFirewall.Count -gt 0) {
        throw "The built-in inbound iWARP firewall rule is not usable on every node."
    }
}
```

Expected result:

- Every node is `Up`.
- No solution-update or Cluster-Aware Updating run is active.
- Network ATC is successful and completed with no error or retry debt.
- Quorum is healthy.
- No active health fault blocks the change.
- One non-primordial pool and all virtual disks are healthy.
- `Get-StorageJob` returns no rows.
- Every CSV is online.
- When either the source or target is iWARP, the built-in firewall rule is present and usable on every node.

Save all output under `$EvidenceRoot`. Stop on any deviation.

## Seal storage and platform resource identities

**Action type:** [READ-ONLY]

The following inventory prevents friendly-name drift or a similarly named resource from becoming the mutation target.

```powershell
$CsvInventory = @(Get-ClusterSharedVolume -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object {
        $Csv = $_
        $EscapedName = "$($Csv.Name)".Replace("'", "''")
        $CimResources = @(Get-CimInstance -Namespace root/MSCluster `
            -ClassName MSCluster_Resource `
            -Filter "Name='$EscapedName'" -ErrorAction Stop)
        if ($CimResources.Count -ne 1) {
            throw "Expected one MSCluster resource for CSV '$($Csv.Name)'. Found $($CimResources.Count)."
        }

        $Info = @($Csv.SharedVolumeInfo) | Select-Object -First 1
        $Partition = $Info.Partition
        $Role = if ("$($Info.FriendlyVolumeName)" -match '(?i)Infrastructure') {
            'Infrastructure'
        } else {
            'Workload'
        }
        $VolumeLeaf = Split-Path -Path "$($Info.FriendlyVolumeName)" -Leaf
        if ([string]::IsNullOrWhiteSpace($VolumeLeaf)) {
            throw "CSV '$($Csv.Name)' has no usable volume leaf name."
        }
        $CsvVirtualDisk = @(Get-VirtualDisk -FriendlyName $VolumeLeaf `
            -ErrorAction Stop)
        if ($CsvVirtualDisk.Count -ne 1) {
            throw "CSV '$($Csv.Name)' must map to exactly one virtual disk named '$VolumeLeaf'."
        }
        if ([string]::IsNullOrWhiteSpace("$($CsvVirtualDisk[0].UniqueId)")) {
            throw "CSV '$($Csv.Name)' has no usable virtual-disk UniqueId."
        }

        [pscustomobject]@{
            Name = "$($Csv.Name)"
            State = "$($Csv.State)"
            OwnerNode = "$($Csv.OwnerNode)"
            FriendlyVolumeName = "$($Info.FriendlyVolumeName)"
            PartitionName = "$($Partition.Name)"
            VirtualDiskUniqueId = "$($CsvVirtualDisk[0].UniqueId)"
            Role = $Role
            CimType = "$($CimResources[0].Type)"
            CimOwnerGroup = "$($CimResources[0].OwnerGroup)"
        }
    })

$InfrastructureCsv = @($CsvInventory | Where-Object Role -eq 'Infrastructure')
if ($InfrastructureCsv.Count -ne 1) {
    $CsvInventory | Format-Table -AutoSize
    throw "Expected exactly one infrastructure CSV. Stop and classify the CSVs explicitly."
}

$PoolResources = @(Get-ClusterResource -ErrorAction Stop |
    Where-Object { "$($_.ResourceType)" -eq 'Storage Pool' })
if ($PoolResources.Count -ne 1) {
    throw "Expected exactly one clustered Storage Pool resource. Found $($PoolResources.Count)."
}

$MocResources = @(Get-ClusterResource -ErrorAction Stop | Where-Object {
    "$($_.Name)" -match '(?i)^MOC Cloud Agent( Service)?$'
})
if ($MocResources.Count -ne 1) {
    throw "Expected exactly one MOC Cloud Agent clustered resource. Found $($MocResources.Count)."
}

$ClusteredVms = @(Get-ClusterGroup -ErrorAction Stop |
    Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' } |
    Sort-Object Name |
    ForEach-Object {
        $Group = $_
        $VmResource = @($Group | Get-ClusterResource -ErrorAction Stop |
            Where-Object { "$($_.ResourceType)" -eq 'Virtual Machine' })
        if ($VmResource.Count -ne 1) {
            throw "Expected one Virtual Machine resource in '$($Group.Name)'."
        }

        $VmIdParameter = @(Get-ClusterParameter -InputObject $VmResource[0] `
            -Name VmId -ErrorAction Stop)
        if ($VmIdParameter.Count -ne 1) {
            throw "Expected one VmId parameter in '$($Group.Name)'."
        }
        $VmId = "$($VmIdParameter[0].Value)"

        $HyperV = Invoke-Command -ComputerName "$($Group.OwnerNode)" `
            -ArgumentList $VmId -ScriptBlock {
                param($SealedVmId)
                $Vm = Get-VM -Id ([guid]$SealedVmId) -ErrorAction Stop
                [pscustomobject]@{
                    Id = "$($Vm.VMId)"
                    Name = "$($Vm.Name)"
                    State = "$($Vm.State)"
                    ConfigurationLocation = "$($Vm.ConfigurationLocation)"
                    DiskPaths = @(Get-VMHardDiskDrive -VM $Vm -ErrorAction Stop |
                        Select-Object -ExpandProperty Path)
                }
            } -ErrorAction Stop

        [pscustomobject]@{
            GroupName = "$($Group.Name)"
            GroupId = "$($Group.Id)"
            GroupState = "$($Group.State)"
            OwnerNode = "$($Group.OwnerNode)"
            VmId = "$($HyperV.Id)"
            VmName = "$($HyperV.Name)"
            VmState = "$($HyperV.State)"
            ConfigurationLocation = "$($HyperV.ConfigurationLocation)"
            DiskPaths = @($HyperV.DiskPaths)
        }
    })

$InfrastructureRoot = "$($InfrastructureCsv[0].FriendlyVolumeName)".TrimEnd('\') + '\'
$ControlPlaneVms = @($ClusteredVms | Where-Object {
    "$($_.ConfigurationLocation)" -like "$InfrastructureRoot*" -or
    @($_.DiskPaths | Where-Object { "$_" -like "$InfrastructureRoot*" }).Count -gt 0
})
if ($ControlPlaneVms.Count -ne 1) {
    $ClusteredVms | Format-Table GroupName, VmName, VmState, ConfigurationLocation
    throw "Expected exactly one clustered appliance VM on the infrastructure CSV. Stop and engage Microsoft Support."
}

$VirtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
$ManualAttachVirtualDisks = @($VirtualDisks | Where-Object {
    [bool]$_.IsManualAttach
})
if ($ManualAttachVirtualDisks.Count -gt 0 -and
    @($CsvInventory | Where-Object {
        [string]::IsNullOrWhiteSpace("$($_.VirtualDiskUniqueId)")
    }).Count -gt 0) {
    throw "A CSV virtual-disk identity is missing. Manual-attach resources cannot be classified safely."
}

$CsvVirtualDiskIds = @($CsvInventory.VirtualDiskUniqueId | Where-Object {
    -not [string]::IsNullOrWhiteSpace("$_")
})
$PhysicalDiskClusterResources = @(Get-ClusterResource -ErrorAction Stop |
    Where-Object { "$($_.ResourceType)" -eq 'Physical Disk' } |
    ForEach-Object {
        $Resource = $_
        $IdentityValues = @(Get-ClusterParameter -InputObject $Resource `
            -ErrorAction SilentlyContinue | ForEach-Object {
                "$($_.Value)"
            } | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            })
        [pscustomobject]@{
            Resource = $Resource
            IdentityValues = $IdentityValues
        }
    })

$AuxiliaryVirtualDiskResources = @($ManualAttachVirtualDisks |
    Where-Object { "$($_.UniqueId)" -notin $CsvVirtualDiskIds } |
    ForEach-Object {
        $VirtualDisk = $_
        $NormalizedVirtualDiskId = (
            "$($VirtualDisk.UniqueId)" -replace '[^0-9A-Fa-f]', ''
        ).ToLowerInvariant()
        $ResourceMatches = @($PhysicalDiskClusterResources | Where-Object {
            $Entry = $_
            "$($Entry.Resource.Name)" -eq "Cluster Virtual Disk ($($VirtualDisk.FriendlyName))" -or
            @($Entry.IdentityValues | Where-Object {
                $NormalizedValue = (
                    "$_" -replace '[^0-9A-Fa-f]', ''
                ).ToLowerInvariant()
                -not [string]::IsNullOrWhiteSpace($NormalizedVirtualDiskId) -and
                $NormalizedValue -eq $NormalizedVirtualDiskId
            }).Count -gt 0
        })
        if ($ResourceMatches.Count -ne 1) {
            throw (
                "Expected one clustered Physical Disk resource for manual-attach virtual disk " +
                "'$($VirtualDisk.FriendlyName)' with UniqueId '$($VirtualDisk.UniqueId)'. " +
                "Found $($ResourceMatches.Count)."
            )
        }

        $Resource = $ResourceMatches[0].Resource
        [pscustomobject]@{
            VirtualDiskName = "$($VirtualDisk.FriendlyName)"
            VirtualDiskUniqueId = "$($VirtualDisk.UniqueId)"
            ResourceName = "$($Resource.Name)"
            ResourceId = "$($Resource.Id)"
            ResourceType = "$($Resource.ResourceType)"
            OwnerGroup = "$($Resource.OwnerGroup)"
            OwnerNode = "$($Resource.OwnerNode)"
            OriginalState = "$($Resource.State)"
        }
    })
if (@($AuxiliaryVirtualDiskResources | Where-Object {
    "$($_.OriginalState)" -ne 'Online'
}).Count -gt 0) {
    $AuxiliaryVirtualDiskResources |
        Format-Table VirtualDiskName, ResourceName, OriginalState
    throw "Every auxiliary manual-attach resource must be Online before the change."
}

$ResourceManifest = [ordered]@{
    ChangeId = $ChangeId
    Cluster = "$($Cluster.Name)"
    Csvs = $CsvInventory
    VirtualDisks = @($VirtualDisks | ForEach-Object {
        [ordered]@{
            FriendlyName = "$($_.FriendlyName)"
            UniqueId = "$($_.UniqueId)"
            IsManualAttach = [bool]$_.IsManualAttach
        }
    })
    Pool = [ordered]@{
        Name = "$($PoolResources[0].Name)"
        Id = "$($PoolResources[0].Id)"
        ResourceType = "$($PoolResources[0].ResourceType)"
        OwnerGroup = "$($PoolResources[0].OwnerGroup)"
    }
    Moc = [ordered]@{
        Name = "$($MocResources[0].Name)"
        Id = "$($MocResources[0].Id)"
        ResourceType = "$($MocResources[0].ResourceType)"
        OwnerGroup = "$($MocResources[0].OwnerGroup)"
    }
    ControlPlaneVm = $ControlPlaneVms[0]
    ClusteredVms = $ClusteredVms
    AuxiliaryVirtualDiskResources = $AuxiliaryVirtualDiskResources
    SourceTransport = $SourceTransport
    SourceTransportValue = $SourceTransportValue
    TargetTransport = $TargetTransport
    TargetTransportValue = $TransportValues[$TargetTransport]
}

$ResourceManifest | ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath (
        Join-Path $EvidenceRoot 'resource-manifest.json'
    ) -ErrorAction Stop

Get-FileHash -Algorithm SHA256 -LiteralPath @(
    (Join-Path $EvidenceRoot 'network-atc-baseline.json'),
    (Join-Path $EvidenceRoot 'resource-manifest.json')
) -ErrorAction Stop | Select-Object Path, Algorithm, Hash |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (
        Join-Path $EvidenceRoot 'baseline-hashes.json'
    ) -ErrorAction Stop

Set-ChangePhase -Phase BaselineSealed
```

Expected result: one sealed inventory records every CSV, the pool, MOC, the appliance VM, all clustered VMs, any non-CSV manual-attach virtual disk and exact clustered resource, and both transport values.

Stop if any identity is ambiguous. Do not select the appliance VM or infrastructure CSV from a display name alone.

## Resume safely after a PowerShell, remoting, or operator-session loss

Do not restart the article from the beginning and do not repeat the last state-changing command blindly. Open an elevated Windows PowerShell session on a cluster node, load the sealed state, inspect the last completed phase, and re-read the authoritative resource state.

```powershell
$PreviousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Stop'

$ActivePointer = Join-Path $env:SystemDrive `
    'AzureLocal-RdmaTransport-Active.txt'
if (-not (Test-Path -LiteralPath $ActivePointer)) {
    throw "No active RDMA transport change pointer exists."
}

$EvidenceRoot = "$(Get-Content -LiteralPath $ActivePointer -Raw)".Trim()
if (-not (Test-Path -LiteralPath $EvidenceRoot)) {
    throw "The active evidence directory '$EvidenceRoot' does not exist."
}
Start-Transcript -Path (Join-Path $EvidenceRoot 'operator-transcript.txt') `
    -Append -ErrorAction Stop

$PhaseState = Get-Content -LiteralPath (Join-Path $EvidenceRoot 'phase-state.json') `
    -Raw | ConvertFrom-Json
$ChangeId = "$($PhaseState.ChangeId)"
$TargetTransport = "$($PhaseState.TargetTransport)"
$Operation = "$($PhaseState.Operation)"
$DesiredTransport = "$($PhaseState.DesiredTransport)"
$DesiredTransportValue = [int]$PhaseState.DesiredTransportValue
$TransportValues = @{ iWARP = 1; RoCEv2 = 4 }
if (
    $ChangeId -notmatch '^\d{8}-\d{6}$' -or
    $TargetTransport -notin $TransportValues.Keys -or
    $Operation -notin @('Forward', 'Rollback') -or
    $DesiredTransport -notin $TransportValues.Keys -or
    $DesiredTransportValue -ne [int]$TransportValues[$DesiredTransport]
) {
    throw "The phase state contains an invalid change identity, operation, or desired transport."
}
if ((Split-Path -Path $EvidenceRoot -Leaf) -ne "AzureLocal-RdmaTransport-$ChangeId") {
    throw "The active pointer does not match the phase-state change identity."
}

$ValidPhases = @(
    'Initialized',
    'BaselineSealed',
    'WorkloadsOff',
    'PlatformOff',
    'CsvsOff',
    'PoolOff',
    'IntentSubmissionPending',
    'IntentSubmitted',
    'IntentConverged',
    'TargetReadbackVerified',
    'PoolOnline',
    'PlatformOnline',
    'StorageHoldPassed',
    'RollbackApproved',
    'ActiveValidationStarted',
    'ActiveAssertionsPassed',
    'ActiveValidationPassed',
    'Completed'
)
if ("$($PhaseState.Phase)" -notin $ValidPhases) {
    throw "The phase state contains an unknown checkpoint."
}
$RollbackOrigins = @(
    'TargetReadbackVerified',
    'PoolOnline',
    'PlatformOnline',
    'StorageHoldPassed',
    'ActiveValidationStarted',
    'ActiveAssertionsPassed',
    'ActiveValidationPassed'
)
$RollbackOriginPhase = "$($PhaseState.RollbackOriginPhase)"
if (
    (
        $Operation -eq 'Rollback' -and
        $RollbackOriginPhase -notin $RollbackOrigins
    ) -or
    (
        $Operation -eq 'Forward' -and
        -not [string]::IsNullOrWhiteSpace($RollbackOriginPhase)
    )
) {
    throw "The phase state contains an invalid rollback origin."
}

$Cluster = Get-Cluster -ErrorAction Stop
$Nodes = @(Get-ClusterNode -ErrorAction Stop | Sort-Object Name)

function Assert-IntentStatusCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Status,

        [Parameter(Mandatory)]
        [object[]]$ClusterNodes,

        [Parameter(Mandatory)]
        [string]$IntentName
    )

    $ExpectedHosts = @($ClusterNodes | ForEach-Object {
        "$($_.Name)".Split('.')[0].ToUpperInvariant()
    } | Sort-Object -Unique)
    $ActualRows = @($Status | ForEach-Object {
        [pscustomobject]@{
            Host = "$($_.Host)".Split('.')[0].ToUpperInvariant()
            IntentName = "$($_.IntentName)"
        }
    })
    $ActualHosts = @($ActualRows.Host)
    $MissingHosts = @($ExpectedHosts | Where-Object { $_ -notin $ActualHosts })
    $UnknownHosts = @($ActualHosts | Where-Object { $_ -notin $ExpectedHosts })
    $DuplicateHosts = @($ActualHosts | Group-Object | Where-Object Count -ne 1)
    $WrongIntent = @($ActualRows | Where-Object IntentName -ne $IntentName)

    if (
        $Status.Count -ne $ExpectedHosts.Count -or
        $MissingHosts.Count -gt 0 -or
        $UnknownHosts.Count -gt 0 -or
        $DuplicateHosts.Count -gt 0 -or
        $WrongIntent.Count -gt 0
    ) {
        throw (
            "Network ATC status coverage is incomplete or ambiguous. " +
            "Expected hosts: $($ExpectedHosts -join ','); " +
            "returned hosts: $($ActualHosts -join ',')."
        )
    }
}

if ("$($PhaseState.Phase)" -eq 'Initialized') {
    Write-Warning (
        "Only the Initialized checkpoint exists. Re-run every baseline and " +
        "identity-sealing block before any state-changing step."
    )
} else {
    $ExpectedHashes = @(Get-Content -LiteralPath `
        (Join-Path $EvidenceRoot 'baseline-hashes.json') -Raw | ConvertFrom-Json)
    foreach ($FileName in @('network-atc-baseline.json', 'resource-manifest.json')) {
        $Expected = @($ExpectedHashes | Where-Object {
            (Split-Path -Path "$($_.Path)" -Leaf) -eq $FileName
        })
        if ($Expected.Count -ne 1) {
            throw "Expected exactly one sealed hash for '$FileName'."
        }

        $Actual = Get-FileHash -Algorithm SHA256 `
            -LiteralPath (Join-Path $EvidenceRoot $FileName)
        if ("$($Actual.Hash)" -ne "$($Expected[0].Hash)") {
            throw "Integrity check failed for '$FileName'. Stop and recover the original evidence package."
        }
    }

    $ResourceManifest = Get-Content -LiteralPath `
        (Join-Path $EvidenceRoot 'resource-manifest.json') -Raw | ConvertFrom-Json
    $AtcBaseline = Get-Content -LiteralPath `
        (Join-Path $EvidenceRoot 'network-atc-baseline.json') -Raw | ConvertFrom-Json

    $SealedNodes = @($AtcBaseline.ClusterNodes | ForEach-Object {
        "$_".Split('.')[0].ToUpperInvariant()
    } | Sort-Object -Unique)
    $CurrentNodes = @($Nodes.Name | ForEach-Object {
        "$_".Split('.')[0].ToUpperInvariant()
    } | Sort-Object -Unique)
    if (
        $SealedNodes.Count -ne $CurrentNodes.Count -or
        @($SealedNodes | Where-Object { $_ -notin $CurrentNodes }).Count -gt 0 -or
        @($CurrentNodes | Where-Object { $_ -notin $SealedNodes }).Count -gt 0
    ) {
        throw "Current cluster membership does not match the sealed node inventory."
    }

    $ExpectedTargetValue = [int]$TransportValues[$TargetTransport]
    $SourceTransport = "$($ResourceManifest.SourceTransport)"
    $SourceTransportValue = [int]$ResourceManifest.SourceTransportValue
    if (
        $SourceTransport -notin $TransportValues.Keys -or
        $SourceTransportValue -ne [int]$TransportValues[$SourceTransport]
    ) {
        throw "The sealed source transport is unsupported or internally inconsistent."
    }
    $ExpectedDesiredTransport = if ($Operation -eq 'Forward') {
        $TargetTransport
    } else {
        $SourceTransport
    }
    $ExpectedDesiredValue = [int]$TransportValues[$ExpectedDesiredTransport]
    if (
        "$($AtcBaseline.ChangeId)" -ne $ChangeId -or
        "$($ResourceManifest.ChangeId)" -ne $ChangeId -or
        "$($AtcBaseline.ClusterName)" -ine "$($Cluster.Name)" -or
        "$($ResourceManifest.Cluster)" -ine "$($Cluster.Name)" -or
        "$($ResourceManifest.TargetTransport)" -ne $TargetTransport -or
        [int]$ResourceManifest.TargetTransportValue -ne $ExpectedTargetValue -or
        $DesiredTransport -ne $ExpectedDesiredTransport -or
        $DesiredTransportValue -ne $ExpectedDesiredValue
    ) {
        throw "The active cluster, change identity, operation, desired transport, and sealed manifests do not agree."
    }

    $StorageIntent = @(Get-NetIntent -ClusterName $Cluster.Name -ErrorAction Stop |
        Where-Object { "$($_.IntentName)" -eq "$($AtcBaseline.IntentName)" })
    if ($StorageIntent.Count -ne 1) {
        throw "The sealed storage intent no longer resolves uniquely."
    }
    $StorageIntent = $StorageIntent[0]
    $AdapterNames = @($AtcBaseline.AdapterNames)
    $ExplicitAdapterOverrides = [ordered]@{}
    foreach ($Property in $AtcBaseline.ExplicitAdapterOverrides.PSObject.Properties) {
        $ExplicitAdapterOverrides[$Property.Name] = $Property.Value
    }

    $Pool = $ResourceManifest.Pool
    $Moc = $ResourceManifest.Moc
    $ControlPlaneEntry = $ResourceManifest.ControlPlaneVm
    $WorkloadCsvs = @($ResourceManifest.Csvs | Where-Object Role -eq 'Workload')
    $InfrastructureCsv = @($ResourceManifest.Csvs | Where-Object Role -eq 'Infrastructure')
    $AuxiliaryVirtualDiskResources = @($ResourceManifest.AuxiliaryVirtualDiskResources)
    $ExpectedVmIdentityPairs = @($ResourceManifest.ClusteredVms |
        ForEach-Object {
            "$($_.GroupId)|$($_.GroupName)|$($_.VmId)"
        })
    $ExpectedAdapterPairs = @(
        foreach ($Node in $Nodes) {
            $NodeName = "$($Node.Name)".Split('.')[0].ToUpperInvariant()
            foreach ($AdapterName in $AdapterNames) {
                "$NodeName|$("$AdapterName".Trim().ToUpperInvariant())"
            }
        }
    )

    if ("$($PhaseState.Phase)" -in @(
        'ActiveValidationStarted',
        'ActiveAssertionsPassed',
        'ActiveValidationPassed'
    )) {
        if ([string]::IsNullOrWhiteSpace(
            "$($PhaseState.ActiveValidationStartUtc)"
        )) {
            throw "The active-validation start time is missing from phase state."
        }
        $ActiveValidationStartUtc = [datetime]::Parse(
            "$($PhaseState.ActiveValidationStartUtc)"
        ).ToUniversalTime()
        $ActiveValidationStartUtcPath = Join-Path $EvidenceRoot `
            "active-validation-$Operation-start-utc.txt"
        if (Test-Path -LiteralPath $ActiveValidationStartUtcPath) {
            $ArtifactStartUtc = [datetime]::Parse(
                "$(Get-Content -LiteralPath $ActiveValidationStartUtcPath -Raw)"
            ).ToUniversalTime()
            if ($ArtifactStartUtc -ne $ActiveValidationStartUtc) {
                throw "The active-validation artifact does not match phase state."
            }
        } else {
            $ActiveValidationStartUtc.ToString('o') |
                Set-Content -LiteralPath $ActiveValidationStartUtcPath `
                    -ErrorAction Stop
        }
    }
}

function Set-ChangePhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'Initialized',
            'BaselineSealed',
            'WorkloadsOff',
            'PlatformOff',
            'CsvsOff',
            'PoolOff',
            'IntentSubmissionPending',
            'IntentSubmitted',
            'IntentConverged',
            'TargetReadbackVerified',
            'PoolOnline',
            'PlatformOnline',
            'StorageHoldPassed',
            'RollbackApproved',
            'ActiveValidationStarted',
            'ActiveAssertionsPassed',
            'ActiveValidationPassed',
            'Completed'
        )]
        [string]$Phase,

        [string]$ActiveValidationStartUtc = '',

        [string]$RollbackOriginPhase = '',

        [switch]$ClearActiveValidationStart
    )

    $StatePath = Join-Path $EvidenceRoot 'phase-state.json'
    $TempPath = "$StatePath.tmp"
    $PersistedValidationStart = ''
    $PersistedRollbackOrigin = ''
    $ExistingPhase = ''
    $ExistingOperation = ''
    if (Test-Path -LiteralPath $StatePath) {
        $ExistingState = Get-Content -LiteralPath $StatePath -Raw |
            ConvertFrom-Json
        $PersistedValidationStart = "$($ExistingState.ActiveValidationStartUtc)"
        $PersistedRollbackOrigin = "$($ExistingState.RollbackOriginPhase)"
        $ExistingPhase = "$($ExistingState.Phase)"
        $ExistingOperation = "$($ExistingState.Operation)"
    }

    $AllowedTransitions = @{
        Initialized = @('BaselineSealed')
        BaselineSealed = @('WorkloadsOff')
        WorkloadsOff = @('PlatformOff')
        PlatformOff = @('CsvsOff')
        CsvsOff = @('PoolOff')
        PoolOff = @('IntentSubmissionPending')
        IntentSubmissionPending = @('IntentSubmitted')
        IntentSubmitted = @('IntentConverged')
        IntentConverged = @('TargetReadbackVerified')
        TargetReadbackVerified = @('PoolOnline')
        PoolOnline = @('PlatformOnline')
        PlatformOnline = @('StorageHoldPassed')
        StorageHoldPassed = @('ActiveValidationStarted')
        RollbackApproved = @('WorkloadsOff')
        ActiveValidationStarted = @('ActiveAssertionsPassed')
        ActiveAssertionsPassed = @('ActiveValidationPassed')
        ActiveValidationPassed = @('Completed')
        Completed = @()
    }
    $RollbackOrigins = @(
        'TargetReadbackVerified',
        'PoolOnline',
        'PlatformOnline',
        'StorageHoldPassed',
        'ActiveValidationStarted',
        'ActiveAssertionsPassed',
        'ActiveValidationPassed'
    )
    if ([string]::IsNullOrWhiteSpace($ExistingPhase)) {
        if ($Phase -ne 'Initialized' -or $Operation -ne 'Forward') {
            throw "The first durable phase must be Forward/Initialized."
        }
    } elseif ($ExistingOperation -ne $Operation) {
        if (
            $ExistingOperation -ne 'Forward' -or
            $Operation -ne 'Rollback' -or
            $Phase -ne 'RollbackApproved' -or
            $ExistingPhase -notin $RollbackOrigins
        ) {
            throw (
                "Invalid operation transition from " +
                "'$ExistingOperation/$ExistingPhase' to '$Operation/$Phase'."
            )
        }
    } elseif (
        $Phase -ne $ExistingPhase -and
        $Phase -notin @($AllowedTransitions[$ExistingPhase])
    ) {
        throw "Invalid phase transition from '$ExistingPhase' to '$Phase'."
    }
    if (
        $ExistingOperation -eq 'Forward' -and
        $Operation -eq 'Rollback' -and
        $Phase -eq 'RollbackApproved'
    ) {
        if (
            $RollbackOriginPhase -ne $ExistingPhase -or
            $RollbackOriginPhase -notin $RollbackOrigins
        ) {
            throw "Rollback approval must persist the exact forward origin phase."
        }
        $PersistedRollbackOrigin = $RollbackOriginPhase
    } elseif ($Operation -eq 'Rollback') {
        if ([string]::IsNullOrWhiteSpace($PersistedRollbackOrigin)) {
            throw "Rollback state is missing its durable origin phase."
        }
        if (
            -not [string]::IsNullOrWhiteSpace($RollbackOriginPhase) -and
            $RollbackOriginPhase -ne $PersistedRollbackOrigin
        ) {
            throw "Rollback origin phase does not match durable state."
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($RollbackOriginPhase)) {
        throw "Forward operation state cannot carry a rollback origin phase."
    }
    if ($ClearActiveValidationStart) {
        $PersistedValidationStart = ''
    } elseif (-not [string]::IsNullOrWhiteSpace($ActiveValidationStartUtc)) {
        $PersistedValidationStart = [datetime]::Parse(
            $ActiveValidationStartUtc
        ).ToUniversalTime().ToString('o')
    }
    $NextState = [pscustomobject]@{
        ChangeId = $ChangeId
        Phase = $Phase
        UpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        TargetTransport = $TargetTransport
        Operation = $Operation
        DesiredTransport = $DesiredTransport
        DesiredTransportValue = $DesiredTransportValue
        ActiveValidationStartUtc = $PersistedValidationStart
        RollbackOriginPhase = $PersistedRollbackOrigin
    }
    try {
        $NextState | ConvertTo-Json |
            Set-Content -LiteralPath $TempPath -ErrorAction Stop
        Move-Item -LiteralPath $TempPath -Destination $StatePath `
            -Force -ErrorAction Stop

        $PersistedState = Get-Content -LiteralPath $StatePath -Raw `
            -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (
            "$($PersistedState.ChangeId)" -ne $ChangeId -or
            "$($PersistedState.Phase)" -ne $Phase -or
            "$($PersistedState.Operation)" -ne $Operation -or
            "$($PersistedState.DesiredTransport)" -ne $DesiredTransport -or
            [int]$PersistedState.DesiredTransportValue -ne
                $DesiredTransportValue -or
            "$($PersistedState.ActiveValidationStartUtc)" -ne
                $PersistedValidationStart -or
            "$($PersistedState.RollbackOriginPhase)" -ne
                $PersistedRollbackOrigin
        ) {
            throw "The persisted phase state does not match the requested transition."
        }
    }
    catch {
        Remove-Item -LiteralPath $TempPath -Force `
            -ErrorAction SilentlyContinue
        throw "Failed to persist phase '$Phase': $($_.Exception.Message)"
    }
}

$PhaseState | Format-List *
}
finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
}
```

Re-run only the read-only verification for the next phase. The named phase means the previous phase completed, not that the current live state is still healthy.

Re-run any function-definition block needed by the next phase, such as `Set-SealedCsvState`. Defining the function does not change cluster state.

`Operation` identifies whether the current run is the approved forward change or a rollback. `DesiredTransport` and `DesiredTransportValue` are the only transport values used by the mutation, readback, and final-validation blocks. Do not overwrite them manually after resume.

| Last completed phase | Required next action |
| --- | --- |
| `Initialized` | Re-run all baseline and identity checks. Do not assume that the manifests are complete. |
| `BaselineSealed` | Re-read VM states, then begin or continue workload shutdown. |
| `WorkloadsOff` | Confirm customer VMs remain `Off`, then quiesce the appliance and MOC. |
| `PlatformOff` | Confirm appliance and MOC state, then offline CSVs. |
| `CsvsOff` | Confirm every CSV is `Offline`, then offline the sealed pool. |
| `PoolOff` | Confirm pool and CSV state, then build and preview the Network ATC override. |
| `IntentSubmissionPending` | Inspect the live intent override and status. Do not resubmit. If acceptance cannot be proven, stop and contact Microsoft Support. |
| `IntentSubmitted` | Query Network ATC status. Do not resubmit. |
| `IntentConverged` | Verify every adapter has the persisted desired transport while storage remains offline. |
| `TargetReadbackVerified` | Begin dependency-ordered platform restoration. |
| `PoolOnline` | Confirm storage health, then restore infrastructure CSV, MOC, and the appliance. |
| `PlatformOnline` | Complete the continuous storage clean hold. |
| `StorageHoldPassed` | Return workload startup to the application owner. |
| `RollbackApproved` | Continue rollback quiescence. Do not resume the forward target. |
| `ActiveValidationStarted` | Continue representative load and capture the application-owner attestation. Do not replace the sealed start time. |
| `ActiveAssertionsPassed` | Complete the final event review and continuous clean hold. |
| `ActiveValidationPassed` | Close the transcript and active pointer. |
| `Completed` | Finish idempotent transcript and active-pointer cleanup. No cluster state-changing action remains. |

If the live resource state does not match the checkpoint, stop and reconcile the discrepancy before continuing or rolling back.

### Define the mutation-failure evidence helper

Re-run this function definition after any session loss before resuming a
state-changing step. It records the mutation error and an authoritative
post-failure state read before it throws the step's stop guidance.

```powershell
function Write-MutationFailureEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$MutationError,

        [Parameter(Mandatory)]
        [scriptblock]$ReadAuthoritativeState,

        [Parameter(Mandatory)]
        [string]$StopGuidance
    )

    $CapturedUtc = (Get-Date).ToUniversalTime()
    $SafeOperationName = $OperationName -replace '[^A-Za-z0-9_-]', '-'
    $EvidencePath = Join-Path $EvidenceRoot (
        'mutation-failure-{0}-{1}.json' -f
        $SafeOperationName,
        $CapturedUtc.ToString('yyyyMMddTHHmmssfffZ')
    )

    $Phase = ''
    $PhaseReadError = ''
    try {
        $Phase = "$(
            (Get-Content -LiteralPath (
                Join-Path $EvidenceRoot 'phase-state.json'
            ) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).Phase
        )"
    }
    catch {
        $PhaseReadError = "$($_.Exception.Message)"
    }

    $StateReadError = ''
    try {
        $AuthoritativeState = @(& $ReadAuthoritativeState)
    }
    catch {
        $AuthoritativeState = @()
        $StateReadError = "$($_.Exception.Message)"
    }

    $FailureRecord = [pscustomobject]@{
        ChangeId = $ChangeId
        Operation = $Operation
        DesiredTransport = $DesiredTransport
        Phase = $Phase
        PhaseReadError = $PhaseReadError
        FailedOperation = $OperationName
        CapturedUtc = $CapturedUtc.ToString('o')
        MutationError = "$($MutationError.Exception.Message)"
        StateReadError = $StateReadError
        AuthoritativeState = $AuthoritativeState
    }

    try {
        $FailureRecord | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $EvidencePath -ErrorAction Stop
    }
    catch {
        throw (
            "$StopGuidance The mutation failed with " +
            "'$($MutationError.Exception.Message)', and failure evidence " +
            "could not be written: $($_.Exception.Message)"
        )
    }

    throw (
        "$StopGuidance The mutation failed with " +
        "'$($MutationError.Exception.Message)'. Authoritative post-failure " +
        "state was captured in '$EvidencePath'."
    )
}
```

## Quiesce workloads and the platform

### Step 1: Gracefully shut down customer VMs

**Action type:** State-changing  
**Risk:** [HIGH RISK]  
**Owner:** Workload owner

The workload owner must stop applications and shut down each customer VM through its normal guest operating-system process. Do not use `-TurnOff`, save state, pause, or terminate a VM as the normal path.

Verify that every clustered VM except the sealed appliance VM is `Off`:

```powershell
$ControlPlaneVmId = "$($ResourceManifest.ControlPlaneVm.VmId)"
$ExpectedVmIdentityPairs = @($ResourceManifest.ClusteredVms |
    ForEach-Object {
        "$($_.GroupId)|$($_.GroupName)|$($_.VmId)"
    })
$CurrentVmGroups = @(Get-ClusterGroup -ErrorAction Stop |
    Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' })
$CurrentVmIdentityPairs = @(foreach ($Group in $CurrentVmGroups) {
    $VmResources = @($Group | Get-ClusterResource -ErrorAction Stop |
        Where-Object { "$($_.ResourceType)" -eq 'Virtual Machine' })
    if ($VmResources.Count -ne 1) {
        throw "Expected one Virtual Machine resource in '$($Group.Name)'."
    }
    $VmIdParameters = @(Get-ClusterParameter -InputObject $VmResources[0] `
        -Name VmId -ErrorAction Stop)
    if ($VmIdParameters.Count -ne 1) {
        throw "Expected one VmId parameter in '$($Group.Name)'."
    }
    "$($Group.Id)|$($Group.Name)|$($VmIdParameters[0].Value)"
})
if (
    $CurrentVmIdentityPairs.Count -ne $ExpectedVmIdentityPairs.Count -or
    @($ExpectedVmIdentityPairs | Where-Object {
        $_ -notin $CurrentVmIdentityPairs
    }).Count -gt 0 -or
    @($CurrentVmIdentityPairs | Where-Object {
        $_ -notin $ExpectedVmIdentityPairs
    }).Count -gt 0 -or
    @($CurrentVmIdentityPairs | Group-Object |
        Where-Object Count -ne 1).Count -gt 0
) {
    throw "Current clustered VM and group identities do not match the sealed inventory."
}

$CustomerVms = @($ResourceManifest.ClusteredVms | Where-Object {
    "$($_.VmId)" -ne $ControlPlaneVmId
})

$CustomerVmState = @(foreach ($Entry in $CustomerVms) {
    $CurrentGroup = @($CurrentVmGroups | Where-Object {
        "$($_.Id)" -eq "$($Entry.GroupId)" -and
        "$($_.Name)" -eq "$($Entry.GroupName)"
    })
    if ($CurrentGroup.Count -ne 1) {
        throw "A sealed customer VM group no longer resolves uniquely."
    }
    $CurrentState = @(Invoke-Command `
        -ComputerName "$($CurrentGroup[0].OwnerNode)" `
        -ArgumentList "$($Entry.VmId)" -ScriptBlock {
            param($VmId)
            Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                Select-Object VMId, Name, State
        } -ErrorAction Stop)
    if (
        $CurrentState.Count -ne 1 -or
        "$($CurrentState[0].VMId)" -ne "$($Entry.VmId)"
    ) {
        throw "A sealed customer VM no longer resolves uniquely by VmId."
    }
    $CurrentState[0]
})
$CustomerVmState | Format-Table -AutoSize

if (@($CustomerVmState | Where-Object State -ne 'Off').Count -gt 0) {
    throw "At least one customer VM is not Off. Stop and return to the workload owner."
}

Set-ChangePhase -Phase WorkloadsOff
```

Retry behavior: do not repeatedly issue shutdown requests. Re-read the VM state, then return control to the workload owner if a VM does not stop.

Rollback: no rollback is needed yet. The workload owner may restart the VMs if the change is abandoned before CSV quiescence begins.

### Step 2: Gracefully stop the appliance VM

**Action type:** State-changing  
**Risk:** [HIGH RISK]

Pre-check:

```powershell
$ControlPlaneEntry = $ResourceManifest.ControlPlaneVm
$ControlPlaneGroup = @(Get-ClusterGroup -ErrorAction Stop |
    Where-Object {
        "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
        "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
    })
if ($ControlPlaneGroup.Count -ne 1) {
    throw "The sealed appliance cluster group no longer resolves uniquely."
}
$ControlPlaneState = @(Invoke-Command `
    -ComputerName "$($ControlPlaneGroup[0].OwnerNode)" `
    -ArgumentList "$($ControlPlaneEntry.VmId)" -ScriptBlock {
        param($VmId)
        Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
            Select-Object VMId, Name, State
    } -ErrorAction Stop)
if (
    $ControlPlaneState.Count -ne 1 -or
    "$($ControlPlaneState[0].VMId)" -ne "$($ControlPlaneEntry.VmId)"
) {
    throw "The sealed appliance VM no longer resolves uniquely by VmId."
}
$ControlPlaneState
```

Action:

```powershell
$ControlPlaneGroup = @(Get-ClusterGroup -ErrorAction Stop |
    Where-Object {
        "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
        "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
    })
if ($ControlPlaneGroup.Count -ne 1) {
    throw "The sealed appliance cluster group no longer resolves uniquely."
}
try {
    Invoke-Command -ComputerName "$($ControlPlaneGroup[0].OwnerNode)" `
        -ArgumentList "$($ControlPlaneEntry.VmId)" -ScriptBlock {
            param($VmId)
            $Vm = Get-VM -Id ([guid]$VmId) -ErrorAction Stop
            if ($Vm.State -ne 'Off') {
                # Without -TurnOff, -Save, or -Force, Stop-VM requests guest OS shutdown.
                Stop-VM -VM $Vm -ErrorAction Stop
            }
        } -ErrorAction Stop
}
catch {
    Write-MutationFailureEvidence `
        -OperationName 'stop-appliance-vm' `
        -MutationError $_ `
        -StopGuidance (
            'The appliance VM did not stop gracefully. Do not force it off. ' +
            'Contact Microsoft Support.'
        ) `
        -ReadAuthoritativeState {
            $CurrentGroup = @(Get-ClusterGroup -ErrorAction Stop |
                Where-Object {
                    "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
                    "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
                })
            $CurrentVm = @()
            if ($CurrentGroup.Count -eq 1) {
                $CurrentVm = @(Invoke-Command `
                    -ComputerName "$($CurrentGroup[0].OwnerNode)" `
                    -ArgumentList "$($ControlPlaneEntry.VmId)" -ScriptBlock {
                        param($VmId)
                        Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                            Select-Object VMId, Name, State
                    } -ErrorAction Stop)
            }
            [pscustomobject]@{
                GroupId = "$($ControlPlaneEntry.GroupId)"
                GroupName = "$($ControlPlaneEntry.GroupName)"
                GroupMatches = $CurrentGroup.Count
                GroupState = "$($CurrentGroup[0].State)"
                OwnerNode = "$($CurrentGroup[0].OwnerNode)"
                VmId = "$($ControlPlaneEntry.VmId)"
                VmMatches = $CurrentVm.Count
                VmState = "$($CurrentVm[0].State)"
            }
        }
}
```

Verification:

```powershell
$ControlPlaneGroup = @(Get-ClusterGroup -ErrorAction Stop |
    Where-Object {
        "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
        "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
    })
if ($ControlPlaneGroup.Count -ne 1) {
    throw "The sealed appliance cluster group no longer resolves uniquely."
}
$ControlPlaneState = @(Invoke-Command `
    -ComputerName "$($ControlPlaneGroup[0].OwnerNode)" `
    -ArgumentList "$($ControlPlaneEntry.VmId)" -ScriptBlock {
        param($VmId)
        Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
            Select-Object VMId, Name, State
    } -ErrorAction Stop)
$ControlPlaneState | Format-Table -AutoSize

if (
    $ControlPlaneState.Count -ne 1 -or
    "$($ControlPlaneState[0].VMId)" -ne "$($ControlPlaneEntry.VmId)" -or
    "$($ControlPlaneState[0].State)" -ne 'Off'
) {
    throw "The appliance VM is not Off."
}
```

Stop if the VM becomes `Saved`, `Paused`, or remains `Running`. Do not force it off. Contact Microsoft Support if graceful shutdown does not complete.

Rollback before the next step: start the sealed cluster group and verify the VM returns to `Running`.

### Step 3: Stop the MOC Cloud Agent resource

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
$Moc = $ResourceManifest.Moc
$MocResource = @(Get-ClusterResource | Where-Object {
    "$($_.Id)" -eq "$($Moc.Id)" -and "$($_.Name)" -eq "$($Moc.Name)"
})
if ($MocResource.Count -ne 1) {
    throw "The sealed MOC resource identity no longer resolves uniquely."
}

if ("$($MocResource[0].State)" -ne 'Offline') {
    try {
        $MocResource[0] |
            Stop-ClusterResource -Wait 900 -ErrorAction Stop
    }
    catch {
        Write-MutationFailureEvidence `
            -OperationName 'stop-moc-resource' `
            -MutationError $_ `
            -StopGuidance (
                'The MOC resource did not reach Offline. Do not repeat the ' +
                'operation while the resource is Pending. Contact Microsoft Support.'
            ) `
            -ReadAuthoritativeState {
                @(Get-ClusterResource -ErrorAction Stop | Where-Object {
                    "$($_.Id)" -eq "$($Moc.Id)" -and
                    "$($_.Name)" -eq "$($Moc.Name)"
                }) | Select-Object Id, Name, State, OwnerNode, OwnerGroup
            }
    }
}

$MocResource = Get-ClusterResource -Name "$($Moc.Name)"
if ("$($MocResource.State)" -ne 'Offline') {
    throw "The MOC resource did not reach Offline."
}

Set-ChangePhase -Phase PlatformOff
```

Retry behavior: do not repeat `Stop-ClusterResource` while the resource is `Pending`. Wait for the command timeout, re-read state, and stop on failure.

Rollback before CSV quiescence: start the same sealed resource, then start the appliance cluster group and verify both return online.

## Offline CSVs and the Storage Spaces Direct pool

### Step 1: Define the sealed CSV state helper

**Action type:** [READ-ONLY]

```powershell
function Get-VerifiedSealedCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $CsvRecord,

        [switch]$RequireOnlineMetadata
    )

    $EscapedName = "$($CsvRecord.Name)".Replace("'", "''")
    $CimMatches = @(Get-CimInstance -Namespace root/MSCluster `
        -ClassName MSCluster_Resource -Filter "Name='$EscapedName'" `
        -ErrorAction Stop |
        Where-Object {
            "$($_.Type)" -eq "$($CsvRecord.CimType)" -and
            "$($_.OwnerGroup)" -eq "$($CsvRecord.CimOwnerGroup)"
        })
    $CsvMatches = @(Get-ClusterSharedVolume -Name "$($CsvRecord.Name)" `
        -ErrorAction Stop)
    if ($CimMatches.Count -ne 1 -or $CsvMatches.Count -ne 1) {
        throw "The sealed CSV identity '$($CsvRecord.Name)' no longer resolves uniquely."
    }

    if ($RequireOnlineMetadata) {
        if ("$($CsvMatches[0].State)" -ne 'Online') {
            throw "CSV '$($CsvRecord.Name)' must be Online for metadata verification."
        }
        $Info = @($CsvMatches[0].SharedVolumeInfo)
        if ($Info.Count -ne 1) {
            throw "CSV '$($CsvRecord.Name)' has ambiguous shared-volume information."
        }
        $PartitionName = "$($Info[0].Partition.Name)"
        $FriendlyVolumeName = "$($Info[0].FriendlyVolumeName)"
        $VolumeLeaf = Split-Path -Path $FriendlyVolumeName -Leaf
        if ([string]::IsNullOrWhiteSpace($VolumeLeaf)) {
            throw "CSV '$($CsvRecord.Name)' has no usable volume leaf name."
        }
        $VirtualDisks = @(Get-VirtualDisk -FriendlyName $VolumeLeaf `
            -ErrorAction Stop)
        if ($VirtualDisks.Count -ne 1) {
            throw "CSV '$($CsvRecord.Name)' no longer maps to one virtual disk."
        }
        if (
            $FriendlyVolumeName -ine "$($CsvRecord.FriendlyVolumeName)" -or
            $PartitionName -ine "$($CsvRecord.PartitionName)" -or
            "$($VirtualDisks[0].UniqueId)" -ne "$($CsvRecord.VirtualDiskUniqueId)"
        ) {
            throw (
                "CSV '$($CsvRecord.Name)' no longer matches its sealed mount " +
                "path, partition, or virtual-disk identity."
            )
        }
    }

    [pscustomobject]@{
        Csv = $CsvMatches[0]
        Cim = $CimMatches[0]
    }
}

function Set-SealedCsvState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $CsvRecord,

        [Parameter(Mandatory)]
        [ValidateSet('Online', 'Offline')]
        [string]$State
    )

    $Before = if ($State -eq 'Offline') {
        Get-VerifiedSealedCsv -CsvRecord $CsvRecord -RequireOnlineMetadata
    } else {
        Get-VerifiedSealedCsv -CsvRecord $CsvRecord
    }
    $Method = if ($State -eq 'Online') { 'BringOnline' } else { 'TakeOffline' }
    try {
        Invoke-CimMethod -InputObject $Before.Cim -MethodName $Method `
            -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "The CSV provider returned: $($_.Exception.Message)"
        Write-Warning "Provider text is not authoritative. Re-read the recorded CSV state before deciding whether to retry."
    }

    $After = if ($State -eq 'Online') {
        Get-VerifiedSealedCsv -CsvRecord $CsvRecord -RequireOnlineMetadata
    } else {
        Get-VerifiedSealedCsv -CsvRecord $CsvRecord
    }
    if ("$($After.Csv.State)" -ne $State) {
        throw "CSV '$($CsvRecord.Name)' is '$($After.Csv.State)', expected '$State'."
    }
}
```

The helper catches provider text because a CSV operation can report `Generic failure` after the requested state has already changed. The authoritative decision is the re-read state.

### Step 2: Offline workload CSVs, then the infrastructure CSV

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
$WorkloadCsvs = @($ResourceManifest.Csvs | Where-Object Role -eq 'Workload')
$InfrastructureCsv = @($ResourceManifest.Csvs | Where-Object Role -eq 'Infrastructure')

foreach ($Csv in $WorkloadCsvs) {
    Set-SealedCsvState -CsvRecord $Csv -State Offline
}

Set-SealedCsvState -CsvRecord $InfrastructureCsv[0] -State Offline

Get-ClusterSharedVolume | Format-Table Name, State, OwnerNode
if (@(Get-ClusterSharedVolume | Where-Object State -ne 'Offline').Count -gt 0) {
    throw "At least one CSV is not Offline."
}

Set-ChangePhase -Phase CsvsOff
```

Expected result: every CSV is `Offline`.

Retry behavior: if provider text reports failure, re-read state first. Retry only when the resource is not `Pending` and remains in the original state. Never issue repeated state changes blindly.

Rollback: online the infrastructure CSV first, then workload CSVs, using the restoration sequence later in this guide.

### Step 3: Offline the exact clustered Storage Pool resource

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
$Pool = $ResourceManifest.Pool
$PoolResource = @(Get-ClusterResource | Where-Object {
    "$($_.Id)" -eq "$($Pool.Id)" -and "$($_.Name)" -eq "$($Pool.Name)"
})
if ($PoolResource.Count -ne 1) {
    throw "The sealed pool resource identity no longer resolves uniquely."
}

if ("$($PoolResource[0].State)" -ne 'Offline') {
    try {
        $PoolResource[0] |
            Stop-ClusterResource -Wait 1800 -ErrorAction Stop
    }
    catch {
        Write-MutationFailureEvidence `
            -OperationName 'stop-storage-pool-resource' `
            -MutationError $_ `
            -StopGuidance (
                'The Storage Pool resource did not reach Offline. Stop and ' +
                'contact Microsoft Support before any repair action.'
            ) `
            -ReadAuthoritativeState {
                @(Get-ClusterResource -ErrorAction Stop | Where-Object {
                    "$($_.Id)" -eq "$($Pool.Id)" -and
                    "$($_.Name)" -eq "$($Pool.Name)"
                }) | Select-Object Id, Name, State, OwnerNode, OwnerGroup
            }
    }
}

$PoolResource = Get-ClusterResource -Name "$($Pool.Name)"
if ("$($PoolResource.State)" -ne 'Offline') {
    throw "The Storage Pool resource did not reach Offline."
}

Set-ChangePhase -Phase PoolOff
```

Expected result: the exact recorded `Storage Pool` cluster resource is `Offline`.

It is expected that friendly volume names may be blank and virtual disks may temporarily appear detached or unknown while the pool is offline. Those states are not acceptable after restoration.

Stop if any unrelated cluster resource changes state or the pool remains `Pending`.

## Change the Network ATC transport

### Step 1: Rebuild the complete adapter override and preview the one-property change

**Action type:** [READ-ONLY]

```powershell
$AdapterOverride = New-NetIntentAdapterPropertyOverrides
foreach ($Property in $ExplicitAdapterOverrides.GetEnumerator()) {
    if ($Property.Key -in @('InstanceId', 'ObjectVersion', 'NetworkDirectTechnology')) {
        continue
    }

    $TargetProperty = $AdapterOverride.PSObject.Properties[$Property.Key]
    if ($null -eq $TargetProperty) {
        throw "Current override property '$($Property.Key)' is not available on this node."
    }
    $TargetProperty.Value = $Property.Value
}
$AdapterOverride.NetworkDirectTechnology = $DesiredTransportValue

function Assert-AdapterOverrideReadback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$LiveOverride,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$SealedOverrides,

        [Parameter(Mandatory)]
        [int]$ExpectedTransportValue
    )

    $DefaultOverride = New-NetIntentAdapterPropertyOverrides
    $ExpectedOverrides = [ordered]@{}
    foreach ($Property in $SealedOverrides.GetEnumerator()) {
        if ($Property.Key -in @(
            'InstanceId',
            'ObjectVersion',
            'NetworkDirectTechnology'
        )) {
            continue
        }
        $ExpectedOverrides[$Property.Key] = $Property.Value
    }
    $ExpectedOverrides.NetworkDirectTechnology = $ExpectedTransportValue

    $ActualOverrides = [ordered]@{}
    foreach ($Property in @($LiveOverride.PSObject.Properties |
        Sort-Object Name)) {
        if ($Property.Name -in @('InstanceId', 'ObjectVersion')) {
            continue
        }
        $DefaultProperty = $DefaultOverride.PSObject.Properties[$Property.Name]
        if ($null -eq $DefaultProperty) {
            throw (
                "Live override property '$($Property.Name)' cannot be " +
                "represented by New-NetIntentAdapterPropertyOverrides on " +
                "this node."
            )
        }
        $ActualJson = $Property.Value |
            ConvertTo-Json -Depth 8 -Compress
        $DefaultJson = $DefaultProperty.Value |
            ConvertTo-Json -Depth 8 -Compress
        if ($ActualJson -ne $DefaultJson) {
            $ActualOverrides[$Property.Name] = $Property.Value
        }
    }

    $ExpectedKeys = @($ExpectedOverrides.Keys | Sort-Object)
    $ActualKeys = @($ActualOverrides.Keys | Sort-Object)
    if (
        $ExpectedKeys.Count -ne $ActualKeys.Count -or
        @($ExpectedKeys | Where-Object { $_ -notin $ActualKeys }).Count -gt 0 -or
        @($ActualKeys | Where-Object { $_ -notin $ExpectedKeys }).Count -gt 0
    ) {
        throw "The live explicit adapter-override property set changed."
    }
    foreach ($Key in $ExpectedKeys) {
        $ExpectedJson = $ExpectedOverrides[$Key] |
            ConvertTo-Json -Depth 8 -Compress
        $ActualJson = $ActualOverrides[$Key] |
            ConvertTo-Json -Depth 8 -Compress
        if ($ExpectedJson -ne $ActualJson) {
            throw "The live adapter override '$Key' does not match the sealed value."
        }
    }
}

$AdapterOverride | Format-List *
```

Human verification:

- Compare this output with `network-atc-baseline.json`.
- Confirm every existing explicit adapter override is present.
- Confirm only `NetworkDirectTechnology` changes.

Stop if any other property is missing or changed.

### Step 2: Submit the intent change

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
$SubmissionState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
if ("$($SubmissionState.Phase)" -eq 'PoolOff') {
    $PointOfNoReturnUpdates = @(Get-SolutionUpdate -ErrorAction Stop)
    $PointOfNoReturnActiveUpdates = @(
        $PointOfNoReturnUpdates | Where-Object {
            "$($_.State)" -in @('Downloading', 'Installing')
        }
    )
    $PointOfNoReturnRuns = @($PointOfNoReturnUpdates | ForEach-Object {
        @($_ | Get-SolutionUpdateRun -ErrorAction Stop |
            Where-Object { "$($_.State)" -eq 'InProgress' })
    })
    $PointOfNoReturnCau = @(Get-CauRun -ClusterName $Cluster.Name `
        -ErrorAction Stop)
    $PointOfNoReturnNodes = @(Get-ClusterNode -ErrorAction Stop)
    $PointOfNoReturnJobs = @(Get-StorageJob -ErrorAction Stop)
    $PointOfNoReturnFaults = @(Get-HealthFault -ErrorAction Stop)
    $PointOfNoReturnQuorum = Get-ClusterQuorum -ErrorAction Stop
    $PointOfNoReturnWitnessHealthy = $true
    if (-not [string]::IsNullOrWhiteSpace(
        "$($PointOfNoReturnQuorum.QuorumResource)"
    )) {
        $PointOfNoReturnWitness = @(Get-ClusterResource `
            -Name "$($PointOfNoReturnQuorum.QuorumResource)" `
            -ErrorAction Stop)
        $PointOfNoReturnWitnessHealthy = (
            $PointOfNoReturnWitness.Count -eq 1 -and
            "$($PointOfNoReturnWitness[0].State)" -eq 'Online'
        )
    }
    $PointOfNoReturnPool = @(Get-ClusterResource -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($Pool.Id)" -and
            "$($_.Name)" -eq "$($Pool.Name)"
        })
    $PointOfNoReturnMoc = @(Get-ClusterResource -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($Moc.Id)" -and
            "$($_.Name)" -eq "$($Moc.Name)"
        })
    $PointOfNoReturnCsvs = @(
        foreach ($CsvRecord in @($ResourceManifest.Csvs)) {
            $EscapedName = "$($CsvRecord.Name)".Replace("'", "''")
            $CimMatches = @(Get-CimInstance -Namespace root/MSCluster `
                -ClassName MSCluster_Resource -Filter "Name='$EscapedName'" `
                -ErrorAction Stop | Where-Object {
                    "$($_.Type)" -eq "$($CsvRecord.CimType)" -and
                    "$($_.OwnerGroup)" -eq "$($CsvRecord.CimOwnerGroup)"
                })
            $CsvMatches = @(Get-ClusterSharedVolume `
                -Name "$($CsvRecord.Name)" -ErrorAction Stop)
            if ($CimMatches.Count -ne 1 -or $CsvMatches.Count -ne 1) {
                throw "A sealed CSV identity no longer resolves uniquely."
            }
            $CsvMatches[0]
        }
    )
    $PointOfNoReturnVmGroups = @(Get-ClusterGroup -ErrorAction Stop |
        Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' })
    $PointOfNoReturnVmIdentityPairs = @(
        foreach ($Group in $PointOfNoReturnVmGroups) {
            $VmResource = @($Group |
                Get-ClusterResource -ErrorAction Stop |
                Where-Object {
                    "$($_.ResourceType)" -eq 'Virtual Machine'
                })
            if ($VmResource.Count -ne 1) {
                throw (
                    "A clustered VM no longer has one Virtual Machine " +
                    "resource."
                )
            }
            $VmId = @(Get-ClusterParameter -InputObject $VmResource[0] `
                -Name VmId -ErrorAction Stop)
            if ($VmId.Count -ne 1) {
                throw "A clustered VM no longer has one VmId parameter."
            }
            "$($Group.Id)|$($Group.Name)|$($VmId[0].Value)"
        }
    )
    $PointOfNoReturnVmState = @(
        foreach ($Entry in $ResourceManifest.ClusteredVms) {
            $CurrentGroup = @($PointOfNoReturnVmGroups | Where-Object {
                "$($_.Id)" -eq "$($Entry.GroupId)" -and
                "$($_.Name)" -eq "$($Entry.GroupName)"
            })
            if ($CurrentGroup.Count -ne 1) {
                throw (
                    "A sealed clustered VM group no longer resolves uniquely."
                )
            }
            Invoke-Command -ComputerName "$($CurrentGroup[0].OwnerNode)" `
                -ArgumentList "$($Entry.VmId)" -ScriptBlock {
                    param($VmId)
                    Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                        Select-Object VMId, State
                } -ErrorAction Stop
        }
    )
    $PointOfNoReturnIntent = @(Get-NetIntent -ClusterName $Cluster.Name `
        -ErrorAction Stop | Where-Object {
            "$($_.IntentName)" -eq "$($StorageIntent.IntentName)"
        })
    if ($PointOfNoReturnIntent.Count -ne 1) {
        throw "The sealed storage intent no longer resolves uniquely."
    }
    $PointOfNoReturnIntentStatus = @(Get-NetIntentStatus `
        -ClusterName $Cluster.Name -Name "$($StorageIntent.IntentName)" `
        -ErrorAction Stop)
    Assert-IntentStatusCoverage -Status $PointOfNoReturnIntentStatus `
        -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
    $PointOfNoReturnBadIntentStatus = @($PointOfNoReturnIntentStatus |
        Where-Object {
            "$($_.ConfigurationStatus)" -ne 'Success' -or
            "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
            [int]$_.RetryCount -gt 0 -or
            -not [string]::IsNullOrWhiteSpace("$($_.Error)")
        })
    $ExpectedCurrentTransportValue = if ($Operation -eq 'Forward') {
        [int]$SourceTransportValue
    } else {
        [int]$ResourceManifest.TargetTransportValue
    }
    Assert-AdapterOverrideReadback `
        -LiveOverride $PointOfNoReturnIntent[0].AdapterAdvancedParametersOverride `
        -SealedOverrides $ExplicitAdapterOverrides `
        -ExpectedTransportValue $ExpectedCurrentTransportValue
    $PointOfNoReturnAdapters = @(Invoke-Command `
        -ComputerName $Nodes.Name `
        -ArgumentList ($AdapterNames -join ',') -ScriptBlock {
            param($AdapterCsv)
            foreach ($AdapterName in @($AdapterCsv -split ',')) {
                $Adapter = Get-NetAdapter -Name $AdapterName `
                    -ErrorAction Stop
                $Rdma = Get-NetAdapterRdma -Name $AdapterName `
                    -ErrorAction Stop
                $Transport = Get-NetAdapterAdvancedProperty `
                    -Name $AdapterName `
                    -RegistryKeyword '*NetworkDirectTechnology' `
                    -ErrorAction Stop
                [pscustomobject]@{
                    Pair = "$($env:COMPUTERNAME.Split('.')[0].ToUpperInvariant())|" +
                        "$($AdapterName.Trim().ToUpperInvariant())"
                    Status = "$($Adapter.Status)"
                    RdmaEnabled = [bool]$Rdma.Enabled
                    TransportValue = [int]$Transport.RegistryValue[0]
                }
            }
        } -ErrorAction Stop)
    $PointOfNoReturnExpectedAdapterPairs = @(
        foreach ($Node in $Nodes) {
            $NodeName = "$($Node.Name)".Split('.')[0].ToUpperInvariant()
            foreach ($AdapterName in $AdapterNames) {
                "$NodeName|$("$AdapterName".Trim().ToUpperInvariant())"
            }
        }
    )
    if (
        $PointOfNoReturnActiveUpdates.Count -gt 0 -or
        $PointOfNoReturnRuns.Count -gt 0 -or
        $PointOfNoReturnCau.Count -gt 0 -or
        @($PointOfNoReturnNodes | Where-Object State -ne 'Up').Count -gt 0 -or
        $PointOfNoReturnJobs.Count -gt 0 -or
        $PointOfNoReturnFaults.Count -gt 0 -or
        $PointOfNoReturnBadIntentStatus.Count -gt 0 -or
        -not $PointOfNoReturnWitnessHealthy -or
        $PointOfNoReturnPool.Count -ne 1 -or
        "$($PointOfNoReturnPool[0].State)" -ne 'Offline' -or
        $PointOfNoReturnMoc.Count -ne 1 -or
        "$($PointOfNoReturnMoc[0].State)" -ne 'Offline' -or
        $PointOfNoReturnCsvs.Count -ne @($ResourceManifest.Csvs).Count -or
        @($PointOfNoReturnCsvs |
            Where-Object State -ne 'Offline').Count -gt 0 -or
        $PointOfNoReturnVmIdentityPairs.Count -ne `
            $ExpectedVmIdentityPairs.Count -or
        @($ExpectedVmIdentityPairs | Where-Object {
            $_ -notin $PointOfNoReturnVmIdentityPairs
        }).Count -gt 0 -or
        @($PointOfNoReturnVmIdentityPairs | Where-Object {
            $_ -notin $ExpectedVmIdentityPairs
        }).Count -gt 0 -or
        @($PointOfNoReturnVmState |
            Where-Object State -ne 'Off').Count -gt 0 -or
        $PointOfNoReturnAdapters.Count -ne `
            $PointOfNoReturnExpectedAdapterPairs.Count -or
        @($PointOfNoReturnExpectedAdapterPairs | Where-Object {
            $_ -notin $PointOfNoReturnAdapters.Pair
        }).Count -gt 0 -or
        @($PointOfNoReturnAdapters.Pair | Where-Object {
            $_ -notin $PointOfNoReturnExpectedAdapterPairs
        }).Count -gt 0 -or
        @($PointOfNoReturnAdapters | Where-Object {
            $_.Status -ne 'Up' -or
            -not $_.RdmaEnabled -or
            $_.TransportValue -ne $ExpectedCurrentTransportValue
        }).Count -gt 0
    ) {
        throw (
            "The point-of-no-return recheck found servicing, health, quorum, " +
            "identity, override, or quiescence drift. Do not submit the intent."
        )
    }

    Set-ChangePhase -Phase IntentSubmissionPending
    try {
        Set-NetIntent -Name "$($StorageIntent.IntentName)" `
            -ClusterName "$($Cluster.Name)" `
            -AdapterPropertyOverrides $AdapterOverride `
            -ErrorAction Stop
    } catch {
        throw (
            "The intent command returned an error after the durable dispatch " +
            "checkpoint. Do not resubmit. Re-enter this block to reconcile " +
            "the live intent. Original error: $($_.Exception.Message)"
        )
    }
    Set-ChangePhase -Phase IntentSubmitted
} elseif ("$($SubmissionState.Phase)" -eq 'IntentSubmissionPending') {
    $LiveIntent = @(Get-NetIntent -ClusterName $Cluster.Name `
        -ErrorAction Stop | Where-Object {
            "$($_.IntentName)" -eq "$($StorageIntent.IntentName)"
        })
    $LiveStatus = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
        -Name "$($StorageIntent.IntentName)" -ErrorAction Stop)
    Assert-IntentStatusCoverage -Status $LiveStatus `
        -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
    $LiveTransportValue = $null
    if ($LiveIntent.Count -eq 1) {
        $LiveAdapterOverride = $LiveIntent[0].AdapterAdvancedParametersOverride
        $LiveTransportValue = [int]$LiveAdapterOverride.NetworkDirectTechnology
    }
    if (
        $LiveIntent.Count -ne 1 -or
        $LiveTransportValue -ne $DesiredTransportValue
    ) {
        throw (
            "Intent dispatch cannot be proven from live desired state. " +
            "Do not resubmit. Preserve status and contact Microsoft Support."
        )
    }
    Assert-AdapterOverrideReadback -LiveOverride $LiveAdapterOverride `
        -SealedOverrides $ExplicitAdapterOverrides `
        -ExpectedTransportValue $DesiredTransportValue
    Set-ChangePhase -Phase IntentSubmitted
} else {
    throw (
        "Intent submission requires PoolOff or IntentSubmissionPending phase. " +
        "Do not issue another mutation."
    )
}
```

Expected result: Network ATC accepts the updated adapter override for the existing storage intent.

Error handling:

- Submit the change once.
- Do not resubmit while any node is provisioning.
- If the command returns an error after submission, query `Get-NetIntent` and `Get-NetIntentStatus` before deciding that the change was not accepted.
- Stop if the intent identity changes or the requested override cannot be read back.

Rollback: repeat this entire guide with the original transport value after the cluster is restored to a controlled quiesced state. Do not issue an automatic transport reversal while Network ATC is still converging.

### Step 3: Wait for Network ATC convergence

**Action type:** [READ-ONLY]

```powershell
$Deadline = (Get-Date).AddMinutes(30)
do {
    $IntentStatus = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
        -Name $StorageIntent.IntentName -ErrorAction Stop)
    $IntentStatus |
        Format-Table Host, IntentName, ConfigurationStatus, ProvisioningStatus, RetryCount, Error

    Assert-IntentStatusCoverage -Status $IntentStatus `
        -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
    $Incomplete = @($IntentStatus | Where-Object {
        "$($_.ConfigurationStatus)" -ne 'Success' -or
        "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
        [int]$_.RetryCount -gt 0 -or
        -not [string]::IsNullOrWhiteSpace("$($_.Error)")
    })

    if ($Incomplete.Count -eq 0) {
        break
    }

    Start-Sleep -Seconds 30
} while ((Get-Date) -lt $Deadline)

if ($Incomplete.Count -gt 0) {
    throw "Network ATC did not converge cleanly within 30 minutes."
}

$ConvergedIntent = @(Get-NetIntent -ClusterName $Cluster.Name `
    -ErrorAction Stop | Where-Object {
        "$($_.IntentName)" -eq "$($StorageIntent.IntentName)"
    })
if ($ConvergedIntent.Count -ne 1) {
    throw "The converged storage intent no longer resolves uniquely."
}
Assert-AdapterOverrideReadback `
    -LiveOverride $ConvergedIntent[0].AdapterAdvancedParametersOverride `
    -SealedOverrides $ExplicitAdapterOverrides `
    -ExpectedTransportValue $DesiredTransportValue

Set-ChangePhase -Phase IntentConverged
```

Expected result: every node reaches successful configuration and successful or completed provisioning with zero retry debt and no error.

Stop if the timeout expires. Do not call `Set-NetIntent` again. Collect the status and escalate.

### Step 4: Verify the desired transport while storage remains offline

**Action type:** [READ-ONLY]

```powershell
$PostChangeAdapterState = @(Invoke-Command -ComputerName $Nodes.Name `
    -ArgumentList ($AdapterNames -join ','), $DesiredTransportValue `
    -ScriptBlock {
        param($AdapterCsv, $TargetValue)
        $Names = @($AdapterCsv -split ',' | ForEach-Object { $_.Trim() })
        foreach ($Name in $Names) {
            $Adapter = Get-NetAdapter -Name $Name -ErrorAction Stop
            $Rdma = Get-NetAdapterRdma -Name $Name -ErrorAction Stop
            $Transport = Get-NetAdapterAdvancedProperty -Name $Name `
                -RegistryKeyword '*NetworkDirectTechnology' -ErrorAction Stop
            [pscustomobject]@{
                Node = $env:COMPUTERNAME
                Adapter = $Name
                Status = "$($Adapter.Status)"
                RdmaEnabled = [bool]$Rdma.Enabled
                TransportValue = [int]$Transport.RegistryValue[0]
                IsTarget = [int]$Transport.RegistryValue[0] -eq $TargetValue
            }
        }
    } -ErrorAction Stop)

$PostChangeAdapterState | Format-Table -AutoSize
if (@($PostChangeAdapterState | Where-Object {
    $_.Status -ne 'Up' -or -not $_.RdmaEnabled -or -not $_.IsTarget
}).Count -gt 0) {
    throw "At least one adapter has not reached the desired transport."
}

Set-ChangePhase -Phase TargetReadbackVerified
```

Expected result: every storage adapter is `Up`, RDMA enabled, and configured for the desired transport.

This proves the desired adapter state, not active RDMA traffic. Active transport verification occurs after storage recovery.

## Restore the platform in dependency order

### Step 1: Online the Storage Pool resource

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
$PoolResource = @(Get-ClusterResource | Where-Object {
    "$($_.Id)" -eq "$($Pool.Id)" -and "$($_.Name)" -eq "$($Pool.Name)"
})
if ($PoolResource.Count -ne 1) {
    throw "The sealed pool resource identity no longer resolves uniquely."
}

if ("$($PoolResource[0].State)" -ne 'Online') {
    try {
        $PoolResource[0] |
            Start-ClusterResource -Wait 1800 -ErrorAction Stop
    }
    catch {
        Write-MutationFailureEvidence `
            -OperationName 'start-storage-pool-resource' `
            -MutationError $_ `
            -StopGuidance (
                'The Storage Pool resource did not return Online. Contact ' +
                'Microsoft Support before any repair action.'
            ) `
            -ReadAuthoritativeState {
                @(Get-ClusterResource -ErrorAction Stop | Where-Object {
                    "$($_.Id)" -eq "$($Pool.Id)" -and
                    "$($_.Name)" -eq "$($Pool.Name)"
                }) | Select-Object Id, Name, State, OwnerNode, OwnerGroup
            }
    }
}

$PoolResource = Get-ClusterResource -Name "$($Pool.Name)"
if ("$($PoolResource.State)" -ne 'Online') {
    throw "The Storage Pool resource did not return Online."
}
```

Stop if the pool remains `Pending`, returns `Failed`, or another pool resource appears. Contact Microsoft Support before repair actions.

### Step 2: Recover any recorded manual-attach virtual-disk resource

**Action type:** State-changing when applicable  
**Risk:** [HIGH RISK]

Some systems contain a separate non-CSV manual-attach virtual disk, such as a performance-history disk. If the pre-change inventory recorded one and its exact clustered `Physical Disk` resource is offline after the pool returns, online that recorded resource before the infrastructure CSV.

Do not guess its identity, create a replacement, format it, or run repair. If the resource was not uniquely recorded before the outage, stop and contact Microsoft Support.

```powershell
foreach ($AuxiliaryRecord in $AuxiliaryVirtualDiskResources) {
    $VirtualDisk = @(Get-VirtualDisk -ErrorAction Stop | Where-Object {
        "$($_.UniqueId)" -eq "$($AuxiliaryRecord.VirtualDiskUniqueId)" -and
        "$($_.FriendlyName)" -eq "$($AuxiliaryRecord.VirtualDiskName)"
    })
    $ClusterResource = @(Get-ClusterResource -ErrorAction Stop | Where-Object {
        "$($_.Id)" -eq "$($AuxiliaryRecord.ResourceId)" -and
        "$($_.Name)" -eq "$($AuxiliaryRecord.ResourceName)" -and
        "$($_.ResourceType)" -eq 'Physical Disk'
    })
    if ($VirtualDisk.Count -ne 1 -or $ClusterResource.Count -ne 1) {
        throw "A sealed manual-attach virtual disk or clustered resource no longer resolves uniquely."
    }

    if ("$($AuxiliaryRecord.OriginalState)" -eq 'Online' -and
        "$($ClusterResource[0].State)" -ne 'Online') {
        try {
            $ClusterResource[0] |
                Start-ClusterResource -Wait 1800 -ErrorAction Stop
        }
        catch {
            Write-MutationFailureEvidence `
                -OperationName (
                    'start-auxiliary-resource-{0}' -f
                    "$($AuxiliaryRecord.ResourceName)"
                ) `
                -MutationError $_ `
                -StopGuidance (
                    "Manual-attach resource " +
                    "'$($AuxiliaryRecord.ResourceName)' did not return to " +
                    "its sealed state. Stop and contact Microsoft Support."
                ) `
                -ReadAuthoritativeState {
                    $CurrentVirtualDisk = @(Get-VirtualDisk `
                        -ErrorAction Stop | Where-Object {
                            "$($_.UniqueId)" -eq
                                "$($AuxiliaryRecord.VirtualDiskUniqueId)" -and
                            "$($_.FriendlyName)" -eq
                                "$($AuxiliaryRecord.VirtualDiskName)"
                        })
                    $CurrentClusterResource = @(Get-ClusterResource `
                        -ErrorAction Stop | Where-Object {
                            "$($_.Id)" -eq
                                "$($AuxiliaryRecord.ResourceId)" -and
                            "$($_.Name)" -eq
                                "$($AuxiliaryRecord.ResourceName)"
                        })
                    [pscustomobject]@{
                        VirtualDiskMatches = $CurrentVirtualDisk.Count
                        VirtualDiskUniqueId =
                            "$($AuxiliaryRecord.VirtualDiskUniqueId)"
                        VirtualDiskName =
                            "$($AuxiliaryRecord.VirtualDiskName)"
                        VirtualDiskHealth =
                            "$($CurrentVirtualDisk[0].HealthStatus)"
                        VirtualDiskOperational =
                            "$($CurrentVirtualDisk[0].OperationalStatus)"
                        ResourceMatches = $CurrentClusterResource.Count
                        ResourceId = "$($AuxiliaryRecord.ResourceId)"
                        ResourceName = "$($AuxiliaryRecord.ResourceName)"
                        ResourceState =
                            "$($CurrentClusterResource[0].State)"
                        OriginalState = "$($AuxiliaryRecord.OriginalState)"
                    }
                }
        }
    }

    $CurrentResource = Get-ClusterResource -Name "$($AuxiliaryRecord.ResourceName)"
    if ("$($CurrentResource.State)" -ne "$($AuxiliaryRecord.OriginalState)") {
        throw (
            "Manual-attach resource '$($AuxiliaryRecord.ResourceName)' is " +
            "'$($CurrentResource.State)', expected original state " +
            "'$($AuxiliaryRecord.OriginalState)'."
        )
    }
}

Set-ChangePhase -Phase PoolOnline
```

Expected result: every sealed auxiliary virtual disk and clustered resource resolves exactly once and returns to its original state. An empty sealed list is valid and makes no change.

### Step 3: Online the infrastructure CSV

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
Set-SealedCsvState -CsvRecord $InfrastructureCsv[0] -State Online
```

Expected result: the exact infrastructure CSV returns `Online`.

Stop if it remains `Pending`, fails, or resolves to a different partition or mount path.

### Step 4: Online MOC, then the appliance VM

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
$MocResource = @(Get-ClusterResource | Where-Object {
    "$($_.Id)" -eq "$($Moc.Id)" -and "$($_.Name)" -eq "$($Moc.Name)"
})
if ($MocResource.Count -ne 1) {
    throw "The sealed MOC resource identity no longer resolves uniquely."
}
if ("$($MocResource[0].State)" -ne 'Online') {
    try {
        $MocResource[0] |
            Start-ClusterResource -Wait 900 -ErrorAction Stop
    }
    catch {
        Write-MutationFailureEvidence `
            -OperationName 'start-moc-resource' `
            -MutationError $_ `
            -StopGuidance (
                'The MOC resource did not return Online. Stop before ' +
                'customer workload startup and contact Microsoft Support.'
            ) `
            -ReadAuthoritativeState {
                @(Get-ClusterResource -ErrorAction Stop | Where-Object {
                    "$($_.Id)" -eq "$($Moc.Id)" -and
                    "$($_.Name)" -eq "$($Moc.Name)"
                }) | Select-Object Id, Name, State, OwnerNode, OwnerGroup
            }
    }
}
$MocResource = @(Get-ClusterResource -ErrorAction Stop | Where-Object {
    "$($_.Id)" -eq "$($Moc.Id)" -and "$($_.Name)" -eq "$($Moc.Name)"
})
if ($MocResource.Count -ne 1) {
    throw "The sealed MOC resource identity no longer resolves uniquely."
}
if ("$($MocResource[0].State)" -ne 'Online') {
    throw (
        "The MOC resource is '$($MocResource[0].State)', expected Online. " +
        "Stop before customer workload startup and contact Microsoft Support."
    )
}

$ControlPlaneGroup = @(Get-ClusterGroup | Where-Object {
    "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
    "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
})
if ($ControlPlaneGroup.Count -ne 1) {
    throw "The sealed appliance cluster-group identity no longer resolves uniquely."
}
if ("$($ControlPlaneGroup[0].State)" -ne 'Online') {
    try {
        $ControlPlaneGroup[0] |
            Start-ClusterGroup -Wait 1800 -ErrorAction Stop
    }
    catch {
        Write-MutationFailureEvidence `
            -OperationName 'start-appliance-cluster-group' `
            -MutationError $_ `
            -StopGuidance (
                'The appliance clustered role did not return Online. Stop ' +
                'before customer workload startup and contact Microsoft Support.'
            ) `
            -ReadAuthoritativeState {
                $CurrentGroup = @(Get-ClusterGroup -ErrorAction Stop |
                    Where-Object {
                        "$($_.Id)" -eq
                            "$($ControlPlaneEntry.GroupId)" -and
                        "$($_.Name)" -eq
                            "$($ControlPlaneEntry.GroupName)"
                    })
                $CurrentVm = @()
                if ($CurrentGroup.Count -eq 1) {
                    $CurrentVm = @(Invoke-Command `
                        -ComputerName "$($CurrentGroup[0].OwnerNode)" `
                        -ArgumentList "$($ControlPlaneEntry.VmId)" `
                        -ScriptBlock {
                            param($VmId)
                            Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                                Select-Object VMId, Name, State
                        } -ErrorAction Stop)
                }
                [pscustomobject]@{
                    GroupId = "$($ControlPlaneEntry.GroupId)"
                    GroupName = "$($ControlPlaneEntry.GroupName)"
                    GroupMatches = $CurrentGroup.Count
                    GroupState = "$($CurrentGroup[0].State)"
                    OwnerNode = "$($CurrentGroup[0].OwnerNode)"
                    VmId = "$($ControlPlaneEntry.VmId)"
                    VmMatches = $CurrentVm.Count
                    VmState = "$($CurrentVm[0].State)"
                }
            }
    }
}
$ControlPlaneGroup = @(Get-ClusterGroup -ErrorAction Stop | Where-Object {
    "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
    "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
})
if ($ControlPlaneGroup.Count -ne 1) {
    throw "The sealed appliance cluster-group identity no longer resolves uniquely."
}
if ("$($ControlPlaneGroup[0].State)" -ne 'Online') {
    throw (
        "The appliance clustered role is '$($ControlPlaneGroup[0].State)', " +
        "expected Online. Stop before customer workload startup and contact " +
        "Microsoft Support."
    )
}

$ControlPlaneState = @(Invoke-Command `
    -ComputerName "$($ControlPlaneGroup[0].OwnerNode)" `
    -ArgumentList "$($ControlPlaneEntry.VmId)" `
    -ScriptBlock {
        param($VmId)
        Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
            Select-Object VMId, Name, State
    } -ErrorAction Stop)
if (
    $ControlPlaneState.Count -ne 1 -or
    "$($ControlPlaneState[0].VMId)" -ne "$($ControlPlaneEntry.VmId)" -or
    "$($ControlPlaneState[0].State)" -ne 'Running'
) {
    throw (
        "The appliance VM did not return to the sealed Running state. Stop " +
        "before customer workload startup and contact Microsoft Support."
    )
}
```

Verification:

```powershell
$MocResource | Format-Table Name, State, OwnerNode
$ControlPlaneGroup | Format-Table Name, State, OwnerNode
$ControlPlaneState | Format-Table VMId, Name, State
```

Expected result: MOC and the appliance clustered role are `Online`, and the appliance VM is `Running`.

### Step 5: Online workload CSVs one at a time

**Action type:** State-changing  
**Risk:** [HIGH RISK]

```powershell
foreach ($Csv in $WorkloadCsvs) {
    Set-SealedCsvState -CsvRecord $Csv -State Online
}

Get-ClusterSharedVolume | Format-Table Name, State, OwnerNode

if (@(Get-ClusterSharedVolume | Where-Object State -ne 'Online').Count -gt 0) {
    throw "At least one CSV is not Online."
}

Set-ChangePhase -Phase PlatformOnline
```

Expected result: every recorded CSV is `Online`.

Stop on the first CSV that does not return online. Do not continue to workload startup.

## Hold a clean platform state

**Action type:** [READ-ONLY]

Require all health conditions to remain continuously clean for at least five minutes. Restart the five-minute clock after any unhealthy sample.

```powershell
$CleanSince = $null
$Deadline = (Get-Date).AddMinutes(30)

do {
    $HealthFaultsNow = @(Get-HealthFault -ErrorAction Stop)
    $NodesNow = @(Get-ClusterNode)
    $UpdatesNow = @(Get-SolutionUpdate -ErrorAction Stop)
    $ActiveSolutionUpdatesNow = @($UpdatesNow | Where-Object {
        "$($_.State)" -in @('Downloading', 'Installing')
    })
    $ActiveUpdateRunsNow = @($UpdatesNow | ForEach-Object {
        @($_ | Get-SolutionUpdateRun -ErrorAction Stop |
            Where-Object { "$($_.State)" -eq 'InProgress' })
    })
    $CauNow = @(Get-CauRun -ClusterName $Cluster.Name -ErrorAction Stop)
    $QuorumNow = Get-ClusterQuorum -ErrorAction Stop
    $WitnessHealthyNow = $true
    if (-not [string]::IsNullOrWhiteSpace("$($QuorumNow.QuorumResource)")) {
        $WitnessNow = @(Get-ClusterResource `
            -Name "$($QuorumNow.QuorumResource)" -ErrorAction Stop)
        $WitnessHealthyNow = (
            $WitnessNow.Count -eq 1 -and
            "$($WitnessNow[0].State)" -eq 'Online'
        )
    }
    $PoolNow = @(Get-ClusterResource -ErrorAction Stop | Where-Object {
        "$($_.Id)" -eq "$($Pool.Id)" -and
        "$($_.Name)" -eq "$($Pool.Name)" -and
        "$($_.ResourceType)" -eq "$($Pool.ResourceType)" -and
        "$($_.OwnerGroup)" -eq "$($Pool.OwnerGroup)"
    })
    $AllCsvNow = @(Get-ClusterSharedVolume -ErrorAction Stop)
    $CsvNow = @(foreach ($CsvRecord in @($ResourceManifest.Csvs)) {
        (Get-VerifiedSealedCsv -CsvRecord $CsvRecord `
            -RequireOnlineMetadata).Csv
    })
    $VirtualDisksNow = @(Get-VirtualDisk)
    $ExpectedCsvNames = @($ResourceManifest.Csvs.Name |
        ForEach-Object { "$_".ToUpperInvariant() } | Sort-Object -Unique)
    $ActualCsvNames = @($AllCsvNow.Name |
        ForEach-Object { "$_".ToUpperInvariant() } | Sort-Object -Unique)
    $ExpectedVirtualDiskIds = @($ResourceManifest.VirtualDisks.UniqueId |
        Where-Object {
        -not [string]::IsNullOrWhiteSpace("$_")
    } | Sort-Object -Unique)
    $ActualVirtualDiskIds = @($VirtualDisksNow.UniqueId | Where-Object {
        -not [string]::IsNullOrWhiteSpace("$_")
    } | Sort-Object -Unique)
    $JobsNow = @(Get-StorageJob)
    $IntentNow = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
        -Name $StorageIntent.IntentName)
    Assert-IntentStatusCoverage -Status $IntentNow `
        -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
    $MocNow = @(Get-ClusterResource -ErrorAction Stop | Where-Object {
        "$($_.Id)" -eq "$($Moc.Id)" -and
        "$($_.Name)" -eq "$($Moc.Name)" -and
        "$($_.ResourceType)" -eq "$($Moc.ResourceType)" -and
        "$($_.OwnerGroup)" -eq "$($Moc.OwnerGroup)"
    })
    $ControlPlaneNow = @(Get-ClusterGroup -Name "$($ControlPlaneEntry.GroupName)")
    $VmGroupsNow = @(Get-ClusterGroup -ErrorAction Stop |
        Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' })
    $VmIdentityPairsNow = @(foreach ($Group in $VmGroupsNow) {
        $VmResources = @($Group | Get-ClusterResource -ErrorAction Stop |
            Where-Object { "$($_.ResourceType)" -eq 'Virtual Machine' })
        if ($VmResources.Count -ne 1) {
            throw "Expected one Virtual Machine resource in '$($Group.Name)'."
        }
        $VmIdParameters = @(Get-ClusterParameter `
            -InputObject $VmResources[0] -Name VmId -ErrorAction Stop)
        if ($VmIdParameters.Count -ne 1) {
            throw "Expected one VmId parameter in '$($Group.Name)'."
        }
        "$($Group.Id)|$($Group.Name)|$($VmIdParameters[0].Value)"
    })
    $VmStateNow = @(foreach ($Entry in $ResourceManifest.ClusteredVms) {
        $CurrentGroup = @($VmGroupsNow | Where-Object {
            "$($_.Id)" -eq "$($Entry.GroupId)" -and
            "$($_.Name)" -eq "$($Entry.GroupName)"
        })
        if ($CurrentGroup.Count -ne 1) {
            throw "A sealed clustered VM group no longer resolves uniquely."
        }
        $HyperV = @(Invoke-Command `
            -ComputerName "$($CurrentGroup[0].OwnerNode)" `
            -ArgumentList "$($Entry.VmId)" -ScriptBlock {
                param($VmId)
                Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                    Select-Object VMId, State
            } -ErrorAction Stop)
        if ($HyperV.Count -ne 1) {
            throw "A sealed VM no longer resolves uniquely."
        }
        [pscustomobject]@{
            IsControlPlane = (
                "$($Entry.GroupId)" -eq "$($ControlPlaneEntry.GroupId)"
            )
            GroupState = "$($CurrentGroup[0].State)"
            VmState = "$($HyperV[0].State)"
        }
    })

    $Healthy = (
        $HealthFaultsNow.Count -eq 0 -and
        @($NodesNow | Where-Object State -ne 'Up').Count -eq 0 -and
        $ActiveSolutionUpdatesNow.Count -eq 0 -and
        $ActiveUpdateRunsNow.Count -eq 0 -and
        $CauNow.Count -eq 0 -and
        $WitnessHealthyNow -and
        $PoolNow.Count -eq 1 -and
        "$($PoolNow[0].State)" -eq 'Online' -and
        $AllCsvNow.Count -eq $ExpectedCsvNames.Count -and
        @($ExpectedCsvNames | Where-Object {
            $_ -notin $ActualCsvNames
        }).Count -eq 0 -and
        @($ActualCsvNames | Where-Object {
            $_ -notin $ExpectedCsvNames
        }).Count -eq 0 -and
        @($CsvNow | Where-Object State -ne 'Online').Count -eq 0 -and
        $VirtualDisksNow.Count -eq $ExpectedVirtualDiskIds.Count -and
        @($ExpectedVirtualDiskIds | Where-Object {
            $_ -notin $ActualVirtualDiskIds
        }).Count -eq 0 -and
        @($ActualVirtualDiskIds | Where-Object {
            $_ -notin $ExpectedVirtualDiskIds
        }).Count -eq 0 -and
        @($VirtualDisksNow | Where-Object {
            "$($_.HealthStatus)" -ne 'Healthy' -or
            "$($_.OperationalStatus)" -notmatch 'OK'
        }).Count -eq 0 -and
        $JobsNow.Count -eq 0 -and
        @($IntentNow | Where-Object {
            "$($_.ConfigurationStatus)" -ne 'Success' -or
            "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
            [int]$_.RetryCount -gt 0 -or
            -not [string]::IsNullOrWhiteSpace("$($_.Error)")
        }).Count -eq 0 -and
        $MocNow.Count -eq 1 -and
        "$($MocNow[0].State)" -eq 'Online' -and
        @($ControlPlaneNow | Where-Object State -ne 'Online').Count -eq 0 -and
        $VmIdentityPairsNow.Count -eq $ExpectedVmIdentityPairs.Count -and
        @($ExpectedVmIdentityPairs | Where-Object {
            $_ -notin $VmIdentityPairsNow
        }).Count -eq 0 -and
        @($VmIdentityPairsNow | Where-Object {
            $_ -notin $ExpectedVmIdentityPairs
        }).Count -eq 0 -and
        @($VmStateNow | Where-Object {
            (
                $_.IsControlPlane -and
                (
                    $_.GroupState -ne 'Online' -or
                    $_.VmState -ne 'Running'
                )
            ) -or
            (
                -not $_.IsControlPlane -and
                (
                    $_.GroupState -ne 'Offline' -or
                    $_.VmState -ne 'Off'
                )
            )
        }).Count -eq 0
    )

    if ($Healthy) {
        if ($null -eq $CleanSince) {
            $CleanSince = Get-Date
        }
    } else {
        $CleanSince = $null
    }

    Start-Sleep -Seconds 30
} while (
    ((Get-Date) -lt $Deadline) -and
    ($null -eq $CleanSince -or (Get-Date) -lt $CleanSince.AddMinutes(5))
)

if ($null -eq $CleanSince -or (Get-Date) -lt $CleanSince.AddMinutes(5)) {
    throw "The platform did not maintain a continuous five-minute clean hold."
}

Set-ChangePhase -Phase StorageHoldPassed
```

Stop if the clean hold cannot complete within 30 minutes. Do not start customer workloads.

## Return workload startup to the application owner

**Action type:** [STATE-CHANGING]

**Risk:** [HIGH RISK]

**Owner:** Workload owner, with the cluster administrator monitoring storage and platform health

**Required phase:** `StorageHoldPassed`

Before authorizing any customer VM startup, prove that the durable checkpoint and the
current storage state still satisfy the startup gate:

```powershell
$StartupPhaseState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
if ("$($StartupPhaseState.Phase)" -ne 'StorageHoldPassed') {
    throw "Customer workload startup requires the durable StorageHoldPassed phase."
}

$StartupHealthFaults = @(Get-HealthFault -ErrorAction Stop)
$StartupStorageJobs = @(Get-StorageJob -ErrorAction Stop)
$StartupVirtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
$StartupCsvs = @(Get-ClusterSharedVolume -ErrorAction Stop)
$StartupBadVirtualDisks = @($StartupVirtualDisks | Where-Object {
    "$($_.HealthStatus)" -ne 'Healthy' -or
    "$($_.OperationalStatus)" -notmatch 'OK'
})
$StartupBadCsvs = @($StartupCsvs | Where-Object State -ne 'Online')

if (
    $StartupHealthFaults.Count -gt 0 -or
    $StartupStorageJobs.Count -gt 0 -or
    $StartupVirtualDisks.Count -lt 1 -or
    $StartupBadVirtualDisks.Count -gt 0 -or
    $StartupCsvs.Count -lt 1 -or
    $StartupBadCsvs.Count -gt 0
) {
    throw "Storage or platform health changed after the clean hold. Do not start customer workloads."
}
```

The application or VM owner decides the startup order and starts the customer workloads. The cluster administrator does not bulk-start VMs without workload-owner approval.

After startup, verify every recorded customer VM by its sealed VM ID. Require the
clustered VM group and Hyper-V VM to be running, and require both the `Heartbeat` and
`Shutdown` integration services to exist, be enabled, and report `OK`:

```powershell
$ResourceManifest = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'resource-manifest.json'
) -Raw | ConvertFrom-Json
$CustomerVmEntries = @($ResourceManifest.ClusteredVms | Where-Object {
    "$($_.VmId)" -ne "$($ResourceManifest.ControlPlaneVm.VmId)"
})

$VmIntegrationState = @($CustomerVmEntries | ForEach-Object {
    $Entry = $_
    $Group = Get-ClusterGroup -Name "$($Entry.GroupName)" -ErrorAction Stop
    $RemoteState = @(Invoke-Command -ComputerName "$($Group.OwnerNode)" `
        -ArgumentList "$($Entry.VmId)" -ScriptBlock {
            param($SealedVmId)

            $Vm = Get-VM -Id ([guid]$SealedVmId) -ErrorAction Stop
            $Services = @(Get-VMIntegrationService -VM $Vm -ErrorAction Stop)
            foreach ($ServiceName in @('Heartbeat', 'Shutdown')) {
                $Match = @($Services | Where-Object Name -eq $ServiceName)
                if ($Match.Count -eq 1) {
                    [pscustomobject]@{
                        VmId = "$($Vm.VMId)"
                        VmName = "$($Vm.Name)"
                        VmState = "$($Vm.State)"
                        Service = $ServiceName
                        Present = $true
                        Enabled = [bool]$Match[0].Enabled
                        PrimaryStatus = "$($Match[0].PrimaryStatusDescription)"
                        SecondaryStatus = "$($Match[0].SecondaryStatusDescription)"
                    }
                } else {
                    [pscustomobject]@{
                        VmId = "$($Vm.VMId)"
                        VmName = "$($Vm.Name)"
                        VmState = "$($Vm.State)"
                        Service = $ServiceName
                        Present = $false
                        Enabled = $false
                        PrimaryStatus = ''
                        SecondaryStatus = ''
                    }
                }
            }
        } -ErrorAction Stop)

    foreach ($Row in $RemoteState) {
        [pscustomobject]@{
            GroupName = "$($Entry.GroupName)"
            GroupState = "$($Group.State)"
            OwnerNode = "$($Group.OwnerNode)"
            VmId = "$($Row.VmId)"
            VmName = "$($Row.VmName)"
            VmState = "$($Row.VmState)"
            Service = "$($Row.Service)"
            Present = [bool]$Row.Present
            Enabled = [bool]$Row.Enabled
            PrimaryStatus = "$($Row.PrimaryStatus)"
            SecondaryStatus = "$($Row.SecondaryStatus)"
        }
    }
})

$VmIntegrationState |
    Tee-Object -FilePath (
        Join-Path $EvidenceRoot 'customer-vm-integration-services.txt'
    ) |
    Format-Table -AutoSize

$BadVmIntegrationState = @($VmIntegrationState | Where-Object {
    $_.GroupState -ne 'Online' -or
    $_.VmState -ne 'Running' -or
    -not $_.Present -or
    -not $_.Enabled -or
    $_.PrimaryStatus -ne 'OK'
})
if ($BadVmIntegrationState.Count -gt 0) {
    throw "A customer VM or required Hyper-V integration service is not healthy."
}
```

The workload owner must also confirm:

- Every application dependency started in the approved order.
- Application health probes pass.
- Client transactions or representative synthetic tests pass.
- No application reports storage timeout, failover, or data-consistency errors.
- The agreed customer communication checkpoint records service restoration.

Do not treat `Running` VM state as proof that the application is healthy.

If VM startup, either integration-service check, an application probe, or storage
health fails, stop starting additional workloads. The workload owner must shut down
the newly started customer VMs in dependency order. Preserve the evidence, restore a
clean storage hold, and obtain rollback approval before entering the documented
rollback sequence. Do not proceed to representative load or active validation while
any startup or health failure remains.

## Validate active RDMA under representative load

Static adapter state and `Get-SmbMultichannelConnection` alone do not prove that the recovered storage workload is actively using the persisted desired transport. Use an approved representative workload, then combine all of the following:

Before starting representative load, seal the beginning of the active-validation window:

```powershell
$ActiveValidationStartUtcPath = Join-Path $EvidenceRoot `
    "active-validation-$Operation-start-utc.txt"
$CurrentPhaseState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
if ("$($CurrentPhaseState.Phase)" -eq 'StorageHoldPassed') {
    if (Test-Path -LiteralPath $ActiveValidationStartUtcPath) {
        throw (
            "An active-validation start timestamp already exists before the " +
            "ActiveValidationStarted checkpoint. Stop and review the evidence."
        )
    }

    $StartText = (Get-Date).ToUniversalTime().ToString('o')
    Set-ChangePhase -Phase ActiveValidationStarted `
        -ActiveValidationStartUtc $StartText
} elseif ("$($CurrentPhaseState.Phase)" -eq 'ActiveValidationStarted') {
    $StartText = "$($CurrentPhaseState.ActiveValidationStartUtc)"
    if ([string]::IsNullOrWhiteSpace($StartText)) {
        throw "The durable active-validation start timestamp is missing."
    }
} else {
    throw (
        "Active validation can start only after StorageHoldPassed or resume " +
        "from ActiveValidationStarted."
    )
}

$DurableStartUtc = [datetime]::Parse($StartText).ToUniversalTime()
if (Test-Path -LiteralPath $ActiveValidationStartUtcPath) {
    $ArtifactStartUtc = [datetime]::Parse(
        "$(Get-Content -LiteralPath $ActiveValidationStartUtcPath -Raw)"
    ).ToUniversalTime()
    if ($ArtifactStartUtc -ne $DurableStartUtc) {
        throw "The active-validation artifact does not match phase state."
    }
} else {
    try {
        $StartFile = [System.IO.File]::Open(
            $ActiveValidationStartUtcPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        try {
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes(
                $DurableStartUtc.ToString('o')
            )
            $StartFile.Write($Bytes, 0, $Bytes.Length)
        } finally {
            $StartFile.Dispose()
        }
    } catch {
        throw "Could not create the active-validation evidence file: $($_.Exception.Message)"
    }
}
```

After the workload owner completes application health probes, dependency checks, and representative transactions, have that owner approve the evidence and create the required attestation:

```powershell
[pscustomobject]@{
    RecordedUtc = (Get-Date).ToUniversalTime().ToString('o')
    RecordedBy = $env:USERNAME
    HealthProbesPassed = $true
    DependencyChecksPassed = $true
    RepresentativeTransactionsPassed = $true
} | ConvertTo-Json |
    Set-Content -LiteralPath (
        Join-Path $EvidenceRoot "application-validation-$Operation.json"
    ) -ErrorAction Stop
```

Do not create the attestation until the checks have actually passed. The final validation block rejects a missing, stale, incomplete, or failed attestation.

```powershell
$ActiveValidationStartUtcPath = Join-Path $EvidenceRoot `
    "active-validation-$Operation-start-utc.txt"
$ApplicationValidationPath = Join-Path $EvidenceRoot `
    "application-validation-$Operation.json"
if (
    -not (Test-Path -LiteralPath $ActiveValidationStartUtcPath) -or
    -not (Test-Path -LiteralPath $ApplicationValidationPath)
) {
    throw "Active-validation start time or application-owner attestation is missing."
}
$CurrentPhaseState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace(
    "$($CurrentPhaseState.ActiveValidationStartUtc)"
)) {
    throw "The active-validation start time is missing from phase state."
}
$ActiveValidationStartUtc = [datetime]::Parse(
    "$($CurrentPhaseState.ActiveValidationStartUtc)"
).ToUniversalTime()
$ArtifactStartUtc = [datetime]::Parse(
    "$(Get-Content -LiteralPath $ActiveValidationStartUtcPath -Raw)"
).ToUniversalTime()
if ($ArtifactStartUtc -ne $ActiveValidationStartUtc) {
    throw "The active-validation artifact does not match phase state."
}
$ApplicationValidation = Get-Content -LiteralPath `
    $ApplicationValidationPath -Raw | ConvertFrom-Json
$ApplicationValidationUtc = [datetime]::Parse(
    "$($ApplicationValidation.RecordedUtc)"
).ToUniversalTime()
$ExpectedVmIdentityPairs = @($ResourceManifest.ClusteredVms |
    ForEach-Object {
        "$($_.GroupId)|$($_.GroupName)|$($_.VmId)"
    })
if (
    $ApplicationValidationUtc -lt $ActiveValidationStartUtc -or
    [string]::IsNullOrWhiteSpace("$($ApplicationValidation.RecordedBy)") -or
    -not [bool]$ApplicationValidation.HealthProbesPassed -or
    -not [bool]$ApplicationValidation.DependencyChecksPassed -or
    -not [bool]$ApplicationValidation.RepresentativeTransactionsPassed
) {
    throw "Application-owner validation is stale, incomplete, or failed."
}

# Network ATC remains converged
$FinalIntentStatus = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
    -Name $StorageIntent.IntentName -ErrorAction Stop)
$FinalIntentStatus |
    Format-Table Host, IntentName, ConfigurationStatus, ProvisioningStatus, RetryCount, Error
Assert-IntentStatusCoverage -Status $FinalIntentStatus `
    -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
$BadFinalIntentStatus = @($FinalIntentStatus | Where-Object {
    "$($_.ConfigurationStatus)" -ne 'Success' -or
    "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
    [int]$_.RetryCount -gt 0 -or
    -not [string]::IsNullOrWhiteSpace("$($_.Error)")
})
if ($BadFinalIntentStatus.Count -gt 0) {
    throw "Network ATC is not clean on every node after active workload validation."
}
$FinalIntent = @(Get-NetIntent -ClusterName $Cluster.Name `
    -ErrorAction Stop | Where-Object {
        "$($_.IntentName)" -eq "$($StorageIntent.IntentName)"
    })
if ($FinalIntent.Count -ne 1) {
    throw "The final storage intent no longer resolves uniquely."
}
Assert-AdapterOverrideReadback `
    -LiveOverride $FinalIntent[0].AdapterAdvancedParametersOverride `
    -SealedOverrides $ExplicitAdapterOverrides `
    -ExpectedTransportValue $DesiredTransportValue

# Every storage adapter remains on the desired transport and RDMA remains enabled
$FinalAdapterState = @(Invoke-Command -ComputerName $Nodes.Name `
    -ArgumentList ($AdapterNames -join ','), $DesiredTransportValue -ScriptBlock {
        param($AdapterCsv, $ExpectedTransportValue)
        foreach ($Name in @($AdapterCsv -split ',')) {
            $AdapterName = $Name.Trim()
            $Adapter = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
            $Transport = Get-NetAdapterAdvancedProperty -Name $AdapterName `
                -RegistryKeyword '*NetworkDirectTechnology' -ErrorAction Stop
            $Rdma = Get-NetAdapterRdma -Name $AdapterName -ErrorAction Stop
            [pscustomobject]@{
                Node = $env:COMPUTERNAME
                Adapter = $AdapterName
                Status = "$($Adapter.Status)"
                RdmaEnabled = [bool]$Rdma.Enabled
                TransportValue = [int]$Transport.RegistryValue[0]
                TransportName = "$($Transport.DisplayValue)"
                IsDesired = [int]$Transport.RegistryValue[0] -eq $ExpectedTransportValue
            }
        }
    } -ErrorAction Stop)
$FinalAdapterState | Format-Table -AutoSize

$ExpectedAdapterPairs = @(
    foreach ($Node in $Nodes) {
        $NodeName = "$($Node.Name)".Split('.')[0].ToUpperInvariant()
        foreach ($AdapterName in $AdapterNames) {
            "$NodeName|$("$AdapterName".Trim().ToUpperInvariant())"
        }
    }
)
$ActualAdapterPairs = @($FinalAdapterState | ForEach-Object {
    "$("$($_.Node)".Split('.')[0].ToUpperInvariant())|$("$($_.Adapter)".Trim().ToUpperInvariant())"
})
$MissingAdapterPairs = @($ExpectedAdapterPairs | Where-Object {
    $_ -notin $ActualAdapterPairs
})
$UnknownAdapterPairs = @($ActualAdapterPairs | Where-Object {
    $_ -notin $ExpectedAdapterPairs
})
$DuplicateAdapterPairs = @($ActualAdapterPairs | Group-Object |
    Where-Object Count -ne 1)
$BadFinalAdapters = @($FinalAdapterState | Where-Object {
    $_.Status -ne 'Up' -or -not $_.RdmaEnabled -or -not $_.IsDesired
})
if (
    $FinalAdapterState.Count -ne $ExpectedAdapterPairs.Count -or
    $MissingAdapterPairs.Count -gt 0 -or
    $UnknownAdapterPairs.Count -gt 0 -or
    $DuplicateAdapterPairs.Count -gt 0 -or
    $BadFinalAdapters.Count -gt 0
) {
    throw "Final storage-adapter coverage or desired transport state is incomplete."
}

# SBL peers are RDMA-capable after storage traffic resumes
$SblConnections = @(Invoke-Command -ComputerName $Nodes.Name -ScriptBlock {
    foreach ($Connection in @(Get-SmbMultichannelConnection `
        -SmbInstance SBL -ErrorAction Stop)) {
        $RequiredProperties = @(
            'ClientRdmaCapable',
            'ServerRdmaCapable',
            'Selected',
            'CurrentChannels',
            'Failed',
            'FailureCount'
        )
        $MissingProperties = @($RequiredProperties | Where-Object {
            $null -eq $Connection.PSObject.Properties[$_]
        })
        if ($MissingProperties.Count -gt 0) {
            throw (
                "The SBL connection object does not expose required " +
                "active-channel properties: $($MissingProperties -join ',')."
            )
        }
        $Connection | Select-Object `
            @{Name='Node';Expression={$env:COMPUTERNAME}},
                ServerName, ClientInterfaceIndex,
                ServerInterfaceIndex, ClientIpAddress, ServerIpAddress,
                ClientRdmaCapable, ServerRdmaCapable, Selected,
                CurrentChannels, MaxChannels, Failed, FailureCount
    }
} -ErrorAction Stop)
$SblConnections | Format-Table -AutoSize
$BadSblConnections = @($SblConnections | Where-Object {
    -not $_.ClientRdmaCapable -or
    -not $_.ServerRdmaCapable -or
    -not $_.Selected -or
    [int]$_.CurrentChannels -lt 1 -or
    [bool]$_.Failed -or
    [int]$_.FailureCount -ne 0
})
$ExpectedSblNodes = @($Nodes.Name | ForEach-Object {
    "$_".Split('.')[0].ToUpperInvariant()
})
$ActualSblNodes = @($SblConnections.Node | ForEach-Object {
    "$_".Split('.')[0].ToUpperInvariant()
} | Sort-Object -Unique)
$MissingSblNodes = @($ExpectedSblNodes | Where-Object {
    $_ -notin $ActualSblNodes
})
$UnknownSblNodes = @($ActualSblNodes | Where-Object {
    $_ -notin $ExpectedSblNodes
})
if (
    $SblConnections.Count -lt 1 -or
    $MissingSblNodes.Count -gt 0 -or
    $UnknownSblNodes.Count -gt 0 -or
    $BadSblConnections.Count -gt 0
) {
    throw (
        "Every sealed node must report a selected, RDMA-capable active SBL " +
        "connection with at least one current channel and no failed-channel " +
        "state or failure count."
    )
}

# Storage and cluster health remain clean
$FinalHealthFaults = @(Get-HealthFault -ErrorAction Stop)
$FinalStorageJobs = @(Get-StorageJob -ErrorAction Stop)
$FinalPools = @(Get-StoragePool -IsPrimordial $false -ErrorAction Stop)
$FinalVirtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
$FinalCsvs = @(Get-ClusterSharedVolume -ErrorAction Stop)
$FinalHealthFaults
$FinalStorageJobs
$FinalPools | Format-Table FriendlyName, HealthStatus, OperationalStatus
$FinalVirtualDisks | Format-Table FriendlyName, HealthStatus, OperationalStatus
$FinalCsvs | Format-Table Name, State, OwnerNode

$FinalMoc = @(Get-ClusterResource | Where-Object {
    "$($_.Id)" -eq "$($Moc.Id)" -and "$($_.Name)" -eq "$($Moc.Name)"
})
$FinalControlPlane = @(Get-ClusterGroup | Where-Object {
    "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
    "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
})
$CurrentClusteredVmGroups = @(Get-ClusterGroup -ErrorAction Stop |
    Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' })
$ActualVmIdentityPairs = @(foreach ($Group in $CurrentClusteredVmGroups) {
    $VmResources = @($Group | Get-ClusterResource -ErrorAction Stop |
        Where-Object { "$($_.ResourceType)" -eq 'Virtual Machine' })
    if ($VmResources.Count -ne 1) {
        throw "Expected one Virtual Machine resource in '$($Group.Name)'."
    }
    $VmIdParameters = @(Get-ClusterParameter -InputObject $VmResources[0] `
        -Name VmId -ErrorAction Stop)
    if ($VmIdParameters.Count -ne 1) {
        throw "Expected one VmId parameter in '$($Group.Name)'."
    }
    "$($Group.Id)|$($Group.Name)|$($VmIdParameters[0].Value)"
})
$MissingVmIdentityPairs = @($ExpectedVmIdentityPairs | Where-Object {
    $_ -notin $ActualVmIdentityPairs
})
$UnknownVmIdentityPairs = @($ActualVmIdentityPairs | Where-Object {
    $_ -notin $ExpectedVmIdentityPairs
})
$DuplicateVmIdentityPairs = @($ActualVmIdentityPairs | Group-Object |
    Where-Object Count -ne 1)
$FinalCustomerVmGroups = @($ResourceManifest.ClusteredVms |
    Where-Object { "$($_.VmId)" -ne "$($ControlPlaneEntry.VmId)" } |
    ForEach-Object {
        $SealedVm = $_
        @(Get-ClusterGroup | Where-Object {
            "$($_.Id)" -eq "$($SealedVm.GroupId)" -and
            "$($_.Name)" -eq "$($SealedVm.GroupName)"
        })
    })

if (
    $FinalHealthFaults.Count -gt 0 -or
    $FinalStorageJobs.Count -gt 0 -or
    $FinalPools.Count -ne 1 -or
    "$($FinalPools[0].HealthStatus)" -ne 'Healthy' -or
    "$($FinalPools[0].OperationalStatus)" -notmatch 'OK' -or
    $FinalVirtualDisks.Count -lt 1 -or
    @($FinalVirtualDisks | Where-Object {
        "$($_.HealthStatus)" -ne 'Healthy' -or
        "$($_.OperationalStatus)" -notmatch 'OK'
    }).Count -gt 0 -or
    $FinalCsvs.Count -lt 1 -or
    @($FinalCsvs | Where-Object State -ne 'Online').Count -gt 0 -or
    $FinalMoc.Count -ne 1 -or "$($FinalMoc[0].State)" -ne 'Online' -or
    $FinalControlPlane.Count -ne 1 -or
    "$($FinalControlPlane[0].State)" -ne 'Online' -or
    $ActualVmIdentityPairs.Count -ne $ExpectedVmIdentityPairs.Count -or
    $MissingVmIdentityPairs.Count -gt 0 -or
    $UnknownVmIdentityPairs.Count -gt 0 -or
    $DuplicateVmIdentityPairs.Count -gt 0 -or
    $FinalCustomerVmGroups.Count -ne (
        @($ResourceManifest.ClusteredVms |
            Where-Object { "$($_.VmId)" -ne "$($ControlPlaneEntry.VmId)" }).Count
    ) -or
    @($FinalCustomerVmGroups | Where-Object State -ne 'Online').Count -gt 0
) {
    throw "Final platform, storage, or workload state is not clean and complete."
}

Set-ChangePhase -Phase ActiveAssertionsPassed
```

If the session ends after `ActiveAssertionsPassed`, rerun the resume block and then run the following block. It reconstructs adapter coverage on every sample and does not depend on variables from the lost session.

```powershell
function Test-ActiveRdmaState {
    $AdapterState = @(Invoke-Command -ComputerName $Nodes.Name `
        -ArgumentList ($AdapterNames -join ','), $DesiredTransportValue `
        -ScriptBlock {
            param($AdapterCsv, $ExpectedTransportValue)
            foreach ($Name in @($AdapterCsv -split ',')) {
                $AdapterName = $Name.Trim()
                $Adapter = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
                $Transport = Get-NetAdapterAdvancedProperty -Name $AdapterName `
                    -RegistryKeyword '*NetworkDirectTechnology' `
                    -ErrorAction Stop
                $Rdma = Get-NetAdapterRdma -Name $AdapterName -ErrorAction Stop
                [pscustomobject]@{
                    Node = $env:COMPUTERNAME
                    Adapter = $AdapterName
                    Status = "$($Adapter.Status)"
                    RdmaEnabled = [bool]$Rdma.Enabled
                    TransportValue = [int]$Transport.RegistryValue[0]
                    IsDesired = (
                        [int]$Transport.RegistryValue[0] -eq
                            $ExpectedTransportValue
                    )
                }
            }
        } -ErrorAction Stop)
    $ExpectedPairs = @(
        foreach ($Node in $Nodes) {
            $NodeName = "$($Node.Name)".Split('.')[0].ToUpperInvariant()
            foreach ($AdapterName in $AdapterNames) {
                "$NodeName|$("$AdapterName".Trim().ToUpperInvariant())"
            }
        }
    )
    $ActualPairs = @($AdapterState | ForEach-Object {
        "$("$($_.Node)".Split('.')[0].ToUpperInvariant())|$("$($_.Adapter)".Trim().ToUpperInvariant())"
    })
    $AdaptersHealthy = (
        $AdapterState.Count -eq $ExpectedPairs.Count -and
        @($ExpectedPairs | Where-Object {
            $_ -notin $ActualPairs
        }).Count -eq 0 -and
        @($ActualPairs | Where-Object {
            $_ -notin $ExpectedPairs
        }).Count -eq 0 -and
        @($ActualPairs | Group-Object |
            Where-Object Count -ne 1).Count -eq 0 -and
        @($AdapterState | Where-Object {
            $_.Status -ne 'Up' -or
            -not $_.RdmaEnabled -or
            -not $_.IsDesired
        }).Count -eq 0
    )

    $SblConnections = @(Invoke-Command -ComputerName $Nodes.Name `
        -ScriptBlock {
            foreach ($Connection in @(Get-SmbMultichannelConnection `
                -SmbInstance SBL -ErrorAction Stop)) {
                $RequiredProperties = @(
                    'ClientRdmaCapable',
                    'ServerRdmaCapable',
                    'Selected',
                    'CurrentChannels',
                    'Failed',
                    'FailureCount'
                )
                $MissingProperties = @($RequiredProperties | Where-Object {
                    $null -eq $Connection.PSObject.Properties[$_]
                })
                if ($MissingProperties.Count -gt 0) {
                    throw (
                        "The SBL connection object does not expose required " +
                        "active-channel properties: " +
                        "$($MissingProperties -join ',')."
                    )
                }
                $Connection | Select-Object `
                    @{Name='Node';Expression={$env:COMPUTERNAME}},
                    ClientIpAddress, ServerIpAddress, ClientRdmaCapable,
                    ServerRdmaCapable, Selected, CurrentChannels,
                    MaxChannels, Failed, FailureCount
            }
        } -ErrorAction Stop)
    $ExpectedSblNodes = @($Nodes.Name | ForEach-Object {
        "$_".Split('.')[0].ToUpperInvariant()
    })
    $ActualSblNodes = @($SblConnections.Node | ForEach-Object {
        "$_".Split('.')[0].ToUpperInvariant()
    } | Sort-Object -Unique)
    $SblHealthy = (
        $SblConnections.Count -gt 0 -and
        @($ExpectedSblNodes | Where-Object {
            $_ -notin $ActualSblNodes
        }).Count -eq 0 -and
        @($ActualSblNodes | Where-Object {
            $_ -notin $ExpectedSblNodes
        }).Count -eq 0 -and
        @($SblConnections | Where-Object {
            -not $_.ClientRdmaCapable -or
            -not $_.ServerRdmaCapable -or
            -not $_.Selected -or
            [int]$_.CurrentChannels -lt 1 -or
            [bool]$_.Failed -or
            [int]$_.FailureCount -ne 0
        }).Count -eq 0
    )

    return ($AdaptersHealthy -and $SblHealthy)
}

# Establish one create-only terminal failure path before event validation or holds
$FinalHoldPhaseState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
$FinalHoldPhase = "$($FinalHoldPhaseState.Phase)"
if ($FinalHoldPhase -ne 'ActiveAssertionsPassed') {
    throw (
        "Active validation requires phase ActiveAssertionsPassed. Current " +
        "durable phase is '$FinalHoldPhase'."
    )
}
$ActiveValidationFailurePath = Join-Path $EvidenceRoot `
    "active-validation-$Operation-terminal-failure.json"
if (Test-Path -LiteralPath $ActiveValidationFailurePath) {
    throw (
        "An undispositioned active-validation failure artifact already " +
        "exists at '$ActiveValidationFailurePath'. Preserve and disposition " +
        "that failure before starting another attempt."
    )
}

# Reject cluster and SMB RDMA events from the representative-load window
$ValidationAttemptId = (
    "$(Get-Date -Format 'yyyyMMdd-HHmmss')-" +
    "$([guid]::NewGuid().ToString('N'))"
)
$ActiveClusterEventPath = Join-Path $EvidenceRoot `
    "active-validation-$Operation-$ValidationAttemptId-cluster-events.csv"
$ActiveSmbRdmaEventPath = Join-Path $EvidenceRoot `
    "active-validation-$Operation-$ValidationAttemptId-smb-rdma-events.csv"
try {
    $ActiveClusterEvents = @(Invoke-Command -ComputerName $Nodes.Name `
        -ArgumentList $ActiveValidationStartUtc -ScriptBlock {
            param($StartTime)
            try {
                Get-WinEvent -FilterHashtable @{
                    LogName = 'System'
                    ProviderName = 'Microsoft-Windows-FailoverClustering'
                    Id = 1069, 1135, 1177, 5120, 5142
                    StartTime = $StartTime
                } -ErrorAction Stop |
                    Select-Object MachineName, TimeCreated, Id,
                        LevelDisplayName, Message
            } catch {
                if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                    throw
                }
            }
        } -ErrorAction Stop)
    $ActiveSmbRdmaEvents = @(Invoke-Command -ComputerName $Nodes.Name `
        -ArgumentList $ActiveValidationStartUtc -ScriptBlock {
            param($StartTime)
            foreach ($Log in @(Get-WinEvent -ListLog '*SMB*' `
                -ErrorAction Stop | Where-Object IsEnabled)) {
                try {
                    Get-WinEvent -FilterHashtable @{
                        LogName = $Log.LogName
                        StartTime = $StartTime
                    } -ErrorAction Stop |
                        Where-Object {
                            $_.Level -le 3 -and $_.Message -match 'RDMA'
                        } |
                        Select-Object MachineName, TimeCreated, Id,
                            LevelDisplayName, ProviderName, Message
                } catch {
                    if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                        throw
                    }
                }
            }
        } -ErrorAction Stop)
    $ActiveClusterEvents | Export-Csv -NoTypeInformation -NoClobber `
        -LiteralPath $ActiveClusterEventPath
    $ActiveSmbRdmaEvents | Export-Csv -NoTypeInformation -NoClobber `
        -LiteralPath $ActiveSmbRdmaEventPath
    if ($ActiveClusterEvents.Count -gt 0 -or $ActiveSmbRdmaEvents.Count -gt 0) {
        $ActiveEventFailureJson = [pscustomobject]@{
            ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
            Phase = $FinalHoldPhase
            FailureKind = 'ActiveEventValidation'
            ClusterEventCount = $ActiveClusterEvents.Count
            SmbRdmaEventCount = $ActiveSmbRdmaEvents.Count
            ClusterEventEvidence = $ActiveClusterEventPath
            SmbRdmaEventEvidence = $ActiveSmbRdmaEventPath
        } | ConvertTo-Json -Depth 8
        New-Item -ItemType File -Path $ActiveValidationFailurePath `
            -Value $ActiveEventFailureJson -ErrorAction Stop | Out-Null
        throw "Active validation found new cluster-impact or SMB RDMA events."
    }
} catch {
    if (-not (Test-Path -LiteralPath $ActiveValidationFailurePath)) {
        $ActiveEventExceptionJson = [pscustomobject]@{
            ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
            Phase = $FinalHoldPhase
            FailureKind = 'ActiveEventCollectionException'
            ExceptionType = "$($_.Exception.GetType().FullName)"
            ExceptionMessage = "$($_.Exception.Message)"
            ErrorRecord = "$_"
            ClusterEventEvidence = $ActiveClusterEventPath
            SmbRdmaEventEvidence = $ActiveSmbRdmaEventPath
        } | ConvertTo-Json -Depth 8
        New-Item -ItemType File -Path $ActiveValidationFailurePath `
            -Value $ActiveEventExceptionJson -ErrorAction Stop | Out-Null
    }
    throw
}

# Require a final continuous five-minute clean hold
$FinalCleanSince = $null
$FinalDeadline = (Get-Date).AddMinutes(30)
do {
    try {
    $FinalHoldSampleId = (
        "$(Get-Date -Format 'yyyyMMdd-HHmmss')-" +
        "$([guid]::NewGuid().ToString('N'))"
    )
    $FinalHoldClusterEventPath = Join-Path $EvidenceRoot `
        "active-validation-$Operation-$FinalHoldSampleId-final-hold-cluster-events.csv"
    $FinalHoldSmbEventPath = Join-Path $EvidenceRoot `
        "active-validation-$Operation-$FinalHoldSampleId-final-hold-smb-rdma-events.csv"
    $FinalHoldHealthFaults = @(Get-HealthFault -ErrorAction Stop)
    $FinalHoldStorageJobs = @(Get-StorageJob -ErrorAction Stop)
    $FinalHoldNodes = @(Get-ClusterNode -ErrorAction Stop)
    $FinalHoldUpdates = @(Get-SolutionUpdate -ErrorAction Stop)
    $FinalHoldActiveUpdates = @($FinalHoldUpdates | Where-Object {
        "$($_.State)" -in @('Downloading', 'Installing')
    })
    $FinalHoldActiveUpdateRuns = @($FinalHoldUpdates | ForEach-Object {
        @($_ | Get-SolutionUpdateRun -ErrorAction Stop |
            Where-Object { "$($_.State)" -eq 'InProgress' })
    })
    $FinalHoldCau = @(Get-CauRun -ClusterName $Cluster.Name `
        -ErrorAction Stop)
    $FinalHoldQuorum = Get-ClusterQuorum -ErrorAction Stop
    $FinalHoldWitnessHealthy = $true
    if (-not [string]::IsNullOrWhiteSpace(
        "$($FinalHoldQuorum.QuorumResource)"
    )) {
        $FinalHoldWitness = @(Get-ClusterResource `
            -Name "$($FinalHoldQuorum.QuorumResource)" -ErrorAction Stop)
        $FinalHoldWitnessHealthy = (
            $FinalHoldWitness.Count -eq 1 -and
            "$($FinalHoldWitness[0].State)" -eq 'Online'
        )
    }
    $FinalHoldPool = @(Get-ClusterResource -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($Pool.Id)" -and
            "$($_.Name)" -eq "$($Pool.Name)" -and
            "$($_.ResourceType)" -eq "$($Pool.ResourceType)" -and
            "$($_.OwnerGroup)" -eq "$($Pool.OwnerGroup)"
        })
    $FinalHoldAllCsvs = @(Get-ClusterSharedVolume -ErrorAction Stop)
    $FinalHoldCsvs = @()
    $FinalHoldCsvIdentityErrors = @()
    foreach ($CsvRecord in @($ResourceManifest.Csvs)) {
        try {
            $FinalHoldCsvs += (
                Get-VerifiedSealedCsv -CsvRecord $CsvRecord `
                    -RequireOnlineMetadata
            ).Csv
        } catch {
            $FinalHoldCsvIdentityErrors += $_.Exception.Message
        }
    }
    $FinalHoldVirtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
    $FinalHoldExpectedCsvNames = @($ResourceManifest.Csvs.Name |
        ForEach-Object { "$_".ToUpperInvariant() } | Sort-Object -Unique)
    $FinalHoldActualCsvNames = @($FinalHoldAllCsvs.Name |
        ForEach-Object { "$_".ToUpperInvariant() } | Sort-Object -Unique)
    $FinalHoldExpectedVirtualDiskIds = @(
        $ResourceManifest.VirtualDisks.UniqueId | Where-Object {
            -not [string]::IsNullOrWhiteSpace("$_")
        } | Sort-Object -Unique
    )
    $FinalHoldActualVirtualDiskIds = @(
        $FinalHoldVirtualDisks.UniqueId | Where-Object {
            -not [string]::IsNullOrWhiteSpace("$_")
        } | Sort-Object -Unique
    )
    $FinalHoldMoc = @(Get-ClusterResource -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($Moc.Id)" -and
            "$($_.Name)" -eq "$($Moc.Name)" -and
            "$($_.ResourceType)" -eq "$($Moc.ResourceType)" -and
            "$($_.OwnerGroup)" -eq "$($Moc.OwnerGroup)"
        })
    $FinalHoldControlPlane = @(Get-ClusterGroup `
        -Name "$($ControlPlaneEntry.GroupName)" -ErrorAction Stop)
    $FinalHoldVmGroups = @(Get-ClusterGroup -ErrorAction Stop |
        Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' })
    $FinalHoldVmIdentityPairs = @(foreach ($Group in $FinalHoldVmGroups) {
        $VmResources = @($Group | Get-ClusterResource -ErrorAction Stop |
            Where-Object { "$($_.ResourceType)" -eq 'Virtual Machine' })
        if ($VmResources.Count -ne 1) {
            throw "Expected one Virtual Machine resource in '$($Group.Name)'."
        }
        $VmIdParameters = @(Get-ClusterParameter `
            -InputObject $VmResources[0] -Name VmId -ErrorAction Stop)
        if ($VmIdParameters.Count -ne 1) {
            throw "Expected one VmId parameter in '$($Group.Name)'."
        }
        "$($Group.Id)|$($Group.Name)|$($VmIdParameters[0].Value)"
    })
    $FinalHoldVmState = @(foreach ($Entry in $ResourceManifest.ClusteredVms) {
        $CurrentGroup = @($FinalHoldVmGroups | Where-Object {
            "$($_.Id)" -eq "$($Entry.GroupId)" -and
            "$($_.Name)" -eq "$($Entry.GroupName)"
        })
        if ($CurrentGroup.Count -ne 1) {
            throw "A sealed clustered VM group no longer resolves uniquely."
        }
        $HyperV = @(Invoke-Command `
            -ComputerName "$($CurrentGroup[0].OwnerNode)" `
            -ArgumentList "$($Entry.VmId)" -ScriptBlock {
                param($VmId)
                Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                    Select-Object VMId, State
            } -ErrorAction Stop)
        if ($HyperV.Count -ne 1) {
            throw "A sealed VM no longer resolves uniquely."
        }
        [pscustomobject]@{
            GroupName = "$($Entry.GroupName)"
            GroupState = "$($CurrentGroup[0].State)"
            VmState = "$($HyperV[0].State)"
        }
    })
    $FinalHoldIntent = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
        -Name $StorageIntent.IntentName -ErrorAction Stop)
    Assert-IntentStatusCoverage -Status $FinalHoldIntent `
        -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
    $FinalHoldRdmaHealthy = Test-ActiveRdmaState
    $FinalHoldEvents = @(Invoke-Command -ComputerName $Nodes.Name `
        -ArgumentList $ActiveValidationStartUtc -ScriptBlock {
            param($StartTime)
            try {
                Get-WinEvent -FilterHashtable @{
                    LogName = 'System'
                    ProviderName = 'Microsoft-Windows-FailoverClustering'
                    Id = 1069, 1135, 1177, 5120, 5142
                    StartTime = $StartTime
                } -ErrorAction Stop
            } catch {
                if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                    throw
                }
            }
        } -ErrorAction Stop)
    $FinalHoldSmbEvents = @(Invoke-Command -ComputerName $Nodes.Name `
        -ArgumentList $ActiveValidationStartUtc -ScriptBlock {
            param($StartTime)
            foreach ($Log in @(Get-WinEvent -ListLog '*SMB*' `
                -ErrorAction Stop | Where-Object IsEnabled)) {
                try {
                    Get-WinEvent -FilterHashtable @{
                        LogName = $Log.LogName
                        StartTime = $StartTime
                    } -ErrorAction Stop |
                        Where-Object {
                            $_.Level -le 3 -and $_.Message -match 'RDMA'
                        }
                } catch {
                    if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                        throw
                    }
                }
            }
        } -ErrorAction Stop)
    $FinalHoldEvents | Export-Csv -NoTypeInformation -NoClobber `
        -LiteralPath $FinalHoldClusterEventPath
    $FinalHoldSmbEvents | Export-Csv -NoTypeInformation -NoClobber `
        -LiteralPath $FinalHoldSmbEventPath

    $FinalHealthy = (
        $FinalHoldHealthFaults.Count -eq 0 -and
        $FinalHoldStorageJobs.Count -eq 0 -and
        @($FinalHoldNodes | Where-Object State -ne 'Up').Count -eq 0 -and
        $FinalHoldActiveUpdates.Count -eq 0 -and
        $FinalHoldActiveUpdateRuns.Count -eq 0 -and
        $FinalHoldCau.Count -eq 0 -and
        $FinalHoldWitnessHealthy -and
        $FinalHoldPool.Count -eq 1 -and
        "$($FinalHoldPool[0].State)" -eq 'Online' -and
        $FinalHoldAllCsvs.Count -eq $FinalHoldExpectedCsvNames.Count -and
        @($FinalHoldExpectedCsvNames | Where-Object {
            $_ -notin $FinalHoldActualCsvNames
        }).Count -eq 0 -and
        @($FinalHoldActualCsvNames | Where-Object {
            $_ -notin $FinalHoldExpectedCsvNames
        }).Count -eq 0 -and
        $FinalHoldCsvIdentityErrors.Count -eq 0 -and
        $FinalHoldCsvs.Count -eq $FinalHoldExpectedCsvNames.Count -and
        @($FinalHoldCsvs | Where-Object State -ne 'Online').Count -eq 0 -and
        $FinalHoldVirtualDisks.Count -eq `
            $FinalHoldExpectedVirtualDiskIds.Count -and
        @($FinalHoldExpectedVirtualDiskIds | Where-Object {
            $_ -notin $FinalHoldActualVirtualDiskIds
        }).Count -eq 0 -and
        @($FinalHoldActualVirtualDiskIds | Where-Object {
            $_ -notin $FinalHoldExpectedVirtualDiskIds
        }).Count -eq 0 -and
        @($FinalHoldVirtualDisks | Where-Object {
            "$($_.HealthStatus)" -ne 'Healthy' -or
            "$($_.OperationalStatus)" -notmatch 'OK'
        }).Count -eq 0 -and
        $FinalHoldMoc.Count -eq 1 -and
        "$($FinalHoldMoc[0].State)" -eq 'Online' -and
        $FinalHoldControlPlane.Count -eq 1 -and
        "$($FinalHoldControlPlane[0].State)" -eq 'Online' -and
        $FinalHoldVmIdentityPairs.Count -eq $ExpectedVmIdentityPairs.Count -and
        @($ExpectedVmIdentityPairs | Where-Object {
            $_ -notin $FinalHoldVmIdentityPairs
        }).Count -eq 0 -and
        @($FinalHoldVmIdentityPairs | Where-Object {
            $_ -notin $ExpectedVmIdentityPairs
        }).Count -eq 0 -and
        @($FinalHoldVmGroups | Where-Object State -ne 'Online').Count -eq 0 -and
        @($FinalHoldVmState | Where-Object {
            $_.GroupState -ne 'Online' -or $_.VmState -ne 'Running'
        }).Count -eq 0 -and
        @($FinalHoldIntent | Where-Object {
            "$($_.ConfigurationStatus)" -ne 'Success' -or
            "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
            [int]$_.RetryCount -gt 0 -or
            -not [string]::IsNullOrWhiteSpace("$($_.Error)")
        }).Count -eq 0 -and
        $FinalHoldRdmaHealthy -and
        $FinalHoldEvents.Count -eq 0 -and
        $FinalHoldSmbEvents.Count -eq 0
    )

    if ($FinalHealthy) {
        if ($null -eq $FinalCleanSince) {
            $FinalCleanSince = Get-Date
        }
    } else {
        $FinalHoldFailureJson = [pscustomobject]@{
            ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
            Phase = $FinalHoldPhase
            HealthFaultCount = $FinalHoldHealthFaults.Count
            StorageJobCount = $FinalHoldStorageJobs.Count
            ActiveSolutionUpdates = @($FinalHoldActiveUpdates |
                ForEach-Object { "$($_.Name):$($_.State)" })
            ActiveUpdateRunCount = $FinalHoldActiveUpdateRuns.Count
            CauRunCount = $FinalHoldCau.Count
            BadNodes = @($FinalHoldNodes | Where-Object State -ne 'Up' |
                ForEach-Object { "$($_.Name):$($_.State)" })
            WitnessHealthy = $FinalHoldWitnessHealthy
            PoolStates = @($FinalHoldPool |
                ForEach-Object { "$($_.Id):$($_.Name):$($_.State)" })
            ExpectedPoolIdentity = "$($Pool.Id):$($Pool.Name)"
            BadCsvs = @($FinalHoldCsvs | Where-Object State -ne 'Online' |
                ForEach-Object { "$($_.Name):$($_.State)" })
            MissingCsvNames = @($FinalHoldExpectedCsvNames |
                Where-Object { $_ -notin $FinalHoldActualCsvNames })
            UnknownCsvNames = @($FinalHoldActualCsvNames |
                Where-Object { $_ -notin $FinalHoldExpectedCsvNames })
            CsvIdentityErrors = @($FinalHoldCsvIdentityErrors)
            BadVirtualDisks = @($FinalHoldVirtualDisks | Where-Object {
                "$($_.HealthStatus)" -ne 'Healthy' -or
                "$($_.OperationalStatus)" -notmatch 'OK'
            } | ForEach-Object {
                "$($_.FriendlyName):$($_.HealthStatus):$($_.OperationalStatus)"
            })
            MissingVirtualDiskIds = @($FinalHoldExpectedVirtualDiskIds |
                Where-Object { $_ -notin $FinalHoldActualVirtualDiskIds })
            UnknownVirtualDiskIds = @($FinalHoldActualVirtualDiskIds |
                Where-Object { $_ -notin $FinalHoldExpectedVirtualDiskIds })
            MocStates = @($FinalHoldMoc |
                ForEach-Object { "$($_.Id):$($_.Name):$($_.State)" })
            ExpectedMocIdentity = "$($Moc.Id):$($Moc.Name)"
            ControlPlaneStates = @($FinalHoldControlPlane |
                ForEach-Object { "$($_.Name):$($_.State)" })
            VmIdentityCount = $FinalHoldVmIdentityPairs.Count
            VmGroupStates = @($FinalHoldVmGroups |
                ForEach-Object { "$($_.Name):$($_.State)" })
            VmStates = @($FinalHoldVmState | ForEach-Object {
                "$($_.GroupName):$($_.GroupState):$($_.VmState)"
            })
            IntentFailures = @($FinalHoldIntent | Where-Object {
                "$($_.ConfigurationStatus)" -ne 'Success' -or
                "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
                [int]$_.RetryCount -gt 0 -or
                -not [string]::IsNullOrWhiteSpace("$($_.Error)")
            } | ForEach-Object {
                "$($_.Host):$($_.ConfigurationStatus):" +
                "$($_.ProvisioningStatus):$($_.RetryCount):$($_.Error)"
            })
            ActiveRdmaHealthy = $FinalHoldRdmaHealthy
            ClusterEventCount = $FinalHoldEvents.Count
            SmbRdmaEventCount = $FinalHoldSmbEvents.Count
            ClusterEventEvidence = $FinalHoldClusterEventPath
            SmbRdmaEventEvidence = $FinalHoldSmbEventPath
        } | ConvertTo-Json -Depth 8
        New-Item -ItemType File -Path $ActiveValidationFailurePath `
            -Value $FinalHoldFailureJson -ErrorAction Stop | Out-Null
        throw (
            "The final validation observed an unhealthy sample. Evidence was " +
            "preserved. Stop and obtain explicit disposition before retrying."
        )
    }
    } catch {
        if (-not (Test-Path -LiteralPath $ActiveValidationFailurePath)) {
            $FinalHoldExceptionJson = [pscustomobject]@{
                ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
                Phase = $FinalHoldPhase
                ExceptionType = "$($_.Exception.GetType().FullName)"
                ExceptionMessage = "$($_.Exception.Message)"
                ErrorRecord = "$_"
                ClusterEventEvidence = $FinalHoldClusterEventPath
                SmbRdmaEventEvidence = $FinalHoldSmbEventPath
            } | ConvertTo-Json -Depth 8
            New-Item -ItemType File -Path $ActiveValidationFailurePath `
                -Value $FinalHoldExceptionJson -ErrorAction Stop | Out-Null
        }
        throw
    }

    Start-Sleep -Seconds 30
} while (
    ((Get-Date) -lt $FinalDeadline) -and
    ($null -eq $FinalCleanSince -or
        (Get-Date) -lt $FinalCleanSince.AddMinutes(5))
)

if (
    $null -eq $FinalCleanSince -or
    (Get-Date) -lt $FinalCleanSince.AddMinutes(5)
) {
    $FinalHoldTimeoutJson = [pscustomobject]@{
        ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
        Phase = $FinalHoldPhase
        FailureKind = 'FinalHoldTimeout'
        CleanSince = if ($null -eq $FinalCleanSince) {
            ''
        } else {
            $FinalCleanSince.ToUniversalTime().ToString('o')
        }
        DeadlineUtc = $FinalDeadline.ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 8
    New-Item -ItemType File -Path $ActiveValidationFailurePath `
        -Value $FinalHoldTimeoutJson -ErrorAction Stop | Out-Null
    throw "The final active-validation hold was not continuously clean for five minutes."
}

# Reconfirm adapter transport and active SBL RDMA after the full hold
try {
    $PostHoldRdmaHealthy = Test-ActiveRdmaState
} catch {
    $PostHoldExceptionJson = [pscustomobject]@{
        ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
        Phase = $FinalHoldPhase
        FailureKind = 'PostHoldRdmaCollectionException'
        ExceptionType = "$($_.Exception.GetType().FullName)"
        ExceptionMessage = "$($_.Exception.Message)"
        ErrorRecord = "$_"
    } | ConvertTo-Json -Depth 8
    New-Item -ItemType File -Path $ActiveValidationFailurePath `
        -Value $PostHoldExceptionJson -ErrorAction Stop | Out-Null
    throw
}
if (-not $PostHoldRdmaHealthy) {
    $PostHoldFailureJson = [pscustomobject]@{
        ObservedUtc = (Get-Date).ToUniversalTime().ToString('o')
        Phase = $FinalHoldPhase
        FailureKind = 'PostHoldRdmaRegression'
        ActiveRdmaHealthy = $false
    } | ConvertTo-Json -Depth 8
    New-Item -ItemType File -Path $ActiveValidationFailurePath `
        -Value $PostHoldFailureJson -ErrorAction Stop | Out-Null
    throw "Active SBL RDMA did not remain clean through the final hold."
}

Set-ChangePhase -Phase ActiveValidationPassed
```

If an active-validation terminal failure artifact exists, copy it into the support evidence set,
record the explicit disposition, and rename the original with a
`-dispositioned-<UTC timestamp>` suffix before a new attempt. Never delete or
overwrite the original failure evidence.

Success requires:

- Network ATC remains successful and completed on every node.
- Every storage adapter remains on the desired transport with RDMA enabled.
- SBL connections report both client and server RDMA capability.
- Every selected SBL connection is RDMA-capable, has at least one current channel, does not report `Failed`, and has `FailureCount` equal to zero.
- Representative storage activity completes without storage, cluster, or network faults.
- The pool, virtual disks, CSVs, MOC, appliance VM, and customer workloads remain healthy.

For iWARP, TCP port 5445 activity can corroborate the transport when traffic is active, but the absence of a visible socket in one sample does not prove failure.

For RoCEv2, the network team should review ECN marking, PFC, and drop counters on the actual storage ports during representative load. A zero ECN-marking count on an uncongested port is not proof that ECN is misconfigured. Interpret marking together with queue depth, PFC, and drop evidence.

The block advances `ActiveAssertionsPassed` only after the exact automated checks and application-owner attestation pass. It advances `ActiveValidationPassed` only after the bounded event review is empty and the final continuous five-minute clean hold completes.

Then close the transcript and active-change pointer:

```powershell
$CompletionState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
if ("$($CompletionState.Phase)" -eq 'ActiveValidationPassed') {
    Set-ChangePhase -Phase Completed
} elseif ("$($CompletionState.Phase)" -ne 'Completed') {
    throw "Change closure requires ActiveValidationPassed or Completed phase."
}

try {
    Stop-Transcript -ErrorAction Stop
} catch {
    if ($_.Exception.Message -notmatch '(?i)not.*transcrib') {
        throw
    }
}

if (Test-Path -LiteralPath $ActivePointer) {
    $PointerTarget = "$(Get-Content -LiteralPath $ActivePointer -Raw)".Trim()
    if ($PointerTarget -ne $EvidenceRoot) {
        throw "The active pointer belongs to another evidence directory."
    }
    Remove-Item -LiteralPath $ActivePointer -Force
}
```

## Rollback

Rollback is a deliberate operator and approver decision. It is not automatic.

Before any rollback outage action, validate the sealed rollback direction and persist it as the active operation:

```powershell
$RollbackState = Get-Content -LiteralPath (
    Join-Path $EvidenceRoot 'phase-state.json'
) -Raw | ConvertFrom-Json
$RollbackOrigins = @(
    'TargetReadbackVerified',
    'PoolOnline',
    'PlatformOnline',
    'StorageHoldPassed',
    'ActiveValidationStarted',
    'ActiveAssertionsPassed',
    'ActiveValidationPassed'
)
if (
    -not (
        "$($RollbackState.Operation)" -eq 'Rollback' -and
        "$($RollbackState.Phase)" -eq 'RollbackApproved'
    ) -and
    (
        "$($RollbackState.Operation)" -ne 'Forward' -or
        "$($RollbackState.Phase)" -notin $RollbackOrigins
    )
) {
    throw (
        "Rollback is blocked from '$($RollbackState.Operation)/" +
        "$($RollbackState.Phase)'. Reconcile any pending or nonconverged " +
        "Network ATC submission with Microsoft Support first."
    )
}

$RollbackIntentStatus = @(Get-NetIntentStatus -ClusterName $Cluster.Name `
    -Name "$($StorageIntent.IntentName)" -ErrorAction Stop)
Assert-IntentStatusCoverage -Status $RollbackIntentStatus `
    -ClusterNodes $Nodes -IntentName "$($StorageIntent.IntentName)"
$BadRollbackIntentStatus = @($RollbackIntentStatus | Where-Object {
    "$($_.ConfigurationStatus)" -ne 'Success' -or
    "$($_.ProvisioningStatus)" -notmatch '^(Success|Completed)$' -or
    [int]$_.RetryCount -gt 0 -or
    -not [string]::IsNullOrWhiteSpace("$($_.Error)")
})
if ($BadRollbackIntentStatus.Count -gt 0) {
    throw (
        "Rollback is blocked while Network ATC is provisioning or unhealthy. " +
        "Preserve status and contact Microsoft Support."
    )
}

if ("$($RollbackState.Operation)" -eq 'Forward') {
    $RollbackOriginPhase = "$($RollbackState.Phase)"
} else {
    $RollbackOriginPhase = "$($RollbackState.RollbackOriginPhase)"
    if ($RollbackOriginPhase -notin $RollbackOrigins) {
        throw "RollbackApproved state is missing a valid rollback origin phase."
    }
}
$RollbackPoolShouldBeOnline = (
    $RollbackOriginPhase -ne 'TargetReadbackVerified'
)
$RollbackCsvsShouldBeOnline = (
    $RollbackOriginPhase -notin @(
        'TargetReadbackVerified',
        'PoolOnline'
    )
)
$RollbackPlatformShouldBeOnline = $RollbackCsvsShouldBeOnline
$RollbackWorkloadsShouldBeOnline = (
    $RollbackOriginPhase -in @(
        'ActiveValidationStarted',
        'ActiveAssertionsPassed',
        'ActiveValidationPassed'
    )
)
    $RollbackUpdates = @(Get-SolutionUpdate -ErrorAction Stop)
    $RollbackActiveUpdates = @($RollbackUpdates | Where-Object {
        "$($_.State)" -in @('Downloading', 'Installing')
    })
    $RollbackUpdateRuns = @($RollbackUpdates | ForEach-Object {
        @($_ | Get-SolutionUpdateRun -ErrorAction Stop |
            Where-Object { "$($_.State)" -eq 'InProgress' })
    })
    $RollbackCau = @(Get-CauRun -ClusterName $Cluster.Name `
        -ErrorAction Stop)
    $RollbackNodes = @(Get-ClusterNode -ErrorAction Stop)
    $RollbackHealthFaults = @(Get-HealthFault -ErrorAction Stop)
    $RollbackStorageJobs = @(Get-StorageJob -ErrorAction Stop)
    $RollbackQuorum = Get-ClusterQuorum -ErrorAction Stop
    $RollbackWitnessHealthy = $true
    if (-not [string]::IsNullOrWhiteSpace(
        "$($RollbackQuorum.QuorumResource)"
    )) {
        $RollbackWitness = @(Get-ClusterResource `
            -Name "$($RollbackQuorum.QuorumResource)" -ErrorAction Stop)
        $RollbackWitnessHealthy = (
            $RollbackWitness.Count -eq 1 -and
            "$($RollbackWitness[0].State)" -eq 'Online'
        )
    }

    $RollbackPool = @(Get-ClusterResource -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($Pool.Id)" -and
            "$($_.Name)" -eq "$($Pool.Name)"
        })
    $RollbackExpectedPoolState = if ($RollbackPoolShouldBeOnline) {
        'Online'
    } else {
        'Offline'
    }
    $RollbackExpectedCsvState = if ($RollbackCsvsShouldBeOnline) {
        'Online'
    } else {
        'Offline'
    }
    $RollbackCsvs = @(foreach ($CsvRecord in @($ResourceManifest.Csvs)) {
        $EscapedName = "$($CsvRecord.Name)".Replace("'", "''")
        $CimMatches = @(Get-CimInstance -Namespace root/MSCluster `
            -ClassName MSCluster_Resource -Filter "Name='$EscapedName'" `
            -ErrorAction Stop | Where-Object {
                "$($_.Type)" -eq "$($CsvRecord.CimType)" -and
                "$($_.OwnerGroup)" -eq "$($CsvRecord.CimOwnerGroup)"
            })
        $CsvMatches = @(Get-ClusterSharedVolume `
            -Name "$($CsvRecord.Name)" -ErrorAction Stop)
        if ($CimMatches.Count -ne 1 -or $CsvMatches.Count -ne 1) {
            throw "A sealed CSV identity no longer resolves uniquely."
        }
        if ($RollbackCsvsShouldBeOnline) {
            $Info = @($CsvMatches[0].SharedVolumeInfo)
            if ($Info.Count -ne 1) {
                throw "A sealed CSV has ambiguous shared-volume information."
            }
            $VolumeLeaf = Split-Path `
                -Path "$($Info[0].FriendlyVolumeName)" -Leaf
            $VirtualDisk = @(Get-VirtualDisk -FriendlyName $VolumeLeaf `
                -ErrorAction Stop)
            if (
                $VirtualDisk.Count -ne 1 -or
                "$($Info[0].FriendlyVolumeName)" -ine `
                    "$($CsvRecord.FriendlyVolumeName)" -or
                "$($Info[0].Partition.Name)" -ine `
                    "$($CsvRecord.PartitionName)" -or
                "$($VirtualDisk[0].UniqueId)" -ne `
                    "$($CsvRecord.VirtualDiskUniqueId)"
            ) {
                throw "A sealed CSV no longer matches its recorded identity."
            }
        }
        $CsvMatches[0]
    })
    $ExpectedRollbackVirtualDiskIds = @(
        $ResourceManifest.VirtualDisks.UniqueId | Where-Object {
            -not [string]::IsNullOrWhiteSpace("$_")
        } | Sort-Object -Unique
    )
    $RollbackVirtualDisks = @()
    $ActualRollbackVirtualDiskIds = @()
    if ($RollbackPoolShouldBeOnline) {
        $RollbackVirtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
        $ActualRollbackVirtualDiskIds = @($RollbackVirtualDisks.UniqueId |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace("$_")
            } | Sort-Object -Unique)
    }
    $RollbackMoc = @(Get-ClusterResource -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($Moc.Id)" -and
            "$($_.Name)" -eq "$($Moc.Name)"
        })
    $RollbackControlPlaneGroup = @(Get-ClusterGroup -ErrorAction Stop |
        Where-Object {
            "$($_.Id)" -eq "$($ControlPlaneEntry.GroupId)" -and
            "$($_.Name)" -eq "$($ControlPlaneEntry.GroupName)"
        })
    if ($RollbackControlPlaneGroup.Count -ne 1) {
        throw "The sealed appliance group no longer resolves uniquely."
    }
    $RollbackControlPlaneVm = @(Invoke-Command `
        -ComputerName "$($RollbackControlPlaneGroup[0].OwnerNode)" `
        -ArgumentList "$($ControlPlaneEntry.VmId)" -ScriptBlock {
            param($VmId)
            Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                Select-Object VMId, State
        } -ErrorAction Stop)
    $RollbackExpectedPlatformState = if ($RollbackPlatformShouldBeOnline) {
        'Online'
    } else {
        'Offline'
    }
    $RollbackExpectedVmState = if ($RollbackPlatformShouldBeOnline) {
        'Running'
    } else {
        'Off'
    }
    $RollbackVmGroups = @(Get-ClusterGroup -ErrorAction Stop |
        Where-Object { "$($_.GroupType)" -eq 'VirtualMachine' })
    $RollbackVmIdentityPairs = @(foreach ($Group in $RollbackVmGroups) {
        $VmResources = @($Group | Get-ClusterResource -ErrorAction Stop |
            Where-Object { "$($_.ResourceType)" -eq 'Virtual Machine' })
        if ($VmResources.Count -ne 1) {
            throw "Expected one Virtual Machine resource in '$($Group.Name)'."
        }
        $VmIdParameters = @(Get-ClusterParameter `
            -InputObject $VmResources[0] -Name VmId -ErrorAction Stop)
        if ($VmIdParameters.Count -ne 1) {
            throw "Expected one VmId parameter in '$($Group.Name)'."
        }
        "$($Group.Id)|$($Group.Name)|$($VmIdParameters[0].Value)"
    })
    $RollbackCustomerVmState = @(
        foreach ($Entry in @($ResourceManifest.ClusteredVms |
            Where-Object {
                "$($_.GroupId)" -ne "$($ControlPlaneEntry.GroupId)"
            })) {
            $CurrentGroup = @($RollbackVmGroups | Where-Object {
                "$($_.Id)" -eq "$($Entry.GroupId)" -and
                "$($_.Name)" -eq "$($Entry.GroupName)"
            })
            if ($CurrentGroup.Count -ne 1) {
                throw "A sealed customer VM group no longer resolves uniquely."
            }
            $HyperV = @(Invoke-Command `
                -ComputerName "$($CurrentGroup[0].OwnerNode)" `
                -ArgumentList "$($Entry.VmId)" -ScriptBlock {
                    param($VmId)
                    Get-VM -Id ([guid]$VmId) -ErrorAction Stop |
                        Select-Object VMId, State
                } -ErrorAction Stop)
            if ($HyperV.Count -ne 1) {
                throw "A sealed customer VM no longer resolves uniquely."
            }
            [pscustomobject]@{
                GroupId = "$($CurrentGroup[0].Id)"
                GroupState = "$($CurrentGroup[0].State)"
                VmId = "$($HyperV[0].VMId)"
                VmState = "$($HyperV[0].State)"
            }
        }
    )
    $RollbackExpectedCustomerGroupState = if (
        $RollbackWorkloadsShouldBeOnline
    ) {
        'Online'
    } else {
        'Offline'
    }
    $RollbackExpectedCustomerVmState = if (
        $RollbackWorkloadsShouldBeOnline
    ) {
        'Running'
    } else {
        'Off'
    }
    $RollbackIntent = @(Get-NetIntent -ClusterName $Cluster.Name `
        -ErrorAction Stop | Where-Object {
            "$($_.IntentName)" -eq "$($StorageIntent.IntentName)"
        })
    if ($RollbackIntent.Count -ne 1) {
        throw "The sealed storage intent no longer resolves uniquely."
    }
    Assert-AdapterOverrideReadback `
        -LiveOverride $RollbackIntent[0].AdapterAdvancedParametersOverride `
        -SealedOverrides $ExplicitAdapterOverrides `
        -ExpectedTransportValue ([int]$ResourceManifest.TargetTransportValue)
    $RollbackAdapters = @(Invoke-Command -ComputerName $Nodes.Name `
        -ArgumentList ($AdapterNames -join ',') -ScriptBlock {
            param($AdapterCsv)
            foreach ($AdapterName in @($AdapterCsv -split ',')) {
                $Adapter = Get-NetAdapter -Name $AdapterName `
                    -ErrorAction Stop
                $Rdma = Get-NetAdapterRdma -Name $AdapterName `
                    -ErrorAction Stop
                $Transport = Get-NetAdapterAdvancedProperty `
                    -Name $AdapterName `
                    -RegistryKeyword '*NetworkDirectTechnology' `
                    -ErrorAction Stop
                [pscustomobject]@{
                    Pair = "$($env:COMPUTERNAME.Split('.')[0].ToUpperInvariant())|" +
                        "$($AdapterName.Trim().ToUpperInvariant())"
                    Status = "$($Adapter.Status)"
                    RdmaEnabled = [bool]$Rdma.Enabled
                    TransportValue = [int]$Transport.RegistryValue[0]
                }
            }
        } -ErrorAction Stop)
    $RollbackExpectedAdapterPairs = @(
        foreach ($Node in $Nodes) {
            $NodeName = "$($Node.Name)".Split('.')[0].ToUpperInvariant()
            foreach ($AdapterName in $AdapterNames) {
                "$NodeName|$("$AdapterName".Trim().ToUpperInvariant())"
            }
        }
    )

    if (
        $RollbackActiveUpdates.Count -gt 0 -or
        $RollbackUpdateRuns.Count -gt 0 -or
        $RollbackCau.Count -gt 0 -or
        @($RollbackNodes | Where-Object State -ne 'Up').Count -gt 0 -or
        $RollbackHealthFaults.Count -gt 0 -or
        $RollbackStorageJobs.Count -gt 0 -or
        -not $RollbackWitnessHealthy -or
        $RollbackPool.Count -ne 1 -or
        "$($RollbackPool[0].State)" -ne $RollbackExpectedPoolState -or
        $RollbackCsvs.Count -ne @($ResourceManifest.Csvs).Count -or
        @($RollbackCsvs | Where-Object {
            "$($_.State)" -ne $RollbackExpectedCsvState
        }).Count -gt 0 -or
        $RollbackMoc.Count -ne 1 -or
        "$($RollbackMoc[0].State)" -ne $RollbackExpectedPlatformState -or
        $RollbackControlPlaneVm.Count -ne 1 -or
        "$($RollbackControlPlaneGroup[0].State)" -ne `
            $RollbackExpectedPlatformState -or
        "$($RollbackControlPlaneVm[0].State)" -ne `
            $RollbackExpectedVmState -or
        $RollbackVmIdentityPairs.Count -ne $ExpectedVmIdentityPairs.Count -or
        @($ExpectedVmIdentityPairs | Where-Object {
            $_ -notin $RollbackVmIdentityPairs
        }).Count -gt 0 -or
        @($RollbackVmIdentityPairs | Where-Object {
            $_ -notin $ExpectedVmIdentityPairs
        }).Count -gt 0 -or
        @($RollbackCustomerVmState | Where-Object {
            $_.GroupState -ne $RollbackExpectedCustomerGroupState -or
            $_.VmState -ne $RollbackExpectedCustomerVmState
        }).Count -gt 0 -or
        (
            $RollbackPoolShouldBeOnline -and
            (
                $RollbackVirtualDisks.Count -ne `
                    $ExpectedRollbackVirtualDiskIds.Count -or
                @($RollbackVirtualDisks | Where-Object {
                    "$($_.HealthStatus)" -ne 'Healthy' -or
                    "$($_.OperationalStatus)" -notmatch 'OK'
                }).Count -gt 0 -or
                @($ExpectedRollbackVirtualDiskIds | Where-Object {
                    $_ -notin $ActualRollbackVirtualDiskIds
                }).Count -gt 0 -or
                @($ActualRollbackVirtualDiskIds | Where-Object {
                    $_ -notin $ExpectedRollbackVirtualDiskIds
                }).Count -gt 0
            )
        ) -or
        $RollbackAdapters.Count -ne $RollbackExpectedAdapterPairs.Count -or
        @($RollbackExpectedAdapterPairs | Where-Object {
            $_ -notin $RollbackAdapters.Pair
        }).Count -gt 0 -or
        @($RollbackAdapters.Pair | Where-Object {
            $_ -notin $RollbackExpectedAdapterPairs
        }).Count -gt 0 -or
        @($RollbackAdapters | Where-Object {
            $_.Status -ne 'Up' -or
            -not $_.RdmaEnabled -or
            $_.TransportValue -ne `
                [int]$ResourceManifest.TargetTransportValue
        }).Count -gt 0
    ) {
        throw (
            "Rollback prerequisites are not healthy and idle. Stop and obtain " +
            "Microsoft Support disposition before starting another outage."
        )
    }

$Operation = 'Rollback'
$DesiredTransport = $SourceTransport
$DesiredTransportValue = [int]$SourceTransportValue
if (
    $DesiredTransport -notin $TransportValues.Keys -or
    $DesiredTransportValue -ne [int]$TransportValues[$DesiredTransport]
) {
    throw "The sealed rollback transport is unsupported or inconsistent."
}

if ($DesiredTransport -eq 'iWARP') {
    $RollbackFirewallState = @(Invoke-Command -ComputerName $Nodes.Name -ScriptBlock {
        $Rules = @(Get-NetFirewallRule -Name 'FPSSMBD-iWARP-In-TCP' `
            -ErrorAction SilentlyContinue)
        [pscustomobject]@{
            Node = $env:COMPUTERNAME
            Count = $Rules.Count
            Enabled = @($Rules.Enabled | Sort-Object -Unique) -join ','
            Direction = @($Rules.Direction | Sort-Object -Unique) -join ','
            Action = @($Rules.Action | Sort-Object -Unique) -join ','
        }
    } -ErrorAction Stop)
    $BadRollbackFirewall = @($RollbackFirewallState | Where-Object {
        $_.Count -lt 1 -or $_.Enabled -ne 'True' -or
        $_.Direction -ne 'Inbound' -or $_.Action -ne 'Allow'
    })
    if ($BadRollbackFirewall.Count -gt 0) {
        throw "The built-in inbound iWARP firewall rule is not usable on every node."
    }
}

Set-ChangePhase -Phase RollbackApproved `
    -RollbackOriginPhase $RollbackOriginPhase `
    -ClearActiveValidationStart
```

1. Stop customer workloads and verify every customer VM is `Off`. Persist `WorkloadsOff`.
2. Stop the appliance VM and MOC resource. Persist `PlatformOff`.
3. Offline workload CSVs, then the infrastructure CSV. Persist `CsvsOff`.
4. Offline the exact recorded Storage Pool resource. Persist `PoolOff`.
5. Re-run [Change the Network ATC transport](#change-the-network-atc-transport). Its mutation and readback use the persisted rollback transport, not the original forward target.
6. Re-run [Restore the platform in dependency order](#restore-the-platform-in-dependency-order).
7. Complete the continuous five-minute clean hold.
8. Return workload startup to the application owner.
9. Re-run [Validate active RDMA under representative load](#validate-active-rdma-under-representative-load). The automated assertions validate the persisted rollback transport before advancing the checkpoint.

If the target was iWARP, keep the built-in iWARP firewall rule enabled until RoCEv2 rollback and full platform recovery are verified. Do not delete or recreate the built-in rule as part of rollback.

## Troubleshooting and stop conditions

| Symptom | Required action |
| --- | --- |
| `Set-NetIntent` returns an error | Query `Get-NetIntent` and `Get-NetIntentStatus` before retrying. Do not resubmit while provisioning is active. |
| Network ATC does not converge | Preserve status, retry count, and error output. Do not issue another transport mutation. Escalate to Microsoft Support and the OEM. |
| CSV command reports `Generic failure` | Re-read the CSV state. If the requested state is already present, do not retry. |
| Pool, virtual disk, or CSV does not recover | Stop. Do not run repair, recreate resources, or disable Storage Spaces Direct. Contact Microsoft Support. |
| MOC or appliance VM does not recover | Stop before customer workload startup. Collect cluster and VM state and contact Microsoft Support. |
| RDMA capability is absent after recovery | Stop workload expansion. Reconfirm adapter transport, Network ATC, firewall for iWARP, and fabric readiness for RoCEv2. |
| A selected SBL connection has no current channels, reports `Failed`, has a nonzero `FailureCount`, or is not RDMA-capable | Treat the desired transport as unverified. Collect SBL connection, adapter, intent, and network evidence before proceeding. |
| RoCEv2 shows drops or pause storms | Stop the validation load. Engage the network team and OEM to verify PFC, ETS, ECN/WRED, and endpoint congestion response. |

## Evidence and escalation package

Collect and retain:

- The change approval, outage owner, rollback decision owner, and communication timeline.
- `network-atc-baseline.json` and `resource-manifest.json`.
- The complete operator transcript.
- Before and after output for `Get-NetIntent`, `Get-NetIntentStatus`, adapter transport, RDMA state, and driver versions.
- Before and after cluster, quorum, pool, virtual-disk, CSV, MOC, appliance VM, and customer VM state.
- Before and after `Get-StorageJob` and `Get-HealthFault`.
- SBL RDMA connection output under representative load.
- SBL RDMA capability, selection, current-channel, failed-state, and failure-count checks.
- For RoCEv2, switch-port PFC, ECN/WRED, drop, and queue evidence from the network team.
- Exact UTC timestamps for the quiesce, intent submission, convergence, recovery, and active validation phases.

Escalate to:

- The OEM for target-transport support, adapter firmware, driver, and endpoint congestion-control configuration.
- The network team for PFC, ETS, ECN/WRED, DCBX, queue, pause, and drop behavior.
- The workload owner for application shutdown and startup.
- Microsoft Support for Network ATC convergence failure, resource identity ambiguity, or any storage, MOC, appliance, CSV, or virtual-disk recovery failure.

## Claims and validation evidence

This guide is statically reviewed operational guidance. It has not been validated by performing a full bidirectional transport change on customer infrastructure.

The procedure intentionally separates:

- Desired-state verification while storage is offline.
- Dependency-ordered platform recovery.
- A continuous clean hold.
- Active target-transport validation under representative load.

Do not describe a change as successful from adapter configuration alone.

## References

- [Host network requirements for Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/host-network-requirements)
- [Physical network requirements for Azure Local](https://learn.microsoft.com/azure/azure-local/concepts/physical-network-requirements)
- [Network considerations for cloud deployments of Azure Local](https://learn.microsoft.com/azure/azure-local/plan/cloud-deployment-network-considerations)
- [Manage Network ATC](https://learn.microsoft.com/windows-server/networking/network-atc/manage-network-atc)
- [Set-NetIntent](https://learn.microsoft.com/powershell/module/networkatc/set-netintent)
- [New-NetIntentAdapterPropertyOverrides](https://learn.microsoft.com/powershell/module/networkatc/new-netintentadapterpropertyoverrides)
- [SMB Direct](https://learn.microsoft.com/windows-server/storage/file-server/smb-direct)
- [Manage SMB Multichannel](https://learn.microsoft.com/windows-server/storage/storage-spaces/manage-smb-multichannel)
- [Troubleshoot failover-cluster event 1135](https://learn.microsoft.com/windows-server/troubleshoot/troubleshooting-cluster-event-id-1135)
- [Storage Spaces Direct troubleshooting, including events 5120 and 1135](https://learn.microsoft.com/windows-server/storage/storage-spaces/troubleshooting-storage-spaces)
- [Stop-VM](https://learn.microsoft.com/powershell/module/hyper-v/stop-vm)
