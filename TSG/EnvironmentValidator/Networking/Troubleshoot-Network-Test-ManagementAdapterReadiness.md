# AzureLocal_Network_Test_ManagementAdapterReadiness
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
  <tr>
    <th style="text-align:left; width: 180px;">Name</th>
    <td><strong>AzureLocal_Network_Test_ManagementAdapterReadiness</strong></td>
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

This validator fails if the management adapters (the adapters assigned to the Management Network Intent) are not configured properly. The management adapter must have a valid IP address configured so that the node can communicate with other nodes during the deployment process.

## Requirements

At least one adapter assigned to the Management Network Intent must meet the following requirements:
1. Have a valid IP Configuration
2. Have a valid default gateway configured
3. Have a valid DNS server configured
4. If this is a DHCP deployment, the adapter must be configured to use DHCP, otherwise it must have a static IP configuration.

If any management adapter is part of a VM Switch then the following requirement also applies:
1. All management adapters must be part of the VM Switch
2. A management adapter named `vManagement(intentName)` must exist and meet the requirements above.

See [Azure Local - Host Network Requirements](https://docs.azure.cn/en-us/azure-local/concepts/host-network-requirements#driver-requirements) for more details.

## Troubleshooting Steps

### Review Environment Validator Output

Review the Environment Validator output JSON. Check the `AdditionalData.Detail` field for summary of which Management Adapters are not configured properly. You can identify the host by the `TargetResourceID` field, the format is `NodeName`.

Note that this validator may report multiple failures in the `Detail` field. Each failure is numbered and described below.

```json
{
    "Name":  "AzureLocal_Network_Test_ManagementAdapterReadiness",
    "DisplayName":  "Validate that at least one Management Adapter has a valid IP Configuration, DNS Server, and Gateway",
    "Tags":  {},
    "Title":  "Validate that at least one Management Adapter has a valid IP Configuration, DNS Server, and Gateway",
    "Status":  1,
    "Severity":  2,
    "Description":  "Each node must have a management adapter with a valid IP Configuration, DNS Server, and Gateway. If this is a DHCP deployment, the management adapter must have a DHCP address. If the adapter is teamed with a VMSwitch, that VMSwitch must have all adapters defined in the management intent and no others.",
    "Remediation":  "https://aka.ms/azurelocal/envvalidator/ManagementAdapterReadiness",
    "TargetResourceID":  "AZLOC-NODE1",
    "TargetResourceName":  "AZLOC-NODE1",
    "TargetResourceType":  "ManagementAdapter",
    "Timestamp":  "\/Date(1758302302961)\/",
    "AdditionalData":  {
                            "Detail":  "1) [PASS] Adapter [non existent adapter] does not have any IPs configured with expected PrefixOrigin [Manual] or unexpected PrefixOrigin [Dhcp], Adapter [ethernet 2] does not have any IPs configured with expected PrefixOrigin [Manual] or unexpected PrefixOrigin [Dhcp]. 2) [FAIL] First management adapter [non existent adapter] does not have an IP Configuration, at least one IP Configuration is expected. 3) [FAIL] First management adapter [non existent adapter] has [0] DNS Client Servers configured, but expected [1+].",
                            "Status":  "FAILURE",
                            "TimeStamp":  "09/19/2025 17:18:22",
                            "Resource":  "ManagementAdapter",
                            "Source":  "AZLOC-NODE1"
                        },
    "HealthCheckSource":  "Manual\\Standard\\Medium\\Network\\c9897dea"
}
```

---

### Failure: `[FAIL] Adapter [AdapterName] has invalid IP(s): [ip 1] with PrefixOrigin [Dhcp], Adapter [AdapterName 2] has valid IP(s): [ip 2] with PrefixOrigin [Manual].`

**Error Message:**
```text
[FAIL] Adapter [AdapterName] has invalid IP(s): [ip 1] with PrefixOrigin [Dhcp], Adapter [AdapterName 2] has valid IP(s): [ip 2] with PrefixOrigin [Manual].
```

**Root Cause:** One of the management adapters listed does not have a valid IP configuration. If this is a DHCP deployment, the prefix origin must be `Dhcp`. Otherwise, the prefix origin must be `Manual`.

#### Remediation Steps

1) Check the IP configuration of the management adapters

  ```powershell
  Get-NetAdapter -Name "ethernet","ethernet 2" | Get-NetIPConfiguration
  ```

2) If this is a DHCP deployment, ensure that both Network Adapters are configured to use DHCP. If this is a static IP deployment, ensure that at least one of the Network Adapters has a valid static IP configuration.

### Failure: `[FAIL] First management adapter [AdapterName] does not have an IP Configuration, at least one IP Configuration is expected.`

**Error Message:**
```text
[FAIL] First management adapter [AdapterName] does not have an IP Configuration, at least one IP Configuration is expected.
```

**Root Cause:** The first management adapter supplied must have a valid IP Configuration. This IP address will be used for communication between nodes during deployment.

#### Remediation Steps

