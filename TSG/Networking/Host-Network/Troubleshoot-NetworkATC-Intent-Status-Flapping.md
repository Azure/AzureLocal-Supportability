<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "command",
    "signal": "Repeated Get-NetIntentStatus output alternates the same intent and host between Validating and Success/Completed"
  },
  "validation": {
    "fidelity_level": "L0",
    "technical_grade": null,
    "reproduction_substrate": "hardware",
    "automation_status": "manual",
    "last_validated": null,
    "spec_ref": ""
  }
}
-->

# Troubleshoot Network ATC intent status flapping

## Table of contents

- [Article metadata](#article-metadata)
- [Executive triage summary](#executive-triage-summary)
- [Symptoms and scope](#symptoms-and-scope)
- [Where this appears](#where-this-appears)
- [Preconditions and stop gates](#preconditions-and-stop-gates)
- [Diagnosis](#diagnosis)
- [Contributing factors and evidence](#contributing-factors-and-evidence)
- [Mitigation](#mitigation)
- [Rollback](#rollback)
- [Verification](#verification)
- [Escalation and evidence package](#escalation-and-evidence-package)
- [Related documentation](#related-documentation)

## Article metadata

| Field | Value |
| --- | --- |
| Component | Network ATC |
| Applicable products | Azure Local |
| Supported versions | Affected and fixed build boundaries are not established |
| Audience | Microsoft Customer Support Services (CSS) engineer and Azure Local cluster administrator |
| Applicable scenarios | Day-to-day operation, update readiness, solution update, and lifecycle operations |
| Severity | Medium. The condition can block operations while appearing healthy in an individual snapshot. |
| Customer impact | Network intent health cannot be established reliably; readiness or lifecycle operations can be blocked |
| Primary owner | Microsoft CSS, with Windows Network ATC product-group escalation when the mitigation does not stabilize the intents |
| Execution surface | On-device |
| Risk summary | Diagnosis is read-only. Reapplying GlobalOverrides is [HIGH RISK], requires a maintenance window and out-of-band access, and can trigger cluster-wide Network ATC reconciliation. |

## Executive triage summary

| Question | Answer |
| --- | --- |
| What is broken? | The same Network ATC intent and host repeatedly alternate between `Validating` and `Success / Completed`. |
| Who should act? | Microsoft CSS or an Azure Local administrator working with Microsoft CSS. |
| Fastest safe next action | Capture repeated, timestamped `Get-NetIntentStatus` samples. |
| Estimated duration | Approximately 10 minutes for diagnosis and post-mitigation observation, excluding change approval. |
| Downtime or workload risk | Possible. Reapplying cluster-scoped GlobalOverrides can trigger Network ATC reconciliation. |
| Escalate immediately if | An intent remains failed, reports a concrete error, the cluster is degraded, additional GlobalOverrides properties are populated, or out-of-band access is unavailable. |

## Symptoms and scope

This article applies only when repeated snapshots show the same intent and host moving between:

- `ConfigurationStatus = Validating`
- `ConfigurationStatus = Success`
- `ProvisioningStatus = Completed`

An individual `Validating` result does not prove this issue. Network ATC can report `Validating` during normal convergence or drift detection.

This article does not apply when:

- An intent remains `Failed`, `ProvisioningFailed`, or `Pending`.
- `Get-NetIntentStatus` reports a concrete adapter, symmetry, VLAN, RDMA, DCB, IP, or switch error.
- Cluster networks are incorrectly included in `MigrationExcludeNetworks`.
- Cluster networks have an `Unused:<intent>` prefix or another proven topology problem.
- An administrator is actively changing intents, adapters, switches, VLANs, IP addresses, or GlobalOverrides.
- `Get-NetIntent -GlobalOverrides` does not return an existing cluster override.

For persistent failure or a concrete error, use [Troubleshoot Cluster Network Intent Status](../../EnvironmentValidator/Networking/Troubleshoot-Network-Test-Cluster-Intent-Status.md). Do not use GlobalOverrides reapplication to bypass an understood configuration or hardware failure.

## Where this appears

| Admin surface | Status | Evidence to capture |
| --- | --- | --- |
| PowerShell on an Azure Local node | shown | Repeated `Get-NetIntentStatus` output shows the same intent and host alternating between `Validating` and `Success / Completed`. |
| Azure portal | absent | The portal surface has not been characterized for this specific oscillation. |
| Windows event logs | shown | Capture the `Microsoft-Windows-Networking-NetworkAtc/Operational` and `Microsoft-Windows-Networking-NetworkAtc/Admin` channels for the observation window. |
| Cluster logs using `Get-ClusterLog` | absent | Cluster-log behavior has not been characterized for this specific oscillation. |
| Windows Failover Cluster Manager | absent | Failover Cluster Manager behavior has not been characterized for this specific oscillation. |
| Windows Admin Center (standalone host) | absent | The standalone Windows Admin Center surface has not been characterized. |
| Windows Admin Center in the Azure portal | absent | The Azure portal Windows Admin Center surface has not been characterized. |
| Component or tool log files on disk | absent | No stable on-disk signature has been established for this specific oscillation. |

## Preconditions and stop gates

Complete these checks before reapplying GlobalOverrides.

| Gate | Pre-check | Expected result or output | Stop condition | Owner |
| --- | --- | --- | --- | --- |
| Permissions | Confirm the operator has local administrator and cluster administration permissions. | The operator can read Network ATC and cluster state. | Required permission is missing. | Cluster administrator |
| Out-of-band access | Confirm console or baseboard management controller access to every node. | The cluster remains reachable if in-band management is interrupted. | Out-of-band access is unavailable. | Cluster administrator |
| Change window | Confirm a maintenance window and active workload monitoring. | The administrator can stop if connectivity changes. | The workload owner has not approved the window. | Workload owner |
| Cluster health | Run `Get-ClusterNode`, `Get-ClusterGroup`, and `Get-VirtualDisk`. | Nodes are up, cluster groups are online, and virtual disks are healthy. | A node is down, a critical group is offline, or storage is degraded. | Cluster administrator |
| Intent state | Capture repeated status and Network ATC event logs. | The exact oscillating signature is present with no concrete failure. | The state is stable, remains failed, or reports an actionable error. | Microsoft CSS |
| Override scope | Inspect the existing cluster override. | Only `EnableNetworkNaming` and `EnableLiveMigrationNetworkSelection` are populated configuration properties. | Another configurable GlobalOverrides property is populated or the current values are ambiguous. | Windows Network ATC product group |

## Diagnosis

### 1. Prove that intent status is oscillating

**Action type: [READ-ONLY]**

Run the following command from one cluster node:

```powershell
$ErrorActionPreference = "Stop"

1..10 | ForEach-Object {
    Write-Host "Run $_ of 10 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    Get-NetIntentStatus |
        Format-Table IntentName, Host, LastConfigApplied,
            ConfigurationStatus, ProvisioningStatus, Error -AutoSize

    if ($_ -lt 10) {
        Start-Sleep -Seconds 30
    }
}
```

**Affected output:** The same intent and host transition between `Validating` and `Success / Completed` during the observation period.

**Stop condition:** If the status remains stable or becomes failed with a concrete error, do not continue with this article.

### 2. Exclude a concrete Network ATC failure

**Action type: [READ-ONLY]**

Review these event channels for the same observation window:

- `Microsoft-Windows-Networking-NetworkAtc/Operational`
- `Microsoft-Windows-Networking-NetworkAtc/Admin`

**Expected affected output:** The logs do not identify a concrete adapter, configuration, or hardware failure that explains the state change.

**Stop condition:** If the logs identify a concrete failure, resolve that issue instead.

### 3. Capture the current GlobalOverrides values

**Action type: [READ-ONLY]**

```powershell
$ErrorActionPreference = "Stop"

Get-ClusterNode
Get-ClusterGroup
Get-VirtualDisk

$globalIntent = Get-NetIntent -GlobalOverrides
if ($null -eq $globalIntent -or $null -eq $globalIntent.ClusterOverride) {
    throw "No existing Network ATC cluster override was found. Stop and escalate."
}

$clusterOverride = $globalIntent.ClusterOverride
$clusterOverride | Format-List *
Get-NetIntentStatus -GlobalOverrides | Format-List *
```

Save the complete output.

The field-observed mitigation in this article is limited to these configurable properties:

- `EnableNetworkNaming`
- `EnableLiveMigrationNetworkSelection`

**Stop condition:** Do not continue if neither property has a value, the current values are ambiguous, or another configurable GlobalOverrides property is populated.

## Contributing factors and evidence

| Evidence label | Contributing factor or observation | Source | Why it matters |
| --- | --- | --- | --- |
| CONFIRMED | Repeated command output can show the same intent and host alternating between `Validating` and `Success / Completed`. | `Get-NetIntentStatus` sampled every 30 seconds | Distinguishes the issue from one normal convergence pass. |
| CONFIRMED | A one-time reapplication that preserved the existing GlobalOverrides values stabilized intent status in an Azure Local hardware environment. | Assisted support observation | Supports the mitigation direction for this narrowly matched symptom. |
| UNVERIFIABLE | The underlying product root cause and affected or fixed build boundary are not established. | No published root-cause or release-boundary evidence | The article must not describe the condition as stale cache, configuration drift, or a fixed product defect. |

**Disproving check:** A stable status sample, a persistent failed status, or a concrete Network ATC event error disproves the diagnosis and blocks this mitigation.

## Mitigation

### Reapply the existing GlobalOverrides values

**Risk label: [HIGH RISK]**

This operation removes and recreates a cluster-scoped Network ATC object. It can trigger Network ATC reconciliation and might interrupt management, compute, live migration, or storage connectivity. Use a maintenance window, maintain out-of-band access, and monitor cluster and workload health.

Do not remove or recreate individual production intents as part of this procedure.

Create the replacement object before removing the current object. Copy the existing values exactly; do not use values from another cluster or from an example.

```powershell
$ErrorActionPreference = "Stop"

$newClusterOverride = New-NetIntentGlobalClusterOverrides

if ($null -ne $clusterOverride.EnableNetworkNaming) {
    $newClusterOverride.EnableNetworkNaming =
        $clusterOverride.EnableNetworkNaming
}

if ($null -ne $clusterOverride.EnableLiveMigrationNetworkSelection) {
    $newClusterOverride.EnableLiveMigrationNetworkSelection =
        $clusterOverride.EnableLiveMigrationNetworkSelection
}

Write-Host "Existing GlobalOverrides values:"
$clusterOverride | Format-List *

Write-Host "Replacement GlobalOverrides values:"
$newClusterOverride | Format-List *
```

Compare the existing and replacement values before continuing.

**Stop condition:** If the values do not match, do not remove the current GlobalOverrides object.

```powershell
Remove-NetIntent -GlobalOverrides
Add-NetIntent -GlobalClusterOverrides $newClusterOverride
```

Run this sequence once. Do not loop the remove and add operation.

**Expected result:** The GlobalOverrides object is recreated with the same effective values.

**Stop condition:** If `Add-NetIntent` fails, immediately run the rollback procedure.

## Rollback

Rollback restores the captured values by adding the replacement GlobalOverrides object again:

```powershell
$ErrorActionPreference = "Stop"

Add-NetIntent -GlobalClusterOverrides $newClusterOverride

Get-NetIntent -GlobalOverrides |
    Select-Object -ExpandProperty ClusterOverride |
    Format-List *
```

**Expected rollback output:** `Get-NetIntent -GlobalOverrides` returns the original captured values.

If the object cannot be restored or connectivity is affected, stop all further Network ATC changes and escalate to Microsoft CSS.

## Verification

### 1. Verify the GlobalOverrides values

**Action type: [READ-ONLY]**

```powershell
Get-NetIntent -GlobalOverrides |
    Select-Object -ExpandProperty ClusterOverride |
    Format-List *
```

The effective values must match the values captured before mitigation.

### 2. Verify intent stability

**Action type: [READ-ONLY]**

```powershell
1..10 | ForEach-Object {
    Write-Host "Run $_ of 10 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    Get-NetIntentStatus |
        Format-Table IntentName, Host, LastConfigApplied,
            ConfigurationStatus, ProvisioningStatus, Error -AutoSize

    if ($_ -lt 10) {
        Start-Sleep -Seconds 30
    }
}
```

The mitigation succeeds only when every applicable intent remains `Success / Completed` throughout the observation period and no new Network ATC Admin or Operational error appears.

If an operation was blocked, rerun its readiness validation before retrying it. Operation success alone does not prove that the intent status is stable.

## Escalation and evidence package

Do not repeat the mitigation or remove and recreate the cluster intents if:

- Status continues to oscillate.
- The issue recurs.
- A concrete Network ATC error appears.
- Rollback fails.
- Connectivity or workload health changes.

Escalate to Microsoft CSS or the Windows Network ATC product group with:

- Azure Local solution and OS versions.
- Before-and-after repeated `Get-NetIntentStatus` output.
- Before-and-after GlobalOverrides values.
- Network ATC Operational and Admin event logs covering the observation and mitigation window.
- Cluster, storage, and workload health before and after the operation.
- The exact command output and timestamp of any failed mitigation or rollback step.

## Related documentation

- [Troubleshoot Cluster Network Intent Status](../../EnvironmentValidator/Networking/Troubleshoot-Network-Test-Cluster-Intent-Status.md)
- [Network ATC overview](https://learn.microsoft.com/azure/azure-local/concepts/network-atc-overview)
- [Manage Network ATC](https://learn.microsoft.com/windows-server/networking/network-atc/manage-network-atc)
- [Azure Local host network requirements](https://learn.microsoft.com/azure/azure-local/concepts/host-network-requirements)
