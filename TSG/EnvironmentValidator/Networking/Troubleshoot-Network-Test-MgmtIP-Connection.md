# AzureLocal_Network_Test_NodeManagementIPConnection

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_NodeManagementIPConnection</strong></td>
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

This validator checks that each node's management IP address can be connected to via remote PowerShell session, and that the computer name obtained from that session matches the expected node name in the deployment configuration.

## Requirements

For static IP deployments:
1. Each management IP defined in the deployment configuration must be reachable via WinRM
2. The computer name from the remote session must match the expected node name in the configuration

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the management IP connectivity test.

```json
{
  "Name": "AzureLocal_Network_Test_NodeManagementIPConnection",
  "DisplayName": "Validate that management IP of host machine is able to be connected",
  "Title": "Validate that management IP of host machine is able to be connected",
  "Status": 1,
  "Severity": 0,
  "Description": "Management IP of each host machine defined in ECE config should be able to be connected correctly.",
  "Remediation": "https://aka.ms/azurelocal/envvalidator/networkmgmtipconfiguration",
  "TargetResourceID": "NODE1, NetworkHostManagementIP",
  "TargetResourceName": "NODE1, NetworkHostManagementIP",
  "TargetResourceType": "NetworkHostManagementIP",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "NODE1",
    "Resource": "NetworkHostManagementIP",
    "Detail": "Management IP on server NODE1 is NOT correct. Expected node name: NODE1, actual node name from IP: NODE2.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Cannot Connect to Management IP

**Root Cause:** The management IP address defined for this node cannot be reached via Windows Remote Management (WinRM). Possible causes include:
- IP address is incorrect or not assigned
- Network connectivity issues
- Firewall blocking WinRM traffic
- WinRM service not running
- IP configured on wrong adapter

#### Remediation Steps

##### 1. Verify IP Address is Assigned to the Node

Connect to the node locally (console, KVM, or physical access) and verify the IP configuration:

```powershell
# Check all IP addresses assigned to network adapters
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength |
    Format-Table -AutoSize

# Look for the expected management IP in the output
```

If the expected management IP is not found:
- Verify the IP is assigned to the correct network adapter
- Check that the adapter is connected and has "Up" status
- Verify network cable is connected

##### 2. Verify Network Connectivity

From the machine running the Environment Validator, test connectivity to the management IP:

```powershell
# Test basic connectivity
Test-NetConnection -ComputerName <ManagementIP> -Port 5985 -InformationLevel Detailed

# Test ICMP ping
Test-Connection -ComputerName <ManagementIP> -Count 4
```

If connectivity fails:
- Check network switch configuration
- Verify correct VLAN configuration (if VLANs are used)
- Check that both machines are on the same network segment or have proper routing

##### 3. Verify WinRM Service is Running

On the target node, check WinRM service status:

```powershell
# Check WinRM service status
Get-Service -Name WinRM | Format-List Name, Status, StartType

# If not running, start it
Start-Service -Name WinRM

# Set to start automatically
Set-Service -Name WinRM -StartupType Automatic
```

##### 4. Verify Firewall Rules

On the target node, ensure Windows Firewall allows WinRM:

```powershell
# Check if WinRM firewall rules are enabled
Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP*" |
    Select-Object Name, Enabled, Direction, Action |
    Format-Table -AutoSize

# Enable WinRM HTTP inbound rule if disabled
Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"
```

##### 5. Test WinRM Configuration

On the target node:

```powershell
# Test WinRM configuration
Test-WSMan -ComputerName localhost

# Check WinRM listeners
Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate
```

From the validator machine:

```powershell
# Test remote WinRM access
Test-WSMan -ComputerName <ManagementIP> -Authentication Default
```

##### 6. Verify Deployment Configuration

Check your deployment configuration file to ensure:
- The IP address is correct for this specific node
- The IP matches what's assigned to the management adapter
- There are no typos in the IP address

---

### Failure: Node Name Mismatch

**Error Message:**
```text
Management IP on server NODE1 is NOT correct. Expected node name: NODE1, actual node name from IP: NODE2.
```

**Root Cause:** The validator successfully connected to the management IP, but the computer name returned from the remote session does not match the expected node name in the configuration. This indicates one of:
- Wrong IP address assigned to wrong node
- IP addresses swapped between nodes
- Computer name not set correctly on the node

#### Remediation Steps

##### 1. Verify Computer Name on Target Node

Connect to the node at the management IP and verify its computer name:

```powershell
# On the target node
$env:COMPUTERNAME
hostname
```

Compare this to the expected name in your deployment configuration.

##### 2. If Computer Name is Wrong - Rename the Computer

If the computer name doesn't match what's expected:

```powershell
# Rename the computer (requires reboot)
Rename-Computer -NewName "ExpectedNodeName" -Restart -Force
```

**OR** update your deployment configuration to use the correct computer name.

##### 3. If IP Assignment is Wrong - Correct IP Configuration

If the computer name is correct but assigned the wrong IP:

1. Verify which node should have which IP according to your deployment plan
2. Correct the IP assignment on the affected nodes:

```powershell
# Example: Assign correct management IP
# Find the management adapter
$mgmtAdapter = Get-NetAdapter | Where-Object { $_.Name -eq "Ethernet" }  # Use actual adapter name

