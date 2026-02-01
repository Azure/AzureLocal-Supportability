# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness</strong></td>
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

This validator tests that infrastructure pool IPs can be assigned to a network adapter and can reach the default gateway. For each IP tested (up to first 9 from the pool), the validator assigns it to a temporary vNIC and validates ICMP connectivity to the gateway.

## Requirements

1. Infrastructure IPs must be available and not in use by other devices
2. IPs must be routable to the default gateway
3. Default gateway must be accessible via ICMP (ping)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness",
  "DisplayName": "Test IP readiness on test adapter for IP from infra pool",
  "Title": "Test IP readiness on test adapter for IP from infra pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test IP readiness on test adapter for IP from infra pool",
  "Remediation": "Make sure infra IP 10.0.0.100 is routable to your gateway 10.0.0.1, and the IP is not used by any other device or service on the network.",
  "TargetResourceID": "Infra_IP_Connection_InfraIP_Readiness_10.0.0.100",
  "TargetResourceName": "Infra_IP_Connection_InfraIP_Readiness_10.0.0.100",
  "TargetResourceType": "Infra_IP_Connection_InfraIP_Readiness_10.0.0.100",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "10.0.0.100",
    "Detail": "[FAILED] Connection from 10.0.0.100 to gateway 10.0.0.1 failed. Cannot get the IP configured correctly on the test adapter.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Infrastructure IP Not Ready or Cannot Reach Gateway

**Error Message:**
```text
[FAILED] Connection from 10.0.0.100 to gateway 10.0.0.1 failed. Cannot get the IP configured correctly on the test adapter.
```

**Root Cause:** The infrastructure IP cannot be configured on the test adapter, or ICMP connectivity to the gateway fails. Possible causes:
- IP is already in use by another device
- IP is not routable to the gateway
- Gateway is not responding to ICMP
- Network configuration issues (VLAN, routing, firewall)
- IP assignment timeout

#### Remediation Steps

##### 1. Verify IP is Not in Use

Check if the infrastructure IP is already in use:

```powershell
# Test if IP is in use
$ipToCheck = "10.0.0.100"  # Replace with the failing IP

# Ping test
$pingResult = Test-Connection -ComputerName $ipToCheck -Count 4 -Quiet
if ($pingResult) {
    Write-Host "⚠ IP $ipToCheck is responding to ping - may be in use" -ForegroundColor Yellow
} else {
    Write-Host "✓ IP $ipToCheck is not responding to ping" -ForegroundColor Green
}

# ARP check
arp -a | Select-String $ipToCheck
```

If IP is in use:
- **Option 1**: Remove the device using that IP
- **Option 2**: Choose a different infrastructure IP pool range that doesn't conflict

##### 2. Verify Gateway Connectivity

Test connectivity to the default gateway:

```powershell
# Get gateway from infrastructure IP pool configuration
$gateway = "10.0.0.1"  # Replace with your actual gateway

# Test ping to gateway
Test-Connection -ComputerName $gateway -Count 4

# Check routing table
Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Format-Table DestinationPrefix, NextHop, InterfaceAlias -AutoSize
```

If gateway is not reachable:
- Verify gateway IP is correct
- Check physical network connectivity
- Verify VLAN configuration (if using VLANs)
- Check switch/router configuration

##### 3. Check VLAN Configuration

If using VLANs, verify configuration:

```powershell
# Check if management adapters have VLAN configuration
Get-NetAdapterAdvancedProperty -Name "MyAdapter" -RegistryKeyword "VlanID" -ErrorAction SilentlyContinue |
    Format-Table Name, DisplayValue -AutoSize

# For infrastructure IP testing, VLAN should match management VLAN
# Check your deployment configuration for the correct VLAN ID
```

##### 4. Verify Physical Network Infrastructure

Check switch and network infrastructure:
- **Spanning Tree**: Ensure STP is not blocking ports (30 second convergence time)
- **Port Security**: Verify switch ports allow MAC address changes
- **VLAN assignment**: Confirm correct VLAN is configured on switch ports
- **Gateway/Router**: Verify router/gateway is operational and configured correctly

##### 5. Test with Manual IP Assignment

Manually test IP assignment on management adapter:

