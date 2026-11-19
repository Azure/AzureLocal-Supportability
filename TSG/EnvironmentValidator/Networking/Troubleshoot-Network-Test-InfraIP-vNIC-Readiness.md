# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness</strong></td>
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

This validator checks that a temporary test virtual network adapter can be created successfully on the virtual switch. This test vNIC is used to assign infrastructure IPs and validate connectivity to DNS servers and Azure endpoints.

## Requirements

1. Ability to create a new virtual network adapter using `Add-VMNetworkAdapter`
2. The test vNIC must be operational and accessible
3. `Get-VMNetworkAdapter` cmdlet must work correctly

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_vNIC_Readiness",
  "DisplayName": "Test virtual adapter readiness for all IP in infra IP pool",
  "Title": "Test virtual adapter readiness for all IP in infra IP pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test virtual adapter readiness for all IP in infra IP pool",
  "Remediation": "Make sure Add/Get-VMNetworkAdapter on SERVER01 can run correctly.",
  "TargetResourceID": "Infra_IP_Connection_VNICReadiness",
  "TargetResourceName": "Infra_IP_Connection_VNICReadiness",
  "TargetResourceType": "Infra_IP_Connection_VNICReadiness",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "VNICReadiness",
    "Detail": "[FAILED] Cannot test connection for infra IP. VM network adapter is not configured correctly on host SERVER01.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Cannot Create Test vNIC

**Error Message:**
```text
[FAILED] Cannot test connection for infra IP. VM network adapter is not configured correctly on host SERVER01.
```

**Root Cause:** The validator cannot create a temporary test vNIC, which could be caused by:
- Hyper-V cmdlets not working properly
- Virtual switch issues
- Insufficient permissions
- System resource constraints

#### Remediation Steps

##### 1. Verify Hyper-V Cmdlets Are Working

Test basic Hyper-V virtual adapter operations:

```powershell
# Test Get-VMNetworkAdapter cmdlet
Get-VMNetworkAdapter -ManagementOS | Format-Table Name, SwitchName, Status -AutoSize

# Test if we can access virtual switch
Get-VMSwitch | Format-Table Name, SwitchType -AutoSize
```

If these cmdlets fail, Hyper-V may not be properly installed or the service may be stopped.

##### 2. Check Hyper-V Services

Ensure Hyper-V services are running:

```powershell
# Check Hyper-V services
Get-Service -Name vmms | Select-Object Name, Status, StartType | Format-Table -AutoSize

# Start services if stopped
if ((Get-Service vmms).Status -ne 'Running') {
    Start-Service vmms
}

# Verify services are running
Get-Service -Name vmms
```

##### 3. Test Creating a Temporary vNIC

Try manually creating a test vNIC to diagnose the issue:

```powershell
# Get the virtual switch
$vmSwitch = Get-VMSwitch -SwitchType External | Select-Object -First 1

if (-not $vmSwitch) {
    Write-Error "No external virtual switch found"
    exit
}

# Try creating a test vNIC
$testVNICName = "TestVNIC_Temp"
try {
    Add-VMNetworkAdapter -ManagementOS -Name $testVNICName -SwitchName $vmSwitch.Name
    Write-Host "✓ Successfully created test vNIC" -ForegroundColor Green

    # Verify it exists
    $testVNIC = Get-VMNetworkAdapter -ManagementOS -Name $testVNICName
    if ($testVNIC) {
        Write-Host "✓ Test vNIC is accessible" -ForegroundColor Green
        Write-Host "  Name: $($testVNIC.Name)" -ForegroundColor White
        Write-Host "  Switch: $($testVNIC.SwitchName)" -ForegroundColor White
        Write-Host "  Status: $($testVNIC.Status)" -ForegroundColor White
    }

    # Clean up
    Remove-VMNetworkAdapter -ManagementOS -Name $testVNICName -Confirm:$false
    Write-Host "✓ Successfully removed test vNIC" -ForegroundColor Green

} catch {
    Write-Host "✗ Failed to create test vNIC" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}
```