# Remove incorrect IP
Remove-NetIPAddress -InterfaceAlias $mgmtAdapter.Name -Confirm:$false

# Assign correct IP
New-NetIPAddress -InterfaceAlias $mgmtAdapter.Name `
    -IPAddress "192.168.1.10" `  # Correct IP for this node
    -PrefixLength 24 `
    -DefaultGateway "192.168.1.1"
```

3. Update DNS settings if needed:

```powershell
Set-DnsClientServerAddress -InterfaceAlias $mgmtAdapter.Name `
    -ServerAddresses "192.168.1.100", "192.168.1.101"
```

##### 4. Verify Node-to-IP Mapping

Cross-check your deployment configuration file:

| Node Name | Expected Management IP | Actual Computer Name | Actual IP |
|-----------|------------------------|----------------------|-----------|
| NODE1 | 192.168.1.10 | ? | ? |
| NODE2 | 192.168.1.11 | ? | ? |
| NODE3 | 192.168.1.12 | ? | ? |

Ensure every node has the correct IP and the correct name.

---

## Additional Information

### When This Validator Runs

This validator only runs during:
- **Deployment with Static IP**: When deploying with manually assigned management IPs
- **Pre-Update with Static IP**: Before update operations when using static IP configuration

It does NOT run for:
- DHCP-based deployments
- Add-Server scenarios

### Static vs. DHCP IP Management

| Configuration Method | Validator Applies? | Notes |
|---------------------|-------------------|-------|
| Static IP (manual assignment) | ✓ Yes | IPs must be pre-configured on nodes |
| DHCP | ✗ No | IPs assigned dynamically |

### Management IP Requirements

For static IP deployments:

1. **Before deployment**: Management IPs must be assigned to the first management adapter on each node
2. **Correct adapter**: IP must be on the adapter specified as the first adapter in the management intent
3. **Connectivity**: All nodes must be able to reach each other via management IPs
4. **Name resolution**: Computer names must match the node names in the deployment configuration

### Verifying Management IP Configuration

To verify your management IP configuration is correct:

```powershell
# On each node, verify:

# 1. Computer name
$env:COMPUTERNAME

# 2. Management IP and adapter
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    Select-Object InterfaceAlias, IPAddress, PrefixLength

# 3. Default gateway
Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object NextHop

# 4. DNS servers
Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 }

# 5. WinRM connectivity
Test-WSMan -ComputerName localhost
```

From the validator machine, test connectivity to all nodes:

```powershell
# Test WinRM to each management IP
$managementIPs = @("192.168.1.10", "192.168.1.11", "192.168.1.12") # Replace with actual IP in your system
$cred = Get-Credential
foreach ($ip in $managementIPs) {
    Write-Host "Testing connection to $ip..." -ForegroundColor Cyan
    try {
        $session = New-PSSession -ComputerName $ip -Credential $cred -ErrorAction Stop
        $computerName = Invoke-Command -Session $session -ScriptBlock { $env:COMPUTERNAME }
        Write-Host "  SUCCESS: Connected to $ip, computer name: $computerName" -ForegroundColor Green
        Remove-PSSession $session
    } catch {
        Write-Host "  FAILED: Cannot connect to $ip - $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### Related Validators

This validator is part of a set of management IP configuration checks:
- **AzureLocal_Network_Test_NodeManagementIPConnection** (this validator) - Tests connectivity
- **AzureLocal_Network_Test_Node_ManagementIP_On_Correct_Adapter** - Verifies IP is on the correct adapter
- **AzureLocal_Network_Test_Node_ManagementIP_Not_Overlap_With_Storage_Subnet** - Verifies no subnet overlap

### Related Documentation
- [Configure Windows Remote Management](https://learn.microsoft.com/windows/win32/winrm/installation-and-configuration-for-windows-remote-management)