```powershell
# Find management adapter
$mgmtAdapter = Get-NetAdapter | Where-Object { $_.Name -like "testadapter" } | Select-Object -First 1

if ($mgmtAdapter) {
    Write-Host "Testing manual IP assignment on: $($mgmtAdapter.Name)" -ForegroundColor Cyan

    # Save current IP configuration
    $currentIP = Get-NetIPConfiguration -InterfaceAlias $mgmtAdapter.Name

    # Test assigning an infrastructure IP
    $testIP = "10.0.0.100"  # Replace with failing IP
    $gateway = "10.0.0.1"   # Replace with your gateway
    $prefixLength = 24

    try {
        # Temporarily assign the IP
        New-NetIPAddress -InterfaceAlias $mgmtAdapter.Name `
            -IPAddress $testIP `
            -PrefixLength $prefixLength `
            -SkipAsSource $true `
            -ErrorAction Stop

        Write-Host "✓ Successfully assigned IP" -ForegroundColor Green

        # Wait for IP to stabilize
        Start-Sleep -Seconds 5

        # Test ping to gateway
        ping $gateway -S $testIP

        # Validate the ping result here

        # Clean up - remove test IP
        Remove-NetIPAddress -InterfaceAlias $mgmtAdapter.Name -IPAddress $testIP -Confirm:$false

    } catch {
        Write-Host "✗ Failed to assign IP: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

##### 6. Check Firewall Rules

Ensure ICMP is allowed:

```powershell
# Check ICMP firewall rules
Get-NetFirewallRule -DisplayName "*ICMP*" | Where-Object { $_.Enabled -eq $true } |
    Select-Object DisplayName, Direction, Action | Format-Table -AutoSize

# Enable ICMP if needed
Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)"
```

##### 8. Retry the Validation

After fixing network issues, re-run the Environment Validator.

---

## Additional Information

### How IP Readiness Testing Works

The validator performs these steps for each infrastructure IP (up to 9 IPs):

1. **Assign IP** to temporary test vNIC
2. **Wait for IP to become "Preferred" state** (up to 180 seconds default)
3. **Ping default gateway** from the IP (15 retries)
4. **If successful**: IP is ready, proceed with connectivity tests
5. **If failed**: Report IP readiness failure, skip to next IP

### Why Only First 9 IPs Are Tested

The validator tests only the first 9 IPs from the infrastructure pool because:
- **6 IPs** are currently required for Azure Local services
- **3 additional IPs** are reserved for future use (e.g., SLB VMs)
- Testing all IPs would take too long (each IP test takes 10-30 seconds)

### IP States and Readiness

Windows IP addresses go through states:
- **Tentative**: IP is being validated (duplicate address detection)
- **Preferred**: IP is ready and usable ✓
- **Deprecated**: IP is being phased out
- **Invalid**: IP configuration failed

The validator waits for "Preferred" state before testing connectivity.

### Common Causes of IP Readiness Failures

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **IP in use** | Ping shows IP responds | Find and remove conflicting device |
| **Wrong subnet/gateway** | No route to gateway | Fix IP pool configuration |
| **VLAN mismatch** | Gateway unreachable | Configure correct VLAN on switch |
| **STP convergence** | Intermittent connectivity | Wait 30 seconds or disable STP PortFast |
| **Firewall blocking ICMP** | Ping timeout | Allow ICMP in firewall rules |
| **Gateway offline** | No gateway response | Check router/gateway status |

### Timeout Values

The validator uses these timeout values:
- **IP configuration timeout**: 180 seconds (configurable via TimeoutWaitForIPInSeconds parameter)
- **Ping retries**: 15 attempts with 1 second between attempts
- **Total time per IP**: Up to 3-4 minutes if experiencing issues

### Infrastructure IP Pool Design

**Best practices:**
- **Use dedicated subnet**: Don't overlap with existing DHCP ranges or static IPs
- **Reserve IPs**: Exclude infrastructure range from DHCP scope
- **Size appropriately**: Minimum 9-16 IPs, recommended 32+  for growth
- **Document**: Keep record of IP pool allocation

**Example good configuration:**
```
Infrastructure Pool: 10.0.10.100 - 10.0.10.150 (51 IPs)
Subnet: 10.0.10.0/24
Gateway: 10.0.10.1
DNS: 10.0.10.10, 10.0.10.11

Ensure:
- No DHCP assignments in this range
- No static IPs assigned in this range
- Gateway is 10.0.10.1 and operational
```

### Prerequisites for This Validator

Requires these validators to pass first:
- Hyper-V Readiness
- VMSwitch Readiness
- Management vNIC Readiness
- Test vNIC Readiness
- DNS Client Readiness

### Related Validators

After this validator passes:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53** - Tests DNS connectivity

### Related Documentation

- [Network requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/host-network-requirements)
- [Firewall requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/firewall-requirements)
