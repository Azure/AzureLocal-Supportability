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
The `Test-SLB_ValidateHNVPANetwork` function validates the Hyper-V Network Virtualization Provider Address (HNVPA) network configuration required for the Software Load Balancer (SLB) in Azure Stack HCI. It checks that the HNVPA network is defined, contains exactly one instance, and that each subnet within it has valid properties such as `AddressPrefix`, `VlanId`, `DefaultGateways`, and `IPPools`. The validator ensures:

- Each subnet's `AddressPrefix` is a valid IPv4 CIDR and does not overlap with others.
- `VlanId` is within the supported range (0–4095).
- `DefaultGateways` are present, valid, and within the subnet.
- Each IP pool's `StartIPAddress` and `EndIPAddress` are valid, in the subnet, and do not include default gateways.
- The total number of available IP addresses across all pools is at least double the number of hosts plus the number of MUXes.

If any property is missing, invalid, or duplicated, the function returns a failure result with details for remediation. Use this validator to proactively detect and resolve HNVPA network configuration issues before they impact SLB deployment or operation.

---

## Example Configuration

Below is an example of a valid `SoftwareLoadBalancer` configuration object:

```json
{
    "HNVPA": [
        {
            "Subnets": [
                {
                    "AddressPrefix": "100.71.149.0/24",
                    "VlanId": 6,
                    "DefaultGateways": [
                        "100.71.149.1", "100.71.149.2"
                    ],
                    "IPPools": [
                        {
                            "StartIPAddress": "100.71.149.125",
                            "EndIPAddress": "100.71.149.127"
                        },
                        {
                            "StartIPAddress": "100.71.149.135",
                            "EndIPAddress": "100.71.149.137"
                        }
                    ]
                },
                {
                    "AddressPrefix": "100.71.148.0/24",
                    "VlanId": 6,
                    "DefaultGateways": [
                        "100.71.148.1"
                    ],
                    "IPPools": [
                        {
                            "StartIPAddress": "100.71.148.125",
                            "EndIPAddress": "100.71.148.127"
                        }
                    ]
                }
            ]
        }
    ]
}
```

This configuration meets all validation requirements for SLB and BGP properties.

---
## Requirements

