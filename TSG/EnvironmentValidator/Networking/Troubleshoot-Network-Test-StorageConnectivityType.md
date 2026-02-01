# AzStackHci_Network_Test_StorageConnectivityType

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_StorageConnectivityType</strong></td>
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

This validator checks that Rack Aware clusters do not use switchless storage connectivity. Rack Aware deployments require switched storage connectivity to ensure proper network routing and communication across multiple racks.

## Requirements

For Rack Aware clusters:
1. Storage connectivity must NOT be switchless (must use network switches)

For Standard or Stretch clusters:
- This validation is skipped (both switched and switchless are supported)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the storage connectivity type.

```json
{
  "Name": "AzStackHci_Network_Test_StorageConnectivityType",
  "DisplayName": "Test storage connectivity type for Rack Aware cluster",
  "Title": "Test storage connectivity type for Rack Aware cluster",
  "Status": 1,
  "Severity": 2,
  "Description": "Test that switchless storage connectivity is NOT used for Rack Aware cluster.",
  "Remediation": "",
  "TargetResourceID": "StorageConnectivityType",
  "TargetResourceName": "StorageConnectivityType",
  "TargetResourceType": "StorageConnectivityType",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "<ComputerName>",
    "Resource": "StorageConnectivityType",
    "Detail": "Switchless storage connectivity is used for Rack Aware cluster.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Switchless Storage Used for Rack Aware Cluster

**Error Message:**
```text
Switchless storage connectivity is used for Rack Aware cluster.
```

**Root Cause:** The deployment is configured to use switchless storage connectivity, but this is not supported for Rack Aware clusters. Rack Aware clusters span multiple racks and require network switches to route storage traffic between racks.

#### Remediation Steps

##### Change to Switched Storage Connectivity

1. Review your deployment configuration and locate the storage connectivity setting.

2. Change the storage connectivity type from switchless to switched:

   **In deployment configuration file:**
   - Look for a parameter like `SwitchlessDeploy`, `StorageConnectivityType`, or similar
   - Change from `switchless` to `switched` or from `true` to `false`

   **Example configuration change:**
   ```json
   {
       "clusterPattern": "RackAware",
       "storageConnectivity": "switched"  // Changed from "switchless"
   }
   ```

3. Ensure your network infrastructure supports switched storage:
   - Network switches are installed and configured
   - Storage adapters are connected to network switches (not directly to each other)
   - VLANs are configured for storage traffic (if required)
   - Switches support required features (Jumbo Frames, RDMA/RoCE if used)

4. Retry the deployment with the updated configuration.

---

## Additional Information

### Understanding Storage Connectivity Types

**Switched Storage:**
- Storage adapters connect through network switches
- Required for Rack Aware clusters
- Supports cross-rack communication
- More flexible for scaling and reconfiguration
- Requires network switch infrastructure

**Switchless Storage:**
- Storage adapters connect directly between nodes
- Only supported for Standard and Stretch clusters  
- Not supported for Rack Aware clusters
- Simpler cabling but less flexible
- Limited to 2-3 node clusters typically

### Why Switchless is Not Supported for Rack Aware

Rack Aware clusters cannot use switchless storage because:
1. **Cross-rack connectivity**: Nodes in different racks cannot directly connect without switches
2. **Scalability**: Direct connections don't scale beyond a few nodes
3. **Fault domains**: Rack-level fault domains require switch-based routing
4. **Network topology**: Physical rack separation requires switch infrastructure

### Storage Connectivity Requirements by Cluster Type

| Cluster Type | Switched | Switchless | Notes |
|-------------|----------|------------|-------|
| **Standard** | ✓ Supported | ✓ Supported | Both options available |
| **Stretch** | ✓ Supported | ✓ Supported | Both options available |
| **Rack Aware** | ✓ Required | ✗ Not Supported | Must use switched |

### Network Switch Requirements for Switched Storage

When using switched storage connectivity, ensure your switches:

1. **Support required speeds**:
   - Minimum: 10Gbps
   - Recommended: 25Gbps or higher
   - Match your adapter capabilities

2. **Support required features**:
   - Jumbo Frames (MTU 9000+)
   - RDMA/RoCE (if using RDMA)
   - Flow Control (if using RoCE)
   - QoS/Priority Flow Control (for lossless Ethernet)

3. **Proper VLAN configuration**:
   - Storage traffic on dedicated VLAN (recommended)
   - Consistent VLAN configuration across all switches
   - Proper inter-switch connectivity

4. **Inter-rack connectivity**:
   - Switches in different racks must be interconnected
   - Sufficient bandwidth between racks
   - Redundant paths for fault tolerance

### Verifying Switched Storage Configuration

After configuring switched storage:

```powershell
# Verify network adapter connectivity
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
    Select-Object Name, Status, LinkSpeed, InterfaceDescription |
    Format-Table -AutoSize

# Check if adapters are connected to switches (not directly connected)
# LinkSpeed should show switch port speed, not direct connection speed
# InterfaceDescription should show adapter model
```

### Converting from Switchless to Switched

If you started planning for switchless but need switched:

1. **Physical changes required**:
   - Install network switches if not present
   - Recable storage adapters to connect through switches
   - Configure switch ports appropriately

2. **Configuration changes required**:
   - Update deployment configuration to use switched mode
   - Configure VLANs on switches (if using)
   - Update network intent configuration

3. **Verify connectivity**:
   - Test network connectivity through switches
   - Verify RDMA functionality (if using)
   - Test storage performance

### Related Documentation

- [Network reference patterns](https://learn.microsoft.com/azure-stack/hci/plan/network-patterns-overview)
