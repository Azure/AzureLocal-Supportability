<!-- tsg-metadata
{
  "schema": "azure-local-supportability/tsg-metadata/v1",
  "document_type": "troubleshoot",
  "products": ["Azure Local"],
  "detector": {
    "type": "envchecker",
    "signal": "AzStackHci_Network_Test_Network_Cluster_Intent_Status"
  },
  "validation": {
    "fidelity_level": "L1",
    "technical_grade": null,
    "reproduction_substrate": "hardware",
    "automation_status": "manual",
    "last_validated": "2026-09-30",
    "spec_ref": ""
  }
}
-->

# AzStackHci_Network_Test_Network_Cluster_Intent_Status

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Network_Cluster_Intent_Status</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Add-Server, Pre-Update</strong></td>
  </tr>
</table>

## Overview

This validator checks that all network intents configured on existing cluster nodes are in a healthy state. Before adding a new server or performing an update, all network intents must have `ConfigurationStatus = Success` and `ProvisioningStatus = Completed`. The validator will wait up to 14 minutes for intents to stabilize if they are in transient states like "Validating" (which can occur during ATC drift detection).

## Requirements

Each network intent on active cluster nodes must meet the following requirements:
1. `ConfigurationStatus` must be `Success`
2. `ProvisioningStatus` must be `Completed`

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the intent status. The `Source` field identifies the node, and the `Resource` field shows the intent name.

