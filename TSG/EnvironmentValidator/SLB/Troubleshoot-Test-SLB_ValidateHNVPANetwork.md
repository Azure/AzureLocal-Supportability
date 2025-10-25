# Troubleshoot-Test-SLB_ValidateHNVPANetwork

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateHNVPANetwork</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Deployment</strong></td>
    </tr>
</table>

## Overview

The `Test-SLB_ValidateHNVPANetwork` function validates the Hyper-V Network Virtualization Provider Address (HNVPA) network configuration required for the Software Load Balancer (SLB) in Azure Local. It checks that the HNVPA network is defined, contains exactly one instance, and that each subnet within it has valid properties such as `AddressPrefix`, `VlanId`, `DefaultGateways`, and `IPPools`. The validator ensures:

- Each subnet's `AddressPrefix` is a valid IPv4 CIDR and does not overlap with others.
- `VlanId` is within the supported range (0–4095).
- `DefaultGateways` are present, valid, and within the subnet.
- Each IP pool's `StartIPAddress` and `EndIPAddress` are valid, in the subnet, and do not include default gateways.
- The total number of available IP addresses across all pools is at least double the number of hosts plus the number of MUXes.

If any property is missing, invalid, or duplicated, the function returns a failure result with details for remediation. Use this validator to proactively detect and resolve HNVPA network configuration issues before they impact SLB deployment or operation.

**Input:**  
The function expects two inputs:

1. **NetworksConfiguration**  
    A configuration object containing the network definitions for HNVPA, PublicVIP, and PrivateVIP. This object must follow the structure shown in the example configuration below, with all required properties for each subnet (`AddressPrefix`, `VlanId`, `DefaultGateways`, and `IPPools`).

2. **PowerShell Sessions**  
    An array of active PowerShell session objects (`PSSession`) to each target host in the environment. These sessions are used to query host state and validate network configuration remotely.

**Example Usage:**

```powershell
$networksConfig = Get-Content -Path "C:\path\to\networks.json" | ConvertFrom-Json
$sessions = New-PSSession -ComputerName $HostList
Test-SLB_ValidateHNVPANetwork -NetworksConfiguration $networksConfig -Sessions $sessions
```

---

## Example Configuration

This example describes the configuration for `HNVPA`, `Public VIP`, and `Private VIP` networks in Azure Local environments. Each section is outlined below:

```text
- Networks: The main object representing the network configuration.
    - HNVPA: Contains the HNVPA network definition.
        - Subnets: An array of subnet objects.
            - AddressPrefix: The subnet's address range in IPv4 CIDR format.
            - VlanId: The VLAN ID for the subnet (0-4095).
            - DefaultGateways: Array of default gateway IP addresses within the subnet.
            - IPPools: Array of IP pool objects for dynamic allocation.
                - StartIPAddress: Starting IP address for allocation.
                - EndIPAddress: Ending IP address for allocation.
    - PublicVIP: Placeholder for public-facing VIP network definitions.
    - PrivateVIP: Placeholder for internal VIP network definitions.
```

This example shows a portion of a Networks configuration that includes the `HNVPA` settings. It highlights the essential properties and structure you need to define for a network that uses `HNVPA`. Use this sample as a reference to ensure your configuration includes all required fields and follows the correct format.

```json
{
    "Networks": {
        "HNVPA": [
            {
                "Subnets": [
                    {
                        "AddressPrefix":  "<Address Prefix>",
                        "VlanId": <VlanId>,
                        "DefaultGateways": [
                           "<Default Gateways>"
                        ],
                        "IPPools": [
                            {
                                "StartIPAddress":  "<Start IP Address>",
                                "EndIPAddress":  "<End IP Address>"
                            },
                            {
                                "StartIPAddress":  "<Start IP Address>",
                                "EndIPAddress":  "<End IP Address>"
                            }
                        ]
                    }
                ]
            }
        ],
        "PublicVIP": [
            /* ... public VIP networks */
        ],
        "PrivateVIP": [
            /* ... private VIP networks */
        ]
    }
}
```

This sample configuration satisfies all HNVPA property validation checks, including valid address prefixes, VLAN IDs, default gateways, and IP pool definitions.

---
## Requirements

