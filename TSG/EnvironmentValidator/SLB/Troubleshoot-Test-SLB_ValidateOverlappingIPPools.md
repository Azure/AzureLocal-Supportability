# Troubleshoot-Test-SLB_ValidateOverlappingIPPools

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateOverlappingIPPools</strong></td>
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

The `Test-SLB_ValidateOverlappingIPPools` function checks for overlapping IP address pools in your Azure Local Software Load Balancer (SLB) network configuration. It analyzes all IP pools defined under `HNVPA`, `PublicVIP`, and `PrivateVIP` network sections, ensuring that no IP ranges overlap across any subnet or network type. If overlapping IP pools are detected, the function returns a failure result with details about the conflicting ranges and guidance for remediation. Use this validator to proactively identify and resolve IP pool overlaps, which can prevent network assignment issues and service disruptions.

---

## Example Configuration

This example describes the configuration for HNVPA, Public VIP, and Private VIP networks in Azure Local environments. Each section is outlined below:

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

This example demonstrates a valid Networks configuration for `HNVPA`, `PublicVIP`, and `PrivateVIP` network types. It outlines the required properties and structure for each section, ensuring your configuration file includes all necessary fields and follows the recommended format. Use this sample as a template to verify your network definitions are complete and correctly organized.

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
        ]
    }
}
```

## Requirements

- Azure Local environment is deployed and accessible.
- `AzStackHci` PowerShell module is installed and imported.
- Sufficient permissions to query and modify nodes.
- `Test-SLB_ValidateOverlappingIPPools` function is available.
- All target hosts are online and reachable from the management system.
- Administrative privileges on both the management system and all target hosts.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and examine the returned result object.
- Filter results for the `Test-SLB_ValidateOverlappingIPPools` validator (by Name or DisplayName) and check for a failure status.
- Inspect the `AdditionalData` block and especially the `Detail` field — it contains the exact overlapping IP ranges and context needed to locate the conflict.
- Also review `TargetResourceID` / `TargetResourceName` to identify the affected resource and Timestamp to correlate when the issue was detected.
- Use the information above to identify which subnet or pool definitions to adjust, then re-run the validator to confirm remediation.
- Refer to the example output below for guidance on interpreting the results.

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateOverlappingIPPools",
    "DisplayName":  "Validate overlapping IP Pools",
    "Tags":  {},
    "Title":  "Validate overlapping IP Pools",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if all IP pools are not overlapping each other",
    "Remediation":  "Ensure that all IP pools are properly configured and do not overlap.",
    "TargetResourceID":  "Property name: IPPools, value: [x.x.x.x, y.y.y.y] overlaps with [x.x.x.x, z.z.z.z]",
    "TargetResourceName":  "IPPools",
    "TargetResourceType":  "IPPools",
    "Timestamp":  "\/Date(1761012664145)\/",
    "AdditionalData":  {
                            "Detail":  "\"IPPools x.x.x.x-y.y.y.y has overlapping with IPPools x.x.x.x-z.z.z.z. Please ensure IP pools do not overlap.\"",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 02:11:04",
                            "Resource":  "IPPools",
                            "Source":  "Networks"
                        },
    "HealthCheckSource":  "Deployment\\Standard\\Medium\\NetworkSLB\\22e52eb5"
}
```

### Failure Results

The following subsections list common failure outcomes from `Test-SLB_ValidateOverlappingIPPools`. Each includes: what failed (failure title), a sample `AdditionalData.Detail` message, and minimal, actionable remediation guidance.

#### Failure: Overlapping IP Pools Detected

**Description:**

The validator detected overlapping IP pool address ranges; this can lead to IP assignment conflicts and disrupt Software Load Balancer (SLB) operations.

**Additional Data Example:**

```text
Detail    : IPPools [x.x.x.x-y.y.y.y] has overlapping with IPPools [x.x.x.x-z.z.z.z]. Please ensure IP pools do not overlap.
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : SoftwareLoadBalancerManager
Source    : SDNIntegration
```

**Remediation Steps:**

1. Backup the current NetworksConfiguration file before making changes.

2. Create an inventory of all IPPools across HNVPA, PublicVIP, and PrivateVIP (Networks -> <`NetworkType`> -> Subnets -> IPPools). Record each pool’s StartIPAddress, EndIPAddress, and parent subnet.

3. Validate each pool:
    - Confirm StartIPAddress and EndIPAddress are valid IPv4 addresses and Start <= End.
    - Confirm the pool lies within the subnet AddressPrefix where it’s defined.

4. Identify overlaps:
    - For every pair of pools, ensure neither Start nor End addresses fall inside the other pool’s range.
    - Pay attention to pools in different network types that share the same subnet range.

5. Remediate overlaps:
    - Adjust StartIPAddress and/or EndIPAddress so ranges do not intersect, or move pools to non‑overlapping subnets.
    - Preserve required reserved addresses and gateway addresses when choosing new ranges.
    - Document any changes and update the source configuration file (use placeholders like `<StartIPAddress>` and `<EndIPAddress>`).

6. Verify changes:
    - Re-run Test-SLB_ValidateOverlappingIPPools.
    - Confirm the validator returns a success status and AdditionalData.Detail no longer reports overlapping ranges.
    - If failures persist, review the reported TargetResourceID/AdditionalData.Detail to locate remaining conflicts and repeat remediation.

---

<!--

### Failure: Null or Missing IP Pool Properties  
Description: The validator could not find valid IP pool properties in the configuration, or the IP pool object is missing required fields.  
Example Failure:  
```
Test-SLB_ValidateOverlappingIPPools: IPPools property is null or missing required values.
```
Remediation Steps:  
- Ensure all subnets have properly defined IPPools with both StartIPAddress and EndIPAddress.
- Validate the configuration file for completeness and correct syntax.
- Add missing IP pool definitions and re-run the validator.

### Warning: IP Pool Range Format Issues  
Description: The validator found IP pool ranges that are not in the expected format, which may prevent proper validation.  
Example Failure:  
```
Test-SLB_ValidateOverlappingIPPools: IPPools [x.x.x.x, y.y.y.y] has an invalid address format.
```
Remediation Steps:  
- Confirm that all IP addresses are valid IPv4 addresses.
- Correct any formatting errors in the IP pool definitions.
- Re-run the validator to ensure all ranges are properly recognized.

---

If you encounter any of these failures or warnings, follow the remediation steps to resolve configuration issues and ensure reliable SLB network operations.
-->