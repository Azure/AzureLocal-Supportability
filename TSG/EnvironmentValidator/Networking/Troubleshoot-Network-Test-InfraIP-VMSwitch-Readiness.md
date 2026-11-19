# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment (without ArcGateway), Upgrade (without ArcGateway)</strong></td>
  </tr>
</table>

## Overview

This validator checks that a suitable virtual switch exists or can be created for testing infrastructure IP pool connectivity. The validator needs a virtual switch with the same physical adapters as defined in the management intent to properly test network connectivity from infrastructure IPs.

## Requirements

1. Either an existing external virtual switch with matching management intent adapters, OR
2. Ability to create a new external virtual switch using the management intent adapters
3. The virtual switch must be properly configured and operational

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about virtual switch readiness.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness",
  "DisplayName": "Test VMSwitch readiness for all IP in infra IP pool",
  "Title": "Test VMSwitch readiness for all IP in infra IP pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test VMSwitch readiness for all IP in infra IP pool",
  "Remediation": "Make sure at least one VMSwitch pre-configured on the host SERVER01 has the same set of adapters defined in management intent.",
  "TargetResourceID": "Infra_IP_Connection_VMSwitchReadiness",
  "TargetResourceName": "Infra_IP_Connection_VMSwitchReadiness",
  "TargetResourceType": "Infra_IP_Connection_VMSwitchReadiness",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "VMSwitchReadiness",
    "Detail": "[FAILED] Cannot test connection for infra IP with wrong VMSwitch configured on host SERVER01.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: No Suitable VMSwitch Found

**Error Message:**
```text
[FAILED] Cannot test connection for infra IP with wrong VMSwitch configured on host SERVER01.
```

**Root Cause:** Either:
- No external virtual switch exists on the host
- Existing virtual switches don't use the same physical adapters as defined in the management intent
- The validator cannot create a suitable virtual switch

#### Remediation Steps

##### 1. Check Current Virtual Switch Configuration

Verify existing virtual switches:

```powershell
# List all virtual switches
Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription, EmbeddedTeamingEnabled -AutoSize

# Check which physical adapters are used by each switch
Get-VMSwitch -SwitchType External | ForEach-Object {
    $switch = $_
    $team = Get-VMSwitchTeam -Name $switch.Name -ErrorAction SilentlyContinue
    if ($team) {
        Write-Host "`nSwitch: $($switch.Name)" -ForegroundColor Cyan
        Write-Host "  Team Members:" -ForegroundColor White
        $team.NetAdapterInterfaceDescription | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "`nSwitch: $($switch.Name)" -ForegroundColor Cyan
        Write-Host "  Single Adapter: $($switch.NetAdapterInterfaceDescription)" -ForegroundColor White
    }
}
```

##### 2. Check Management Intent Configuration

Identify which adapters should be used according to your deployment configuration:

```powershell
# View physical adapters
Get-NetAdapter -Physical | Select-Object Name, Status, LinkSpeed, InterfaceDescription | Format-Table -AutoSize

# Your management intent should specify which adapters to use
# Example: Management intent uses "Ethernet" and "Ethernet 2"
```
##### 3. if you have an existing VMSwitch, but uses wrong adapters
You might need to modify/re-create the VMSwitch so it use the same adapters as defined in the management intent.

> **Warning:** Modifying the virtual switch will temporarily disconnect network connectivity.

```powershell
# Remove existing switch (if safe to do so)
$oldSwitch = Get-VMSwitch -Name "ExistingSwitch"
Remove-VMSwitch -Name $oldSwitch.Name -Force

# Create new switch with correct adapters
$adapterNames = @("Ethernet", "Ethernet 2")
New-VMSwitch -Name "ConvergedSwitch(ManagementIntent)" `
    -NetAdapterName $adapterNames `
    -EnableEmbeddedTeaming $true `
    -AllowManagementOS $true
```

##### 4. Verify Virtual Switch is Operational

After creating or modifying the virtual switch:

```powershell
# Check switch status
Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription |  Format-List

# Check that management OS has access
Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName, Status | Format-Table -AutoSize

# Verify physical adapters are bound to the switch
Get-VMSwitchTeam -Name "ConvergedSwitch(ManagementIntent)" | Select-Object Name, TeamingMode, LoadBalancingAlgorithm

# Test basic connectivity
Test-NetConnection -ComputerName 8.8.8.8 -InformationLevel Detailed
```

##### 5. Retry the Validation

After creating or fixing the virtual switch, re-run the Environment Validator.

---

## Additional Information

### Virtual Switch Requirements for Infrastructure IP Testing

The validator requires a virtual switch that:

1. **Uses management intent adapters**: Must use the same physical adapters specified in the deployment's management intent
2. **Is External type**: Must be an external virtual switch (not Internal or Private)
3. **Allows Management OS**: Must have `-AllowManagementOS $true` to create management vNICs
4. **Is operational**: Must be in a healthy state

### Virtual Switch Naming Convention

The validator uses Network ATC naming standards:

- **Switch name pattern**: `ConvergedSwitch(IntentName)` or similar
- **Management vNIC pattern**: `vManagement(IntentName)`

Example for intent named "ManagementIntent":
- Switch: `ConvergedSwitch(ManagementIntent)`
- vNIC: `vManagement(ManagementIntent)`

### Existing vs. New Virtual Switch

The validator behaves differently based on existing virtual switch configuration:

