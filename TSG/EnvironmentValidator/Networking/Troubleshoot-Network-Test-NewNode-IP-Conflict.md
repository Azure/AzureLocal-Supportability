# AzStackHci_Network_Test_New_Node_Validity_IP_Conflict

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_New_Node_Validity_IP_Conflict</strong></td>
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

This validator checks that the management IP address of the new node being added to the cluster is not already in use by another node. This differs from the duplicate IP check in that it specifically verifies the IP addresses saved in the ECE configuration store and in the parameter passed into Add-Server cmdlet call.

## Requirements

The new node must meet the following requirement:
1. The node's management IP address must not be in use by any other node in the cluster

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about which node is using the conflicting IP. The `TargetResourceID` shows the new node's management IP address.

```json
{
  "Name": "AzStackHci_Network_Test_New_Node_Validity_IP_Conflict",
  "DisplayName": "Test New Node Configuration Conflicting IP",
  "Title": "Test New Node Configuration Conflicting IP",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking New Node IP is not on another node",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "10.0.1.50",
  "TargetResourceName": "IPAddress",
  "TargetResourceType": "IPAddress",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NodeAndManagementIPMapping",
    "Resource": "NodeNameAndManagementIP",
    "Detail": "Mgmt IP '10.0.1.50' was found on another Node. Found on 'NODE1'",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Management IP Found on Another Node

**Error Message:**
```text
Mgmt IP '10.0.1.50' was found on another Node. Found on 'NODE1'
```

**Root Cause:** The management IP address configured on the new node is already in use by another existing node in the cluster (in this example, NODE1). This creates an IP conflict that prevents the new node from being added.

#### Remediation Steps

##### Option 1: Change the New Node's Management IP (Recommended)

This is the recommended approach as it doesn't impact existing cluster nodes.

1. Identify the conflicting node from the error message (e.g., `NODE1`).

2. Verify the conflict by checking the existing node's IP:

   ```powershell
   # Run on the existing node mentioned in the error (e.g., NODE1)
   $computerName = $env:COMPUTERNAME
   $mgmtIP = (Get-NetIPConfiguration | Where-Object { $null -ne $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" }).IPv4Address.IPAddress
   Write-Host "Node: $computerName, Management IP: $mgmtIP"
   ```

3. Choose a new unique IP address for the new node that is:
   - Not used by any existing cluster node
   - Outside the infrastructure IP pool range
   - In the same subnet as existing cluster nodes
   - Not in use by any other device on the network

4. On the new node being added, change the management IP address:

5. Verify the new IP address is configured correctly:

6. Verify network connectivity:

   ```powershell
   # Test connectivity to default gateway
   Test-NetConnection -ComputerName "10.0.1.1"

   # Test connectivity to the existing node
   Test-NetConnection -ComputerName "10.0.1.50"  # Should reach NODE1

   # Test from an existing node to the new node
   Test-NetConnection -ComputerName "10.0.1.55"  # Should reach new node
   ```

7. Retry the Add-Server operation.

> **Important**: Changing the management IP address will temporarily disconnect the node from the network. Ensure you have console access or remote management (e.g., iLO, iDRAC) before making this change.

##### Option 2: Correct the Configuration (If Misconfigured)

If the new node was incorrectly configured with an existing node's IP:

1. Review the deployment configuration or answer file to ensure the correct IP address is specified for the new node.

2. Correct any configuration errors in the deployment parameters.

3. Retry the Add-Server operation with the corrected configuration.

---

## Additional Information

### Understanding IP Conflicts

An IP conflict occurs when two devices on the same network are configured with the same IP address. This can cause:
- **Network instability**: Packets may be delivered to the wrong device
- **Connection failures**: Services may become unreachable
- **Cluster communication issues**: Nodes cannot reliably communicate

### Difference from Duplicate IP Check

While similar, this validator differs from `AzStackHci_Network_Test_New_Node_Validity_Duplicate_IP`:
- **Duplicate IP check**: Verifies no two nodes have the same IP (general duplicate detection)
- **IP Conflict check**: Specifically verifies the new node's IP is not on a different (existing) node

Both checks ensure IP uniqueness but from slightly different perspectives.

### Common Causes of IP Conflicts
| Cause | Description | Prevention |
|-------|-------------|-----------|
| Manual configuration error | IP address was manually configured incorrectly | Use IP address management (IPAM) tools |
| Cloned node | New node was cloned from an existing node | Always reconfigure IP after cloning |
| DHCP issue | DHCP server assigned duplicate address | Use DHCP reservations for cluster nodes |

### Troubleshooting Tips

1. **List all node IPs**:
   ```powershell
   # Run on each existing cluster node to create an inventory
   Get-ClusterNode | ForEach-Object {
       $nodeName = $_.Name
       $session = New-PSSession -ComputerName $nodeName
       $ip = Invoke-Command -Session $session -ScriptBlock {
           (Get-NetIPConfiguration | Where-Object {
               $null -ne $_.IPv4DefaultGateway -and
               $_.NetAdapter.Status -eq "Up"
           }).IPv4Address.IPAddress
       }
       Remove-PSSession $session
       [PSCustomObject]@{
           NodeName = $nodeName
           ManagementIP = $ip
       }
   }
   ```

2. **Verify IP availability before configuration**:
   ```powershell
   # Test if IP is in use (from any existing cluster node)
   $testIP = "10.0.1.55"
   $pingResult = Test-NetConnection -ComputerName $testIP -InformationLevel Quiet
   if ($pingResult) {
       Write-Host "WARNING: IP $testIP is already in use!"
   } else {
       Write-Host "IP $testIP is available"
   }
   ```

3. **Check for ARP cache conflicts**:
   ```powershell
   # View ARP cache to see which MAC address is associated with the IP
   Get-NetNeighbor -IPAddress "10.0.1.50" -ErrorAction SilentlyContinue
   ```

### Example Scenario

**Existing cluster nodes:**
- NODE1: 10.0.1.10
- NODE2: 10.0.1.11
- NODE3: 10.0.1.12

**Adding new node (NODE4):**
- **Incorrect**: Configured as 10.0.1.10 (conflicts with NODE1) ❌
- **Correct**: Configured as 10.0.1.13 (unique IP) ✅

### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
