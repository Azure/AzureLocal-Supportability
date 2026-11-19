# AzureLocal_Network_Test_Node_ManagementIP_On_Correct_Adapter

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_Node_ManagementIP_On_Correct_Adapter</strong></td>
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

This validator checks that the management IP address configured on each node is assigned to the correct network adapter - specifically, the first adapter defined in the management intent or its corresponding virtual adapter (vManagement).

## Requirements

For static IP deployments:
1. Management IP must be configured on the first physical adapter specified in the management intent
2. OR, if a virtual switch has already been created, the management IP must be on the vManagement virtual adapter

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the adapter configuration.

```json
{
  "Name": "AzureLocal_Network_Test_Node_ManagementIP_On_Correct_Adapter",
  "DisplayName": "Test machine management IP is configured on correct adapter",
  "Title": "Test machine management IP is configured on correct adapter",
  "Status": 1,
  "Severity": 0,
  "Description": "Test machine management IP is configured on correct adapter",
  "Remediation": "https://learn.microsoft.com/azure-stack/hci/deploy/deployment-tool-checklist",
  "TargetResourceID": "NODE1, MgmtIPOnCorrectAdapter",
  "TargetResourceName": "NODE1, MgmtIPOnCorrectAdapter",
  "TargetResourceType": "MgmtIPOnCorrectAdapter",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "NODE1, MgmtIPOnCorrectAdapter",
    "Resource": "NODE1, MgmtIPOnCorrectAdapter",
    "Detail": "Management IP is not found on expected adapter Ethernet or vManagement(ManagementIntent) on server NODE1.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Management IP Not on Correct Adapter

**Error Message:**
```text
Management IP is not found on expected adapter Ethernet or vManagement(ManagementIntent) on server NODE1.
```

**Root Cause:** The management IP address is configured on the wrong network adapter. It should be on:
- The first physical adapter defined in the management intent (e.g., "Ethernet"), OR
- The corresponding virtual management adapter "vManagement(intentName)" if a virtual switch has been created

#### Remediation Steps

##### 1. Identify the Current IP Configuration

On the affected node, check which adapter has the management IP:

```powershell
# View all IP addresses and their adapters
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState |
    Format-Table -AutoSize
```

##### 2. Check Your Management Intent Configuration

Review your deployment configuration to identify the expected adapter:

```json
{
    "intents": [
        {
            "name": "ManagementIntent",
            "trafficType": ["Management"],
            "adapter": ["Ethernet", "Ethernet 2"]  // First adapter is "Ethernet"
        }
    ]
}
```

The management IP should be on the **first adapter** in the list ("Ethernet" in this example).

##### 3. Option A: Move IP to Correct Physical Adapter (No Virtual Switch)

If no virtual switch has been created yet, move the IP to the correct physical adapter:

```powershell
# Step 1: Identify the current and target adapters
$currentAdapter = "Ethernet 3"  # Adapter currently has the IP
$targetAdapter = "Ethernet"     # First adapter from management intent
$managementIP = "192.168.1.10"  # The management IP
$prefixLength = 24
$gateway = "192.168.1.1"
$dnsServers = @("192.168.1.100", "192.168.1.101")

# Step 2: Remove IP from current adapter
Remove-NetIPAddress -InterfaceAlias $currentAdapter -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceAlias $currentAdapter -Confirm:$false -ErrorAction SilentlyContinue

# Step 3: Assign IP to correct adapter
New-NetIPAddress -InterfaceAlias $targetAdapter `
    -IPAddress $managementIP `
    -PrefixLength $prefixLength `
    -DefaultGateway $gateway

# Step 4: Set DNS servers
Set-DnsClientServerAddress -InterfaceAlias $targetAdapter -ServerAddresses $dnsServers

# Step 5: Verify configuration
Get-NetIPConfiguration -InterfaceAlias $targetAdapter
```

##### 4. Option B: IP on Virtual Adapter (Virtual Switch Already Exists)

If you've already created a virtual switch via Network ATC, the management IP should be on the vManagement virtual adapter:

```powershell
# Check if virtual switch and vManagement adapter exist
Get-VMSwitch -SwitchType External
Get-VMNetworkAdapter -ManagementOS | Where-Object { $_.Name -like "vManagement*" }

# If vManagement exists but doesn't have the IP, assign it
$vMgmtAdapter = Get-VMNetworkAdapter -ManagementOS | Where-Object { $_.Name -like "vManagement*" } | Select-Object -First 1
$vAdapterName = "vManagement(ManagementIntent)"  # Update with actual name

# Assign IP to vManagement adapter
New-NetIPAddress -InterfaceAlias $vAdapterName `
    -IPAddress "192.168.1.10" `
    -PrefixLength 24 `
    -DefaultGateway "192.168.1.1"

