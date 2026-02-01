# AzStackHci_Network_Test_AKS_Subnet_Service_CIDR_IP_Range_Overlap

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_AKS_Subnet_Service_CIDR_IP_Range_Overlap</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Warning</strong>: This validator will not block operations but may result in suboptimal network conditions.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This validator checks that IP pool ranges (StartingAddress to EndingAddress) do not overlap with the Kubernetes Service CIDR subnet. While this is a warning rather than a critical error, overlaps with the Service CIDR may result in suboptimal network conditions or connectivity issues with AKS workloads.

## Requirements

IP pools should meet the following requirement:
1. IP pool StartingAddress and EndingAddress should not fall within the Service CIDR subnet (default: `10.96.0.0/12`)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about which IP pool is overlapping with the Service CIDR. The `TargetResourceID` field shows the specific IP pool range.

```json
{
  "Name": "AzStackHci_Network_Test_AKS_Subnet_Service_CIDR_IP_Range_Overlap",
  "DisplayName": "Test for overlaps with Service CIDR IP Subnet 10.96.0.0/12",
  "Title": "Test for overlaps with Service CIDR IP Subnet 10.96.0.0/12",
  "Status": 1,
  "Severity": 1,
  "Description": "Checking start and end address are not within the Service CIDR Subnet",
  "Remediation": "Verify IP pool(s) are not overlapping with AKS pre-defined Service subnet. Check https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning for more information.",
  "TargetResourceID": "IpPool-10.100.1.10-10.100.1.20",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "Timestamp": "<timestamp>/",
  "AdditionalData": {
    "Source": "CustomerNetwork",
    "Resource": "CustomerSubnet",
    "Detail": "Start IP '10.244.1.10' and End IP '10.244.1.20' overlaps with the Service subnet: 10.96.0.0/12.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Warning: IP Range Overlaps with Service CIDR

**Warning Message:**
```text
IP Range: 10.100.1.10 - 10.100.1.20 overlaps with K8s Default Service CIDR: 10.96.0.0/12. Be aware that this many result in suboptimal network conditions.
```

**Description:** The IP pool range overlaps with the Kubernetes Service CIDR subnet (default: `10.96.0.0/12`). While this is a warning and not critical, it may cause network routing issues or conflicts when deploying AKS workloads.

#### Remediation Steps

##### Option 1: Reconfigure IP Pool to Avoid Service CIDR Range (Recommended)

While this is a warning and not critical, it is strongly recommended to reconfigure the IP pool to avoid potential network issues.

1. Review the current IP pool configuration to identify the overlapping range. Look at the `TargetResourceID` field in the error message to identify the specific IP pool (e.g., `IpPool-10.100.1.10-10.100.1.20`).

2. Understand the Service CIDR range:
   - Default Service CIDR: `10.96.0.0/12`
   - This means addresses from `10.96.0.0` to `10.111.255.255` are reserved
   - Your IP pools should be outside this entire range

3. Choose a new IP range that does not overlap with the Service CIDR subnet. Recommended alternatives:
   - `10.0.x.x/24` - Common for small networks (note: not in `10.96-10.111` range)
   - `192.168.x.x/24` - Private network range
   - `172.16.x.x` through `172.31.x.x` - Private network range
   - `10.112.x.x` and higher (outside the `10.96.0.0/12` range)

4. Update the IP pool configuration through your deployment method:

   **For Azure portal deployment:**
   - Modify the IP pool configuration in the deployment wizard before proceeding

   **For PowerShell deployment:**
   - Update the IP pool parameters in your deployment script or configuration file

   **Example IP pool configuration (outside Service CIDR):**
   ```powershell
   # Example: Change from 10.100.1.10-10.100.1.20 to 10.0.1.10-10.0.1.20
   $ipPool = @{
       StartingAddress = "10.0.1.10"
       EndingAddress   = "10.0.1.20"
   }
   ```

5. Verify the new IP range does not conflict with:
   - POD CIDR: `10.244.0.0/16` (see related validator)
   - Service CIDR: `10.96.0.0/12`
   - Other network segments in your environment

6. Retry the validation after reconfiguring the IP pool.

> **Note**: Ensure the new IP range:
> - Is routable within your network
> - Does not conflict with existing infrastructure
> - Has sufficient capacity for your deployment needs
> - Is in the same subnet as node management IPs

##### Option 2: Accept the Warning and Proceed (Not Recommended)

If reconfiguring the IP pool is not feasible, you may proceed with the deployment, but be aware that:
- This may result in suboptimal network conditions
- Connectivity issues with AKS workloads may occur
- Network routing problems may arise
- You may need to reconfigure the network later to resolve issues

**If you choose to proceed:**
1. Document the IP overlap in your deployment notes
2. Monitor for network connectivity issues after deployment
3. Be prepared to reconfigure the network if problems arise

---

## Additional Information

### Default AKS CIDR Ranges

- **POD CIDR**: `10.244.0.0/16` (default, can be customized)
  - Reserved for Kubernetes pod IP addresses
  - Critical: Must not overlap with customer networks
- **Service CIDR**: `10.96.0.0/12` (default)
  - Reserved for Kubernetes service IP addresses
  - Warning: Should not overlap with customer networks

### Understanding the Service CIDR Range

The Service CIDR `10.96.0.0/12` includes all addresses from:
- **Start**: `10.96.0.0`
- **End**: `10.111.255.255`
- **Total addresses**: 1,048,576 addresses

Your IP pools should use addresses completely outside this range.

### Service CIDR Breakdown

The `/12` CIDR includes these `/16` subnets:
- `10.96.0.0/16` through `10.111.0.0/16` (16 subnets total)

To avoid overlap, use IP addresses outside the range `10.96.0.0 - 10.111.255.255`.

### Recommended IP Addressing Schemes

| Use Case | Recommended Range | CIDR Notation | Addresses |
|----------|------------------|---------------|-----------|
| Small deployment | 192.168.1.0 - 192.168.1.255 | 192.168.1.0/24 | 254 |
| Medium deployment | 10.0.0.0 - 10.0.255.255 | 10.0.0.0/16 | 65,534 |
| Large deployment | 172.16.0.0 - 172.31.255.255 | 172.16.0.0/12 | 1,048,574 |
| Alternative in 10.x.x.x | 10.112.0.0 - 10.127.255.255 | 10.112.0.0/12 | 1,048,574 |

Avoid using:
- `10.244.x.x` (POD CIDR)
- `10.96.x.x` through `10.111.x.x` (Service CIDR)

### Why This Matters

While Service CIDR overlaps are only a warning, they can cause:
1. **Routing conflicts**: Network traffic may be misdirected
2. **Service connectivity issues**: Kubernetes services may not be reachable
3. **Unpredictable behavior**: Network behavior may be inconsistent
4. **Troubleshooting complexity**: Network issues become harder to diagnose

It's best to avoid these overlaps from the start rather than troubleshooting them later.

### Related Documentation

- [AKS IP Address Planning](https://learn.microsoft.com/en-us/azure/aks/aksarc/aks-hci-ip-address-planning)
- [Azure Local Network Requirements](https://learn.microsoft.com/en-us/azure-stack/hci/concepts/host-network-requirements)
