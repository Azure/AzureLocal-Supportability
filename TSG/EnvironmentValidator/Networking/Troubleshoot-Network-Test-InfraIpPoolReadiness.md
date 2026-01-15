# AzStackHci_Network_Test_InfraIpPoolReadiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_InfraIpPoolReadiness</strong></td>
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

This validator verifies that the Infrastructure IP Pool (Management IP Range) configuration meets requirements for Azure Local deployment. The validator performs multiple checks to ensure the IP pools are properly configured and available for use.

## Requirements

The Infrastructure IP Pool must meet the following requirements:

1. **No Duplicate IPs**: IP addresses must not be repeated across different pools
2. **Subnet Alignment**: All IP addresses in pools must be within the specified Management Subnet
3. **No Active Hosts**: IP addresses in the pool must not respond to ping or have services listening on ports 5986, 5985, or 22
4. **Range Size**: The total number of IP addresses across all pools must be between 6 and 255
5. **Pool Count**: Must have 1 or 2 IP pools. If 2 pools are provided, the first pool must contain exactly 1 IP address

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. This validator performs multiple checks and may report different failure types. Check the `Name` and `AdditionalData.Detail` fields to identify the specific issue.

---

## Check 1: IP Pools Subnet and No Duplicates

**Validator Name:** `AzStackHci_Network_Test_IP_Pools_Subnet_No_Duplicates`

### Example Output

```json
{
  "Name": "AzStackHci_Network_Test_IP_Pools_Subnet_No_Duplicates",
  "Title": "Test IP Pools in Management Subnet and No duplicate IPs in IpPools",
  "DisplayName": "Test IP Pools 192.168.1.0/24",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking start and end address are on the same subnet",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "IpPool-192.168.1.0/24",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "AdditionalData": {
    "Detail": "Ip Pools have duplicates or do not fall in subnet 192.168.1.0/24",
    "Status": "FAILURE"
  }
}
```

### Root Cause

One or more of the following issues exists:
- IP addresses are duplicated across different pools
- IP addresses in the pools are not within the specified Management Subnet
- IP ranges within pools overlap

### Remediation Steps

1. Review your IP pool configuration and ensure no IP addresses are repeated:
   ```json
   # Example: Check your IP pool configuration, below is a wrong configuration as IP 192.168.1.10 is duplicated.
            "IPPools": [
              {
                "StartingAddress": "192.168.1.10",
                "EndingAddress": "192.168.1.10"
              },
              {
                "StartingAddress": "192.168.1.10",
                "EndingAddress": "192.168.1.20"
              }
            ],
   ```

2. Verify all IP addresses are within the Management Subnet:
   ```json
   # Verify IPs are in subnet
    "InfrastructureNetwork": [
        {
            "VlanId": "0",
            "SubnetMask": "255.255.255.0",
            "Gateway": "192.168.1.1",
            ...
        },
        ...
    ]
   # Ensure all IPs from pools fall within this subnet range
   ```
   For example, above "SubnetMask" definition will give you a "*/24*" subnet and all the IP defined in section "InfrastructureNetwork | IPPools" should fall into subnet *192.168.1.0/24*.

3. Remove any duplicate or overlapping IP addresses from your pool configuration in the JSON

4. Make sure all IP defined in "IPPools" are in the subnet defined by "SubnetMask".

5. Re-run the Environment Validator

---

## Check 2: Management IP Range Subnet

**Validator Name:** `AzStackHci_Network_Test_Management_IP_Range_Subnet`

### Example Output

```json
{
  "Name": "AzStackHci_Network_Test_Management_IP_Range_Subnet",
  "Title": "Test Management IP Subnet",
  "DisplayName": "Test Management IP Subnet 192.168.1.10 - 192.168.1.20",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking start and end address are on the same subnet",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "192.168.1.10-192.168.1.20",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "AdditionalData": {
    "Detail": "IP range 192.168.1.10 - 192.168.1.20 is not in the management subnet",
    "Status": "FAILURE"
  }
}
```

### Root Cause

The starting or ending IP address in a pool is not within the specified Management Subnet.

### Remediation Steps

