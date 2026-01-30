# AzureLocal_Network_Test_AKS_Subnet_POD_SERVICE_CIDR_DNSServer_Overlap

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_AKS_Subnet_POD_SERVICE_CIDR_DNSServer_Overlap</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Informational</strong>: This validator provides information but will not block operations.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This validator checks that DNS server addresses configured on the management adapter do not overlap with the Kubernetes POD CIDR or Service CIDR subnets. While this is informational and will not block deployment, DNS servers in these ranges may indicate a configuration issue.

## Requirements

DNS servers should meet the following recommendation:
1. DNS server IP addresses should not fall within the POD CIDR subnet (default: `10.244.0.0/16`)
2. DNS server IP addresses should not fall within the Service CIDR subnet (default: `10.96.0.0/12`)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the DNS server addresses and whether they overlap with AKS CIDR ranges.

```json
{
  "Name": "AzureLocal_Network_Test_AKS_Subnet_POD_SERVICE_CIDR_DNSServer_Overlap",
  "DisplayName": "Test for DNS server overlaps with POD CIDR Subnet 10.244.0.0/16 and Service CIDR Subnet 10.96.0.0/12",
  "Title": "Test for DNS server overlaps with POD CIDR Subnet 10.244.0.0/16 and Service CIDR Subnet 10.96.0.0/12",
  "Status": 1,
  "Severity": 0,
  "Description": "Checking DNS server address(es) not within the POD CIDR Subnet 10.244.0.0/16 and Service CIDR Subnet 10.96.0.0/12",
  "Remediation": "Verify DNS servers configured are not overlapping with AKS pre-defined POD subnet and Service subnet. Check https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning for more information.",
  "TargetResourceID": "DNSServer-10.244.0.10",
  "TargetResourceName": "DNSServer-10.244.0.10",
  "TargetResourceType": "DNSServer-10.244.0.10",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "DNSServerPODServiceCIDR",
    "Resource": "DNSServerPODServiceCIDR",
    "Detail": "DNS server address(es): 10.244.0.10. POD CIDR: 10.244.0.0/16; Service CIDR: 10.96.0.0/12",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Informational: DNS Server Overlaps with POD or Service CIDR

**Message:**
```text
DNS server address(es): 10.244.0.10. POD CIDR: 10.244.0.0/16; Service CIDR: 10.96.0.0/12
```

**Description:** The DNS server address configured on the management adapter overlaps with the POD CIDR or Service CIDR subnet. This is informational and will not block deployment, but may indicate a configuration issue or potential routing conflicts. Microsoft will upgrade the severity of this validator in the future.

#### Recommended Actions

##### Verify DNS Server Configuration

1. Check the DNS server configuration on the management adapter:

   ```powershell
   # Get DNS configuration from appropriate adapter
   # change $adapterName to the adapter name defined in your system.
   $adapterName = "myAdapterName"
    Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4
   ```

2. Verify the DNS server IP addresses:
   - Check if the reported DNS server IP is correct
   - Verify the DNS server is reachable and functional
   - Confirm this is the intended DNS server for your environment

3. If the DNS server address is incorrect or in a conflicting range, consider reconfiguring it:

   ```powershell
   # Set DNS server to an address outside the CIDR ranges
   # Replace with your actual DNS server address
   $dnsServers = @("192.168.1.1", "192.168.1.2")
   Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dnsServers
   ```

4. Verify the new DNS configuration:

   ```powershell
   Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4

   # Test DNS resolution
   Resolve-DnsName "microsoft.com"
   ```

##### Understanding the Impact

Having a DNS server in the POD or Service CIDR ranges may cause:
- **Routing conflicts**: DNS queries may be misdirected when AKS workloads are deployed
- **Connectivity issues**: DNS resolution may fail for pods or services
- **Network complexity**: Troubleshooting becomes more difficult

However, if the DNS server is:
- Actually located at that address and functioning correctly
- Properly routed and accessible
- Not conflicting with AKS workload networking

Then you may choose to accept this configuration and monitor for issues.

##### When to Reconfigure

Consider reconfiguring the DNS server address if:
1. The DNS server is a placeholder or temporary configuration
2. You plan to deploy AKS workloads on this cluster
3. You want to avoid potential future networking conflicts
4. You have DNS servers available in non-conflicting ranges

##### When It's Acceptable to Proceed

You may proceed without changes if:
1. The DNS server is intentionally placed in this range
2. You have verified it does not conflict with your AKS deployment plans
3. Your network routing is configured to handle this scenario
4. You've documented this configuration for future reference

---

## Additional Information

### Default AKS CIDR Ranges

- **POD CIDR**: `10.244.0.0/16` (default)
  - Range: `10.244.0.0` to `10.244.255.255`
  - Reserved for Kubernetes pod IP addresses
- **Service CIDR**: `10.96.0.0/12` (default)
  - Range: `10.96.0.0` to `10.111.255.255`
  - Reserved for Kubernetes service IP addresses

### Recommended DNS Server Placement

For optimal network design, place DNS servers in ranges that do not conflict with:
- POD CIDR: `10.244.0.0/16`
- Service CIDR: `10.96.0.0/12`
- Infrastructure IP pools

**Common DNS server locations:**
- Corporate DNS: Use your organization's existing DNS infrastructure
- On-premises DNS: Typically in your datacenter's management network
- Cloud DNS: Azure DNS or other cloud-provided DNS services

**Example non-conflicting ranges:**
- `192.168.x.x` - Private network range
- `10.0.x.x` - Private network range (avoid `10.96-10.111` and `10.244`)
- `172.16.x.x` - Private network range

### Related Documentation

- [AKS IP Address Planning](https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning)
- [Azure Local Network Requirements](https://learn.microsoft.com/en-us/azure-stack/hci/concepts/host-network-requirements)
- [DNS configuration for Azure Local](https://learn.microsoft.com/en-us/azure-stack/hci/manage/configure-dns)
