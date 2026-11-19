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
        <td><strong>SLB Deployment, SLB Scale-In, SLB Scale-Out</strong></td>
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
There are not enough management IP addresses available in the pool to support SLB deployment or scaling operations. The required number of IPs is calculated based on the number of MUXes (1 for single-node, 2 for multi-node by default) plus 1 additional IP for SLBM during new deployments.

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
- Calculate required IPs: Single-node = 1 MUX + 1 SLBM (if new deployment); Multi-node = 2 MUXes + 1 SLBM (if new deployment).

---

#### Failure: No Management Subnets Found

**Description:**
The validator could not find any management subnet configuration in the ECE store. This indicates a configuration issue with the cluster deployment.

**Additional Data Example:**

```text
Detail    : No management subnets found
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : ManagementIPAddresses
Source    : x.x.x.x
```

**Remediation Steps:**

- Verify that the cluster deployment completed successfully and the ECE configuration is intact.
- Check that management network configuration exists in the deployment parameters.
- If this is a new deployment, review your deployment configuration to ensure management subnet ranges are properly defined.
- Contact Microsoft Support if the management subnet configuration is missing after a successful deployment.

---

#### Failure: No Allocatable IPs Found for Management Subnet

**Description:**
The management subnet exists in the configuration, but it has no allocatable IP addresses available. All IPs in the pool may already be allocated to other resources.

**Additional Data Example:**

```text
Detail    : No allocatable IPs found for management subnet
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : ManagementIPAddresses
Source    : x.x.x.x
```

**Remediation Steps:**

- Review the current IP allocations in the management subnet to identify which resources are using the available IPs.
- Expand the management subnet IP range to include additional IP addresses.
- Ensure the IP range in your configuration has sufficient addresses for cluster nodes, Network Controller VMs, SLB MUX VMs, and SLBM.

---

#### Failure: Multiple Management Subnets Found

**Description:**
The validator detected more than one management subnet in the ECE configuration. The validator expects exactly one management subnet to determine available IP addresses.

**Additional Data Example:**

```text
Detail    : Multiple management subnets found, unable to determine available IPs
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : ManagementIPAddresses
Source    : x.x.x.x
```

**Remediation Steps:**

- Review your deployment configuration to identify why multiple management subnets exist.
- Consolidate to a single management subnet configuration if multiple were defined unintentionally.
- Contact Microsoft Support for guidance if multiple management subnets are required for your environment.

---

#### Failure: Failed to Retrieve Management IP Pool Information

**Description:**
The validator was unable to query the ECE store for management subnet information. This could be due to connectivity issues, permission problems, or ECE service issues.

**Additional Data Example:**

```text
Detail    : Failed to retrieve management IP pool information
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : ManagementIPAddresses
Source    : x.x.x.x
```

**Remediation Steps:**

- Verify that the ECE cluster service is running and accessible.
- Check that you have administrative privileges on the cluster.
- Verify connectivity to the cluster nodes where ECE is running.
- Review the Windows Event Log for any ECE-related errors.
- If the ECE service is not responding, try restarting the ECE cluster resource (with caution in production environments).

---
