# AzStackHci_Network_Test_StorageConnections_NoValidationMethod
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_StorageConnections_NoValidationMethod</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td><strong>Deployment</strong></td>
  </tr>
</table>

## Overview

This validator fails when the Storage Adapters do not have an APIPA address, or have a non-APIPA address.

APIPA addresses (169.254.x.x) allow automatic IP assignment within the storage network and enable connectivity tests without relying on DHCP or manual IPs.

> **Note:** Storage Adapters refer to the network adapters that are used in the Storage Network Intent.

## Requirements

Each Storage Adapter on every node in the cluster must:

- **Have a single APIPA address** (169.254.x.x) assigned to them
- **Have no other IP addresses** assigned to them (no static IPs, no DHCP addresses)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Host and Storage Adapters are not configured properly. You can identify the host by the `TargetResourceID` field, the format is `NodeName, AdapterName`.

```json
{
  "Name": "AzStackHci_Network_Test_StorageConnections_NoValidationMethod",
  "DisplayName": "Validate that each Storage Adapter has a single APIPA address for connectivity testing.",
  "Tags": {},
  "Title": "Validate that each Storage Adapter has a single APIPA address for connectivity testing.",
  "Status": 1,
  "Severity": 2,
  "Description": "Each Storage Adapter must have exactly one APIPA address and no other assigned IP addresses. APIPA is used to validate storage connectivity between nodes. The presence of manually assigned or DHCP IP addresses may interfere with connectivity tests.",
  "Remediation": "https://aka.ms/azurelocal/envvalidator/storageconnections",
  "TargetResourceID": "azloc-node1, ethernet 3",
  "TargetResourceName": "azloc-node1, ethernet 3",
  "TargetResourceType": "StorageAdapter",
  "Timestamp": "/Date(1750096684067)/",
  "AdditionalData": {
    "Detail": "Adapter has the following IP address(es) configured: [ x.x.x.x ]. The Storage Adapter must not have any manually assigned or DHCP IP addresses, and DHCP should be disabled. It must have a single APIPA address.",
    "Status": "FAILURE",
    "TimeStamp": "06/16/2025 17:58:04",
    "Resource": "StorageAdapter",
    "Source": "azloc-node1, ethernet 3"
  },
  "HealthCheckSource": "Manual\\Standard\\Medium\\Network\\72bf139a"
}
```

### Failure: `Adapter has the following IP address(es) configured: [x.x.x.x]`

**Error Message:**
```text
Adapter has the following IP address(es) configured: [x.x.x.x]. 
The Storage Adapter must not have any manually assigned or DHCP IP addresses, and DHCP should be disabled.
```

**Root Cause:** The Storage Adapter has static IP or DHCP-assigned IP addresses that must be removed.

#### Remediation Steps

##### Remove Manual/DHCP IP Addresses

1) Disable DHCP on Storage Adapter. DHCP must be disabled to allow APIPA address assignment.

   ```powershell
   # Replace "ethernet 3" with your actual adapter name
   Set-NetIPInterface -InterfaceAlias "ethernet 3" -Dhcp Disabled
   ```

2) Remove Static IP Addresses

   ```powershell
   # Method 1: Remove specific IP address
   Remove-NetIPAddress -InterfaceAlias "ethernet 3" -IPAddress "192.168.1.100" -Confirm:$false

   # Method 2: Remove all Manual/DHCP IPv4 addresses
   $adapter = Get-NetAdapter -Name "ethernet 3"
   $adapter | Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin @("Manual", "DHCP") | Remove-NetIPAddress -Confirm:$false
   ```

3) Verify APIPA Address Assignment

   ```powershell
   # Wait for APIPA address to be assigned (may take a few seconds)
   Start-Sleep -Seconds 10

   # Verify APIPA address is present
   Get-NetAdapter -Name "ethernet 3" | Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like "169.254.*"}
   ```

### Failure: `Adapter does not have any IP addresses configured`

#### Example
```text
Adapter does not have any IP addresses configured
```

**Root Cause:** The Storage Adapter lacks the required APIPA address configuration.

#### Remediation Steps

1) Verify Adapter Status

   ```powershell
   # Check if adapter is enabled
   Get-NetAdapter -Name "ethernet 3" | Select-Object Name, Status, LinkSpeed

   # Enable adapter if disabled
   Enable-NetAdapter -Name "ethernet 3"
   ```

2) Ensure DHCP is Disabled

   ```powershell
   # Disable DHCP to allow APIPA
   Set-NetIPInterface -InterfaceAlias "ethernet 3" -Dhcp Disabled
   ```

3) Force APIPA Address Assignment

   ```powershell
   # Restart adapter to trigger APIPA assignment
   Restart-NetAdapter -Name "ethernet 3"

   # Wait and verify APIPA address
   Start-Sleep -Seconds 15
   Get-NetAdapter -Name "ethernet 3" | Get-NetIPAddress -AddressFamily IPv4
   ```

## Expected Configuration

After successful remediation, each Storage Adapter should show:

```text
Name          : ethernet 3
Status        : Up
DHCP Enabled  : Disabled
IP Addresses  : 169.254.x.x (Origin: WellKnown)
```