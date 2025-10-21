# Troubleshoot-Test-SLB_ValidateNCLoadBalancerManager

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateNCLoadBalancerManager</strong></td>
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
The `Test-SLB_ValidateNCLoadBalancerManager` function validates the provisioning state of the Network Controller (NC) Load Balancer Manager in your Azure Local environment. It connects to the NC using the appropriate certificate, retrieves the load balancer manager resource, and checks if its provisioning state is healthy (`Succeeded`). If the state is not healthy or missing, the function returns a failure result with details for remediation. Use this validator to proactively detect and resolve issues with the NC Load Balancer Manager before they impact your environment.

---

## Example Configuration

Below is an example of a valid `loadBalancerManager` resource from NC:

```json
{
    {
        "resourceRef":  "/loadBalancerManager/config",
        "resourceId":  "config",
        "etag":  "<GUID>",
        "instanceId":  "<GUID>",
        "properties":  {
                        "provisioningState":  "Succeeded",
                        "loadBalancerManagerIPAddress":  "10.10.10.10",
                        "outboundNatIPExemptions":  [
                                                        "100.100.100.100/32",
                                                    ],
                        "vipIpPools":  [
                                            {
                                                "resourceRef":  "<Reference to IP pools>"
                                            }
                                        ]
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
- The `Test-SLB_ValidateNCLoadBalancerManager` function is available in your environment.
- All target hosts are online and reachable from the management system.
- You have administrative privileges on both the management system and all target hosts.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object:
- Look for failures related to `Test-SLB_ValidateNCLoadBalancerManager`.
- Example output:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCLoadBalancerManager",
    "DisplayName":  "Network Controller (NC) load balancer manager state",
    "Tags":  {},
    "Title":  "Network Controller (NC) load balancer manager state",
    "Status":  0,
    "Severity":  2,
    "Description":  "Test if all NC load balancer manager provisioning state are healthy.",
    "Remediation":  "NC load balancer manager provisioning state are not healthy.",
    "TargetResourceID":  "NCLoadBalancerManager",
    "TargetResourceName":  "NCLoadBalancerManager",
    "TargetResourceType":  "Network Controller load balancer manager",
    "Timestamp":  "\/Date(1761019775518)\/",
    "AdditionalData":  {
                            "Detail":  "\"Load balancer manager provisioning state are healthy.\"",
                            "Status":  "SUCCESS",
                            "TimeStamp":  "10/21/2025 04:09:35",
                            "Resource":  "Network Controller load balancer manager",
                            "Source":  "192.168.200.93"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\c2440959"
}
```

## Failure Return Results

Below are possible failure return results from `$SLBManagerValidRstObject`, including example messages and recommended remediation steps.


### Failure and Warning Results

---

### Failure: Provisioning State Not Succeeded
**Description:**  
The provisioning state of the NC Load Balancer Manager is not `"Succeeded"`. This indicates that the resource is not healthy and may block further operations.

**Example Failure:**  
```
{
    "Valid": false,
    "Provisioning": "Failed"
}
```
or
```
{
    "Valid": false,
    "Provisioning": "Updating"
}
```

**Remediation Steps:**  
- Review the NC Load Balancer Manager resource in the Azure Local environment.
- Check for errors in the NC logs and event viewer on the affected node.
- Ensure all required services are running and network connectivity is healthy.
- Retry the provisioning operation or redeploy the Load Balancer Manager if necessary.

---

### Failure: No NC Load Balancer Manager Found
**Description:**  
The validator could not retrieve the NC Load Balancer Manager resource. This may indicate a misconfiguration or that the resource is missing.

**Example Failure:**  
```
No NC load balancer manager found
```

**Remediation Steps:**  
- Verify that the Network Controller is correctly deployed and configured.
- Ensure the Load Balancer Manager resource exists in the NC.
- Check for issues with NC connectivity or certificate configuration.
- Recreate the Load Balancer Manager resource if missing.

---

### Failure: Unable to Set Connection to NC
**Description:**  
The validator failed to establish a connection to the Network Controller REST API, possibly due to certificate or network issues.

**Example Failure:**  
```
Unable to set connection to NC
```

**Remediation Steps:**  
- Confirm the NC REST API FQDN is correct and reachable from the management system.
- Validate that the required client certificate is present and trusted.
- Check firewall rules and network connectivity between the management system and NC.
- Reissue or import the correct certificate if needed.

---

### Warning: Provisioning State Unknown or Missing
**Description:**  
The provisioning state property is missing or contains an unexpected value, which may indicate an incomplete or corrupted resource.

**Example Failure:**  
```
{
    "Valid": false,
    "Provisioning": null
}
```
or
```
{
    "Valid": false,
    "Provisioning": "Unknown"
}
```

**Remediation Steps:**  
- Inspect the NC Load Balancer Manager resource for completeness.
- Check for recent changes or failed updates to the resource.
- Restore or redeploy the resource if necessary.

---