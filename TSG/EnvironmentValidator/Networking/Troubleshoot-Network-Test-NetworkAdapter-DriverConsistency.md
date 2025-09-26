# AzureLocal_Network_Test_NetworkAdapter_DriverConsistency
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_NetworkAdapter_DriverConsistency</strong></td>
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

This validator fails if the network adapters that are part of a Network Intent do not use consistent driver versions across all nodes. 

All nodes in the cluster must maintain this consistency to ensure predictable networking behavior.

## Requirements

Adapters that are part of any one Network Intent must meet the following requirements:
1. Must exist on the system
2. Must use the same driver version across all nodes in the cluster

See [Azure Local - Host Network Requirements](https://docs.azure.cn/en-us/azure-local/concepts/host-network-requirements#driver-requirements) for more details.

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Host's Network Adapters are not configured properly. You can identify the host by the `TargetResourceID` field, the format is `NodeName`.

```json
{
    "Name":  "AzureLocal_Network_Test_NetworkAdapter_DriverConsistency",
    "DisplayName":  "Validate that Network Intent Adapters use consistent driver versions across all nodes",
    "Tags":  {},
    "Title":  "Validate that Network Intent Adapters use consistent driver versions across all nodes",
    "Status":  0,
    "Severity":  2,
    "Description":  "All Network Adapters assigned to a Network Intent must use consistent driver versions across all nodes. Adapters from the same manufacturer should have identical driver versions. All nodes in the cluster must maintain this consistency to ensure predictable networking behavior.",
    "Remediation":  "https://aka.ms/azurelocal/envvalidator/IntentAdapterDrivers",
    "TargetResourceID":  "ManagementCompute Intent",
    "TargetResourceName":  "ManagementCompute Intent",
    "TargetResourceType":  "Network Intent Adapters",
    "Timestamp":  "\/Date(1758143304641)\/",
    "AdditionalData":  {
                            "Detail":  "[FAIL] ManagementCompute Intent uses multiple driver versions: [Driver Date 2024-04-16 Version 24.4.26429.0 NDIS 6.89] (AZLOC-NODE1/ethernet, pester-host2/ethernet), [Driver Date 2024-04-16 Version 23.10.26252.0 NDIS 6.89] (AZLOC-NODE1/ethernet 2, pester-host2/ethernet 2).",
                            "Status":  "FAILURE",
                            "TimeStamp":  "09/17/2025 21:08:24",
                            "Resource":  "ManagementCompute Intent",
                            "Source":  "AZLOC-NODE1"
                        },
    "HealthCheckSource":  "Manual\\Standard\\Medium\\Network\\9880e803"
}
```

---

### Failure: `[FAIL] IntentName uses multiple driver versions: [Driver Date YYYY-MM-DD Version X.X.XXXXX.X NDIS X.XX] (NodeName/AdapterName, ...), [Driver Date YYYY-MM-DD Version X.X.XXXXX.X NDIS X.XX] (NodeName/AdapterName, ...).`

**Error Message:**
```text
[FAIL] ManagementCompute Intent uses multiple driver versions: [Driver Date 2024-04-16 Version 24.4.26429.0 NDIS 6.89] (AZLOC-NODE1/ethernet, pester-host2/ethernet), [Driver Date 2024-04-16 Version 23.10.26252.0 NDIS 6.89] (AZLOC-NODE1/ethernet 2, pester-host2/ethernet 2).
```

**Root Cause:** The network adapters within the specified Network Intent are using multiple different driver versions across the nodes, which can lead to inconsistent networking behavior.

#### Remediation Steps

1) Check with your hardware vendor to obtain the appropriate drivers for the Network Adapters.
2) Update the drivers on each Network Adapter in the Network Intent to ensure they all use the same version across all nodes in the cluster. Note that the adapters in each Network Intent must use the same driver across all nodes.

### Failure: `[FAIL] IntentName uses multiple driver versions: [Adapter Not Found] (NodeName/AdapterName, ...) ...`

**Error Message:**
```text
[FAIL] ManagementCompute Intent uses multiple driver versions: [Adapter Not Found] (AZLOC-NODE1/ethernet), [Driver Date 2024-04-16 Version 24.4.26429.0 NDIS 6.89] (AZLOC-NODE1/ethernet 2, pester-host2/ethernet, pester-host2/ethernet 2).
```

**Root Cause:** The specified network adapter does not exist on the system.

#### Remediation Steps

1) Check that the adapter exists

  ```powershell
  Get-NetAdapter -Name "AdapterName"
  ```

If the adapter is not found, ensure it has the correct name and is physically installed on the system.