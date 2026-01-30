# AzStackHci_Network_Test_Network_StorageVlanFor2NodeSwitchLess

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzStackHci_Network_Test_Network_StorageVlanFor2NodeSwitchLess</strong></td>
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

This validator checks that 2-node switchless deployments provide exactly one storage VLAN ID for each storage adapter. Switchless deployments require VLAN configuration to properly isolate storage traffic between the two nodes.

## Requirements

For 2-node switchless deployments:
1. The deployment configuration must include a storageNetworks section with VLAN IDs
2. The number of VLAN IDs provided must equal the number of storage adapters

For other deployment types (switched or non-2-node):
- This validation is skipped (not applicable)

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for information about storage VLAN configuration.

```json
{
  "Name": "AzStackHci_Network_Test_Network_StorageVlanFor2NodeSwitchLess",
  "DisplayName": "Test storage VLANID requirement for 2-node switchless deployment",
  "Title": "Test storage VLANID requirement for 2-node switchless deployment",
  "Status": 1,
  "Severity": 2,
  "Description": "Check user provides one storage VLANID for each storage adapter provided on 2-node switchless deployment",
  "Remediation": "Please provide valid storageNetworks and storage VLANID information in your deployment configuration file: Make sure you provide one storage VLANID for each storage adapter provided on 2-node switchless deployment.",
  "TargetResourceID": "StorageVlanIdFor2NodeSwitchLess",
  "TargetResourceName": "StorageVlanIdFor2NodeSwitchLess",
  "TargetResourceType": "StorageVlanIdFor2NodeSwitchLess",
  "Timestamp": "<timestamp>",
  "AdditionalData": {
    "Source": "<ComputerName>",
    "Resource": "StorageVlanIdFor2NodeSwitchLess",
    "Detail": "No storageNetworks section or valid storage VLANID info provided in the configuration.",
    "Status": "FAILURE",
    "TimeStamp": "<timestamp>"
  }
}
```

---

### Failure: No Storage VLAN IDs Provided

**Error Message:**
```text
No storageNetworks section or valid storage VLANID info provided in the configuration.
```

**Root Cause:** The deployment configuration is missing the storageNetworks section or does not contain valid storage VLAN ID information. For 2-node switchless deployments, VLAN IDs are required to properly tag and isolate storage traffic.

#### Remediation Steps

##### Add Storage VLAN Configuration

1. Identify how many storage adapters are in your storage intent:

   - Check your deployment configuration for the storage intent definition
   - Count the number of adapters defined for storage

2. Update your deployment configuration file to include storage VLAN IDs:

   **Example configuration (JSON format):**
   ```json
   {
       "storageNetworks": [
           {
               "name": "Storage1",
               "networkAdapterName": "Ethernet 2",
               "vlanId": 711
           },
           {
               "name": "Storage2",
               "networkAdapterName": "Ethernet 3",
               "vlanId": 712
           }
       ],
       "intents": [
           {
               "name": "StorageIntent",
               "trafficType": ["Storage"],
               "adapter": ["Ethernet 2", "Ethernet 3"]
           }
       ]
   }
   ```

3. Ensure the number of VLAN IDs matches the number of storage adapters:
   - 2 storage adapters → 2 VLAN IDs required
   - 4 storage adapters → 4 VLAN IDs required

4. Use unique VLAN IDs for each storage adapter:
   - Do not reuse the same VLAN ID for multiple adapters
   - Use VLANs that are configured on your network infrastructure (if applicable)
   - Recommended range: 700-799 for storage traffic

5. Retry the deployment with the updated configuration.

---

### Failure: VLAN Count Does Not Match Adapter Count

**Error Message:**
```text
Found [ 1 ] storage VLANID in the configuration: 711
```
(When there are 2 storage adapters but only 1 VLAN ID provided)

**Root Cause:** The number of storage VLAN IDs provided in the configuration does not match the number of storage adapters. Each storage adapter in a 2-node switchless deployment requires its own VLAN ID.

#### Remediation Steps

1. Check how many storage adapters are defined in your storage intent:

   ```powershell
   # Check your configuration file or deployment parameters
   # Count the storage adapters
   ```

