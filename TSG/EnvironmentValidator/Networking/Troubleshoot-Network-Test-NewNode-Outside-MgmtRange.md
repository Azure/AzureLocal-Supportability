# AzStackHci_Network_Test_New_Node_Validity_Outside_Mgmt_Range

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_New_Node_Validity_Outside_Mgmt_Range</strong></td>
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

This validator checks that the management IP address of the new node being added to the cluster does not fall within the infrastructure IP pool range. The infrastructure IP pool is reserved for dynamic IP allocation, and node management IPs must be outside this range to avoid conflicts.

## Requirements

The new node must meet the following requirement:
1. The node's management IP address must be outside the infrastructure IP pool range (StartingAddress to EndingAddress)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the management IP and IP pool range. The `Source` field identifies the new node name, and the `TargetResourceID` shows the management IP address.

```json
{
  "Name": "AzStackHci_Network_Test_New_Node_Validity_Outside_Mgmt_Range",
  "DisplayName": "Test New Node Configuration Outside Management Range",
  "Title": "Test New Node Configuration Outside Management Range",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking New Node IP",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "10.0.1.150",
  "TargetResourceName": "IPAddress",
  "TargetResourceType": "IPAddress",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NODE2",
    "Resource": "NewNodeManagementIP",
    "Detail": "New Node Mgmt IP '10.0.1.150' is inside the Start '10.0.1.100' and End '10.0.1.200' of the infra IP Pool! Make sure the IP is not in the range of the Infra IP Pool.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: New Node Management IP is Inside Infrastructure IP Pool Range

**Error Message:**
```text
New Node Mgmt IP '10.0.1.150' is inside the Start '10.0.1.100' and End '10.0.1.200' of the infra IP Pool! Make sure the IP is not in the range of the Infra IP Pool.
```

**Root Cause:** The new node's management IP address falls within the infrastructure IP pool range. This creates a conflict because the IP address could be dynamically assigned to a cluster resource, resulting in IP address conflicts.

#### Remediation Steps

##### Change the New Node's Management IP Address (Recommended)

Reconfigure the new node to use a management IP address outside the infrastructure IP pool range.

1. Identify the infrastructure IP pool range from the error message (e.g., `10.0.1.100-10.0.1.200`).

2. Choose a new IP address for the new node that is:
   - Outside the infrastructure IP pool range
   - In the same subnet as the infrastructure IP pool and existing nodes
   - Not in use by any other device on the network
   - Not used by any existing cluster nodes

3. On the new node, change the management IP address:

   ```powershell
   # Use the management adapter name in your system
   $adapterName = "myAdapterName"

   # Remove the old IP address
   $oldIP = "10.0.1.150"  # Replace with the current management IP from error
   Remove-NetIPAddress -InterfaceAlias $adapterName -IPAddress $oldIP -Confirm:$false

   # Add the new IP address (outside the IP pool range)
   $newIP = "10.0.1.50"  # Replace with new IP outside the pool range
   $prefixLength = 24  # Replace with your subnet prefix length
   $defaultGateway = "10.0.1.1"  # Replace with your gateway

   New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $newIP -PrefixLength $prefixLength -DefaultGateway $defaultGateway
   ```

4. Verify the new IP address is configured correctly:

   ```powershell
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Manual" }
   Get-NetIPConfiguration -InterfaceAlias $adapterName
   ```

5. Verify network connectivity:

   ```powershell
   # Test connectivity to default gateway
   Test-NetConnection -ComputerName "10.0.1.1"

   # Test connectivity to an existing cluster node
   Test-NetConnection -ComputerName "<ExistingNodeIP>"

   # Test DNS resolution
   Resolve-DnsName "microsoft.com"
   ```

6. Retry the Add-Server operation.

> **Important**: Changing the management IP address will temporarily disconnect the node from the network. Ensure you have console access or remote management (e.g., iLO, iDRAC) before making this change.

---

## Additional Information

### Understanding IP Pool Ranges

The infrastructure IP pool is a range of IP addresses reserved for:
- Cluster IP address
- Virtual IP addresses for cluster resources
- Dynamic IP allocation for services

Example IP pool: `10.0.1.100` to `10.0.1.200`
- This reserves 101 IP addresses (100-200 inclusive)
- Node management IPs must be outside this range

### Choosing a New Management IP

When selecting a new management IP for the node:

1. **Check the IP pool boundaries**:
   - If pool is `10.0.1.100-10.0.1.200`, use IPs below 100 or above 200
   - Examples: `10.0.1.50`, `10.0.1.99`, `10.0.1.201`, `10.0.1.250`

2. **Verify IP is not in use**:
   ```powershell
   # Test if IP is in use (from any existing cluster node)
   Test-NetConnection -ComputerName "10.0.1.50" -InformationLevel Quiet
   # Should return False if IP is available
   ```

3. **Ensure same subnet**:
   - New IP must be in the same subnet as existing nodes
   - Use the same prefix length (subnet mask)

4. **Document the IP assignment**:
   - Keep track of which IPs are assigned to nodes
   - Maintain an IP address management spreadsheet or IPAM system

### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Plan host networking for Azure Local](https://learn.microsoft.com/azure-stack/hci/plan/plan-host-networking)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