| Scenario | Validator Behavior |
|----------|-------------------|
| **No external switches exist** | Creates a new temporary switch for testing |
| **1 external switch with correct adapters** | Uses the existing switch |
| **1 external switch with wrong adapters** | **FAILS** - cannot proceed |
| **Multiple external switches** | Searches for one with matching adapters |

### Switch Embedded Teaming (SET)

For multi-adapter management intents, the validator expects Switch Embedded Teaming:

```powershell
# SET switch combines multiple NICs into a team
# Benefits:
# - Load balancing across adapters
# - Fault tolerance if one adapter fails
# - RDMA support (if NICs support it)

# Verify SET is enabled
Get-VMSwitch | Where-Object { $_.EmbeddedTeamingEnabled -eq $true }

# Check team configuration
Get-VMSwitchTeam | Select-Object Name, TeamingMode, LoadBalancingAlgorithm, NetAdapterInterfaceDescription
```

### Common Virtual Switch Issues

#### Issue: Switch creation fails

**Solution 1 - Check adapter status:**
```powershell
# Ensure adapters are Up and not already bound
Get-NetAdapter -Physical | Select-Object Name, Status, DriverDescription

# Check if adapters are already bound to another switch
Get-VMSwitch | ForEach-Object {
    $_ | Select-Object Name, @{N='Adapters';E={($_ | Get-VMSwitchTeam).NetAdapterInterfaceDescription -join ', '}}
}
```

**Solution 2 - Remove existing bindings:**
If adapter is bound to old switch, remove it

#### Issue: Management OS loses connectivity after switch creation
Make sure the first adapter used in your management intent list is having connection before you configure the VMSwitch.

#### Issue: Wrong adapters in the switch

**Solution - Rebuild switch with correct adapters:**
```powershell
# Document current management IP configuration
$mgmtIP = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }
$ipAddress = $mgmtIP.IPv4Address.IPAddress
$prefixLength = $mgmtIP.IPv4Address.PrefixLength
$gateway = $mgmtIP.IPv4DefaultGateway.NextHop
$dnsServers = ($mgmtIP | Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses

# Remove old switch
Remove-VMSwitch -Name "OldSwitch" -Force

# Create new switch with correct adapters
$correctAdapters = @("Ethernet", "Ethernet 2")  # From management intent
New-VMSwitch -Name "ConvergedSwitch(ManagementIntent)" `
    -NetAdapterName $correctAdapters `
    -EnableEmbeddedTeaming $true `
    -AllowManagementOS $true

# Reconfigure management IP
Start-Sleep -Seconds 5
$newVNIC = Get-NetAdapter | Where-Object { $_.Name -like "vEthernet*" -and $_.Status -eq "Up" } | Select-Object -First 1
New-NetIPAddress -InterfaceAlias $newVNIC.Name `
    -IPAddress $ipAddress `
    -PrefixLength $prefixLength `
    -DefaultGateway $gateway
Set-DnsClientServerAddress -InterfaceAlias $newVNIC.Name -ServerAddresses $dnsServers
```

### Temporary vs. Permanent Virtual Switch

**Temporary switch (created by validator):**
- Created only if no suitable switch exists
- Used only for validation testing
- Cleaned up after validation completes
- Named according to Network ATC standards

**Permanent switch (pre-existing):**
- Already exists from previous Network ATC deployment or manual creation
- Used by validator if it matches requirements
- Not modified or removed by validator

### Network ATC and Virtual Switches

During actual deployment, Network ATC will create virtual switches based on intents:

```powershell
# After deployment, Network ATC creates switches
# Example for management intent:
Add-NetIntent -Name "ManagementIntent" `
    -Management `
    -AdapterName "Ethernet", "Ethernet 2"

# This creates:
# - External virtual switch with SET
# - vManagement virtual adapter
# - Proper IP configuration
```

The validator's temporary switch mimics this structure for testing purposes.

### Verification Commands

Complete verification of virtual switch setup:

```powershell
# 1. Check switch exists and is external
Get-VMSwitch -SwitchType External | Format-Table Name, SwitchType, EmbeddedTeamingEnabled -AutoSize

# 2. Check adapters in the switch match management intent
$switch = Get-VMSwitch -Name "ConvergedSwitch(ManagementIntent)"
Get-VMSwitchTeam -Name $switch.Name | Select-Object -ExpandProperty NetAdapterInterfaceDescription

# 3. Check management vNIC exists
Get-VMNetworkAdapter -ManagementOS | Where-Object { $_.SwitchName -eq $switch.Name }

# 4. Check physical adapters are Up
Get-NetAdapter | Where-Object { $_.InterfaceDescription -in (Get-VMSwitchTeam -Name $switch.Name).NetAdapterInterfaceDescription }

# 5. Test connectivity
Test-NetConnection -ComputerName 8.8.8.8
```

### Related Validators

Prerequisites for this validator:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness** - Must pass first

Validators that run after this validator:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_MANAGEMENT_VNIC_Readiness** - Validates management vNIC
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness** - Validates test vNIC creation
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness** - Tests IP configuration
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53** - Tests DNS connectivity

### Related Documentation

- [Create a virtual switch for Hyper-V](https://learn.microsoft.com/windows-server/virtualization/hyper-v/get-started/create-a-virtual-switch-for-hyper-v-virtual-machines)
- [Azure Local host network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
