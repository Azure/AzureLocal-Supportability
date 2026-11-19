# AzStackHci_Network_Test_New_Node_And_IP_Match

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_New_Node_And_IP_Match</strong></td>
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

This validator checks that the new node's hostname and management IP address match the expected configuration provided in the Add-Server operation. The node name retrieved from the system must correspond to the management IP address assigned to that node.

## Requirements

The new node must meet the following requirement:
1. The node's hostname must match the expected configuration for its management IP address

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the node name and IP mismatch. The `TargetResourceID` shows the management IP address.

```json
{
  "Name": "AzStackHci_Network_Test_New_Node_And_IP_Match",
  "DisplayName": "Test New Node Configuration Name and IP Match",
  "Title": "Test New Node Configuration Name and IP Match",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking New Node Name and IP match",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "10.0.1.50",
  "TargetResourceName": "IPAddress",
  "TargetResourceType": "IPAddress",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NodeAndManagementIPMapping",
    "Resource": "NewNodeNameAndManagementIP",
    "Detail": "New Node Mgmt IP '10.0.1.50' is not on the New Node. Found instead on 'NODE1'",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Node Name and IP Do Not Match Expected Configuration

**Error Message:**
```text
New Node Mgmt IP '10.0.1.50' is not on the New Node. Found instead on 'NODE1'
```

**Root Cause:** The management IP address being used for the Add-Server operation is associated with a different node than expected. This typically indicates a configuration mismatch where:
- The wrong IP address was specified in the Add-Server configuration
- The node hostname doesn't match the expected mapping
- The node was not properly configured before Add-Server

#### Remediation Steps

##### Verify Node Configuration

1. Check the actual node name and IP configuration on the node being added:

   ```powershell
   # Run on the node being added
   $computerName = $env:COMPUTERNAME
   $mgmtIP = (Get-NetIPConfiguration | Where-Object {
       $null -ne $_.IPv4DefaultGateway -and
       $_.NetAdapter.Status -eq "Up"
   }).IPv4Address.IPAddress

   Write-Host "Actual Node Name: $computerName"
   Write-Host "Actual Management IP: $mgmtIP"
   ```

2. Compare with the expected configuration:
   - Expected Node Name: (from Add-Server configuration)
   - Expected Management IP: (from error message, e.g., `10.0.1.50`)

##### Option 1: Correct the Add-Server Configuration (If Wrong IP Specified)

If the Add-Server configuration specifies the wrong IP address:

1. Review the Add-Server parameters and retry with the corrected configuration.

##### Option 2: Rename the Node (If Wrong Hostname)

If the node has the wrong hostname:

1. Check if the node needs to be renamed to match the expected configuration:

2. Rename the computer (requires restart):

3. After the node restarts, verify the name change:

   ```powershell
   $env:COMPUTERNAME
   ```

4. Retry the Add-Server operation.

> **Warning**: Renaming a computer requires a restart and will temporarily disconnect the node.

##### Option 3: Reconfigure the Node's Management IP (If Wrong IP)

If the node has the wrong management IP configured:

1. Determine the correct IP address for this node from your deployment plan.

2. On the node being added, change the management IP:

3. Retry the Add-Server operation.

---

## Additional Information

### Understanding the Node Name and IP Mapping

During Add-Server operations, Azure Local expects:
1. **A specific node name** to be added (e.g., NODE4)
2. **A specific management IP** for that node (e.g., 10.0.1.13)
3. **The hostname and IP must match** on the actual node

This validator ensures the mapping is correct before proceeding with the add operation.

### Best Practices for Add-Server Preparation

1. **Pre-configure the node**:
   - Set the correct hostname
   - Configure the correct management IP
   - Verify network connectivity
   - Document the configuration

2. **Create a deployment checklist**:
   ```plaintext
   Node Preparation Checklist:
   ☐ Hostname set to: NODE4
   ☐ Management IP: 10.0.1.13 /24
   ☐ Gateway: 10.0.1.1
   ☐ DNS: 10.0.1.1
   ☐ Network connectivity tested
   ☐ Time synchronized with cluster
   ```

3. **Verify before Add-Server**:
   ```powershell
   # Run on the node before adding to cluster
   $computerName = $env:COMPUTERNAME
   $mgmtIP = (Get-NetIPConfiguration | Where-Object {
       $null -ne $_.IPv4DefaultGateway -and
       $_.NetAdapter.Status -eq "Up"
   }).IPv4Address.IPAddress

   Write-Host "Node Name: $computerName"
   Write-Host "Management IP: $mgmtIP"
   Write-Host ""
   Write-Host "Expected Node Name: NODE4"
   Write-Host "Expected Management IP: 10.0.1.13"
   Write-Host ""
   if ($computerName -eq "NODE4" -and $mgmtIP -eq "10.0.1.13") {
       Write-Host "✓ Configuration matches expectations" -ForegroundColor Green
   } else {
       Write-Host "✗ Configuration does NOT match expectations" -ForegroundColor Red
   }
   ```

### Example Deployment Plan

For adding NODE4 to an existing 3-node cluster:

| Node | Expected Hostname | Expected Management IP | Status |
|------|------------------|----------------------|--------|
| NODE1 | NODE1 | 10.0.1.10 | Existing |
| NODE2 | NODE2 | 10.0.1.11 | Existing |
| NODE3 | NODE3 | 10.0.1.12 | Existing |
| NODE4 | NODE4 | 10.0.1.13 | Being Added |

**Before running Add-Server:**
1. Configure NODE4 with hostname "NODE4"
2. Configure NODE4 with IP 10.0.1.13
3. Verify configuration matches expectations
4. Run Add-Server with NODE4/10.0.1.13 configuration

### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