- Azure Local is deployed and operational.
- The `AzStackHci` PowerShell module is installed and imported.
- You have administrative privileges on the management system and all target hosts.
- The `Test-SLB_ValidateHNVPANetwork` function is available.
- All target hosts are online and reachable from the management system.
- You have permissions to query and modify nodes.
- The HNVPA network configuration is accessible and contains at least one subnet.
- Each subnet must specify `AddressPrefix`, `VlanId`, `DefaultGateways`, and `IPPools`.
- The total number of available IP addresses in all HNVPA IP pools must be at least double the number of hosts plus the number of MUXes.
- All IP addresses, VLAN IDs, and gateways must be valid and non-overlapping as per the validation logic.

## Troubleshooting Steps

### Review Environment Validator Output

- Execute the `Test-SLB_ValidateHNVPANetwork` validator and examine the returned result object.
- Identify any failure entries specifically associated with the HNVPA network validation.
- Review the output details to understand which configuration properties failed validation and why.
- Refer to the example output below to understand how issues are reported and what information to look for when troubleshooting.

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateHNVPANetwork",
    "DisplayName":  "Validate the Hyper-V Network Virtualization Provider Address (HNVPA) network configuration for the Software Load Balancer (SLB)",
    "Tags":  {},
    "Title":  "Validate the Hyper-V Network Virtualization Provider Address (HNVPA) network configuration for the Software Load Balancer (SLB)",
    "Status":  1,
    "Severity":  2,
    "Description":  "Execute comprehensive validation of HNVPA network configuration to ensure it meets the requirements for proper SLB deployment in Azure Local environments. This function is critical for validating the network infrastructure before deploying SLB components.",
    "Remediation":  "Need to update URL here",
    "TargetResourceID":  "Property name: DefaultGateways, value: x.x.x.x",
    "TargetResourceName":  "DefaultGateways",
    "TargetResourceType":  "HNVPA",
    "Timestamp":  "\/Date(1761004281844)\/",
    "AdditionalData":  {
                        "Detail":  "The property [DefaultGateways] [x.x.x.x] is not in the subnet [y.y.y.y/24]",
                        "Status":  "FAILURE",
                        "TimeStamp":  "10/20/2025 23:51:21",
                        "Resource":  "HNVPA",
                        "Source":  "Networks"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\073ad76b"
}
```

### Failure Results

Below are all possible failure return results from `Test-SLB_ValidateHNVPANetwork`. For each result, example detail messages from the `AdditionalData` field are provided, along with recommended remediation steps to resolve the issue.

---

#### Failure: HNVPA Network Not Defined

**Description:**

The validator did not find the `HNVPA` property in the supplied configuration.

**Additional Data Example:**

```text
Detail    : No HNVPA network found in configuration. Please ensure HNVPA network is defined.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Ensure the `HNVPA` network is present.

---

#### Failure: Multiple HNVPA Networks Defined

**Description:**  
The configuration contains multiple `HNVPA` network objects, but only one is supported.

**Additional Data Example:**

```text
Detail    : Multiple HNVPA networks found in ECE NetworksConfiguration. Please ensure only one HNVPA network is defined.
Status    : FAILURE
TimeStamp : 2025-06-01T15:56:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Remove additional HNVPA network objects so only one remains in the configuration.

---

#### Failure: No Subnets Defined in HNVPA

**Description:**  
The `Subnets` property is missing or empty in the HNVPA configuration.

**Additional Data Example:**

```text
Detail    : [HNVPA] network does not have a valid [Subnets] defined. Please ensure a valid [Subnets] is configured for the [HNVPA] network.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Add at least one valid subnet to the `Subnets` array in the HNVPA configuration.

---

#### Failure: Missing AddressPrefix in Subnet

**Description:**  
A subnet in the HNVPA network is missing the required `AddressPrefix` property.

**Additional Data Example:**

```text
Detail    : [HNVPA] network does not have a valid [AddressPrefix] defined. Please ensure a valid [AddressPrefix] is configured for the [HNVPA] network.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Add a valid `AddressPrefix` (in IPv4 CIDR format, e.g., `x.x.x.x/24`) to each subnet in the HNVPA configuration.

---

#### Failure: Invalid AddressPrefix format

**Description:**  
The subnet does not specify a valid IPv4 CIDR for `AddressPrefix`.

**Additional Data Example:**

```text
Detail    : The property [AddressPrefix] on the [HNVPA] network has an invalid format. Please verify the value matches the required format and try again.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Specify a valid IPv4 CIDR (e.g., `x.x.x.x/24`) for each subnet's `AddressPrefix`.

