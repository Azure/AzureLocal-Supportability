# Troubleshoot-Test-SLB_ValidateNCLoadBalancerMux

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateNCLoadBalancerMux</strong></td>
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

The `Test-SLB_ValidateNCLoadBalancerMux` function validates the configuration and provisioning state of all Software Load Balancer (SLB) Multiplexer (MUX) instances managed by the Network Controller (NC) in your Azure Local environment. It connects to the NC, retrieves all SLB MUX resources, and checks their health by evaluating both provisioning and configuration states. If any MUX is not healthy, the validator returns a failure result with detailed information and remediation guidance. Use this validator to proactively detect and resolve SLB MUX issues to maintain network reliability and high availability.

---

## Example Configuration

Below is an example of a valid `loadBalancerManager` resource from the Network Controller:

```json
{
    "name": "slb-mux-01",
    "properties": {
        "provisioningState": "Succeeded",
        "configurationState": {
            "code": "Success",
            "message": "Configuration applied successfully."
        },
        "bgpSettings": {
            "asn": 65001,
            "peerIp": "10.0.0.1"
        }
    }
}
```

This configuration meets all validation requirements for SLB and BGP properties.

---

## Requirements

- Azure Local environment is deployed and accessible.
- The `AzStackHci` PowerShell module is installed and imported.
- You have permissions to query and modify Software Load Balancer (SLB) nodes and Multiplexer (MUX) instances.
- The `SLBValidator_ValidateNCLoadBalancerMux` function is available in your environment.
- All target hosts are online and reachable from the management system.
- You have administrative privileges on both the management system and all target hosts.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object.
- Look for failures related to `SLBValidator_ValidateNCLoadBalancerMux`.
- Example output:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCLoadBalancerMux",
    "DisplayName":  "All Software Load Balancer (SLB) Multiplexer (MUX) state on Network Controller (NC)",
    "Tags":  {},
    "Title":  "All Software Load Balancer (SLB) Multiplexer (MUX) state on Network Controller (NC)",
    "Status":  0,
    "Severity":  2,
    "Description":  "Test if all SLB MUX configuration and provisioning state are healthy.",
    "Remediation":  "SLB MUX configuration and provisioning state are not healthy.",
    "TargetResourceID":  "SLB MUX: v-SLB01, Loadbalancer Mux is Healthy.",
    "TargetResourceName":  "Success",
    "TargetResourceType":  "SoftwareLoadBalancerManager",
    "Timestamp":  "\/Date(1761019761682)\/",
    "AdditionalData":  {
                            "Detail":  "\"Load balancer Mux state is healthy and operational.\"",
                            "Status":  "SUCCESS",
                            "TimeStamp":  "10/21/2025 04:09:21",
                            "Resource":  "SoftwareLoadBalancerManager",
                            "Source":  "192.168.200.93"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\c2440959"
}
```

## Failure Return Results

Below are possible failure return results from `$ncSlbMuxResults`, including example messages and recommended remediation steps.


### Failure and Warning Results

---

#### Failure: SLB MUX Provisioning State Not Healthy
**Description:**  
The validator detected that one or more SLB Multiplexer (MUX) instances managed by the Network Controller are not in a healthy provisioning state. This typically means the MUX is not fully deployed, is stuck in a transitional state, or has failed to initialize.

**Example Failure:**  
```
SLB MUX [mux-01] provisioning state is 'Failed'. The configuration state has code [ProvisioningFailed]: The MUX failed to complete provisioning due to a configuration error.
```

**Remediation Steps:**
- Review the detailed error message for the affected MUX.
- Check the Network Controller and SLB MUX event logs for related errors.
- Ensure all required network and infrastructure dependencies are available.
- Retry the operation or redeploy the affected MUX if necessary.

---

#### Failure: SLB MUX Configuration State Not Healthy
**Description:**  
The validator found that the configuration state of one or more SLB MUX instances is not healthy. This may indicate misconfiguration, missing parameters, or failed application of settings.

**Example Failure:**  
```
SLB MUX [mux-02] configuration state is 'Error'. The configuration state has code [ConfigApplyError]: Failed to apply configuration due to invalid BGP settings.
```

**Remediation Steps:**
- Verify the configuration parameters for the affected MUX.
- Correct any invalid or missing settings (e.g., BGP configuration).
- Apply the configuration again and re-run the validator.

---

#### Failure: No SLB MUX Instances Found
**Description:**  
The validator could not find any SLB MUX resources managed by the Network Controller. This may indicate a deployment issue or a problem with the Network Controller connection.

**Example Failure:**  
```
No NC load balancer MUXes found
```

**Remediation Steps:**
- Confirm that SLB MUX instances are deployed and registered with the Network Controller.
- Check connectivity and credentials for accessing the Network Controller.
- Redeploy SLB MUX resources if necessary.

---

#### Warning: SLB MUX in Transitional State
**Description:**  
One or more SLB MUX instances are in a transitional state (e.g., 'Updating', 'Provisioning'). This may be expected during deployment or configuration changes, but prolonged transitional states may indicate issues.

**Example Failure:**  
```
SLB MUX [mux-03] provisioning state is 'Updating'. The configuration state has code [ConfigInProgress]: Configuration update is in progress.
```

**Remediation Steps:**
- Wait for the operation to complete and re-run the validator.
- If the state does not change after a reasonable period, investigate logs and consider restarting the affected MUX.

---