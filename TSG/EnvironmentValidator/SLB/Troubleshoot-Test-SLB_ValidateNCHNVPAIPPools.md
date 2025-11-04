# Troubleshoot-Test-SLB_ValidateNCHNVPAIPPools

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLB_ValidateNCHNVPAIPPools</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Add Node</strong></td>
    </tr>
</table>

## Overview

`Test-SLB_ValidateNCHNVPAIPPools` validates that your Azure Local environment has a sufficient number of available IP addresses in the Hyper-V Network Virtualization Provider Address (HNVPA) pools to support all existing nodes, new hosts being added, and SLB multiplexers (MUXes). It checks the Network Controller for HNVPA logical networks and subnets, calculates available IPs, and compares this against the required count. The function reports a critical failure if available IPs are insufficient, blocking further operations until remediated.

## Requirements

To run this validator, ensure:

- Your Azure Local environment is deployed and reachable.
- The PowerShell module `AzStackHci` is installed and imported.
- You have permissions to query and modify nodes.
- The function must be executed with valid PowerShell remoting sessions (`PSSession`) to all target nodes.
- The environment must have Network Controller and SLB MUXes properly configured.
- The required supporting modules for Network Controller (`Microsoft.AS.Network.Deploy.NC`) are available on the target nodes.

## Troubleshooting Steps

### Review Environment Validator Output

To review the output of `Test-SLB_ValidateNCHNVPAIPPools`:

- Run the validator and capture the result object.
- Filter for the entry with `Name` equal to `Test-SLB_ValidateNCHNVPAIPPools`.
- Inspect the `Status` and the `AdditionalData.Detail` field for the specific validation result:
- Use `AdditionalData.Resource` and `AdditionalData.Status` to identify the affected resource and severity.
- Apply the appropriate remediation steps (e.g., increase IP pool size, resolve NC issues) and re-run the validator.

Example output:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCHNVPAIPPools",
    "DisplayName":  "Validate the available IP pools from Hyper-V Network Virtualization Provider Address (HNVPA) network'",
    "Tags":  {},
    "Title":  "Validate the available IP pools from Hyper-V Network Virtualization Provider Address (HNVPA) network'",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if HNVPA IP pools have sufficient IP addresses.",
    "Remediation": "<Remediation URL>",
    "TargetResourceID":  "NC HNVPA Available IP Addresses: [$totalAvailableIP], Required: [$requiredIPs]",
    "TargetResourceName":  "IPPools",
    "TargetResourceType":  "HNVPA",
    "Timestamp":  "\/Date(1761012664074)\/",
    "AdditionalData":  {
                            "Detail":  "\"Detected not enough HNVPA IP addresses for all nodes and SLB MUXes. There are [3] available IPs but [4] are required.\"",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 02:11:04",
                            "Resource":  "HNVPA",
                            "Source":  "IPPools"
                        },
    "HealthCheckSource":  "AddNode\\Standard\\Medium\\NetworkSLB\\22e52eb5"
}
```

### Failure Results

Below are the possible failure and warning results that `Test-SLB_ValidateNCHNVPAIPPools` may return. For each result, you will find:

- **What failed:** Identifies the affected resource (see `AdditionalData.Resource` and `TargetResourceType`).
- **Example message:** Shows a typical `AdditionalData.Detail` output for the failure.
- **Remediation actions:** Lists targeted steps to resolve the issue before re-running the validator.

**How to use this section:**  
Start by reviewing the `AdditionalData.Detail` field in your validator output for the specific error or warning. Then, confirm the context using `TargetResourceName`, `TargetResourceType`, and `Status`. Apply the recommended remediation steps for your scenario, and re-run the validator to verify resolution.

#### Failure: Insufficient Available IP Addresses

**Description:**  
The validator detected that the number of available IP addresses in the HNVPA pools is less than the required amount to support all current nodes, new hosts, and SLB MUXes. This blocks further operations until remediated.

**Example Failure:**

```text
Detail: Detected not enough HNVPA IP addresses for all nodes and SLB MUXes. There are [3] available IPs but [4] are required.
Status: FAILURE
TimeStamp: <timestamp>
Resource: HNVPA
Source: IPPools
```

**Remediation Steps:**

- Increase the size of the HNVPA IP pool in Network Controller to ensure sufficient IPs.
- Remove unused or stale IP allocations if possible.
- Verify that all subnets are correctly configured and not over-allocated.
- Re-run the validator after remediation.

---

#### Failure: Network Controller Returned Null or Unexpected Results

**Description:**  
The validator was unable to retrieve logical network or subnet information from the Network Controller, or the returned data was incomplete or malformed.

**Example Failure:**

```text
Detail: Network Controller (NC) returned null or unexpected results.
Status: FAILURE
TimeStamp: <timestamp>
Resource: HNVPA
Source: IPPools
```

**Remediation Steps:**

- Verify Network Controller health and connectivity.
- Ensure the required PowerShell modules are installed and imported on target nodes.
- Check for configuration or permission issues in Network Controller.
- Review logs for errors and resolve any detected issues.
- Re-run the validator after remediation.

---
