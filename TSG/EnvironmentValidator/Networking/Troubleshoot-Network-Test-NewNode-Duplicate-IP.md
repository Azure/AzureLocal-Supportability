# AzStackHci_Network_Test_New_Node_Validity_Duplicate_IP

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_New_Node_Validity_Duplicate_IP</strong></td>
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

This validator checks that the management IP address of the new node being added to the cluster is not already defined in the ECE configuration or has duplication in the new nodes itself (if multiple nodes are added at the same time).
Each node in the cluster must have a unique management IP address.

## Requirements

The new node must meet the following requirement:
1. The node's management IP address must be unique and not used by any other node in the cluster

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about whether duplicate IPs were found. The `TargetResourceID` shows the new node's management IP address.

```json
{
  "Name": "AzStackHci_Network_Test_New_Node_Validity_Duplicate_IP",
  "DisplayName": "Test New Node Configuration Duplicate IP",
  "Title": "Test New Node Configuration Duplicate IP",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking New Node IP is not a duplicate",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "10.0.1.50",
  "TargetResourceName": "IPAddress",
  "TargetResourceType": "IPAddress",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NodeAndManagementIPMapping",
    "Resource": "NodeManagementIPs",
    "Detail": "Duplicate IPs found for Node Management IPs",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Duplicate IPs Found for Node Management IPs

**Root Cause:** Multiple nodes in the cluster (including the new node being added) are configured with the same management IP address. This creates network conflicts and prevents proper cluster communication.

#### Remediation Steps

##### Confirmation of Duplicate IPs

1. You could use below command to confirm the management IP addresses of all existing cluster nodes and new node to be added:

   ```powershell
   # Run on each node
   $computerName = $env:COMPUTERNAME
   $mgmtIP = (Get-NetIPConfiguration | Where-Object { $null -ne $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" }).IPv4Address.IPAddress
   Write-Host "Node: $computerName, Management IP: $mgmtIP"
   ```

##### Change the New Node's Management IP Address

Once you've confirmed the duplicate, change the new node's management IP to a unique address.

1. Choose a new IP address that is:
   - Unique (not used by any existing cluster node)
   - Outside the infrastructure IP pool range
   - In the same subnet as existing cluster nodes
   - Not in use by any other device on the network

2. On the new node, change the management IP address:

   ```powershell
   # Get the management adapter name
    $adapterName = "myAdapterName" # Replace with the actual adapter name in your system

   # Remove the duplicate IP address
   $duplicateIP = "10.0.1.50"  # Replace with the duplicate IP
   Remove-NetIPAddress -InterfaceAlias $adapterName -IPAddress $duplicateIP -Confirm:$false

   # Add a unique IP address
   $newUniqueIP = "10.0.1.55"  # Replace with a unique IP
   $prefixLength = 24  # Replace with your subnet prefix length
   $defaultGateway = "10.0.1.1"  # Replace with your gateway

   New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $newUniqueIP -PrefixLength $prefixLength -DefaultGateway $defaultGateway
   ```

3. Verify the new IP address is configured correctly:

   ```powershell
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Manual" }
   Get-NetIPConfiguration -InterfaceAlias $adapterName
   ```

4. Verify network connectivity and uniqueness:

   ```powershell
   # Test connectivity to default gateway
   Test-NetConnection -ComputerName "10.0.1.1" # Replace with your gateway

   # Test connectivity to an existing cluster node
   Test-NetConnection -ComputerName "<ExistingNodeIP>"

   # Verify the IP is not in use by any other device
   # Run this from an existing cluster node:
   Test-NetConnection -ComputerName "10.0.1.55" -InformationLevel Quiet
   # Should return True only when pinging the new node
   ```

5. Retry the Add-Server operation.

> **Important**: Changing the management IP address will temporarily disconnect the node from the network. Ensure you have console access or remote management (e.g., iLO, iDRAC) before making this change.

---

## Additional Information

### Why Duplicate IPs Cause Problems

Duplicate IP addresses cause several critical issues:
1. **Network conflicts**: Both nodes try to respond to the same IP
2. **Unreliable communication**: Network traffic may be routed to the wrong node
3. **Cluster instability**: The cluster cannot reliably communicate with nodes
4. **Add-Server failure**: The operation will fail to complete

### Common Causes of Duplicate IPs
| Cause | Description | Prevention |
|-------|-------------|-----------|
| Copy-paste error | Copied IP from existing node documentation | Double-check IP before configuration |
| Outdated documentation | Using old IP assignments | Keep IP inventory up to date |
| Manual typo | Incorrect IP entered during configuration | Verify IP address before applying |

### Best Practices for IP Address Management

1. **Maintain an IP address inventory**:
   - Create a spreadsheet tracking all cluster node IPs
   - Document which IPs are reserved for infrastructure pool
   - Update the inventory when adding or removing nodes

2. **Use consistent IP addressing schemes**:
   - Example: First node = .10, second node = .11, etc.
   - Reserve .100-.200 for infrastructure pool
   - Keep management IPs in a contiguous range

3. **Verify before deployment**:
   ```powershell
   # Before configuring a new node, verify IP is available
   Test-NetConnection -ComputerName "10.0.1.55" -InformationLevel Quiet
   # Should return False if IP is available
   ```

4. **Use DHCP reservations or static IPs consistently**:
   - For static IP deployments, configure IPs manually before Add-Server
   - For DHCP deployments, create DHCP reservations for each node

### Example IP Addressing Scheme

For a 4-node cluster with infrastructure pool:

| Node | Management IP | Infrastructure Pool | Gateway |
|------|--------------|-------------------|---------|
| NODE1 | 10.0.1.11 | 10.0.1.100-10.0.1.200 | 10.0.1.1 |
| NODE2 | 10.0.1.12 | 10.0.1.100-10.0.1.200 | 10.0.1.1 |
| NODE3 | 10.0.1.13 | 10.0.1.100-10.0.1.200 | 10.0.1.1 |
| NODE4 | 10.0.1.14 | 10.0.1.100-10.0.1.200 | 10.0.1.1 |

### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
