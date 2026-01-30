# AzStackHci_Network_Test_New_Node_First_Adapter_Validity

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_New_Node_First_Adapter_Validity</strong></td>
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

This validator checks that the first network adapter specified in the management intent on the new node has the management IP address configured. The validator checks both the physical adapter and the virtual management adapter (if using a VMSwitch).

## Requirements

The new node must meet the following requirements:
1. The first physical adapter defined in the management intent must exist on the system, OR
2. If using a VMSwitch, the virtual management adapter `vManagement(IntentName)` must exist
3. The adapter (physical or virtual) must have the management IP address configured

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the adapter and IP configuration. The `TargetResourceName` shows the adapter name being checked.

```json
{
  "Name": "AzStackHci_Network_Test_New_Node_First_Adapter_Validity",
  "DisplayName": "Test New Node Configuration First Network Adapter has Management IP",
  "Title": "Test New Node Configuration First Network Adapter has Management IP",
  "Status": 1,
  "Severity": 2,
  "Description": "Checking New Node first adapter has management IP",
  "Remediation": "https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-tool-checklist",
  "TargetResourceID": "10.0.1.50",
  "TargetResourceName": "Ethernet",
  "TargetResourceType": "Network Adapter",
  "Timestamp": "\\/Date(timestamp)\\/",
  "AdditionalData": {
    "Source": "NewNodeAdapter",
    "Resource": "NewNodeAdapterIP",
    "Detail": "Either the adapter (physical or virtual) ('Ethernet' or 'vManagement(ManagementIntent)') was not found or the mgmt IP ('10.0.1.50') on the adapter was wrong",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Adapter Not Found or Management IP Not on Adapter
**Root Cause:** The validator could not find the expected network adapter with the management IP address. This can occur if:
- The physical adapter name doesn't match the management intent configuration
- The virtual management adapter doesn't exist (for VMSwitch configurations)
- The management IP is configured on a different adapter
- The adapter exists but doesn't have any IP address configured

#### Remediation Steps

##### Step 1: Verify Adapter Configuration

First, identify which adapters exist on the node and their IP configurations:

```powershell
# Run on the new node being added
# List all network adapters
Get-NetAdapter | Select-Object Name, Status, InterfaceDescription

# List all IP addresses
Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixOrigin

# Get IP configuration with gateway
Get-NetIPConfiguration | Where-Object {
    $null -ne $_.IPv4DefaultGateway -and
    $_.NetAdapter.Status -eq "Up"
} | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway
```

##### Step 2: Check Management Intent Configuration

Verify which adapter is defined in the management intent:

```powershell
# Run on the existing node in the cluster
$mgmtIntent = Get-NetIntent | Where-Object { $_.IsManagementIntentSet -eq "true" }
if ($mgmtIntent) {
    Write-Host "Management Intent Name: $($mgmtIntent.IntentName)"
    Write-Host "Management Intent Adapters: $($mgmtIntent.NetAdapterNamesAsList -join ', ')"
} else {
    Write-Host "No management intent found!"
}
```

##### Step 3: Remediate Based on Configuration Type

Choose the appropriate remediation based on whether you're using a VMSwitch or physical adapter configuration.

###### Scenario A: Using Physical Adapter (No VMSwitch)

If you're using a physical adapter for management:

1. Verify the first adapter in the management intent exists in the new node:

   ```powershell
   $firstAdapterName = $mgmtIntent.NetAdapterNamesAsList[0]
   Get-NetAdapter -Name $firstAdapterName -ErrorAction SilentlyContinue
   ```

2. Configure the management IP on the correct adapter:

   ```powershell
   $adapterName = $firstAdapterName  # From above
   $mgmtIP = "10.0.1.50"  # Replace with your management IP
   $prefixLength = 24  # Replace with your subnet prefix length
   $defaultGateway = "10.0.1.1"  # Replace with your gateway

   # Remove any existing IPs (if needed)
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
       Remove-NetIPAddress -Confirm:$false

   # Configure the management IP
   New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $mgmtIP -PrefixLength $prefixLength -DefaultGateway $defaultGateway

   # Configure DNS
   Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses "10.0.1.1"  # Replace with your DNS
   ```

3. Verify the configuration:

   ```powershell
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4
   Get-NetIPConfiguration -InterfaceAlias $adapterName
   Test-NetConnection -ComputerName "10.0.1.1"  # Test gateway
   ```

###### Scenario B: Using VMSwitch with Virtual Management Adapter

If you're using a VMSwitch:

1. Check if the virtual management adapter exists on the new node:

   ```powershell
   $intentName = $mgmtIntent.IntentName
   $vNicName = "vManagement($intentName)"

   $vNic = Get-VMNetworkAdapter -ManagementOS -Name $vNicName -ErrorAction SilentlyContinue
   if ($vNic) {
       Write-Host "Virtual adapter '$vNicName' exists"
   } else {
       Write-Host "ERROR: Virtual adapter '$vNicName' NOT found!"
   }
   ```

2. If the virtual adapter doesn't exist, you may need to recreate the VMSwitch or add the virtual adapter:

3. Configure the management IP on the virtual adapter:

   ```powershell
   $adapterName = $vNicName
   $mgmtIP = "10.0.1.50"  # Replace with your management IP
   $prefixLength = 24  # Replace with your subnet prefix length
   $defaultGateway = "10.0.1.1"  # Replace with your gateway

   # Remove any existing IPs (if needed)
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
       Remove-NetIPAddress -Confirm:$false

   # Configure the management IP
   New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $mgmtIP -PrefixLength $prefixLength -DefaultGateway $defaultGateway

   # Configure DNS
   Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses "10.0.1.1"  # Replace with your DNS
   ```

4. Verify the configuration:

   ```powershell
   Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4
   Get-NetIPConfiguration -InterfaceAlias $adapterName
   Test-NetConnection -ComputerName "10.0.1.1"  # Test gateway
   ```

##### Step 4: Retry Add-Server

After configuring the correct adapter with the management IP, retry the Add-Server operation.

---

## Additional Information

### Understanding Management Adapter Configuration

Azure Local supports two configuration models:

1. **Physical Adapter**: Management IP is directly on the physical network adapter
2. **VMSwitch with Virtual Adapter**: Management IP is on a virtual adapter attached to a VMSwitch

The validator checks both possibilities:
- First, it checks the physical adapter specified in the management intent
- If not found or IP doesn't match, it checks for `vManagement(IntentName)` virtual adapter

### Common Causes of Failure

| Cause | Description | Resolution |
|-------|-------------|-----------|
| Adapter name mismatch | Physical adapter has different name than intent | Rename adapter or update intent |
| VMSwitch not exists | The VMSwitch does not exist on the new node, or created with a different adapter set | Try to create the VMSwitch with right adapter list |
| IP on wrong adapter | Management IP on different adapter | Move IP to correct adapter |
| No IP configured | Adapter exists but has no IP | Configure management IP |
| Adapter disabled | Adapter exists but is disabled | Enable the adapter |

### Checking Adapter Status

Use these commands to troubleshoot:

```powershell
# Get all adapters and their status
Get-NetAdapter | Format-Table Name, Status, LinkSpeed, InterfaceDescription -AutoSize

# Get all IP configurations
Get-NetIPConfiguration | Format-Table InterfaceAlias, IPv4Address, IPv4DefaultGateway -AutoSize

# Check for VMNetworkAdapters (Management OS)
Get-VMNetworkAdapter -ManagementOS | Format-Table Name, SwitchName, IPAddresses -AutoSize

# Check VMSwitch info
Get-VMSwitch

```

### Physical vs. Virtual Adapter Decision
### Related Documentation

- [Azure Local Network Requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