---

#### Failure: Invalid or Missing VlanId

**Description:**  
The subnet does not specify a VLAN ID, or the value is outside the supported range (0–4095).

**Additional Data Example:**

```text
Detail    : [HNVPA] network does not have a valid [VlanId] defined. Please ensure a valid [VlanId] is configured for the [HNVPA] network.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Specify a valid integer value for `VlanId` between 0 and 4095 for each subnet.

---

#### Failure: Missing or Invalid IPPools

**Description:**  
The subnet does not define any IP pools, or the pool definitions are invalid.

**Additional Data Example:**

```text
Detail    : [HNVPA] network does not have a valid [IPPools] defined. Please ensure a valid [IPPools] is configured for the [HNVPA] network.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Define at least one valid IP pool for each subnet, specifying both `StartIPAddress` and `EndIPAddress`.

---

#### Failure: Missing DefaultGateways

**Description:**  
No default gateways are defined for the subnet. The `DefaultGateways` property is either missing or contains no entries.

**Additional Data Example:**

```text
Detail    : [HNVPA] network does not have a valid [DefaultGateways] defined. Please ensure a valid [DefaultGateways] is configured for the [HNVPA] network.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Add at least one valid IPv4 address to the `DefaultGateways` array in every subnet configuration.

---

#### Failure: Invalid DefaultGateways Format

**Description:**  
The `DefaultGateways` property contains values that are not valid IPv4 addresses.

**Additional Data Example:**

```text
Detail    : The property [DefaultGateways] on the [HNVPA] network has an invalid format. Please verify the value matches the required format and try again.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Ensure each subnet's `DefaultGateways` array includes at least one valid IPv4 address (e.g., `x.x.x.x`), and that all entries are properly formatted.

---

#### Failure: DefaultGateway Not in Subnet

**Description:**  
One or more default gateways are not part of the subnet's address range.

**Additional Data Example:**

```text
Detail    : The property [DefaultGateways] [x.x.x.x] is not in the subnet [y.y.y.y/24].
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Ensure all default gateways are valid IP addresses within the subnet's `AddressPrefix`.

---

#### Failure: IP Pool Start/End IP address Not in Subnet

**Description:**  
The `StartIPAddress` or `EndIPAddress` of an IP pool is not in the subnet's address range.

**Additional Data Example:**

```text
Detail    : The property [EndIPAddress] [x.x.x.x] is not in the subnet [y.y.y.y/24]
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Ensure all IP pool addresses are within the subnet's `AddressPrefix`.

---

#### Failure: IP Pool Start IP address Greater Than or Equal to End

**Description:**  
The `StartIPAddress` in an IP pool is greater than or equal to the `EndIPAddress`, which is invalid.

**Additional Data Example:**

```text
Detail    : The property [IPPools] on the [HNVPA] network has an invalid format. Start IP address [x.x.x.x]  is bigger than End IP address [y.y.y.y].
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Update the IP pool so that `StartIPAddress` is less than `EndIPAddress` for each pool.

---

#### Failure: DefaultGateway Included in IP Pool

**Description:**  
One or more default gateways are part of an IP pool, which is not allowed.

**Additional Data Example:**

```text
Detail    : DefaultGateway x.x.x.x is included in IP pool [x.x.x.x, y.y.y.y].
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Adjust the IP pool ranges to exclude all default gateway addresses.

---

#### Failure: Overlapping Address Prefixes

**Description:**  
Two or more subnets have overlapping `AddressPrefix` ranges.

**Additional Data Example:**

```text
[AddressPrefix] [x.x.x.x/24] has overlapping with [AddressPrefix] [y.y.y.y/25]. Please ensure address prefix do not overlap.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Ensure all subnet `AddressPrefix` values are unique and do not overlap.

---

#### Failure: Not Enough Available IPs in IP Pools

**Description:**  
The sum of all available IPs in the HNVPA IP pools is less than double the number of hosts plus the number of MUXes.

**Additional Data Example:**

```text
Detail    : HNVPA network has [5] available IPs but requires minimum [6] IP addresses (2 * 2 hosts + 2 muxes)
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : HNVPA
Source    : Networks
```

**Remediation Steps:**  
Increase the size or number of IP pools so the total available IPs meet or exceed the required count.

---
