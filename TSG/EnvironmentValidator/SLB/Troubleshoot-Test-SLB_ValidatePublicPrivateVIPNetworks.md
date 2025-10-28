# Troubleshoot-Test-SLB_ValidatePublicPrivateVIPNetworks

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLB_ValidatePublicPrivateVIPNetworks</strong></td>
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

This function validates the configuration of public and private Virtual IP (VIP) networks in your Azure Local environment. It checks that all required properties for each VIP network—such as subnets, address prefixes, VLAN IDs, and IP pools—are present and correctly formatted. The function ensures that public VIP networks are always defined (mandatory), while private VIP networks are optional but validated if present.

## Example Configuration

This example describes the configuration for HNVPA, Public VIP, and Private VIP networks in Azure Local environments. Here’s a breakdown of each part:

```text
- HNVPA: Placeholder for HNVPA network definitions.
- PublicVIP: The main object representing public VIP network configuration.
    - Name: The name of the public VIP network.
    - Subnets: An array of subnet objects.
        - AddressPrefix: The subnet's address range in IPv4 CIDR format.
        - VlanId: The VLAN ID for the subnet (0-4095).
        - IPPools: Array of IP pool objects for dynamic allocation.
            - StartIPAddress: Starting IP address for allocation.
            - EndIPAddress: Ending IP address for allocation.
- PrivateVIP: The main object representing private VIP network configuration.
    - Name: The name of the private VIP network.
    - Subnets: An array of subnet objects.
        - AddressPrefix: The subnet's address range in IPv4 CIDR format.
        - VlanId: The VLAN ID for the subnet (0-4095).
        - IPPools: Array of IP pool objects for dynamic allocation.
            - StartIPAddress: Starting IP address for allocation.
            - EndIPAddress: Ending IP address for allocation.
```

Below is an example of a partial `Networks` configuration, including both public and private VIP networks. This sample demonstrates the required properties and structure for each VIP type.

```json
{
    "HNVPA": [ /* HNVPA networks */ ],
    "PublicVIP": [
        {
            "Name": "PublicVIPNetwork1",
            "Subnets": [
                {
                    "AddressPrefix":  "<Address Prefix>",
                    "VlanId": <VlanId>,
                    "IPPools": [
                        {
                            "StartIPAddress":  "<Start IP Address>",
                            "EndIPAddress":  "<End IP Address>"
                        }
                    ]
                }
            ]
        }
        /* Additional public VIP networks */
    ],
    "PrivateVIP": [
        {
            "Name": "PrivateVIPNetwork1",
            "Subnets": [
                "AddressPrefix": "<AddressPrefix>",
                "VlanId": <VlanId>,
                "IPPools": [
                    {
                        "StartIPAddress": "<Start IP Address>",
                        "EndIPAddress": "<EndIPAddress>"
                    }
                ]
            ]
        }
        /* Additional private VIP networks */
    ]
}
```

> **Note:**
>
> - **Public VIP networks are required; private VIP networks are optional.**
> - Ensure all properties (`AddressPrefix`, `VlanId`, `IPPools`) are present and correctly formatted for each subnet.
>

Maintaining valid VIP network definitions is critical for proper load balancing, network segmentation, and high availability. Misconfiguration may result in validation failures, reduced redundancy, or service disruption.

## Requirements

To use this validator, ensure the following prerequisites:

