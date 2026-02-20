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

**Root Cause:** A known issue causes the local status returned by `Get-NetIntentStatus` to toggle between `Validating` and `Success` after a Global Intent failure. This means the intent never stays in a stable `Success` state long enough for the validator to pass, blocking solution updates.

You may observe this behavior when running `Get-NetIntentStatus` repeatedly — the `ConfigurationStatus` rapidly flips between `Validating` and `Success` on one or more nodes, while the `ProvisioningStatus` may appear empty during the `Validating` phase.

#### Remediation Steps

##### Step 1: Confirm the Flipping Behavior

1. Run `Get-NetIntentStatus` multiple times in quick succession and observe whether `ConfigurationStatus` alternates between `Validating` and `Success`:

   ```powershell
   # Run multiple times to observe the flipping behavior
   Get-NetIntentStatus | ft IntentName, Host, ConfigurationStatus, ProvisioningStatus
   ```

2. If you see the status toggling between `Validating` and `Success` (rather than staying in `Failed` or remaining stuck in `Validating`), proceed with the mitigation below.

##### Step 2: Reset Global Intent Overrides

The mitigation involves removing and re-adding the global cluster overrides for Network ATC. This stabilizes the intent status.

1. Check current global overrides:

   ```powershell
   # Check current overrides
   $globalIntent = Get-NetIntent -GlobalOverrides
   $clusterOverride = $globalIntent.ClusterOverride
   $clusterOverride
   ```

2. Create new cluster overrides and apply previous override values:

   ```powershell
   $newClusterOverride = New-NetIntentGlobalClusterOverrides

   # NOTE:
   # MAKE SURE YOUR NEW OVERRIDE VALUE MATCHES YOUR PREVIOUS VALUE, unless there is any empty value on the previous data
   # Set overrides on object based on the old value:  ex) $newClusterOverride.<prop> = <val>
   # If all the old properties are having empty value, you could put:
   # $newClusterOverride.EnableLiveMigrationNetworkSelection = $true
   # $newClusterOverride.EnableNetworkNaming= $true
   # DO NOT USE OTHER DEFAULT VALUE IF THE OLD PROPERTIES HAVE EMPTY VALUE
   ```

3. Remove old intent global overrides and re-add them:

   ```powershell
   # Remove old intent global overrides
   Remove-NetIntent -GlobalOverrides

   # Re-add global cluster overrides
   Add-NetIntent -GlobalClusterOverrides $newClusterOverride
   ```

4. Verify that the intent status is now stable:

   ```powershell
   # Verify intent status is stable at Success
   Get-NetIntentStatus | ft IntentName, Host, ConfigurationStatus, ProvisioningStatus
   ```

   Confirm that `ConfigurationStatus` remains `Success` and `ProvisioningStatus` is `Completed` across multiple checks.

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