##### 4. Check for Resource Constraints

Verify system has sufficient resources:

```powershell
# Check available memory
$os = Get-CimInstance Win32_OperatingSystem
$freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
Write-Host "Free Memory: $freeMemoryGB GB"

# Check existing vNIC count
$vnicCount = (Get-VMNetworkAdapter -ManagementOS).Count
Write-Host "Existing Management vNICs: $vnicCount"

# Check virtual switch health
Get-VMSwitch | ForEach-Object {
    Write-Host "`nSwitch: $($_.Name)"
    Write-Host "  Type: $($_.SwitchType)"
    Write-Host "  Embedded Teaming: $($_.EmbeddedTeamingEnabled)"

    $adapters = Get-VMNetworkAdapter -ManagementOS | Where-Object { $_.SwitchName -eq $_.Name }
    Write-Host "  Connected vNICs: $($adapters.Count)"
}
```

##### 5. Check Permissions

Ensure you're running with administrator privileges:

```powershell
# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✓ Running with administrator privileges" -ForegroundColor Green
} else {
    Write-Host "✗ NOT running with administrator privileges" -ForegroundColor Red
    Write-Host "  The Environment Validator must run with administrator rights" -ForegroundColor Yellow
}
```

##### 6. Restart Hyper-V Services

If cmdlets are not working, try restarting Hyper-V services:

```powershell
# Restart Hyper-V Virtual Machine Management service
Restart-Service vmms -Force

# Wait a moment
Start-Sleep -Seconds 5

# Verify services are running
Get-Service vmms, vmcompute | Format-Table Name, Status -AutoSize

# Test vNIC operations again
Get-VMNetworkAdapter -ManagementOS | Select-Object Name, SwitchName
```

##### 7. Check Event Logs

Review Hyper-V event logs for errors:

```powershell
# Check recent Hyper-V errors
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-*" -MaxEvents 20 -ErrorAction SilentlyContinue |
    Where-Object { $_.LevelDisplayName -eq "Error" } |
    Select-Object TimeCreated, LogName, Message |
    Format-List

# Check specifically for VMMS errors
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 10 -ErrorAction SilentlyContinue |
    Where-Object { $_.LevelDisplayName -eq "Error" } |
    Format-List TimeCreated, Message
```

##### 8. Retry the Validation

After fixing the issues, re-run the Environment Validator.

---

## Additional Information

### Test vNIC Purpose

The validator creates a temporary test vNIC to:

1. Assign infrastructure IPs one at a time
2. Test connectivity from each IP to DNS servers (port 53)
3. Test connectivity from each IP to required Azure endpoints
4. Collect connectivity validation results
5. Clean up and remove the test vNIC after validation

### Test vNIC Lifecycle

```
1. Create temporary vNIC → connected to virtual switch
2. For each infrastructure IP (up to first 9 IPs):
   a. Assign IP to test vNIC
   b. Wait for IP to become ready
   c. Test connectivity to DNS servers
   d. Test connectivity to Azure endpoints
   e. Remove IP from test vNIC
3. Remove temporary vNIC (cleanup)
```

### How Many vNICs Can Exist?

There's no hard limit on management vNICs, but:
- Too many vNICs can consume system resources
- Typical deployments have 1-3 management vNICs
- Test vNIC is temporary and cleaned up after validation

### Prerequisites for This Validator

This validator requires:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness** - Hyper-V must be installed
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness** - Virtual switch must exist
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_MANAGEMENT_VNIC_Readiness** - Management vNIC must exist

### Related Validators

Validators that run after this validator:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNSClientServerAddress_Readiness** - Validates DNS configuration
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness** - Tests infrastructure IP assignment
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53** - Tests DNS connectivity

### Related Documentation

- [Hyper-V Network Virtualization](https://learn.microsoft.com/windows-server/networking/sdn/technologies/hyper-v-network-virtualization/hyper-v-network-virtualization)