- Azure Stack HCI is deployed and operational.
- The `AzStackHci` PowerShell module is installed and imported.
- You have administrative privileges on the management system and all target hosts.
- The `Test-SLB_ValidateHNVPANetwork` function is available.
- All target hosts are online and reachable from the management system.
- You have permissions to query and modify SLB nodes and Multiplexer (MUX) instances.
- The HNVPA network configuration is accessible and contains at least one subnet.
- Each subnet must specify `AddressPrefix`, `VlanId`, `DefaultGateways`, and `IPPools`.
- The total number of available IP addresses in all HNVPA IP pools must be at least double the number of hosts plus the number of MUXes.
- All IP addresses, VLAN IDs, and gateways must be valid and non-overlapping as per the validation logic.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object:
- Look for failures related to `Test-SLB_ValidateSoftwareLoadBalancer`.
- Example output:

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
    "TargetResourceID":  "Property name: DefaultGateways, value: 192.168.100.1",
    "TargetResourceName":  "DefaultGateways",
    "TargetResourceType":  "HNVPA",
    "Timestamp":  "\/Date(1761004281844)\/",
    "AdditionalData":  {
                        "Detail":  "\"The property \u0027DefaultGateways\u0027 \u0027192.168.100.1\u0027 is not in the subnet \u0027192.168.200.0/24\u0027\"",
                        "Status":  "FAILURE",
                        "TimeStamp":  "10/20/2025 23:51:21",
                        "Resource":  "HNVPA",
                        "Source":  "Networks"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\073ad76b"
}
```

## Failure Return Results

Below are all possible failure return results from `$SLBResultObject`, including example messages and recommended remediation steps.

### Failure and Warning Results

#### 1. HNVPA Network Not Defined
- **Failure:** HNVPA network configuration is missing.
- **Description:** The validator did not find the `HNVPA` property in the supplied configuration.  
    **Error Message:** `HNVPA network not found in configuration.`
- **Example Failure:**  
    ```
    HNVPA network not found in configuration.
    ```
- **Remediation Steps:**  
    Ensure the configuration object contains a valid `HNVPA` property with at least one subnet defined.

---

#### 2. Multiple HNVPA Networks Defined
- **Failure:** More than one HNVPA network instance found.
- **Description:** The configuration contains multiple `HNVPA` network objects, but only one is supported.  
    **Error Message:** `Multiple HNVPA networks found. Only one is supported.`
- **Example Failure:**  
    ```
    Multiple HNVPA networks found. Only one is supported.
    ```
- **Remediation Steps:**  
    Remove additional HNVPA network objects so only one remains in the configuration.

---

#### 3. No Subnets Defined in HNVPA
- **Failure:** No subnets defined for HNVPA network.
- **Description:** The `Subnets` property is missing or empty in the HNVPA configuration.  
    **Error Message:** `HNVPA network is missing required property: Subnets.`
- **Example Failure:**  
    ```
    HNVPA network is missing required property: Subnets.
    ```
- **Remediation Steps:**  
    Add at least one valid subnet to the `Subnets` array in the HNVPA configuration.

---

#### 4. Missing or Invalid AddressPrefix
- **Failure:** Subnet is missing or has an invalid `AddressPrefix`.
- **Description:** The subnet does not specify a valid IPv4 CIDR for `AddressPrefix`.  
    **Error Message:** `HNVPA subnet is missing required property: AddressPrefix.`  
    or  
    `AddressPrefix for HNVPA subnet is not a valid IPv4 CIDR.`
- **Example Failure:**  
    ```
    HNVPA subnet is missing required property: AddressPrefix.
    ```
    or
    ```
    AddressPrefix for HNVPA subnet is not a valid IPv4 CIDR.
    ```
- **Remediation Steps:**  
    Specify a valid IPv4 CIDR (e.g., `100.71.149.0/24`) for each subnet's `AddressPrefix`.

---

#### 5. Invalid or Missing VlanId
- **Failure:** Subnet is missing or has an invalid `VlanId`.
- **Description:** The subnet does not specify a VLAN ID, or the value is outside the supported range (0–4095).  
    **Error Message:** `HNVPA subnet is missing required property: VlanId.`
- **Example Failure:**  
    ```
    HNVPA subnet is missing required property: VlanId.
    ```
- **Remediation Steps:**  
    Specify a valid integer value for `VlanId` between 0 and 4095 for each subnet.

---

#### 6. Missing or Invalid IPPools
- **Failure:** Subnet is missing or has invalid `IPPools`.
- **Description:** The subnet does not define any IP pools, or the pool definitions are invalid.  
    **Error Message:** `HNVPA subnet is missing required property: IPPools.`
- **Example Failure:**  
    ```
    HNVPA subnet is missing required property: IPPools.
    ```
- **Remediation Steps:**  
    Define at least one valid IP pool for each subnet, specifying both `StartIPAddress` and `EndIPAddress`.

---

#### 7. Missing or Invalid DefaultGateways
- **Failure:** Subnet is missing or has invalid `DefaultGateways`.
- **Description:** The subnet does not define any default gateways, or the gateways are not valid IP addresses.  
    **Error Message:** `HNVPA subnet is missing required property: DefaultGateways.`
- **Example Failure:**  
    ```
    HNVPA subnet is missing required property: DefaultGateways.
    ```
- **Remediation Steps:**  
    Specify at least one valid IPv4 address in the `DefaultGateways` array for each subnet.

---

#### 8. DefaultGateway Not in Subnet
- **Failure:** Default gateway is not within the subnet's address prefix.
- **Description:** One or more default gateways are not part of the subnet's address range.  
    **Error Message:** `DefaultGateways value 100.71.149.254 is not in subnet 100.71.149.0/24.`
- **Example Failure:**  
    ```
    DefaultGateways value 100.71.149.254 is not in subnet 100.71.148.0/24.
    ```
- **Remediation Steps:**  
    Ensure all default gateways are valid IP addresses within the subnet's `AddressPrefix`.

---

#### 9. IP Pool Start/End Not in Subnet
- **Failure:** IP pool start or end address is not within the subnet.
- **Description:** The `StartIPAddress` or `EndIPAddress` of an IP pool is not in the subnet's address range.  
    **Error Message:** `StartIPAddress 100.71.150.10 not in 100.71.149.0/24.`
- **Example Failure:**  
    ```
    StartIPAddress 100.71.150.10 not in 100.71.149.0/24.
    ```
- **Remediation Steps:**  
    Ensure all IP pool addresses are within the subnet's `AddressPrefix`.

---

#### 10. IP Pool Start Greater Than or Equal to End
- **Failure:** IP pool start address is greater than or equal to end address.
- **Description:** The `StartIPAddress` must be less than the `EndIPAddress` in each pool.  
    **Error Message:** `StartIPAddress >= EndIPAddress for IPPools in HNVPA.`
- **Example Failure:**  
    ```
    StartIPAddress >= EndIPAddress for IPPools in HNVPA: 100.71.149.130 >= 100.71.149.129
    ```
- **Remediation Steps:**  
    Correct the IP pool so that `StartIPAddress` is less than `EndIPAddress`.

---

#### 11. DefaultGateway Included in IP Pool
- **Failure:** Default gateway address is included in an IP pool range.
- **Description:** One or more default gateways are part of an IP pool, which is not allowed.  
    **Error Message:** `DefaultGateway 100.71.149.1 is included in IP pool [100.71.149.1, 100.71.149.10].`
- **Example Failure:**  
    ```
    DefaultGateway 100.71.149.1 is included in IP pool [100.71.149.1, 100.71.149.10].
    ```
- **Remediation Steps:**  
    Adjust the IP pool ranges to exclude all default gateway addresses.

---

#### 12. Overlapping Address Prefixes
- **Failure:** Subnet address prefixes overlap.
- **Description:** Two or more subnets have overlapping `AddressPrefix` ranges.  
    **Error Message:** `AddressPrefix 100.71.149.0/24 overlaps with 100.71.149.0/25.`
- **Example Failure:**  
    ```
    AddressPrefix 100.71.149.0/24 overlaps with 100.71.149.0/25.
    ```
- **Remediation Steps:**  
    Ensure all subnet `AddressPrefix` values are unique and do not overlap.

---

#### 13. Not Enough Available IPs in IP Pools
- **Failure:** Total available IP addresses in all IP pools is less than required.
- **Description:** The sum of all available IPs in the HNVPA IP pools is less than double the number of hosts plus the number of MUXes.  
    **Error Message:** `Not enough available IPs in HNVPA IPPools. Available: 5, Required: 7 (Hosts: 3, MUXes: 1).`
- **Example Failure:**  
    ```
    Not enough available IPs in HNVPA IPPools. Available: 5, Required: 7 (Hosts: 3, MUXes: 1).
    ```
- **Remediation Steps:**  
    Increase the size or number of IP pools so the total available IPs meet or exceed the required count.

---