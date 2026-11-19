# AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness</strong></td>
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

This validator checks that the Hyper-V role is installed and available on the host. Hyper-V is required to test infrastructure IP pool connectivity because the validator need to create a temporary virtual switch and virtual network adapter to validate that infrastructure IPs can reach DNS servers and required endpoints.

## Requirements

1. Hyper-V role must be installed on the host

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about Hyper-V readiness.

```json
{
  "Name": "AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_Hyper_V_Readiness",
  "DisplayName": "Test Hyper-V readiness for all IP in infra IP pool",
  "Title": "Test Hyper-V readiness for all IP in infra IP pool",
  "Status": 1,
  "Severity": 2,
  "Description": "Test Hyper-V readiness for all IP in infra IP pool",
  "Remediation": "Make sure that Hyper-V is installed on host SERVER01 and rerun the validation.",
  "TargetResourceID": "Infra_IP_Connection_HyperVReadiness",
  "TargetResourceName": "Infra_IP_Connection_HyperVReadiness",
  "TargetResourceType": "Infra_IP_Connection_HyperVReadiness",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "SERVER01",
    "Resource": "HyperVReadiness",
    "Detail": "[FAILED] Cannot test connection for infra IP without Hyper-V on host SERVER01.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: Hyper-V Not Installed

**Error Message:**
```text
[FAILED] Cannot test connection for infra IP without Hyper-V on host SERVER01.
```

**Root Cause:** The Hyper-V role is not installed on the host. The infrastructure IP connectivity validator requires Hyper-V to create a temporary virtual switch and virtual adapter for testing network connectivity from infrastructure IPs.

#### Remediation Steps

##### 1. Check Current Hyper-V Status

Check if Hyper-V is installed:

```powershell
# Check Hyper-V Windows feature status
Get-WindowsFeature -Name "Hyper-V"

# Check if Hyper-V cmdlets are available
Get-Command Get-VMSwitch -ErrorAction SilentlyContinue
```

**Expected output if installed:**
```
Display Name                       Name            Install State
-----------------                  ----            -------------
[X] Hyper-V                        Hyper-V         Installed
```

##### 2. Install Hyper-V Role

If Hyper-V is not installed, install it:

```powershell
# Install Hyper-V role
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

# Note: A reboot is required after installation
```

**Alternative method using DISM:**
```powershell
# Enable Hyper-V using DISM
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart

# Install Hyper-V management tools
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart

# Reboot the system
Restart-Computer -Force
```

##### 3. Verify Installation

After the reboot, verify Hyper-V is properly installed:

```powershell
# Verify Hyper-V feature is installed
Get-WindowsFeature -Name "Hyper-V" | Select-Object DisplayName, InstallState

# Verify Hyper-V services are running
Get-Service -Name vmms | Select-Object Name, Status, StartType

# Verify Hyper-V cmdlets are available
Get-Command Get-VMSwitch, New-VMSwitch, Get-VMNetworkAdapter
```

**Expected services status:**
```
Name         Status  StartType
----         ------  ---------
vmms         Running Automatic
```

##### 4. Check for Installation Issues

If Hyper-V installation fails or cannot be enabled:

**Check hardware virtualization support:**
```powershell
# Check if virtualization is enabled in BIOS/UEFI
systeminfo | findstr /i "hyper-v"

# Check processor virtualization capabilities
Get-CimInstance -ClassName Win32_Processor | Select-Object Name, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions
```

**Common issues:**
- **Virtualization not enabled in BIOS**: Enable Intel VT-x or AMD-V in BIOS/UEFI settings
- **Conflicting hypervisor**: Remove other virtualization products (VMware Workstation, VirtualBox, etc.)
- **Running in a VM**: Nested virtualization must be enabled on the host hypervisor

##### 5. Retry the Validation

After installing Hyper-V and rebooting, re-run the Environment Validator.

---

## Additional Information

### Why Hyper-V is Required for This Validator

The infrastructure IP connectivity validator performs the following operations that require Hyper-V:

1. **Creates a temporary virtual switch** (or uses an existing one)
2. **Creates a virtual network adapter** (vNIC) for testing
3. **Assigns infrastructure IPs** to the virtual adapter one at a time
4. **Tests connectivity** from each IP to DNS servers and Azure endpoints
5. **Cleans up** the test resources after validation

This approach allows the validator to test connectivity from infrastructure IPs without permanently configuring them on physical adapters.

### When This Validator Runs

This validator only runs in scenarios where infrastructure IP connectivity needs to be tested:

| Scenario | Runs? | Conditions |
|----------|-------|------------|
| **Deployment** | ✓ Yes | Only if ArcGateway is NOT enabled |
| **Upgrade** | ✓ Yes | Only if ArcGateway is NOT enabled |

**Note:** If ArcGateway is enabled, this validator is skipped because ArcGateway provides an alternative connectivity method that might not require infrastructure IP validation.

### Hyper-V Requirements for Azure Local

Hyper-V is a core requirement for Azure Local clusters:

- **Required for cluster operations**: Hosts VMs and containerized workloads
- **Required for Network ATC**: Creates virtual switches for network isolation
- **Required for storage**: Storage Spaces Direct uses Hyper-V features
- **Required for management**: Admin VMs and Arc Resource Bridge run on Hyper-V

### Verifying Hyper-V Installation

Complete verification of Hyper-V installation:

```powershell
# Check all Hyper-V related features
Get-WindowsFeature -Name Hyper-V* | Where-Object { $_.InstallState -eq "Installed" } |
    Select-Object DisplayName, Name, InstallState |
    Format-Table -AutoSize