```json
{
  "Name": "AzStackHci_Network_Test_Network_Cluster_Intent_Status",
  "DisplayName": "Test Network intent on existing cluster nodes",
  "Title": "Test Network intent on existing cluster nodes",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking if network intent is healthy on existing nodes",
  "Remediation": "To check cluster network intent status, run below cmdlet on your cluster:\n    Get-NetIntentStatus\n  ConfigurationStatus should be \"Success\"\n  ProvisioningStatus  should be \"Completed\":",
  "TargetResourceID": "NetworkIntent",
  "TargetResourceName": "NetworkIntent",
  "TargetResourceType": "NetworkIntent",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NODE1",
    "Resource": "ManagementComputeIntent",
    "Detail": "Intent ManagementComputeIntent on host NODE1 in a failed state. ConfigurationStatus: Failed ProvisioningStatus: Error",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Intent in Failed State

**Error Message:**
```text
Intent ManagementComputeIntent on host NODE1 in a failed state. ConfigurationStatus: Failed ProvisioningStatus: Error
```

**Root Cause:** The network intent has failed to provision successfully. This can occur due to configuration errors, hardware issues, driver problems, or conflicts with existing network settings.

#### Remediation Steps

##### Step 1: Check Intent Status Details

1. Get detailed status information for the failing intent:

   ```powershell
   # Check intent status on all nodes
   Get-NetIntentStatus
   ```

2. You should able to find the configuration status and provisioning status from above output

3. Check the intent configuration:

   ```powershell
   # Get intent details
   Get-NetIntent -Name "ManagementComputeIntent" | Format-List
   ```

##### Step 2: Check Network Adapter Status

Network intent failures are often related to adapter issues:

1. Verify all adapters in the intent exist and are operational:

   ```powershell
   # Get the intent's adapters
   $intent = Get-NetIntent -Name "<intent name>"
   $adapterNames = $intent.NetAdapterNamesAsList

   # Check adapter status on the failing node
   Get-NetAdapter -Name $adapterNames -ErrorAction SilentlyContinue
   ```

##### Step 3: Common Fixes for Intent Failures

###### Scenario A: Adapter Not Found or Down

If an adapter doesn't exist or is down:

1. Check physical connectivity:
   - Verify cables are connected
   - Check switch port status
   - Verify adapter is enabled in BIOS

2. Enable the adapter if it's disabled:

   ```powershell
   # On the failing node
   Enable-NetAdapter -Name "Ethernet"  # Replace with adapter name
   ```

###### Scenario B: Driver Issues

If there are driver-related problems:

1. Check driver version and status:

   ```powershell
   Get-NetAdapter -Name $adapter -ErrorAction SilentlyContinue
   ```

2. Update drivers if needed (see related TSG for adapter driver issues).

###### Scenario C: VMSwitch Conflicts

If there are VMSwitch configuration conflicts:

1. Check for existing VMSwitches:

   ```powershell
   Get-VMSwitch
   ```

2. If there's a conflicting VMSwitch, Network ATC may need to reconcile it or you may need to remove it manually.

##### Step 4: Retry the Intent

If you've resolved the underlying issue, you can retry the intent provisioning:

1. **Option A: Update the intent** (triggers reprovisioning):

   ```powershell
   # This will trigger ATC to retry provisioning
   Set-NetIntentRetryState -ClusterName "<cluster name>" -Name "<intent name>" -NodeName "<cluster node name>"
   ```

2. **Option B: Remove and recreate the intent**:

   ```powershell
   # Get current intent configuration
   Remove-NetIntent -ClusterName "<cluster name>".Name -Name "<intent name>"

   Add-NetIntent -Name "<intent name>" ... # make sure include other parameters
   ```

3. Monitor the intent status:

   ```powershell
   # Monitor intent provisioning
   Get-NetIntentStatus
   ```

---

### Failure: Intent ConfigurationStatus Flipping Between Validating and Success

**Error Message:**
```text
Intent <IntentName> on host <NodeName> in pending state and hasn't stabilized. ConfigurationStatus: Validating ProvisioningStatus: <empty>
```

This section applies only when repeated samples show the same intent and host alternating between `Validating` and `Success / Completed`. An individual `Validating` result does not prove this issue because Network ATC can report `Validating` during normal drift detection.

Do not use this mitigation when:

- An intent remains `Failed`, `ProvisioningFailed`, or `Pending`.
- `Get-NetIntentStatus` or the Network ATC event logs report a concrete adapter, symmetry, VLAN, RDMA, DCB, IP, or switch error.
- An administrator is actively changing intents, adapters, switches, VLANs, IP addresses, or GlobalOverrides.
- `Get-NetIntent -GlobalOverrides` does not return an existing cluster override.

**Contributing factor:** This behavior has been observed after a Global Intent failure. Reapplying the existing GlobalOverrides values can stabilize the status, but the exact root cause and affected or fixed build boundaries are not established by this article.

#### Remediation Steps

##### Step 1: Confirm the Flipping Behavior

**Action type: [READ-ONLY]**

Run `Get-NetIntentStatus` repeatedly and preserve timestamps:

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

Proceed only if the same intent and host transition between `Validating` and `Success / Completed` during the observation period.

**Stop condition:** If the status remains stable or becomes failed with a concrete error, do not continue with this mitigation.

##### Step 2: Exclude a Concrete Network ATC Failure

**Action type: [READ-ONLY]**

Review these event channels for the same observation window:

- `Microsoft-Windows-Networking-NetworkAtc/Operational`
- `Microsoft-Windows-Networking-NetworkAtc/Admin`

**Stop condition:** If the logs identify a concrete adapter, configuration, or hardware failure, resolve that issue instead. Do not use GlobalOverrides reapplication to bypass an understood failure.

##### Step 3: Capture GlobalOverrides and Check Safety Gates

**Action type: [READ-ONLY]**

Before making a cluster-scoped change:

1. Confirm that all cluster nodes are up, critical cluster groups are online, and virtual disks are healthy.
2. Schedule a maintenance window and monitor cluster and workload connectivity.
3. Confirm that out-of-band access is available for every node.
4. Capture the existing GlobalOverrides values.

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

The field-observed mitigation in this section is limited to the following configurable properties:

- `EnableNetworkNaming`
- `EnableLiveMigrationNetworkSelection`

**Stop condition:** Do not continue if the current values are ambiguous, cluster health is degraded, out-of-band access is unavailable, or another configurable GlobalOverrides property is populated. Escalate to Microsoft CSS or the Windows Network ATC product group.

##### Step 4: Reapply the Existing GlobalOverrides Values

**Risk label: [HIGH RISK]**

This operation removes and recreates a cluster-scoped Network ATC object. It can trigger Network ATC reconciliation and might interrupt management, compute, live migration, or storage connectivity. Do not remove or recreate individual production intents as part of this procedure.

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

**Rollback:** If `Add-NetIntent` fails, immediately restore the captured object:

```powershell
Add-NetIntent -GlobalClusterOverrides $newClusterOverride

