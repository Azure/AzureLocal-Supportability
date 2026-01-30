# AzStackHci_Network_Test_Validity_MgmtIp_NotIn_Infra_Pool

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Validity_MgmtIp_NotIn_Infra_Pool</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment, Add-Server</strong></td>
  </tr>
</table>

## Overview

This validator checks that the management IP address assigned to each node does not overlap with the infrastructure IP pool range. The infrastructure IP pool is reserved for dynamic allocation of IP addresses to cluster resources, and node management IPs must be outside this range to avoid conflicts.

## Requirements

Each node must meet the following requirement:
1. The management IP address must be outside the infrastructure IP pool range (StartingAddress to EndingAddress)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about which node's management IP is conflicting with the IP pool. The `Source` field identifies the node, and the `TargetResourceID` shows the IP pool range.

```json
{
  "Name": "AzStackHci_Network_Test_Validity_MgmtIp_NotIn_Infra_Pool",
  "DisplayName": "Test Validity Management IP not in Infra Pool",
  "Title": "Test Validity Management IP not in Infra Pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking management IPs are not in infra IP pool",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "10.0.1.100-10.0.1.200",
  "TargetResourceName": "ManagementIpIpPoolConfiguration",
  "TargetResourceType": "ManagementIpIpPoolConfiguration",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NODE1",
    "Resource": "NodeManagementIP",
    "Detail": "Management IP [10.0.1.150] is in the infrastructure IP pool range [10.0.1.100-10.0.1.200]",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Management IP is within infrastructure IP pool range

**Error Message:**
```text
Management IP [10.0.1.150] is in the infrastructure IP pool range [10.0.1.100-10.0.1.200]
```

**Root Cause:** The node's management IP address falls within the infrastructure IP pool range. This creates a conflict because the IP address could be dynamically assigned to a cluster resource, resulting in IP address conflicts.

#### Remediation Steps

You have two options to remediate this issue:

##### Option 1: Change the node's management IP address (Recommended)

Reconfigure the node to use a management IP address outside the infrastructure IP pool range.

1. Identify the current management IP and the infrastructure IP pool range from the error message.

2. Choose a new IP address for the node that is:
   - Outside the infrastructure IP pool range
   - In the same subnet as the infrastructure IP pool
   - Not in use by any other device on the network

3. Change the management IP address on the affected node:

   ```powershell
   # Remove the old IP address
   # Make sure $adapterName contains the right adapter name in your system
   $adapterName = "myAdapterName"
   $oldIP = "10.0.1.150"  # Replace with the current management IP
   Remove-NetIPAddress -InterfaceAlias $adapterName -IPAddress $oldIP -Confirm:$false

   # Add the new IP address
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

5. Retry the validation to ensure the issue is resolved.

> **Important**: Changing the management IP address will temporarily disconnect the node from the network. Ensure you have console access or remote management (e.g., iLO, iDRAC) before making this change.

##### Option 2: Adjust the infrastructure IP pool range

Reconfigure the infrastructure IP pool to exclude the node's management IP address.

1. Identify the current management IP addresses of all nodes in the cluster.

2. Adjust the infrastructure IP pool range to exclude these addresses

3. Update the infrastructure IP pool configuration through your deployment method (Azure portal, ARM template).

4. Retry the validation to ensure the issue is resolved.

> **Note**: This option require modifying your deployment configuration files or ARM template parameters before starting the deployment.

---

## Additional Information

### Best Practices

- Reserve a separate range of IP addresses for node management IPs outside the infrastructure IP pool
- Document the IP addressing scheme for your Azure Local cluster
- Use IP Address Management (IPAM) tools to track IP address assignments and avoid conflicts

### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Plan host networking for Azure Local](https://learn.microsoft.com/azure-stack/hci/plan/plan-host-networking)
