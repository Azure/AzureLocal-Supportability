# AzStackHci_Network_Test_Network_AddNode_NetworkATC_Service

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Network_AddNode_NetworkATC_Service</strong></td>
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

This validator checks that the NetworkATC feature and service are properly installed and running on the new node being added to the cluster. Network ATC is required to manage network intents on Azure Local nodes.

## Requirements

The new node must meet one of the following requirements:
1. NetworkATC feature is installed AND the NetworkATC service is running, OR
2. NetworkATC feature is available for installation (not yet installed)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about the NetworkATC feature and service status. The `Source` field identifies the new node.

```json
{
  "Name": "AzStackHci_Network_Test_Network_AddNode_NetworkATC_Service",
  "DisplayName": "Test NetworkATC service is running on new node",
  "Title": "Test NetworkATC service is running on new node",
  "Status": 1,
  "Severity": 2,
  "Description": "Check NetworkATC service is running on new node",
  "Remediation": "https://learn.microsoft.com/azure-stack/hci/deploy/deployment-tool-checklist",
  "TargetResourceID": "NetworkATCService",
  "TargetResourceName": "NetworkATCService",
  "TargetResourceType": "NetworkATCService",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "NODE4",
    "Resource": "AddNodeNewNodeNetworkATCServiceCheck",
    "Detail": "NetworkATC feature/service status: Feature Installed Service Stopped on NODE4",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: NetworkATC Service Not Running

**Error Message:**
```text
NetworkATC feature/service status: Feature Installed Service Stopped on NODE4
```

**Root Cause:** The NetworkATC feature is installed on the node, but the NetworkATC service is not running. This prevents Network ATC from managing network intents on the node.

#### Remediation Steps

1. Check the NetworkATC service status on the new node:

   ```powershell
   # Run on the new node
   Get-Service -Name NetworkATC
   ```

2. Start the NetworkATC service:

   ```powershell
   Start-Service -Name NetworkATC
   ```

3. Verify the service is running:

   ```powershell
   Get-Service -Name NetworkATC | Select-Object Name, Status, StartType
   ```

4. Ensure the service is set to start automatically:

   ```powershell
   Set-Service -Name NetworkATC -StartupType Automatic
   ```

5. Verify the service can communicate properly:

   ```powershell
   # Check NetworkATC cmdlets are working
   Get-NetIntent -ErrorAction SilentlyContinue
   ```

6. Retry the Add-Server operation.

---

### Failure: NetworkATC Feature Not Installed

**Error Message:**
```text
NetworkATC feature not installed/available on NODE4
```

**Root Cause:** The NetworkATC Windows feature is not installed and not available on the system. This should not happen on a properly prepared Azure Local node.

#### Remediation Steps

1. Check if the NetworkATC feature is available:

   ```powershell
   # Run on the new node
   Get-WindowsFeature -Name NetworkATC
   ```

2. Install the NetworkATC feature:

   ```powershell
   Install-WindowsFeature -Name NetworkATC -IncludeManagementTools
   ```

3. Verify the installation:

   ```powershell
   Get-WindowsFeature -Name NetworkATC | Select-Object Name, InstallState
   ```

4. Start the NetworkATC service:

   ```powershell
   Start-Service -Name NetworkATC
   Set-Service -Name NetworkATC -StartupType Automatic
   ```

5. Verify the service is running:

   ```powershell
   Get-Service -Name NetworkATC | Select-Object Name, Status, StartType
   ```

6. Retry the Add-Server operation.

> **Note**: If the NetworkATC feature is not available at all, this may indicate:
> - The operating system version is incorrect or incomplete
> - Required components were not installed during OS installation
> - The node needs to be rebuilt with the proper Azure Local OS image

---

## Additional Information

### Understanding NetworkATC Feature States

The NetworkATC Windows feature can be in three states:

| InstallState | Description | Validator Result |
|-------------|-------------|-----------------|
| **Installed** | Feature is installed; service should be running | ✓ Pass (if service running) / ✗ Fail (if service stopped) |
| **Available** | Feature is available but not yet installed | ✓ Pass (will be installed during Add-Server) |
| **Removed** or **Unknown** | Feature not available on system | ✗ Fail |

### NetworkATC Service Status

When the feature is installed, the service must be running:

```powershell
# Check service status
Get-Service -Name NetworkATC | Format-List Name, Status, StartType, DisplayName

# Expected output:
# Name      : NetworkATC
# Status    : Running
# StartType : Automatic
```

### Common Causes of Service Failures

| Cause | Description | Resolution |
|-------|-------------|-----------|
| Service stopped manually | Administrator stopped the service | Start the service |
| Service crashed | Service encountered an error and stopped | Check event logs, restart service |
| Startup type disabled | Service set to Manual or Disabled | Set to Automatic and start |
| OS corruption | System files corrupted | Run SFC scan or reinstall OS |

### Troubleshooting Service Start Failures

If the service fails to start:

1. Check event logs:

   ```powershell
   # Check NetworkATC event logs
   Get-WinEvent -LogName "Microsoft-Windows-Networking-NetworkATC/Operational" -MaxEvents 50 |
       Where-Object { $_.TimeCreated -gt (Get-Date).AddHours(-1) } |
       Select-Object TimeCreated, Id, LevelDisplayName, Message |
       Format-Table -Wrap

   # Check System event log
   Get-EventLog -LogName System -Source "Service Control Manager" -Newest 20 |
       Where-Object { $_.Message -like "*NetworkATC*" } |
       Format-List TimeGenerated, EntryType, Message
   ```

2. Try starting with verbose error information:

   ```powershell
   # Start service and capture any errors
   try {
       Start-Service -Name NetworkATC -ErrorAction Stop
       Write-Host "✓ Service started successfully" -ForegroundColor Green
   } catch {
       Write-Host "✗ Service failed to start" -ForegroundColor Red
       Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
   }
   ```

3. Check if required modules are available:

   ```powershell
   # NetworkATC requires PowerShell modules
   Get-Module -ListAvailable | Where-Object { $_.Name -like "*Network*" -or $_.Name -like "*ATC*" }
   ```

### Best Practices for Node Preparation

Before adding a server to the cluster:

1. **Verify OS installation**:
   - Use the correct Azure Local OS image
   - Complete all Windows updates
   - Install required features

2. **Verify NetworkATC readiness**:
   ```powershell
   # Node preparation checklist
   Get-WindowsFeature -Name NetworkATC | Format-List Name, InstallState
   Get-Service -Name NetworkATC | Format-List Name, Status, StartType
   Get-NetIntent -ErrorAction SilentlyContinue  # Should not error
   ```

3. **Ensure service auto-starts**:
   - Set NetworkATC to Automatic startup
   - Verify it survives a reboot

### Related Documentation

- [Network ATC overview](https://learn.microsoft.com/azure-stack/hci/deploy/network-atc-overview)
- [Add servers to an Azure Local cluster](https://learn.microsoft.com/azure-stack/hci/manage/add-server)
- [Manage Network ATC](https://learn.microsoft.com/azure-stack/hci/manage/manage-network-atc)
