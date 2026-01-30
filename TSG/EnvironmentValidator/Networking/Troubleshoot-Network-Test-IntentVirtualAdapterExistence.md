# AzureLocal_Network_Test_IntentVirtualAdapterExistence

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_IntentVirtualAdapterExistence</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Informational</strong>: This validator provides diagnostic information.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Upgrade, Pre-Update</strong></td>
  </tr>
</table>

## Overview

This validator checks that all expected virtual network adapters created by Network ATC intents exist and are in the "Up" state. These virtual adapters are critical for network traffic separation and proper cluster operation.

## Requirements

For each Network ATC intent configured:

1. **Management Intent**: vManagement(IntentName) virtual adapter must exist and be Up
2. **Converged Intent (Storage + Management/Compute)**: vSMB(IntentName#AdapterName) virtual adapters must exist and be Up for each storage adapter

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about which virtual adapters are missing or not Up.

```json
{
  "Name": "AzureLocal_Network_Test_IntentVirtualAdapterExistence",
  "DisplayName": "Test intent virtual adapter readiness on server",
  "Title": "Test intent virtual adapter readiness",
  "Status": 1,
  "Severity": 0,
  "Description": "Check intent virtual adapter readiness on NODE1",
  "Remediation": "https://aka.ms/azurelocal/envvalidator/IntentVirtualAdapterExistence",
  "TargetResourceID": "IntentVirtualAdapterExistence",
  "TargetResourceName": "IntentVirtualAdapterExistence",
  "TargetResourceType": "IntentVirtualAdapterExistence",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "NODE1",
    "Resource": "IntentVirtualAdapterExistence",
    "Detail": "Virtual adapter status on NODE1\n    ERROR: VMNetworkAdapter vManagement(ManagementIntent) does NOT exist.\n    Pass:  NetAdapter vSMB(StorageIntent#Ethernet 2) exists and is Up.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Virtual Network Adapter Does Not Exist

**Error Message:**
```text
Virtual adapter status on NODE1
    ERROR: VMNetworkAdapter vManagement(ManagementIntent) does NOT exist.
    ERROR: VMNetworkAdapter vSMB(StorageIntent#Ethernet 2) does NOT exist.
```

**Root Cause:** The expected virtual network adapters were not created by Network ATC, or were deleted/removed. This typically indicates:
- Network ATC intent was not applied successfully
- Virtual switch was not created
- Intent configuration is incomplete or failed

#### Remediation Steps

##### 1. Check Network ATC Intent Status

Verify Network ATC intent configuration and status:

```powershell
# Check all Network ATC intents
Get-NetIntent | Format-List Name, IntentType, IsComputeIntentSet, IsManagementIntentSet, IsStorageIntentSet, ProvisioningStatus

# Check intent status
Get-NetIntentStatus

```

**Expected output for healthy intent:**
```
Name                   : ManagementIntent
IsManagementIntentSet  : True
ProvisioningStatus     : Completed
ConfigurationStatus    : Success
```

##### 2. Check Virtual Switch Existence

Verify that the virtual switch was created:

```powershell
# Check virtual switches
Get-VMSwitch

```

**Expected:** At least one external virtual switch with EmbeddedTeamingEnabled = True (SET switch) and the virtual switch is using the adapters defined for the management intent.

##### 3. Check Virtual Network Adapters

List all virtual network adapters:

```powershell
# Check VMNetworkAdapters
Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName, Status | Format-Table -AutoSize

# Check corresponding NetAdapters
Get-NetAdapter | Where-Object { $_.Name -like "vManagement*" -or $_.Name -like "vSMB*" } |
    Select-Object Name, Status, LinkSpeed, InterfaceDescription |
    Format-Table -AutoSize
```

##### 4. Option A: Re-apply Network ATC Intent

If the intent exists but virtual adapters are missing, try re-applying the intent:

```powershell
# Get existing intent configuration
$intent = Get-NetIntent -Name "ManagementIntent"  # Replace with your intent name

# Remove and re-add the intent
Remove-NetIntent -Name "ManagementIntent"

# Wait for cleanup
Start-Sleep -Seconds 30

# Re-add intent (example - adjust parameters to match your configuration)
Add-NetIntent -Name "ManagementIntent" `
    -Management `
    -AdapterName @("Ethernet", "Ethernet 1") ... # make sure you include other necessary parameters that align with your system requirement

# Monitor provisioning status
Get-NetIntentStatus -Name "ManagementIntent"

```

##### 5. Option B: Manually Create Missing Virtual Adapter (Temporary Workaround)

> **Note:** This is not recommended for production. The proper solution is to fix the Network ATC intent. Use this only for emergency situations.

```powershell
# Get the virtual switch name
$vmSwitch = Get-VMSwitch -SwitchType External -Name "SwitchName" # Replace with your VMSwitch name

# Create missing vManagement adapter
Add-VMNetworkAdapter -ManagementOS -Name "vManagement(ManagementIntent)" -SwitchName $vmSwitch.Name

# You might need to rename the name of the NetAdapter object, as that is not using the above "vManagement(ManagementIntent)" name.
Get-NetAdapter -Name "vEthernet (vManagement(ManagementIntent))" | Rename-NetAdapter -NewName "vManagement(ManagementIntent)"

# Verify creation
Get-VMNetworkAdapter -ManagementOS -Name "vManagement(ManagementIntent)"
Get-NetAdapter -Name "vManagement(ManagementIntent)"
```

##### 6. Check for Intent Configuration Errors

Review the intent configuration for errors:

```powershell
# Check detailed error messages
Get-NetIntentStatus

# Check event logs for Network ATC errors
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VmSwitch-Operational" -MaxEvents 50 |
    Select-Object TimeCreated, Message |
    Format-List
```

##### 7. Verify Physical Adapters

Ensure the physical adapters referenced in the intent are present and Up:

```powershell
# Check physical adapters used in intents
$intent = Get-NetIntent -Name "ManagementIntent"
$adapterNames = $intent.NetAdapterNamesAsList

foreach ($adapterName in $adapterNames) {
    $adapter = Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue
    if ($adapter) {
        Write-Host "Adapter $adapterName - Status: $($adapter.Status), Speed: $($adapter.LinkSpeed)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Adapter $adapterName not found!" -ForegroundColor Red
    }
}
```

---

### Failure: Virtual Network Adapter Exists But Is Not Up

**Error Message:**
```text
Virtual adapter status on NODE1
    Pass:  VMNetworkAdapter vManagement(ManagementIntent) exists.
    ERROR: NetAdapter vManagement(ManagementIntent) does NOT exist or is not Up.
```

**Root Cause:** The virtual adapter exists but is in "Disabled" or "Disconnected" state.

#### Remediation Steps

##### 1. Check Adapter Status

```powershell
# Check the adapter status
Get-NetAdapter -Name "vManagement(ManagementIntent)" | Format-List Name, Status, MediaConnectionState

# Check VM network adapter status
Get-VMNetworkAdapter -ManagementOS -Name "vManagement(ManagementIntent)" | Format-List Name, Status, Connected
```

##### 2. Enable the Adapter

If the adapter is disabled:

```powershell
# Enable NetAdapter
Enable-NetAdapter -Name "vManagement(ManagementIntent)" -Confirm:$false

# Verify status
Get-NetAdapter -Name "vManagement(ManagementIntent)" | Select-Object Name, Status
```

##### 3. Check Virtual Switch Connection

Ensure the adapter is connected to the virtual switch:

```powershell
# Check VMNetworkAdapter connection
Get-VMNetworkAdapter -ManagementOS -Name "vManagement(ManagementIntent)"

# Check virtual switch status
Get-VMSwitch -Name $vmAdapter.SwitchName
```

##### 4. Check Physical Adapter Status

If virtual adapter is down, check underlying physical adapters:

```powershell
# Get virtual switch
$vmSwitch = Get-VMSwitch -SwitchType External | Where-Object { $_.Name -eq "ConvergedSwitch(ManagementIntent)" }

# Check physical adapters in the SET team
Get-VMSwitchTeam -Name $vmSwitch.Name

# Check team members
Get-VMSwitchTeam -Name $vmSwitch.Name | Select-Object -ExpandProperty NetAdapterInterfaceDescription | ForEach-Object {
    $physAdapter = Get-NetAdapter -InterfaceDescription $_
    [PSCustomObject]@{
        Name = $physAdapter.Name
        Status = $physAdapter.Status
        LinkSpeed = $physAdapter.LinkSpeed
    }
} | Format-Table -AutoSize
```

If physical adapters are down, enable them:

```powershell
Enable-NetAdapter -Name "Ethernet" -Confirm:$false
Enable-NetAdapter -Name "Ethernet 1" -Confirm:$false
```

---

## Additional Information

### Understanding Virtual Adapter Types

Network ATC creates different virtual adapters based on intent type:

| Intent Configuration | Virtual Adapter Created | Purpose |
|---------------------|------------------------|---------|
| Management only | vManagement(IntentName) | Management traffic |
| Storage only | None (uses physical adapters) | Storage traffic on physical adapters |
| Management + Storage (converged) | vManagement(IntentName) + vSMB(IntentName#Adapter) per storage adapter | Separated management and storage on same physical adapters |
| Compute + Storage (converged) | vSMB(IntentName#Adapter) per storage adapter | Separated compute and storage |

### Example: Management Intent Virtual Adapters

**Intent configuration:**
```json
{
    "name": "ManagementIntent",
    "trafficType": ["Management"],
    "adapter": ["Ethernet", "Ethernet 1"]
}
```

**Expected virtual adapters:**
- vManagement(ManagementIntent) - Single virtual adapter for management traffic

### Example: Converged Intent Virtual Adapters

**Intent configuration:**
```json
{
    "name": "ConvergedIntent",
    "trafficType": ["Management", "Compute", "Storage"],
    "adapter": ["Ethernet 2", "Ethernet 3", "Ethernet 4", "Ethernet 5"]
}
```

**Expected virtual adapters:**
- vManagement(ConvergedIntent) - For management traffic
- vSMB(ConvergedIntent#Ethernet 2) - For storage traffic on Ethernet 2
- vSMB(ConvergedIntent#Ethernet 3) - For storage traffic on Ethernet 3
- vSMB(ConvergedIntent#Ethernet 4) - For storage traffic on Ethernet 4
- vSMB(ConvergedIntent#Ethernet 5) - For storage traffic on Ethernet 5

### Checking Expected Virtual Adapters

To determine what virtual adapters should exist based on your intents:

```powershell
# Function to list expected virtual adapters
$intents = Get-NetIntent

foreach ($intent in $intents) {
    Write-Host "`nIntent: $($intent.IntentName)" -ForegroundColor Cyan
    Write-Host "  Traffic Types: $($intent.IntentType)" -ForegroundColor White

    $expectedAdapters = @()

    # Check for management
    if ($intent.IsManagementIntentSet) {
        $expectedAdapters += "vManagement($($intent.IntentName))"
    }

    # Check for converged storage
    if ($intent.IsStorageIntentSet -and ($intent.IsManagementIntentSet -or $intent.IsComputeIntentSet)) {
        foreach ($adapter in $intent.NetAdapterNamesAsList) {
            $expectedAdapters += "vSMB($($intent.IntentName)#$adapter)"
        }
    }

    Write-Host "  Expected VIRTUAL adapters:" -ForegroundColor Yellow
    foreach ($adapter in $expectedAdapters) {
        $exists = Get-NetAdapter -Name $adapter -ErrorAction SilentlyContinue
        if ($exists -and $exists.Status -eq "Up") {
            Write-Host "    ✓ $adapter (Status: $($exists.Status))" -ForegroundColor Green
        } elseif ($exists) {
            Write-Host "    ⚠ $adapter (Status: $($exists.Status))" -ForegroundColor Yellow
        } else {
            Write-Host "    ✗ $adapter (MISSING)" -ForegroundColor Red
        }
    }
}
```

### Network ATC Intent Lifecycle

**Checking lifecycle status:**
```powershell
Get-NetIntentStatus | Select-Object IntentName, ProvisioningStatus, ConfigurationStatus, LastUpdated, LastSuccess | Format-List
```

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Virtual adapter doesn't exist | Intent not applied | Re-apply Network ATC intent |
| Adapter exists but is Down | Physical adapter issue | Check and enable physical adapters |
| VMNetworkAdapter exists, NetAdapter doesn't | Driver or binding issue | Restart Hyper-V Virtual Switch service |
| All adapters missing | Virtual switch not created | Check physical adapter availability, re-create intent |

### Related Documentation

- [Network ATC overview](https://learn.microsoft.com/azure-stack/hci/deploy/network-atc-overview)
- [Manage Network ATC](https://learn.microsoft.com/azure-stack/hci/deploy/network-atc)
- [Host network requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
- [Troubleshoot Network ATC](https://learn.microsoft.com/azure-stack/hci/manage/troubleshoot-network-atc)
