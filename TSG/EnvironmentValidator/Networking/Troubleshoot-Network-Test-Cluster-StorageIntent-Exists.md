# AzStackHci_Network_Test_Network_Cluster_StorageIntentExistence

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Network_Cluster_StorageIntentExistence</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Add-Server</strong></td>
  </tr>
</table>

## Overview

This validator checks that a storage intent exists on the cluster before adding a new server. Storage intents are required for 2+ node Azure Local clusters to ensure proper storage network configuration. Without a storage intent, the new server cannot be added successfully.

## Requirements

The cluster must meet the following requirement:
1. At least one network intent must have `IsStorageIntentSet` equal to `True`

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about whether a storage intent was found. The `Source` field identifies the cluster name.

```json
{
  "Name": "AzStackHci_Network_Test_Network_Cluster_StorageIntentExistence",
  "DisplayName": "Test Storage intent should exists on current cluster",
  "Title": "Test Storage intent existence",
  "Status": 1,
  "Severity": 2,
  "Description": "Check if the storage intent is configured on the existing cluster",
  "Remediation": "Storage intent is required for 2+ nodes Azure Local cluster.\nPlease run below PowerShell cmdlet to add storage intent into the cluster:\n    Add-NetIntent\nCheck https://learn.microsoft.com/en-us/azure/azure-local/ for more information!",
  "TargetResourceID": "StorageIntent",
  "TargetResourceName": "StorageIntent",
  "TargetResourceType": "StorageIntent",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "MyCluster",
    "Resource": "AddNodeStorageIntentCheck",
    "Detail": "Storage Intent is not configured on the cluster MyCluster.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Storage Intent Not Configured

**Error Message:**
```text
Storage Intent is not configured on the cluster MyCluster.
```

**Root Cause:** The cluster does not have a storage intent configured. Storage intents are required for 2+ node clusters to define which network adapters are used for storage traffic (SMB, iSCSI, or RDMA traffic for Storage Spaces Direct).

#### Remediation Steps

##### Step 1: Verify Current Intent Configuration

1. Check all existing intents on the cluster:

   ```powershell
   # List all intents
   Get-NetIntent | Select-Object IntentName, IsStorageIntentSet, TrafficType, Adapter
   ```

2. Check if any intent has storage traffic type:

   ```powershell
   # Check for storage traffic in any intent
   Get-NetIntent | Where-Object { $_.TrafficType -contains "Storage" } |
       Select-Object IntentName, TrafficType, Adapter
   ```

3. Verify intent status across nodes:

   ```powershell
   # Check intent status on all cluster nodes
   Get-NetIntentStatus | Select-Object Host, IntentName, IsStorageIntentSet |
       Format-Table -AutoSize
   ```

##### Step 2: Determine Storage Network Design

Before adding a storage intent, determine your storage network design:

**Option A: Dedicated Storage Network**
- Separate physical adapters dedicated to storage traffic
- Recommended for high-performance workloads
- Example: eth2, eth3 for storage only

**Option B: Converged Network**
- Storage traffic shares adapters with other traffic types
- Recommended for most deployments
- Example: eth0, eth1 for management, compute, and storage

##### Step 3: Add Storage Intent

Choose the appropriate option based on your network design:

###### Option A: Add Dedicated Storage Intent

If you have dedicated storage adapters:

1. Identify the storage adapters on each node:

   ```powershell
   # Check adapters on all cluster nodes
   Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
   ```

2. Make sure you have a dedicated storage intent:

   If you accidentally removed the storage intent that was provisioned during the Azure Local deployment time, or your current Azure Local cluster is a single node cluster, you could add it back using **Set-StorageNetworkIntent** cmdlet.

###### Option B: Add Storage to Existing Intent (Converged)

If storage should share adapters with other traffic, you will need to remove current intent and re-create the intent with adding an additional "-Storage" option. Your system might experience disconnection if you are removing the management intent.

##### Step 4: Verify Storage Intent Creation

1. Confirm the storage intent exists:

   ```powershell
   # Check for storage intent
   Get-NetIntent | Where-Object { $_.IsStorageIntentSet -eq $true }
   ```

2. Monitor intent provisioning:

   ```powershell
   Get-NetIntentStatus
   ```

3. Verify storage network connectivity:

   ```powershell
   # Check storage adapter IP
   ipconfig /all
   # ping the storage IP to each other
   ping "<storage IP on the other node>" -S "<storage IP on current node>"

   ```

##### Step 5: Retry Add-Server Operation

After successfully creating the storage intent and verifying it's healthy, retry the Add-Server operation.

---

## Additional Information

### Why Storage Intent is Required

For 2+ node Azure Local clusters, storage intents are required to:
1. **Define storage network paths** - Specifies which adapters handle storage traffic
2. **Enable Storage Spaces Direct** - Required for distributed storage
3. **Optimize storage performance** - Ensures proper QoS and traffic isolation
4. **Enable RDMA** - Configures RDMA for high-performance storage

### Common Storage Network Designs

| Design | Description | Traffic Types | Adapters |
|--------|-------------|---------------|----------|
| **Dedicated Storage** | Separate adapters for storage | Storage only | eth2, eth3 |
| **Fully Converged** | All traffic on same adapters | Management, Compute, Storage | eth0, eth1 |

### Checking Storage Intent Configuration

```powershell
# View all storage-related configuration
Get-NetIntent

# Check storage adapter IPs
Get-NetIPAddress
# or
ipconfig /all
```

### Single-Node Clusters

**Note**: Single-node clusters do not require a storage intent. This validator only applies when adding a server to an existing cluster (making it 2+ nodes).

### Storage Network Requirements

When creating a storage intent, ensure:
1. **Adapters support RDMA** (if using RDMA)
2. **Sufficient bandwidth** (10Gbps+ recommended)
3. **Dedicated VLAN**
4. **Consistent configuration** across all nodes
5. **IP addressing planned** for storage network

### Troubleshooting Intent Provisioning

If the intent fails to provision:
1. Check adapter status (see Cluster Intent Status TSG)
2. Verify driver compatibility
3. Check for VMSwitch conflicts
4. Review Network ATC logs

### Best Practices

1. **Plan storage network design** before creating intents
2. **Use RDMA-capable adapters** for best performance
3. **Separate storage traffic** from other traffic when possible
4. **Document network configuration** for future reference
5. **Test storage connectivity** after creating intent
6. **Monitor intent status** regularly

### Related Documentation

- [Network ATC overview](https://learn.microsoft.com/en-us/azure/azure-local/concepts/network-atc-overview)
- [Host network requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
