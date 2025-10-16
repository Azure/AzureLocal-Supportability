# Troubleshoot-Test-SLB_ValidatePublicPrivateVIPNetworks

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidatePublicPrivateVIPNetworks</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Deployment, Add Node, Pre-Update</strong></td>
    </tr>
</table>

## Overview
This function validates the configuration of public and private Virtual IP (VIP) networks in your Azure Stack HCI environment. It checks that all required properties for each VIP network—such as subnets, address prefixes, VLAN IDs, and IP pools—are present and correctly formatted. The function ensures that public VIP networks are always defined (mandatory), while private VIP networks are optional but validated if present. 

The input parameter `$NetworksConfiguration` should be a PowerShell object (or JSON) with the following structure:

```json
{
    "PublicVIP": [
        {
            "Name": "PublicVIPNetwork1",
            "Subnets": [
                {
                    "AddressPrefix": "100.72.20.0/24",
                    "VlanId": 0,
                    "IPPools": [
                        {
                            "StartIPAddress": "100.72.20.61",
                            "EndIPAddress": "100.72.20.250"
                        }
                    ]
                }
            ]
        }
        // ... more public VIP networks
    ],
    "PrivateVIP": [
        {
            "Name": "PrivateVIPNetwork1",
            "Subnets": [
                {
                    "AddressPrefix": "100.73.30.0/26",
                    "VlanId": 0,
                    "IPPools": [
                        {
                            "StartIPAddress": "100.73.30.1",
                            "EndIPAddress": "100.73.30.62"
                        }
                    ]
                }
            ]
        }
        // ... more private VIP networks
    ]
}
```

Maintaining valid VIP network definitions is critical for proper load balancing, network segmentation, and high availability. Misconfiguration may result in validation failures, reduced redundancy, or service disruption.

## Requirements

To use this validator, ensure the following prerequisites:

- An Azure Stack HCI environment is deployed and accessible.
- The PowerShell module `AzStackHci` is installed and imported.
- You have sufficient permissions to query and modify SLB nodes.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object:
- Look for failures related to `Test-SLB_ValidatePublicPrivateVIPNetworks`.
- Example output:
    ```powershell
    $SLBNodesValidRstObject = Test-SLB_ValidatePublicPrivateVIPNetworks
    $SLBNodesValidRstObject
    ```

## Failure Return Results

Below are all possible failure return results from `$PublicPrivateVIPsRstObject`, with example messages and recommended remediation steps.


### Failure and Warning Results

---

#### 1. Failure: No Public VIP Networks Found
**Description:**  
The validator did not find any public VIP networks in the configuration. Public VIP networks are mandatory for proper SLB operation.  
**Example Failure:**  
```
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
```
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
The `AddressPrefix` property does not match the expected CIDR notation (e.g., `100.72.20.0/24`).  
**Example Failure:**  
```
Status: Failure
Message: Invalid format for AddressPrefix in PublicVIP: 100.72.20.0-24
Name: AddressPrefix
ID: 100.72.20.0-24
Type: PublicVIP
```
**Remediation Steps:**  
- Use standard CIDR notation for all `AddressPrefix` values (e.g., `x.x.x.x/yy`).
- Correct any typos or formatting errors.

---

#### 4. Failure: Invalid or Missing VlanId
**Description:**  
The `VlanId` property is missing, not an integer, or outside the valid range (0–4095).  
**Example Failure:**  
```
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
```
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
```
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
```
Status: Failure
Message: StartIPAddress 100.72.21.200 not in subnet 100.72.21.0/25
Name: IPPools
ID: 100.72.21.200 not in 100.72.21.0/25
Type: PublicVIP
```
**Remediation Steps:**  
- Adjust the IP pool range so both start and end addresses are within the subnet’s address prefix.

---

#### 8. Failure: DefaultGateway Address in IP Pool Range
**Description:**  
A default gateway address is included within the IP pool range, which is not allowed.  
**Example Failure:**  
```
Status: Failure
Message: DefaultGateway 100.72.20.1 is in IP pool range [100.72.20.1, 100.72.20.250]
Name: DefaultGateways
ID: 100.72.20.1 in [100.72.20.1, 100.72.20.250]
Type: PublicVIP
```
**Remediation Steps:**  
- Ensure default gateway addresses are outside all defined IP pool ranges.

---

#### 9. Warning: No Private VIP Networks Found
**Description:**  
No private VIP networks are defined. This is not a failure, but private VIPs will not be validated.  
**Example Failure:**  
```
Status: Success
Message: No Private VIP networks found in configuration. Skipping Private VIP validation.
Name: <NULL>
ID: <NULL>
Type: PrivateVIP
```
**Remediation Steps:**  
- If private VIPs are required for your scenario, add them to the configuration.

---

> **Note:**  
All failures include a `Status: Failure` and a descriptive message. Remediate according to the message and re-run the validator to confirm resolution.