2. Update the storageNetworks section to provide one VLAN ID per adapter:

   **Example: 2 adapters require 2 VLAN IDs**
   ```json
   {
       "storageNetworks": [
           {
               "name": "Storage1",
               "networkAdapterName": "Ethernet 2",
               "vlanId": 711
           },
           {
               "name": "Storage2",
               "networkAdapterName": "Ethernet 3",
               "vlanId": 712  // Added second VLAN
           }
       ]
   }
   ```

3. Ensure VLAN IDs are unique:
   - Each adapter must have a different VLAN ID
   - Do not use the same VLAN ID for multiple adapters in switchless deployments

4. Retry the deployment with the updated configuration.

---

## Additional Information

### Why VLANs are Required for 2-Node Switchless

In 2-node switchless deployments:
- Storage adapters connect directly between the two nodes (no switch)
- VLANs are used to create logical network separation
- Each adapter pair (node1-adapter1 ↔ node2-adapter1) uses a unique VLAN
- This prevents network loops and ensures proper traffic isolation

### VLAN Configuration Example

For a 2-node switchless cluster with 2 storage adapters:

| Node | Adapter | VLAN ID | Connects To |
|------|---------|---------|-------------|
| NODE1 | Ethernet 2 | 711 | NODE2 Ethernet 2 (VLAN 711) |
| NODE1 | Ethernet 3 | 712 | NODE2 Ethernet 3 (VLAN 712) |
| NODE2 | Ethernet 2 | 711 | NODE1 Ethernet 2 (VLAN 711) |
| NODE2 | Ethernet 3 | 712 | NODE1 Ethernet 3 (VLAN 712) |

### Recommended VLAN ID Ranges

| Purpose | Recommended Range | Example |
|---------|------------------|---------|
| Storage (switchless) | 700-799 | 711, 712, 713, 714 |
| Management | 1-99 | 1, 10, 50 |
| Compute/VM | 100-699 | 100, 200, 300 |

### Storage Network Configuration File Example

Complete example for 2-node switchless with 4 storage adapters:

```json
{
    "clusterPattern": "Standard",
    "switchlessDeploy": true,
    "storageNetworks": [
        {
            "name": "Storage1",
            "networkAdapterName": "Ethernet 2",
            "vlanId": 711
        },
        {
            "name": "Storage2",
            "networkAdapterName": "Ethernet 3",
            "vlanId": 712
        },
        {
            "name": "Storage3",
            "networkAdapterName": "Ethernet 4",
            "vlanId": 713
        },
        {
            "name": "Storage4",
            "networkAdapterName": "Ethernet 5",
            "vlanId": 714
        }
    ],
    "intents": [
        {
            "name": "ManagementIntent",
            "trafficType": ["Management"],
            "adapter": ["Ethernet", "Ethernet 1"]
        },
        {
            "name": "StorageIntent",
            "trafficType": ["Storage"],
            "adapter": ["Ethernet 2", "Ethernet 3", "Ethernet 4", "Ethernet 5"]
        }
    ]
}
```

### When This Validation Applies

This validator only runs when **ALL** of these conditions are met:
1. **Node count** = 2 (exactly 2 nodes)
2. **Switchless** = true (direct-connect storage)
3. **Scenario** = Deployment

For other scenarios, this validation is skipped.

### Verifying VLAN Configuration

After deployment, verify VLANs are configured:

```powershell
# Check VLAN IDs on storage adapters
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
    $vlan = Get-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "VlanID" -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Adapter = $_.Name
        VLANID = if ($vlan) { $vlan.DisplayValue } else { "None" }
        Status = $_.Status
    }
} | Format-Table -AutoSize
```

### Related Documentation

- [Plan host networking for switchless deployments](https://learn.microsoft.com/azure-stack/hci/plan/two-node-switchless)
- [Network reference patterns](https://learn.microsoft.com/azure-stack/hci/plan/network-patterns-overview)
- [Storage Spaces Direct networking](https://learn.microsoft.com/azure-stack/hci/concepts/storage-spaces-direct-networking)
- [Network ATC overview](https://learn.microsoft.com/azure-stack/hci/deploy/network-atc-overview)
