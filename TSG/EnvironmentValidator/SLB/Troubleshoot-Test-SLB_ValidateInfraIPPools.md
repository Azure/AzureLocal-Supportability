# Troubleshoot-Test-SLB_ValidateInfraIPPools

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLB_ValidateInfraIPPools</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>SLB Deployment, SLB Scale-in, SLB Scale-out</strong></td>
    </tr>
</table>

## Overview

The `Test-SLB_ValidateInfraIPPools` function checks whether your Azure Local environment has enough management IP addresses available for SLB deployment and operation. It calculates the required number of management IPs based on the number of hosts and MUXes, and queries the environment for the current available pool size. If the available IPs are insufficient, the function returns a critical failure result with remediation guidance.

**Input:**

- A set of PowerShell sessions (`PSSession`) to the target nodes.
- Optional: `IsDeployment` (boolean) to indicate if this is a new deployment (reserves one extra IP).
- Optional: `NumberOfMuxes` (integer) if not provided in the configuration.
- Optional: `SoftwareLoadbalancerConfiguration` object.

## Requirements

To run this validator, ensure:

- Azure Local environment is deployed and accessible.
- Administrative privileges on the management system and all target hosts.
- The `AzStackHci` PowerShell module is installed and imported.
- The `Test-SLB_ValidateInfraIPPools` function is available.
- All target hosts are online and reachable.
- Sufficient permissions to query and modify nodes.

## Troubleshooting Steps

### Review Environment Validator Output

- Run `Test-SLB_ValidateInfraIPPools` and review the returned result object.
- Focus on the `AdditionalData.Detail` field for the number of available management IPs and the required count.
- If the result indicates failure, add more management IPs to the pool.

Example Output

```json
{
    "Name": "AzStackHci_NetworkSLB_Test-SLB_ValidateInfraIPPools",
    "Title": "Check management IP addresses",
    "DisplayName": "Check management IP addresses",
    "Severity": "CRITICAL",
    "Description": "Test if we have enough management IP addresses",
    "Remediation": "<Remediation URL>",
    "TargetResourceID": "ManagementIPAddresses",
    "TargetResourceName": "ManagementIPAddresses",
    "TargetResourceType": "ManagementIPAddresses",
    "Timestamp": "2025-11-03T12:34:56Z",
    "Status": "FAILURE",
    "AdditionalData": {
        "Source": "x.x.x.x",
        "Resource": "ManagementIPAddresses",
        "Detail": "Not enough Management IPs to deploy SLB. There are [3] available management IPs but [4] are required.",
        "Status": "FAILURE",
        "TimeStamp": "2025-11-03T12:34:56Z"
    },
    "HealthCheckSource": "DeploySLB\\Standard\\Medium\\NetworkSLB\\073ad76b"
}
```

### Failure Results

Below are the possible failure results returned by `Test-SLB_ValidateInfraIPPools`. For each failure type, you will find example messages from the `AdditionalData` field and recommended remediation steps to address the issue.

#### Failure: Insufficient Management IPs (Infrastructure IP Addresses)

**Description:**
There are not enough management IP addresses available in the pool to support SLB deployment or scaling operations.

**Additional Data Example:**

```text
Detail    : Not enough Management IPs to deploy SLB. There are [3] available management IPs but [4] are required.
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : ManagementIPAddresses
Source    : x.x.x.x
```

**Remediation Steps:**

- Add additional management IP addresses to the pool until the available count meets or exceeds the required number.
- For new deployments, ensure one extra IP is reserved for SLBM.
- If multiple management subnets are detected, update configuration to ensure only one subnet is present.

---
