# AzStackHci_Network_Test_StorageAdapterReadiness

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_StorageAdapterReadiness</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>
      <ul style="margin:0; padding-left:1.2em;">
        <li><strong>Deployment</strong> with a separate Storage Network Intent</li>
        <li><strong>Add Node</strong> operation with a separate Storage Network Intent</li>
      </ul>
    </td>
  </tr>
</table>

## Overview

This environment validator checks that the Storage Adapters are properly configured for Azure Local Deployment and Add Node scenarios. For this requirement, **Storage Adapter** refers to the network adapters for the Storage Network Intent.

_This validator only applies to Azure Local deployments with a separate Storage Network Intent._

### Requirements

All Storage Adapters on every node in the cluster must:

- Not have any IP addresses configured manually or via DHCP
- Support VLANID (the adapter must expose the VLANID property)
- Not have a VLANID configured (the value should be blank or zero)
- Have a unique name per node (no duplicate adapter names on the same node)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON, here is an example:

```json
{
  "Name": "AzStackHci_Network_Test_StorageAdapterReadiness",
  "DisplayName": "Validate that the Storage Adapters are ready for deployment",
  "Tags": {},
  "Title": "Validate that the Storage Adapters are ready for deployment",
  "Status": 1,
  "Severity": 2,
  "Description": "Validates that the Storage adapters on the node do not have Manual/DHCP IP Addresses or VLANID configured. There should not be multiple Storage adapters with the same name on the same node.",
  "Remediation": "https://aka.ms/azurelocal/envvalidator/storageadapterreadiness",
  "TargetResourceID": "AZLOC-NODE1, ethernet 3",
  "TargetResourceName": "AZLOC-NODE1, ethernet 3",
  "TargetResourceType": "StorageAdapter",
  "Timestamp": "/Date(1747080202442)/",
  "AdditionalData": {
    "Detail": "1) Adapter has the following IP address(es) configured: [ x.x.x.x ]. The Storage adapter should not have any Manual/DHCP IP addresses configured and DHCP should be disabled. 2) Adapter has the following VLANID configured: [ y ]. The Storage adapter should support VLANID, but not have a value configured.",
    "Status": "FAILURE",
    "TimeStamp": "05/12/2025 20:03:22",
    "Resource": "StorageAdapter",
    "Source": "AZLOC-NODE1, ethernet 3"
  },
  "HealthCheckSource": "Manual\\Standard\\Medium\\Network\\041bd958"
}
```

Check the AdditionalData field for summary of which Storage Adapters are not configured properly. Then refer to the remediation steps below. You can identify the resource by the `TargetResourceID` field. The format is `NodeName, AdapterName`. In this example, the node name is `AZLOC-NODE1` and the adapter name is `ethernet 3`.

In this example, the Storage Adapter on node `AZLOC-NODE1` with the name `ethernet 3` has two issues. It has an IP address configured and a VLANID configured.

---

### Failure: Adapter has the following IP address(es) configured: [ x.x.x.x ]. The Storage adapter should not have any Manual/DHCP IP addresses configured and DHCP should be disabled.

NetworkATC will configure the Storage Adapter IP addresses as part of the deployment process. The Storage Adapters should not have any IP addresses configured and DHCP should be disabled. To remediate this issue, follow these steps for each node and Storage Adapter that is listed.

#### Remediation Steps

1. Remove any IP Addresses configured on the Storage Adapter.
   ```powershell
   $adapter = Get-NetAdapter -Name "ethernet 3"
   $adapter | Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin @("Manual", "DHCP") | Remove-NetIPAddress
   ```
2. Disable DHCP on the Storage Adapter.
   ```powershell
   $adapter = Get-NetAdapter -Name "ethernet 3"
   $adapter | Set-NetIPInterface -Dhcp Disabled
   ```
3. Verify that the Storage Adapter does not have any IP addresses configured.
   ```powershell
   $adapter = Get-NetAdapter -Name "ethernet 3"
   $adapter | Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin @("Manual", "DHCP")
   ```

### Failure: Adapter has the following VLANID configured: [ y ]. The Storage adapter should support VLANID, but not have a value configured.

The Storage Adapter should support VLANID, but not have a value configured. Network ATC will configure the VLANID as part of the deployment process. To remediate this issue, follow these steps for each node and Storage Adapter that is listed.

#### Remediation Steps

1. Remove any VLANID configured on the Storage Adapter.
   ```powershell
   $adapter = Get-NetAdapter -Name "ethernet 3"
   $adapter | Set-NetAdapterAdvancedProperty -RegistryKeyword "VLANID" -RegistryValue 0
   ```
2. Verify that the Storage Adapter does not have any VLANID configured.
   ```powershell
   $adapter = Get-NetAdapter -Name "ethernet 3"
   $adapter | Get-NetAdapterAdvancedProperty -RegistryKeyword "VLANID"
   ```

### Failure: Adapter does not support VLANID. The Storage adapter should support VLANID.

Storage Adapters must support VLANID.