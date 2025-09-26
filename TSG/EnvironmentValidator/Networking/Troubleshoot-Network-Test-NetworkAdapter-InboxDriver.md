# AzureLocal_Network_Test_NetworkAdapter_InboxDriver
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_NetworkAdapter_InboxDriver</strong></td>
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

This validation check fails when a network adapter that is a part of a Network Intent uses an inbox driver. Inbox drivers are not supported by Azure Local.

An inbox driver will have the DriverProvider "Microsoft" or "Windows".

## Requirements

Adapters that are part of a Network Intent must meet the following requirements:
1. Must exist on the system
2. Must NOT use an inbox driver (DriverProvider "Microsoft" or "Windows")

See [Azure Local - Host Network Requirements](https://docs.azure.cn/en-us/azure-local/concepts/host-network-requirements#driver-requirements) for more details.

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Host's Network Adapters are not configured properly. You can identify the host by the `TargetResourceID` field, the format is `NodeName, NetworkAdapters`.

```json
{
    "Name":  "AzureLocal_Network_Test_NetworkAdapter_InboxDriver",
    "DisplayName":  "Validate that the Network Adapters are not using inbox drivers",
    "Tags":  {},
    "Title":  "Validate that the Network Adapters are not using inbox drivers",
    "Status":  1,
    "Severity":  2,
    "Description":  "The Network Adapters used by a Network Intent must not use inbox drivers, unless it is a virtual deployment. Inbox drivers will have the DriverProvider equal to Microsoft or Windows. Work with your hardware vendor to obtain the appropriate drivers.",
    "Remediation":  "https://aka.ms/azurelocal/envvalidator/InboxDrivers",
    "TargetResourceID":  "AZLOC-NODE1, Network Adapters",
    "TargetResourceName":  "AZLOC-NODE1, Network Adapters",
    "TargetResourceType":  "NetworkAdapter",
    "Timestamp":  "\/Date(1758300600191)\/",
    "AdditionalData":  {
                            "Detail":  "AZLOC-NODE1 (1/2 adapters passed):  ethernet [Microsoft], ethernet 2 [Mellanox Technologies Ltd.]. No adapters should use inbox (Microsoft or Windows) drivers.",
                            "Status":  "FAILURE",
                            "TimeStamp":  "09/19/2025 16:50:00",
                            "Resource":  "NetworkAdapter",
                            "Source":  "AZLOC-NODE1, Network Adapters"
                        },
    "HealthCheckSource":  "Manual\\Standard\\Medium\\Network\\c826ddf1"
}
```

---

### Failure: `adapter [Not Found]`

**Error Message:**
```text
AZLOC-NODE1 (1/2 adapters passed): example-adapter [Not Found], ethernet 2 [Mellanox Technologies Ltd.]. No adapters should use inbox (Microsoft or Windows) drivers.
```

**Root Cause:** The specified network adapter does not exist on the system.

#### Remediation Steps

1) Check that the adapter exists

  ```powershell
  Get-NetAdapter -Name "example-adapter"
  ```

If the adapter is not found, ensure it has the correct name and is physically installed on the system.

### Failure: `adapter [Microsoft]`

#### Example
```text
AZLOC-NODE1 (1/2 adapters passed):  ethernet [Microsoft], ethernet 2 [Mellanox Technologies Ltd.]. No adapters should use inbox (Microsoft or Windows) drivers.
```

**Root Cause:** The Network Adapter is using an inbox driver, which is not supported by Azure Local.

#### Remediation Steps

1) Check with your hardware vendor to obtain the appropriate drivers for the Network Adapter. Download and install the drivers on the host. Note that the adapters in each Network Intent must use the same driver across all nodes.