- An Azure Local environment is deployed and accessible.
- The PowerShell module `AzStackHci` is installed and imported.
- You have sufficient permissions to query and modify nodes.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and capture the result object.
- Filter the results for the `Test-SLB_ValidatePublicPrivateVIPNetworks` entry (by Name or DisplayName).
- Inspect the Status and the `AdditionalData` section — especially `AdditionalData.Detail` — it contains the precise validation failure (e.g., malformed fields, IP order, or missing properties).
- Use `AdditionalData.Resource` and `AdditionalData.Status` to identify the affected VIP type and the severity, then apply the appropriate remediation and re-run the validator.
- Refer to the example output below to understand how issues are reported and what information to look for when troubleshooting.

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidatePublicPrivateVIPNetworks",
    "DisplayName":  "Check public and private Virtual IP (VIP) addresses",
    "Tags":  {},
    "Title":  "Check public and private Virtual IP (VIP) addresses",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if we have valid public and/or private VIP addresses",
    "Remediation":  "Please check public and/or private VIP addresses",
    "TargetResourceID":  "Property name: IPPools, value: x.x.x.x \u003e= y.y.y.y",
    "TargetResourceName":  "IPPools",
    "TargetResourceType":  "PrivateVIP",
    "Timestamp":  "\/Date(1761012664074)\/",
    "AdditionalData":  {
                            "Detail":  "\"The property [IPPools] on the [PrivateVIP] network has an invalid format. Start IP address [x.x.x.x]  is bigger than End IP address [y.y.y.y].\"",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 02:11:04",
                            "Resource":  "PrivateVIP",
                            "Source":  "Networks"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\22e52eb5"
}
```

### Failure Results

Below are the enumerated failure (and warning) result types that `Test-SLB_ValidatePublicPrivateVIPNetworks` can return. Each entry includes:

- What failed (mapped to AdditionalData.Resource and TargetResourceType)
- Example snippet resembling AdditionalData.Detail messaging
- Focused remediation actions you should apply before re-running the validator

Use AdditionalData.Detail first for the precise parsing error or invalid value, then confirm context with TargetResourceName / TargetResourceType and Status before making changes.

#### 1. Failure: No Public VIP Networks Found

**Description:**  
The validator did not find any public VIP networks in the configuration. Public VIP networks are mandatory for proper SLB operation.

**Example Failure:**

```text
Status: Failure
Message: No Public VIP networks found in configuration.
Name: <NULL>
ID: <NULL>
Type: PublicVIP
```

**Remediation Steps:**

- Ensure at least one public VIP network is defined in your `$NetworksConfiguration`.
- Verify the `PublicVIP` array is present and contains valid network objects.

---

#### 2. Failure: Missing or Invalid Subnet Properties

**Description:**  
A required subnet property (such as `AddressPrefix`, `VlanId`, or `IPPools`) is missing or invalid in a VIP network.

**Example Failure:**

```text
Status: Failure
Message: PublicVIP network is missing required property: AddressPrefix
Name: AddressPrefix
ID: <NULL>
Type: PublicVIP
```

**Remediation Steps:**

- Check that each subnet in every VIP network includes valid `AddressPrefix`, `VlanId`, and `IPPools`.
- Correct any missing or malformed properties.

---

#### 3. Failure: Invalid AddressPrefix Format

**Description:**
The `AddressPrefix` property does not match the expected CIDR notation (e.g., `x.x.x.x/24`).

**Example Failure:**

```text
Status: Failure
Message: Invalid format for AddressPrefix in PublicVIP: x.x.x.x-24
Name: AddressPrefix
ID: x.x.x.x-24
Type: PublicVIP
```

**Remediation Steps:**

- Use standard CIDR notation for all `AddressPrefix` values (e.g., `x.x.x.x/24`).
- Correct any typos or formatting errors.

---

#### 4. Failure: Invalid or Missing VlanId

**Description:**  
The `VlanId` property is missing, not an integer, or outside the valid range (0–4095).

**Example Failure:**

```text
Status: Failure
Message: PublicVIP network is missing required property: VlanId
Name: VlanId
ID: <NULL>
Type: PublicVIP
```

**Remediation Steps:**

- Ensure `VlanId` is specified as an integer between 0 and 4095 for each subnet.

---

#### 5. Failure: Missing or Empty IPPools

**Description:**  
The `IPPools` property is missing or contains no entries for a subnet.

**Example Failure:**

```text
Status: Failure
Message: PublicVIP network is missing required property: IPPools
Name: IPPools
ID: <NULL>
Type: PublicVIP
```

**Remediation Steps:**

- Define at least one valid IP pool for each subnet in every VIP network.

---

#### 6. Failure: Invalid StartIPAddress or EndIPAddress in IPPools

**Description:**  
`StartIPAddress` or `EndIPAddress` is missing, not a valid IP address, or not in the correct order.  

**Example Failure:**

```text
Status: Failure
Message: Invalid StartIPAddress or EndIPAddress in IPPools for PublicVIP
Name: IPPools
ID: <NULL>
Type: PublicVIP
```

**Remediation Steps:**

- Ensure both `StartIPAddress` and `EndIPAddress` are valid IPv4 addresses.
- `EndIPAddress` must be greater than `StartIPAddress`.

---

#### 7. Failure: IP Pool Range Not in Subnet

**Description:**  
The IP pool’s start or end address is not within the subnet’s `AddressPrefix`.  

**Example Failure:**  

```text
Status: Failure
Message: StartIPAddress x.x.x.x not in subnet y.y.y.y/25
Name: IPPools
ID: x.x.x.x not in y.y.y.y/25
Type: PublicVIP
```

**Remediation Steps:**  

- Adjust the IP pool range so both start and end addresses are within the subnet’s address prefix.

---

#### 8. Warning: No Private VIP Networks Found

**Description:**
No private VIP networks are defined. This is not a failure, but private VIPs will not be validated.

**Example Failure:**

```text
Status: Success
Message: No Private VIP networks found in configuration. Skipping Private VIP validation.
Name: <NULL>
ID: <NULL>
Type: PrivateVIP
```

**Remediation Steps:**

- If private VIPs are required for your scenario, add them to the configuration.

---

<!--
> **Note:**  
All failures include a `Status: Failure` and a descriptive message. Remediate according to the message and re-run the validator to confirm resolution.
-->
