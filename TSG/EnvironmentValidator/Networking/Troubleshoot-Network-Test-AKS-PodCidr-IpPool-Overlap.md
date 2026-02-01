# AzStackHci_Network_Test_AKS_Subnet_POD_CIDR_IP_Range_Overlap

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_AKS_Subnet_POD_CIDR_IP_Range_Overlap</strong></td>
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

This validator checks that IP pool ranges (StartingAddress to EndingAddress) do not overlap with the Kubernetes POD CIDR subnet. The POD CIDR is reserved for Kubernetes pod networking in AKS workloads, and customer IP pools must not conflict with this range.

## Requirements

IP pools must meet the following requirement:
1. IP pool StartingAddress and EndingAddress must not fall within the POD CIDR subnet (default: `10.244.0.0/16`)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about which IP pool is overlapping with the POD CIDR. The `TargetResourceID` field shows the specific IP pool range.

```json
{
  "Name": "AzStackHci_Network_Test_AKS_Subnet_POD_CIDR_IP_Range_Overlap",
  "DisplayName": "Test for overlaps with POD CIDR Subnet 10.244.0.0/16",
  "Title": "Test for overlaps with POD CIDR Subnet 10.244.0.0/16",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking start and end address are not within the POD CIDR Subnet 10.244.0.0/16",
  "Remediation": "Verify IP pool(s) are not overlapping with AKS pre-defined POD subnet. Check https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning for more information.",
  "TargetResourceID": "IpPool-10.244.1.10-10.244.1.20",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "CustomerNetwork",
    "Resource": "CustomerSubnet",
    "Detail": "Start IP '10.244.1.10' and End IP '10.244.1.20' overlaps with the POD subnet: 10.244.0.0/16.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: IP Range Overlaps with POD CIDR

**Error Message:**
```text
IP Range: 10.244.1.10 - 10.244.1.20 overlaps with K8s Default POD CIDR: 10.244.0.0/16. Please reconfigure the network to resolve this conflict.
```

**Root Cause:** The IP pool range overlaps with the Kubernetes POD CIDR subnet (default: `10.244.0.0/16`). This creates a critical conflict because these addresses are reserved for Kubernetes pod networking in AKS workloads.

#### Remediation Steps

##### Reconfigure IP Pool to Avoid POD CIDR Range

The IP pool must be reconfigured to use addresses outside the POD CIDR range (`10.244.0.0/16` by default).

1. Review the current IP pool configuration to identify the overlapping range. Look at the `TargetResourceID` field in the error message to identify the specific IP pool (e.g., `IpPool-10.244.1.10-10.244.1.20`).

2. Understand the POD CIDR range:
   - Default POD CIDR: `10.244.0.0/16`
   - This means addresses from `10.244.0.0` to `10.244.255.255` are reserved
   - Your IP pools must be outside this entire range

3. Choose a new IP range that does not overlap with the POD CIDR subnet. Recommended alternatives:
   - `10.0.x.x/24` - Common for small networks
   - `192.168.x.x/24` - Private network range
   - `172.16.x.x` through `172.31.x.x` - Private network range
   - Any other subnet in your enterprise that doesn't conflict with `10.244.0.0/16`

4. Update the IP pool configuration through your deployment method:

   **For Azure portal deployment:**
   - Modify the IP pool configuration in the deployment wizard before proceeding

   **Example IP pool configuration (outside POD CIDR):**
   ```powershell
   # Example: Change from 10.244.1.10-10.244.1.20 to 10.0.1.10-10.0.1.20
   $ipPool = @{
       StartingAddress = "10.0.1.10"
       EndingAddress   = "10.0.1.20"
   }
   ```

5. Verify the new IP range does not conflict with:
   - POD CIDR: `10.244.0.0/16`
   - Service CIDR: `10.96.0.0/12` (see related validator)
   - Other network segments in your environment

6. Retry the validation after reconfiguring the IP pool.

> **Important**: Ensure the new IP range:
> - Is routable within your network
> - Does not conflict with existing infrastructure
> - Has sufficient capacity for your deployment needs
> - Is in the same subnet as node management IPs

---

## Additional Information

### Default AKS CIDR Ranges

- **POD CIDR**: `10.244.0.0/16` (default, can be customized)
  - Reserved for Kubernetes pod IP addresses
  - Critical: Must not overlap with customer networks
- **Service CIDR**: `10.96.0.0/12` (default)
  - Reserved for Kubernetes service IP addresses
  - Warning: Should not overlap with customer networks

### Understanding the POD CIDR Range

The POD CIDR `10.244.0.0/16` includes all addresses from:
- **Start**: `10.244.0.0`
- **End**: `10.244.255.255`
- **Total addresses**: 65,536 addresses

Your IP pools must use addresses completely outside this range.

### Recommended IP Addressing Schemes

| Use Case | Recommended Range | CIDR Notation | Addresses |
|----------|------------------|---------------|-----------|
| Small deployment | 192.168.1.0 - 192.168.1.255 | 192.168.1.0/24 | 254 |
| Medium deployment | 10.0.0.0 - 10.0.255.255 | 10.0.0.0/16 | 65,534 |
| Large deployment | 172.16.0.0 - 172.31.255.255 | 172.16.0.0/12 | 1,048,574 |

Avoid using `10.244.x.x` or `10.96.x.x` to prevent conflicts with AKS default ranges.

### Related Documentation

- [AKS IP Address Planning](https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning)
- [Azure Local Network Requirements](https://learn.microsoft.com/en-us/azure-stack/hci/concepts/host-network-requirements)