1) Check that the adapter exists

  ```powershell
  Get-NetAdapter -Name "AdapterName"
  ```

2) Create an IP Configuration on the adapter, refer to [Configure the Operating System using sconfig](https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-install-os?#configure-the-operating-system-using-sconfig) for more details.

  ```powershell
  # Example for static IP configuration
  $AdapterName = "AdapterName"
  $IPAddress = "IP_Address"
  $PrefixLength = "Prefix_Length"
  $DefaultGateway = "Default_Gateway"
  $DNSServers = @("DNS_Server1") # IMPORTANT! Azure Local does not support modifying DNS Server settings post-deployment.
  
  Get-NetAdapter -Name $AdapterName

  New-NetIPAddress -InterfaceAlias "AdapterName" -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
  Set-DnsClientServerAddress -InterfaceAlias "AdapterName" -ServerAddresses $DNSServers
  ```

### Failure: `[FAIL] First management adapter [AdapterName] has [0] DNS Client Servers configured, but expected [1+].`

**Error Message:**
```text
[FAIL] First management adapter [AdapterName] has [0] DNS Client Servers configured, but expected [1+].
```

**Root Cause:** The first management adapter must have at least one DNS server configured.

<div style="border-left: 4px solid #28a745; padding: 15px; margin: 20px 0; background: rgba(40, 167, 69, 0.1); border-radius: 6px;">
  <strong>⚠️ Important:</strong> Azure Local does not support modifying the DNS Server settings post-deployment. See <a href="https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations?#dns-server-considerations">DNS Server Considerations</a>
</div>

#### Remediation Steps

1) Check the DNS configuration of the management adapter

  ```powershell
  Get-NetAdapter -Name "AdapterName" | Get-DnsClientServerAddress
  ```

2) Configure at least one DNS server on the adapter

  ```powershell
  Set-DnsClientServerAddress -InterfaceAlias "AdapterName" -ServerAddresses @("DNS_Server1")
  ```

---

<div
  style="border-left: 4px solid #0366d6; padding: 15px; margin: 20px 0; background: rgba(3, 102, 214, 0.1); border-radius: 6px;"
>
  <strong>📘 Note:</strong> The VMSwitch requirements below only apply to clusters where the Virtual Switch needs to be created before deployment. This is optional and will not apply to most clusters. For more details, see  <a href="https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations?#2-configure-management-virtual-network-adapter-using-required-network-atc-naming-convention-for-all-nodes">Management VLAN ID with a virtual switch</a>
</div>

### [FAIL] VMSwitch [ManagementSwitch] uses physical adapter [AdapterGuid] defined in the management intent, but it does not use all physical adapters defined in the management intent.

**Error Message:**
```text
[FAIL] VMSwitch [ManagementSwitch] uses physical adapter [AdapterGuid] defined in the management intent, but it does not use all physical adapters defined in the management intent.
```

**Root Cause:** If a VM Switch has a management adapter assigned to it, then all management adapters must be part of the VM Switch. This is an **OPTIONAL** requirement and may not apply to your deployment. For more details, see [Management VLAN ID with a Virtual Switch](https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations?#management-vlan-id-with-a-virtual-switch)

#### Remediation Steps

1) Check the VM Switch configuration

  ```powershell
  Get-VMSwitch "ManagementSwitch" | Select-Object -ExpandProperty NetAdapterInterfaceGuid
  Get-NetAdapter | Select-Object Name, InterfaceGuid
  ```

2) Ensure that all management adapters are part of the VM Switch. If not, add the missing adapters to the VM Switch.

  ```powershell
  Add-VMSwitchTeamMember -SwitchName "ManagementSwitch" -NetAdapterName "AdapterName"
  ```

### [FAIL] Found VMSwitch [ManagementSwitch] that uses all physical adapters defined in the management intent. Expected 1 VMNetworkAdapter [vManagement(ManagementIntentName)] but found 0. Found 1 NetAdapter [vManagement(ManagementIntentName)] configured.

**Error Message:**
```text
[FAIL] Found VMSwitch [ManagementSwitch] that uses all physical adapters defined in the management intent. Expected 1 VMNetworkAdapter [vManagement(ManagementIntentName)] but found 0. Found 1 NetAdapter [vManagement(ManagementIntentName)] configured.
```

**Root Cause:** If a VM Switch with both management adapters is defined, then a virtual management adapter named `vManagement(ManagementIntentName)` must exist and be configured properly. This `vManagement(ManagementIntentName)` adapter will be used for management traffic. For more details on configuring this adapter see [Configure management virtual network adapter using required Network ATC naming convention for all nodes](https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations?#2-configure-management-virtual-network-adapter-using-required-network-atc-naming-convention-for-all-nodes)

#### Remediation Steps

See [Configure management virtual network adapter using required Network ATC naming convention for all nodes](https://learn.microsoft.com/en-us/azure/azure-local/plan/cloud-deployment-network-considerations?#2-configure-management-virtual-network-adapter-using-required-network-atc-naming-convention-for-all-nodes) for more details.