# Check Hyper-V virtual switch capabilities
Get-VMHost | Select-Object VirtualHardDiskPath, VirtualMachinePath, EnableEnhancedSessionMode

# Verify network virtualization capabilities
Get-VMSystemSwitchExtension | Select-Object Name, Vendor, Enabled
```

### Troubleshooting Hyper-V Installation Issues

#### Issue: Installation Fails with Error

**Solution 1 - Check for conflicting software:**
```powershell
# For example, check for other hypervisors
Get-WmiObject Win32_Product | Where-Object { $_.Name -like "*VMware*" -or $_.Name -like "*VirtualBox*" }

# Uninstall conflicting software before installing Hyper-V
```

**Solution 2 - Verify system requirements:**
```powershell
# Check if system meets minimum requirements
# - 64-bit processor with SLAT (Second Level Address Translation)
# - VM Monitor Mode Extension (VT-c on Intel or AMD-V on AMD)
# - Minimum 4 GB RAM (8+ GB recommended)
# - BIOS-level hardware virtualization support enabled

Get-ComputerInfo | Select-Object CsProcessors, OsTotalVisibleMemorySize, HyperVisorPresent, HyperVRequirementVirtualizationFirmwareEnabled
```

#### Issue: Hyper-V Cmdlets Not Available

**Solution:**
```powershell
# Install Hyper-V PowerShell module separately
Install-WindowsFeature -Name Hyper-V-PowerShell

# Import module manually
Import-Module Hyper-V

# Verify module is loaded
Get-Module Hyper-V
```

#### Issue: Hyper-V Services Not Starting

**Solution:**
```powershell
# Check service dependencies
Get-Service -Name vmms -DependentServices
Get-Service -Name vmms | Select-Object -ExpandProperty ServicesDependedOn

# Start services manually
Start-Service -Name vmms
Start-Service -Name vmcompute

# Check Windows Event Logs for errors
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-*" -MaxEvents 20 |
    Where-Object { $_.LevelDisplayName -eq "Error" } |
    Select-Object TimeCreated, Message |
    Format-List
```

### Installing Hyper-V on Server Core

If running Server Core:

```powershell
# Install Hyper-V on Server Core
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

# Verify installation
Get-WindowsFeature -Name Hyper-V*

# If management tools are needed
Install-WindowsFeature -Name RSAT-Hyper-V-Tools
```

### Related Validators

Other infrastructure IP connection validators that run after this validator passes:
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_VMSwitch_Readiness** - Validates virtual switch
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_MANAGEMENT_VNIC_Readiness** - Validates management vNIC
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_IPReadiness** - Tests IP configuration
- **AzureLocal_NetworkInfraConnection_Test_Infra_IP_Connection_DNS_Server_Port_53** - Tests DNS connectivity

### Related Documentation

- [Install Hyper-V on Windows Server](https://learn.microsoft.com/windows-server/virtualization/hyper-v/get-started/install-the-hyper-v-role-on-windows-server)
- [Hyper-V on Windows Server](https://learn.microsoft.com/windows-server/virtualization/hyper-v/hyper-v-on-windows-server)
- [System requirements for Hyper-V](https://learn.microsoft.com/windows-server/virtualization/hyper-v/system-requirements-for-hyper-v-on-windows)
- [Azure Local host network requirements](https://learn.microsoft.com/azure-stack/hci/concepts/host-network-requirements)