Set-DnsClientServerAddress -InterfaceAlias $vAdapterName `
    -ServerAddresses "192.168.1.100", "192.168.1.101"
```

##### 5. Verify the Configuration

After making changes, verify the management IP is on the correct adapter:

```powershell
# Expected adapter name from configuration (first adapter in management intent)
$expectedPhysicalAdapter = "Ethernet"
$expectedVirtualAdapter = "vManagement(ManagementIntent)"  # If virtual switch exists

# Check physical adapter
Get-NetIPConfiguration -InterfaceAlias $expectedPhysicalAdapter -ErrorAction SilentlyContinue

# Check virtual adapter (if applicable)
Get-NetIPConfiguration -InterfaceAlias $expectedVirtualAdapter -ErrorAction SilentlyContinue

# Verify connectivity
Test-NetConnection -ComputerName "192.168.1.1" -InformationLevel Detailed  # Gateway
```

---

## Additional Information

### Understanding Management Adapter Requirements

**Physical Adapter (Pre-Deployment):**
- Before Network ATC creates the virtual switch, the management IP must be on the first physical adapter defined in the management intent
- This allows initial connectivity during deployment

**Virtual Adapter (Post-ATC):**
- After Network ATC creates a SET (Switch Embedded Teaming) virtual switch, it creates a vManagement virtual adapter
- The management IP is then moved to the vManagement adapter
- The naming pattern is `vManagement(IntentName)` where IntentName is the name of the management intent

### Management Adapter Selection

The validator expects the management IP on the **first adapter** in the management intent adapter list:

```json
{
    "intents": [
        {
            "name": "ManagementIntent",
            "trafficType": ["Management"],
            "adapter": ["Ethernet", "Ethernet 2"]
            // ↑ Management IP should be on "Ethernet" (first in list)
        }
    ]
}
```

### Checking Current Adapter Configuration

To see all network adapters and their IPs:

```powershell
# List all adapters with IP configuration
Get-NetAdapter | Sort-Object Name | ForEach-Object {
    $ipConfig = Get-NetIPAddress -InterfaceAlias $_.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254.*" }

    [PSCustomObject]@{
        Adapter = $_.Name
        Status = $_.Status
        IP = if ($ipConfig) { $ipConfig.IPAddress } else { "None" }
        Type = if ($_.Name -like "vManagement*") { "Virtual (ATC)" }
               elseif ($_.Name -like "vEthernet*") { "Virtual" }
               else { "Physical" }
    }
} | Format-Table -AutoSize
```

### Common Scenarios

| Scenario | Expected Adapter | Notes |
|----------|-----------------|-------|
| **Pre-deployment** | First physical adapter from intent | Before Network ATC runs |
| **During deployment** | Transitioning from physical to virtual | IP may be on either |
| **Post-deployment** | vManagement(IntentName) | After Network ATC creates virtual switch |
| **Pre-Update** | vManagement(IntentName) | Should already be configured |

### Virtual Adapter Naming

Network ATC creates virtual adapters with specific naming patterns:

| Intent Type | Virtual Adapter Name | Example |
|------------|---------------------|---------|
| Management Only | `vManagement(IntentName)` | `vManagement(ManagementIntent)` |
| Storage in Converged | `vSMB(IntentName#AdapterName)` | `vSMB(ConvergedIntent#Ethernet2)` |

### Verification After Deployment

After successful deployment, verify the management configuration:

```powershell
# Check that vManagement adapter exists and has correct IP
$vMgmt = Get-VMNetworkAdapter -ManagementOS | Where-Object { $_.Name -like "vManagement*" }
if ($vMgmt) {
    Write-Host "vManagement adapter found: $($vMgmt.Name)" -ForegroundColor Green
    Get-NetIPConfiguration -InterfaceAlias $vMgmt.Name
} else {
    Write-Host "vManagement adapter not found - check Network ATC status" -ForegroundColor Yellow
}

# Check Network ATC intent status
Get-NetIntent | Format-List Name, IntentType, IsComputeIntentSet, IsManagementIntentSet, IsStorageIntentSet
```

### Related Validators

This validator is part of a set of management IP configuration checks:
- **AzureLocal_Network_Test_NodeManagementIPConnection** - Tests connectivity to management IP
- **AzureLocal_Network_Test_Node_ManagementIP_On_Correct_Adapter** (this validator) - Verifies IP on correct adapter
- **AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet** - Verifies no subnet overlap

### Related Documentation
- [Host network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
