# AzureLocal_Network_Test_NetworkDefaultGatewayRequirement
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_NetworkDefaultGatewayRequirement</strong></td>
  </tr>
  <tr>
    <th style="text-align:left; width: 180px;">Severity</th>
    <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
  </tr>
  <tr>
    <th style="text-align:left;">Applicable Scenarios</th>
    <td>
      <ul style="margin:0; padding-left:1.2em;">
        <li><strong>Deployment</strong></li>
        <li><strong>Add-Server</strong></li>
      </ul>
    </td>
  </tr>
</table>

## Overview

This environment validator checks that there is only one default gateway defined on each server in the system.

## Requirements

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData` field for summary of which server's default gateway are not configured properly. You can identify the host by the `TargetResourceID` field, the format is `MachineName, NetworkDefaultGateway`.

```json
{
    "Name":  "AzureLocal_Network_Test_NetworkDefaultGatewayRequirement",
    "DisplayName":  "Validate that only one default gateway is defined on the server",
    "Tags":  {},
    "Title":  "Validate that only one default gateway is defined on the server",
    "Status":  1,
    "Severity":  2,
    "Description":  "Each node must have a single default gateway configured.",
    "Remediation":  "https://aka.ms/azurelocal/envvalidator/networkgatewayrequirement",
    "TargetResourceID":  "AZLOC-NODE1, NetworkDefaultGateway",
    "TargetResourceName":  "AZLOC-NODE1, NetworkDefaultGateway",
    "TargetResourceType":  "NetworkDefaultGateway",
    "Timestamp":  "\/Date(1758300600191)\/",
    "AdditionalData":  {
                            "Detail":  "Multiple default gateways found on AZLOC-NODE1: 192.168.2.1, 200.121.1.1. There should be only one default gateway defined on the server. Please run below PowerShell cmdlet to verify the default gateway configuration on the machine:     Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 If you find multiple different gateway defined for the NextHop property from the above cmdlet call, please remove the one that you do not need from the system.     Remove-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop <GATEWAY_IP_YOU_DO_NOT_NEED> -Confirm:$false",
                            "Status":  "FAILURE",
                            "TimeStamp":  "09/19/2025 16:50:00",
                            "Resource":  "NetworkDefaultGateway",
                            "Source":  "AZLOC-NODE1"
                        },
    "HealthCheckSource":  "Manual\\Standard\\Medium\\Network\\c826ddf1"
}
```

---

### Failure: `Multiple default gateways found on MACHINENAME`

**Error Message:**
```text
Multiple default gateways found on MACHINENAME: 192.168.2.1, 200.121.1.1.
```

**Root Cause:** The validator found multiple default gateways defined in the system.

#### Remediation Steps

1) Check the default gateway configured in the system by looking at route table for "DestinationPrefix" of "0.0.0.0/0"

  ```powershell
  Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4
  ```

The above might return multiple entries. We need to clean the route table so it only contains 1 default entry to "0.0.0.0/0":
```powershell
Remove-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop <GATEWAY_IP_YOU_DO_NOT_NEED> -Confirm:$false
```

### Failure: `No default gateway defined on any adapter(s) on MACHINENAME`

**Error Message:**
```text
No default gateway defined on any adapter(s) on MACHINENAME.
```

**Root Cause:** The validator cannot find a valid default gateway defined in the system.

#### Remediation Steps

1) Check the default gateway configured in the system by looking at route table for "DestinationPrefix" of "0.0.0.0/0"

  ```powershell
  Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4
  ```

It might not have any information returned. You need to make sure your route table contains at least 1 default gateway for your management subnet.
Below is an example on how to add a new route in your system's route table. Please adjust based on your network requirement.
```powershell
New-NetRoute -DestinationPrefix "0.0.0.0/0" -InterfaceAlias <MGMT_ADAPTER_ALIAS> -AddressFamily IPv4 -NextHop <GATEWAY_IP_YOU_DO_NOT_NEED>
```
