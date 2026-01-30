# AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Informational</strong>: This validator provides diagnostic information.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment (Static IP only), Pre-Update (Static IP only)</strong></td>
  </tr>
</table>

## Overview

This validator checks that the management IP subnet does not overlap with any storage network subnet. Overlapping subnets can cause routing issues and prevent storage traffic from functioning correctly.

## Requirements

For static IP deployments:
1. The management IP subnet must be on a different subnet than all storage adapter subnets
2. Each storage adapter subnet must be unique and isolated from management traffic

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about subnet overlap.

```json
{
  "Name": "AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet",
  "DisplayName": "Test machine management IP is not in the same subnet as any storage network",
  "Title": "Test machine management IP is not in the same subnet as any storage network",
  "Status": 1,
  "Severity": 0,
  "Description": "Test machine management IP is not in the same subnet as any storage network",
  "Remediation": "https://learn.microsoft.com/azure-stack/hci/deploy/deployment-tool-checklist",
  "TargetResourceID": "NODE1, MgmtIPNotOverlapStorageSubnet",
  "TargetResourceName": "NODE1, MgmtIPNotOverlapStorageSubnet",
  "TargetResourceType": "MgmtIPNotOverlapStorageSubnet",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "NODE1, MgmtIPNotOverlapStorageSubnet",
    "Resource": "NODE1, MgmtIPNotOverlapStorageSubnet",
    "Detail": "Management IP 10.71.1.10 on subnet 10.71.1.0/24 overlaps with storage subnet(s): 10.71.1.0/24, 10.71.2.0/24.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Management IP Overlaps with Storage Subnet

**Error Message:**
```text
Management IP 10.71.1.10 on subnet 10.71.1.0/24 overlaps with storage subnet(s): 10.71.1.0/24, 10.71.2.0/24.
```

**Root Cause:** The management IP is configured in the same subnet as one or more storage adapters. This creates a routing conflict where the system cannot determine whether traffic should go through the management adapter or storage adapters.

#### Why This is a Problem

1. **Routing conflicts**: OS cannot determine which adapter to use for traffic in the overlapping subnet
2. **Storage performance**: Management traffic may interfere with storage performance
3. **Network isolation**: Best practice is to separate management and storage traffic on different subnets
4. **Troubleshooting complexity**: Overlap makes network issues harder to diagnose

#### Remediation Steps

##### 1. Identify Current Network Configuration

On the affected node, check current IP configuration:

```powershell
# View all IP addresses and their subnets
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    ForEach-Object {
        $ip = $_.IPAddress
        $prefix = $_.PrefixLength
        # Calculate subnet
        $ipObj = [IPAddress]$ip
        $mask = [IPAddress]([math]::pow(2, 32) - [math]::pow(2, (32 - $prefix)))
        $subnet = ([IPAddress]($ipObj.Address -band $mask.Address)).IPAddressToString

        [PSCustomObject]@{
            Adapter = $_.InterfaceAlias
            IP = $ip
            Prefix = $prefix
            Subnet = "$subnet/$prefix"
        }
    } | Format-Table -AutoSize
