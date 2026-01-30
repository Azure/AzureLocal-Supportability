# AzStackHci_Network_Test_Validity_MgmtIp_In_Infra_Subnet

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Validity_MgmtIp_In_Infra_Subnet</strong></td>
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

This validator checks that the management IP address assigned to each node is in the same subnet as the infrastructure IP pool. All management IPs and the infrastructure IP pool must be in the same subnet to ensure proper network communication within the cluster.

## Requirements

Each node must meet the following requirement:
1. The management IP address must be in the same subnet (CIDR) as the infrastructure IP pool

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the subnet mismatch. The `Source` field identifies the node, and the `TargetResourceID` shows both the management IP subnet and the infrastructure subnet.

```json
{
  "Name": "AzStackHci_Network_Test_Validity_MgmtIp_In_Infra_Subnet",
  "DisplayName": "Test Validity Management IP in same infra subnet as IP pools",
  "Title": "Test Validity Management IP in same infra subnet as IP pools",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking management IPs are in same subnet as infra IP pool",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "10.0.1.10/24-10.0.2.0/24",
  "TargetResourceName": "ManagementIpIpPoolCIDR",
  "TargetResourceType": "ManagementIpIpPoolCIDR",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NODE1",
    "Resource": "ManagementIpIpPoolCIDR",
    "Detail": "Management IP [10.0.1.10] is not in the same subnet as infrastructure IP pool. Management subnet: 10.0.1.0/24, Infrastructure subnet: 10.0.2.0/24",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Management IP is in a different subnet than infrastructure IP pool

**Error Message:**
```text
Management IP [10.0.1.10] is not in the same subnet as infrastructure IP pool. Management subnet: 10.0.1.0/24, Infrastructure subnet: 10.0.2.0/24
```

**Root Cause:** The node's management IP address is in a different subnet than the infrastructure IP pool. This prevents proper network communication between the node and cluster resources that receive IP addresses from the infrastructure pool.

#### Remediation Steps

You have two options to remediate this issue:

##### Option 1: Change the node's management IP address to match the infrastructure subnet (Recommended)

Reconfigure the node's management IP to be in the same subnet as the infrastructure IP pool.

1. Identify the infrastructure subnet from the error message (e.g., `10.0.2.0/24`).

2. Choose a new IP address for the node that is:
   - In the same subnet as the infrastructure IP pool
   - Outside the infrastructure IP pool range (to avoid conflicts)
   - Not in use by any other device on the network

3. Change the management IP address on the affected node:

   ```powershell
   # Make sure $adapterName contains the right management adapter from your system
   $adapterName = "myAdapterName"

   # Remove the old IP address
   $oldIP = "10.0.1.10"  # Replace with the current management IP
   Remove-NetIPAddress -InterfaceAlias $adapterName -IPAddress $oldIP -Confirm:$false

   # Remove old default gateway if needed
   Remove-NetRoute -InterfaceAlias $adapterName -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

   # Add the new IP address in the correct subnet
   $newIP = "10.0.2.10"  # Replace with new IP in the infrastructure subnet
   $prefixLength = 24  # Replace with your subnet prefix length
   $defaultGateway = "10.0.2.1"  # Replace with the gateway for the infrastructure subnet

   New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $newIP -PrefixLength $prefixLength -DefaultGateway $defaultGateway
   ```

4. Update DNS server configuration if needed:

   ```powershell
   $dnsServers = @("10.0.2.1")  # Replace with DNS servers accessible from the new subnet
   Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dnsServers
   ```

5. Verify the new IP address is configured correctly:

   ```powershell
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Manual" }
   Get-NetIPConfiguration -InterfaceAlias $adapterName
   ```

6. Verify network connectivity:

   ```powershell
   # Test connectivity to default gateway
   Test-NetConnection -ComputerName "10.0.2.1"
   ```

7. Retry the validation to ensure the issue is resolved.

> **Important**: Changing the management IP address will temporarily disconnect the node from the network. Ensure you have console access or remote management (e.g., iLO, iDRAC) before making this change.

##### Option 2: Adjust the infrastructure IP pool subnet

Reconfigure the infrastructure IP pool to be in the same subnet as the node management IPs.

1. Identify the current management IP subnet of all nodes (e.g., `10.0.1.0/24`).

2. Adjust the infrastructure IP pool to use addresses in the same subnet:
   - Choose a range within the management subnet that doesn't conflict with node management IPs
   - For example, if nodes use `10.0.1.1-10.0.1.10`, set the pool to `10.0.1.100-10.0.1.200`

3. Update the infrastructure IP pool configuration through your deployment method (Azure portal, PowerShell, or configuration files).

4. Ensure the subnet mask is consistent across all configuration:

   ```powershell
   # Example: Verify all nodes are on the same subnet
   Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Manual" } | Select-Object IPAddress, PrefixLength
   ```

5. Retry the validation to ensure the issue is resolved.

> **Note**: This option requires modifying your deployment configuration before starting or continuing the deployment.

---

### Understanding CIDR Notation

The error message shows subnets in CIDR notation (e.g., `10.0.1.0/24`). The number after the slash indicates how many bits are used for the network portion:

- `/24` = 255.255.255.0 (most common for small networks)
- `/23` = 255.255.254.0
- `/22` = 255.255.252.0

Check [Classless Inter-Domain Routing](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) for more information.

---

## Additional Information

### Best Practices

- Use consistent subnet across all management IPs and infrastructure IP pools
- Document your IP addressing scheme, including:
  - Node management IP range
  - Infrastructure IP pool range
  - Subnet mask (prefix length)
  - Default gateway
  - DNS servers
- Use IP Address Management (IPAM) tools to plan and track IP address assignments

### Common Subnet Configurations

| Prefix Length | Subnet Mask     | Usable IPs | Common Use Case                    |
|---------------|-----------------|------------|------------------------------------|
| /24           | 255.255.255.0   | 254        | Small clusters (up to ~250 nodes)  |
| /23           | 255.255.254.0   | 510        | Medium clusters                    |
| /22           | 255.255.252.0   | 1022       | Large clusters or future growth    |

### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Plan host networking for Azure Local](https://learn.microsoft.com/azure-stack/hci/plan/plan-host-networking)
- [IP addressing for Azure Local](https://learn.microsoft.com/azure-stack/hci/plan/network-patterns-overview#ip-addressing)
