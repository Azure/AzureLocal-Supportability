# AzStackHci_Network_Test_StorageConnections_VMSwitch_Configuration

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_StorageConnections_VMSwitch_Configuration</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This environment validator failure occurs when the Storage Adapters are associated with different VMSwitches across nodes. Creating a VMSwitch pre-deployment is optional; if it is misconfigured, this validator will fail.

> **Note:** Storage Adapters refer to the network adapters that are used in the Storage Network Intent.

## Requirements

All Storage Adapters on every node in the cluster must meet one of these criteria:

- **Option A (recommended):** Not be connected to any VMSwitches, OR
- **Option B:** Be connected to the same VMSwitch (consistent name and settings) across all nodes

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Host and Storage Adapters are not configured properly. You can identify the host(s) by the `TargetResourceID` field. The format is `NodeName (AdapterName)`

```json
{
  "Name": "AzStackHci_Network_Test_StorageConnections_VMSwitch_Configuration",
  "DisplayName": "Validate that Storage Adapters have consistent VMSwitch configuration across all nodes.",
  "Tags": {},
  "Title": "Validate that Storage Adapters have consistent VMSwitch configuration across all nodes.",
  "Status": 1,
  "Severity": 2,
  "Description": "All Storage Adapters must have the same VMSwitch configuration across nodes. This check only applies if the VMSwitch was created before deployment, which is optional.",
  "Remediation": "https://aka.ms/azurelocal/envvalidator/storageconnections",
  "TargetResourceID": "azloc-node1 (ethernet 2), azloc-node2 (ethernet 2)",
  "TargetResourceName": "azloc-node1 (ethernet 2), azloc-node2 (ethernet 2)",
  "TargetResourceType": "StorageAdapter",
  "Timestamp": "/Date(1750352645605)/",
  "AdditionalData": {
    "Detail": "Storage Adapter VMSwitch configurations differ between nodes: azloc-node1 (ethernet 2) has VMSwitch [testSwitch], azloc-node2 (ethernet 2) has no VMSwitch assigned.",
    "Status": "FAILURE",
    "TimeStamp": "06/19/2025 17:04:05",
    "Resource": "StorageAdapter",
    "Source": "azloc-node1 (ethernet 2), azloc-node2 (ethernet 2)"
  }
}
```

### Failure: `VMSwitch Configuration Mismatch Between Nodes`

#### Example

```text
Storage Adapter VMSwitch configurations differ between nodes: azloc-node1 (ethernet 2) has VMSwitch 'testSwitch', azloc-node2 (ethernet 2) has no VMSwitch assigned.
```

**Root Cause:** Storage Adapters have inconsistent VMSwitch associations across cluster nodes.

#### Remediation Steps

You have two options to resolve this failure:

##### Option 1: Remove the VMSwitches (Recommended)

The deployment process will automatically create the VMSwitch. It is not required to be created pre-deployment.

**Benefits:**

- Simplifies configuration
- Reduces potential conflicts
- Allows deployment to handle VMSwitch creation optimally

1. Remove the VMSwitch from all nodes with a failure.

   ```powershell
   # Step 1: Identify VMSwitches on affected adapters
   Get-VMSwitch | Where-Object { $_.NetAdapterInterfaceDescription -like "*ethernet 2*" }

   # Step 2: Remove the VMSwitch from each node (run on each affected node)
   Remove-VMSwitch -Name "testSwitch" -Force

   # Step 3: Verify VMSwitch removal
   Get-VMSwitch | Where-Object { $_.Name -eq "testSwitch" }
   # Should return no results
   ```

##### Option 2: Modify the Existing VMSwitch Configuration

Compare the VMSwitch configuration across all nodes and ensure they are consistent.

1. Compare Current Configuration

   Run on each node to understand current state:

   ```powershell
   # Check all VMSwitches
   Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription

   # Check specific adapter VMSwitch association
   Get-VMSwitch | Where-Object { $_.NetAdapterInterfaceDescription -like "*ethernet 2*" }

   # Check adapter details
   Get-NetAdapter -Name "ethernet 2" | Select-Object Name, Status, LinkSpeed
   ```

2. Choose Target Configuration

   Decide whether to:

   - **Option A:** Create VMSwitch on nodes that don't have it
   - **Option B:** Remove VMSwitch from nodes that have it

3. Option A, Create Missing VMSwitch

   ```powershell
   # Create VMSwitch on nodes that don't have it
   # Run this on nodes missing the VMSwitch
   New-VMSwitch -Name "testSwitch" -NetAdapterName "ethernet 2" -AllowManagementOS $true

   # Verify creation
   Get-VMSwitch -Name "testSwitch"
   ```

4. Option B, Remove Existing VMSwitch

   ```powershell
   # Remove VMSwitch from nodes that have it
   # Run this on nodes with the VMSwitch
   Remove-VMSwitch -Name "testSwitch2" -Force

   # Verify removal
   Get-VMSwitch | Where-Object { $_.Name -eq "testSwitch2" }
   ```