```

Example output showing the problem:
```
Adapter                  IP           Prefix Subnet
-------                  --           ------ ------
vManagement(...)         10.71.1.10   24     10.71.1.0/24    ← Management
vSMB(...#Ethernet 2)     10.71.1.20   24     10.71.1.0/24    ← Storage (OVERLAP!)
vSMB(...#Ethernet 3)     10.71.2.20   24     10.71.2.0/24    ← Storage
```

##### 2. Review Your Network Design

Check your deployment configuration and network plan:

**Storage Auto-IP (default):**
- Storage subnets are automatically assigned as: 10.71.1.0/24, 10.71.2.0/24, 10.71.3.0/24, etc.
- One subnet per VLAN or per adapter (depending on configuration)

**Static Storage IP:**
- Storage subnets are defined in the `storageNetworks` section of your deployment configuration

##### 3. Option A: Change Management IP Subnet (Recommended)

Move the management network to a different subnet:

```powershell
# Example: Change management from 10.71.1.x to 192.168.1.x

# Step 1: Remove current management IP
$mgmtAdapter = "vManagement(ManagementIntent)"  # Or physical adapter name
Remove-NetIPAddress -InterfaceAlias $mgmtAdapter -Confirm:$false
Remove-NetRoute -InterfaceAlias $mgmtAdapter -Confirm:$false

# Step 2: Assign new management IP in different subnet
New-NetIPAddress -InterfaceAlias $mgmtAdapter `
    -IPAddress "192.168.1.10" `
    -PrefixLength 24 `
    -DefaultGateway "192.168.1.1"

# Step 3: Update DNS servers
Set-DnsClientServerAddress -InterfaceAlias $mgmtAdapter `
    -ServerAddresses "192.168.1.100", "192.168.1.101"

# Step 4: Verify no overlap
Get-NetIPAddress -InterfaceAlias $mgmtAdapter
```

**Important:** If changing management subnet:
- Update the change on ALL nodes in the cluster
- Update your deployment configuration file
- Update DNS records
- Update any firewall rules or network policies
- Ensure the new subnet is routable in your network infrastructure

##### 4. Option B: Change Storage IP Subnets

Alternatively, change the storage network subnets (less common):

**For Auto-IP Storage:**
- Storage subnets are hardcoded to 10.71.x.0/24
- Cannot easily change without modifying deployment configuration
- Usually easier to change management subnet instead

**For Static Storage IP:**
- Update the `storageNetworks` section in your deployment configuration
- Choose different subnets that don't conflict with management

```json
{
    "storageNetworks": [
        {
            "name": "Storage1_Network",
            "networkAdapterName": "Ethernet 2",
            "vlanId": 711,
            "storageAdapterIPInfo": [
                {
                    "physicalNode": "NODE1",
                    "ipv4Address": "172.16.1.10",      // Changed from 10.71.1.x
                    "subnetMask": "255.255.255.0"
                }
            ]
        }
    ]
}
```

##### 5. Verify the Fix

After making changes, verify subnets are unique:

```powershell
# Check all adapter subnets
$subnets = @{}
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    ForEach-Object {
        $ip = $_.IPAddress
        $prefix = $_.PrefixLength
        $ipObj = [IPAddress]$ip
        $mask = [IPAddress]([math]::pow(2, 32) - [math]::pow(2, (32 - $prefix)))
        $subnet = ([IPAddress]($ipObj.Address -band $mask.Address)).IPAddressToString + "/$prefix"

        if ($subnets.ContainsKey($subnet)) {
            $subnets[$subnet] += ", " + $_.InterfaceAlias
        } else {
            $subnets[$subnet] = $_.InterfaceAlias
        }
    }

# Display results
$subnets.GetEnumerator()
```

---

## Additional Information

### Recommended Network Subnet Design

Best practice is to use separate subnet ranges for different traffic types:

| Traffic Type | Recommended Subnet Range | Example | Notes |
|-------------|------------------------|---------|-------|
| **Management** | 192.168.x.0/24 or 10.0.x.0/24 | 192.168.1.0/24 | Routable corporate network |
| **Storage (Auto-IP)** | 10.71.x.0/24 (fixed) | 10.71.1.0/24, 10.71.2.0/24 | Automatically assigned |
| **Storage (Static)** | 172.16.x.0/24 or 10.72-99.x.0/24 | 172.16.1.0/24, 172.16.2.0/24 | User-defined |
| **VM/Compute** | As per datacenter design | 10.10.0.0/16 | Depends on workload |

### Example: Good Network Design (No Overlap)

```
NODE1:
  vManagement(ManagementIntent)      192.168.1.10/24  ← Management subnet
  vSMB(StorageIntent#Ethernet 2)     10.71.1.10/24    ← Storage subnet 1
  vSMB(StorageIntent#Ethernet 3)     10.71.2.10/24    ← Storage subnet 2

NODE2:
  vManagement(ManagementIntent)      192.168.1.11/24  ← Management subnet
  vSMB(StorageIntent#Ethernet 2)     10.71.1.11/24    ← Storage subnet 1
  vSMB(StorageIntent#Ethernet 3)     10.71.2.11/24    ← Storage subnet 2
```

All subnets are unique - no overlap!

### Example: Bad Network Design (Overlap)

```
NODE1:
  vManagement(ManagementIntent)      10.71.1.10/24    ← Management
  vSMB(StorageIntent#Ethernet 2)     10.71.1.20/24    ← Storage (SAME SUBNET!)
  vSMB(StorageIntent#Ethernet 3)     10.71.2.20/24    ← Storage
```

Management and Storage1 are in the same 10.71.1.0/24 subnet - this will cause problems!

### Storage Auto-IP Subnet Assignment

When using storage auto-IP (EnableStorageAutoIP = true):
- The system automatically assigns storage subnets as 10.71.1.0/24, 10.71.2.0/24, etc.
- Number of subnets = minimum of (number of storage VLANs, number of storage adapters)
- IPs assigned within each subnet based on node position

**Therefore:** When using auto-IP, ensure your management subnet is NOT in the 10.71.x.0/24 range.

### Checking Deployment Configuration
Below example are for reference only. Please double check [latest example](https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.azurestackhci/create-cluster-2-node-switched-custom-storageip/azuredeploy.parameters.json) to see if schema is changed.

**For Auto-IP Storage:**
```json
{
    "hostNetwork": {
        "enableStorageAutoIP": true,  // Auto-IP enabled
        "intents": [
            {
                "name": "ManagementIntent",
                "adapter": ["Ethernet", "Ethernet 1"]
            },
            {
                "name": "StorageIntent",
                "adapter": ["Ethernet 2", "Ethernet 3"]
            }
        ],
        "storageNetworks": [
            { "name": "Storage1", "vlanId": 711 },  // Will get 10.71.1.0/24
            { "name": "Storage2", "vlanId": 712 }   // Will get 10.71.2.0/24
        ]
    }
}
```

**For Static Storage:**
```json
{
    "hostNetwork": {
        "enableStorageAutoIP": false,  // Static IP
        "storageNetworks": [
            {
                "name": "Storage1_Network",
                "vlanId": 711,
                "storageAdapterIPInfo": [
                    {
                        "physicalNode": "NODE1",
                        "ipv4Address": "172.16.1.10",  // Explicitly defined
                        "subnetMask": "255.255.255.0"
                    }
                ]
            }
        ]
    }
}
```

### Routing and Network Behavior with Overlap

When subnets overlap, Windows networking behavior can be unpredictable:

1. **Metric-based routing**: Windows uses route metrics to decide which adapter to use
2. **Load balancing**: May attempt to balance traffic across adapters (not desired for storage)
3. **Failover**: May switch adapters if one becomes unavailable
4. **Performance impact**: Storage traffic may go through wrong adapter, reducing performance

### Related Validators

This validator is part of a set of management IP configuration checks:
- **AzureLocal_Network_Test_NodeManagementIPConnection** - Tests connectivity to management IP
- **AzureLocal_Network_Test_Node_ManagementIP_On_Correct_Adapter** - Verifies IP on correct adapter
- **AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet** (this validator) - Verifies no subnet overlap

### Related Documentation
- [Network reference patterns](https://learn.microsoft.com/azure-stack/hci/plan/network-patterns-overview)
- [Custom IPs for storage in Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations#custom-ips-for-storage)