1. Verify the Management Subnet CIDR notation is correct:
   ```json
   # Verify IPs are in subnet
    "InfrastructureNetwork": [
        {
            "VlanId": "0",
            "SubnetMask": "255.255.255.0",
            "Gateway": "192.168.1.1",
            ...
        },
        ...
    ]
   # Ensure all IPs from pools fall within this subnet range

2. Ensure both starting and ending addresses are within the subnet:
   ```json
   # Example: Check your IP pool configuration, below is a wrong configuration as IP 192.168.2.10 is not in subnet 192.168.1.0/24
            "IPPools": [
              {
                "StartingAddress": "192.168.2.10",
                "EndingAddress": "192.168.2.10"
              },
              {
                "StartingAddress": "192.168.1.12",
                "EndingAddress": "192.168.1.20"
              }
            ],
   ```

3. Update your IP pool configuration with valid addresses from the subnet defined by "SubnetMask".

4. Re-run the Environment Validator

---

## Check 3: No Active Hosts in IP Range

**Validator Name:** `AzStackHci_Network_Test_Management_IP_No_Active_Hosts`

### Example Output

```json
{
  "Name": "AzStackHci_Network_Test_Management_IP_No_Active_Hosts",
  "Title": "Test Management IP Range for Active Hosts",
  "DisplayName": "Test Management IP Range 192.168.1.15 for Active Hosts",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking no hosts respond on Management IP range",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "192.168.1.15",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "AdditionalData": {
    "Source": "192.168.1.15",
    "Resource": "ICMP/SSH/WINRM",
    "Detail": "Ping:True, 5986:False, 5985:True, 22:False",
    "Status": "FAILURE"
  }
}
```

### Root Cause

An IP address in the pool is currently in use. The `AdditionalData.Detail` field shows which connectivity tests passed:
- **Ping**: `True` means the IP responds to ICMP ping
- **5986**: `True` means WinRM HTTPS (port 5986) is responding
- **5985**: `True` means WinRM HTTP (port 5985) is responding
- **22**: `True` means SSH (port 22) is responding

### Remediation Steps

1. Identify what device is using the IP address:
   ```powershell
   # Test connectivity to the IP
   Test-NetConnection -ComputerName <IP-Address> -InformationLevel Detailed

   # Try to identify the device
   Resolve-DnsName -Name <IP-Address> -ErrorAction SilentlyContinue

   # Check ARP cache
   Get-NetNeighbor -IPAddress <IP-Address>
   ```

2. Choose one of the following options:
   - **Option A**: Change the IP address of the device using this IP to an address outside the pool
   - **Option B**: Modify your IP pool configuration to exclude the IPs that are in use

3. Verify the IP is no longer in use:
   ```powershell
   Test-NetConnection -ComputerName <IP-Address> -InformationLevel Quiet
   ```

4. Re-run the Environment Validator

---

## Check 4: IP Range Size

**Validator Name:** `AzStackHci_Network_Test_Management_IP_Range_Size`

### Example Output

```json
{
  "Name": "AzStackHci_Network_Test_Management_IP_Range_Size",
  "Title": "Test Management IP Range Size",
  "DisplayName": "Test Management IP Range Size of all the pools. 4 ips found.",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking management IP range size is between 6-255",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "Size:4",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "AdditionalData": {
    "Detail": "Management IP range size must be between 6 and 255",
    "Status": "FAILURE"
  }
}
```

### Root Cause

The total number of IP addresses across all pools is either:
- Less than 6 (insufficient IPs for deployment)
- Greater than 16 (exceeds maximum supported range)

### Remediation Steps

1. Calculate the total number of IPs in your pools:
   ```powershell
   # Example calculation
   # Pool 1: 192.168.1.10 to 192.168.1.15 = 6 IPs
   # Pool 2: 192.168.1.20 to 192.168.1.25 = 6 IPs
   # Total: 12 IPs
   ```

2. Adjust your IP pools to provide between 6 and 16 IP addresses total:
   ```powershell
   # Example: Single pool with 10 IPs
   $IpPool = @{
       StartingAddress = "192.168.1.10"
       EndingAddress = "192.168.1.19"
   }
   ```

3. Re-run the Environment Validator

---

## Check 5: IP Pool Count

**Validator Name:** `AzStackHci_Network_Test_Management_IP_Range_Pool_Count`

### Example Output

```json
{
  "Name": "AzStackHci_Network_Test_Management_IP_Range_Pool_Count",
  "Title": "Test Management IP Pool Count",
  "DisplayName": "Test Management IP Range Number of IP Pools.",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking management IP pools has one or two pools. First pool must only have 1 ip if 2 pools",
  "Remediation": "https://aka.ms/hci-envch",
  "TargetResourceID": "Count:3",
  "TargetResourceName": "ManagementIPRange",
  "TargetResourceType": "Network Range",
  "AdditionalData": {
    "Detail": "Found 3 pools. Expected 1 or 2 pools. If 2 pools, first pool must have 5 or fewer IPs.",
    "Status": "FAILURE"
  }
}
```

### Root Cause

One of the following pool configuration issues exists:
- More than 2 IP pools are defined
- Exactly 2 pools are defined, but the first pool contains more than 1 IP address

### Remediation Steps

1. **If you have more than 2 pools**, consolidate them into 1 or 2 pools:
   ```powershell
   # Instead of 3 pools:
   # Pool 1: 192.168.1.10-192.168.1.12
   # Pool 2: 192.168.1.20-192.168.1.22
   # Pool 3: 192.168.1.30-192.168.1.32

   # Use 1 consolidated pool:
   $IpPool = @{
       StartingAddress = "192.168.1.10"
       EndingAddress = "192.168.1.25"
   }
   ```

2. **If you have 2 pools**, ensure the first pool contains exactly 1 IP:
   ```powershell
   # Correct configuration with 2 pools
   $IpPools = @(
       @{StartingAddress = "192.168.1.10"; EndingAddress = "192.168.1.10"}  # First pool: 1 IP
       @{StartingAddress = "192.168.1.20"; EndingAddress = "192.168.1.30"}  # Second pool: 11 IPs
   )
   ```

3. Re-run the Environment Validator

---

## Additional Notes

- The validator will restart the Device Management Service (if present) after validation to refresh network adapter details to Azure
- When using 2 pools, the first pool (containing 1 IP) is reserved for cluster IP.
- All validations must pass for the deployment to proceed

## Related Documentation
- [Azure Local - Prerequisites](https://aka.ms/hci-envch)
- [Azure Local - Host Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