Get-NetIntent -GlobalOverrides |
    Select-Object -ExpandProperty ClusterOverride |
    Format-List *
```

If the object cannot be restored or connectivity is affected, stop all further Network ATC changes and escalate with the command output and event logs.

##### Step 5: Verify Stability

**Action type: [READ-ONLY]**

First verify that the effective GlobalOverrides values match the captured values:

```powershell
Get-NetIntent -GlobalOverrides |
    Select-Object -ExpandProperty ClusterOverride |
    Format-List *
```

Then repeat the status observation:

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

If an update was blocked, rerun update readiness validation before retrying the update. Update success alone does not prove that the intent status is stable.

If status continues to oscillate, do not repeat the mitigation or remove and recreate the cluster intents. Escalate with:

- Azure Local solution and OS versions.
- Before-and-after repeated `Get-NetIntentStatus` output.
- Before-and-after GlobalOverrides values.
- Network ATC Operational and Admin event logs covering the observation and mitigation window.
- Cluster, storage, and workload health before and after the operation.
- The exact output and timestamp of any failed mitigation or rollback step.

---

### Transient States

The intent transient states include:

- **Provisioning**: Intent is being initially provisioned
- **Retrying**: Intent provisioning failed and is retrying
- **Validating**: ATC is performing drift detection (occurs every 15 minutes)
- **Pending**: Intent is queued for provisioning

If an intent remains in a transient state and never back to **Completed** state, it likely indicates a problem that needs attention.

---

## Additional Information

### Understanding Intent Status Values

**ConfigurationStatus values:**
- `Success`: Intent is properly configured
- `Failed`: Intent configuration or provisioning failed
- `Provisioning`: Intent is being set up (transient)
- `Retrying`: Previous attempt failed, retrying (transient)
- `Validating`: ATC drift detection in progress (transient)
- `Pending`: Intent is queued (transient)

**ProvisioningStatus values:**
- `Completed`: Intent provisioning completed successfully
- `InProgress`: Intent provisioning is in progress (transient)

### Checking Intent Logs

For detailed troubleshooting, check Network ATC logs:

```powershell
# Get recent Network ATC events
Get-WinEvent -LogName "Microsoft-Windows-Networking-NetworkATC/Operational" -MaxEvents 100 |
    Where-Object { $_.TimeCreated -gt (Get-Date).AddHours(-1) } |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Format-Table -AutoSize -Wrap
```

### Common Intent Failure Causes

| Cause | Description | Resolution |
|-------|-------------|-----------|
| Adapter down | Network adapter is disconnected or disabled | Check physical connectivity, enable adapter |
| Driver issues | Incompatible or faulty network driver | Update or reinstall drivers |
| VMSwitch conflicts | Existing VMSwitch conflicts with intent | Remove conflicting VMSwitch or reconcile |
| RDMA configuration | RDMA settings incompatible | Check RDMA configuration |
| Resource conflicts | IP address or VLAN conflicts | Check network configuration |

### Best Practices

1. **Ensure all adapters are healthy** before creating intents
2. **Use consistent driver versions** across all nodes
3. **Document intent configuration** for troubleshooting
4. **Monitor intent status** regularly
5. **Allow time for provisioning** before making changes
6. **Check logs** for detailed error information

### Related Documentation

- [Network ATC overview](https://learn.microsoft.com/en-us/azure/azure-local/concepts/network-atc-overview)
- [Manage network intents](https://learn.microsoft.com/en-us/windows-server/networking/network-atc/manage-network-atc)
- [Host network requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
