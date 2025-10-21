# Troubleshoot-Test-SLB_ValidateNCServers

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLBValidator_ValidateNCServers</strong></td>
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
The `Test-SLB_ValidateNCServers` function validates the health and configuration state of all Network Controller (NC) servers in your Azure Local environment. It connects to each NC server, checks provisioning and configuration status, and reports any unhealthy states or errors. The validator ensures that all NC servers are correctly configured and operational, which is critical for network reliability and SLB functionality. If any server is misconfigured or not healthy, the function returns detailed failure results and remediation guidance to help you resolve issues before they impact your environment.

---

## Example Configuration

Below is an example of a valid `Servers` resource from the Network Controller:

```json
{
    "resourceId": "node-01",
    "properties": {
        "provisioningState": "Succeeded",
        "configurationState":  {
            "status":  "Success",
            "detailedInfo":  [
                                {
                                    "source":  "SoftwareLoadBalancerManager",
                                    "message":  "Host is Connected.",
                                    "code":  "Success"
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
- Sufficient permissions to query and modify Software Load Balancer (SLB) nodes and Multiplexer (MUX) instances.
- The `Test-SLB_ValidateNCServers` function is available in your environment.
- All target NC servers are online and reachable from the management system.
- Administrative privileges on both the management system and all target NC servers.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object:
- Look for failures related to `Test-SLB_ValidateNCServers`.
- Example output:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCServers",
    "DisplayName":  "All Network Controller (NC) server state",
    "Tags":  {},
    "Title":  "All Network Controller (NC) server state",
    "Status":  0,
    "Severity":  2,
    "Description":  "Test if all NC servers configuration and provisioning state are healthy.",
    "Remediation":  "NC server configuration and provisioning state are not healthy.",
    "TargetResourceID":  "NC server: v-Host1, Host is Connected.",
    "TargetResourceName":  "Success",
    "TargetResourceType":  "SoftwareLoadBalancerManager",
    "Timestamp":  "\/Date(1761019789100)\/",
    "AdditionalData":  {
                            "Detail":  "\"NC server provisioning and configuration state are healthy.\"",
                            "Status":  "SUCCESS",
                            "TimeStamp":  "10/21/2025 04:09:49",
                            "Resource":  "SoftwareLoadBalancerManager",
                            "Source":  "192.168.200.93"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\c2440959"
}
```

## Failure Return Results

Below are all possible failure return results from `$ncServerResults`, including example messages and recommended remediation steps.

### Failure and Warning Results

---
#### Failure: Provisioning State Not Succeeded
**Description:** The NC server's `provisioningState` is not `Succeeded`. This indicates the server was not provisioned correctly and may not be operational.
**Example Failure:**  
```json
"provisioningState": "Failed"
```
**Remediation Steps:**  
- Check deployment logs for errors.
- Re-run the provisioning process for the affected NC server.
- Ensure network connectivity and required permissions.

---

#### Failure: Configuration State Not Success
**Description:** The NC server's `configurationState.status` is not `Success`. This means the server is not configured properly and may impact SLB functionality.
**Example Failure:**  
```json
"configurationState": {
    "status": "Error",
    "detailedInfo": [
        {
            "source": "SoftwareLoadBalancerManager",
            "message": "Host is Disconnected.",
            "code": "Error"
        }
    ]
}
```
**Remediation Steps:**  
- Review the detailedInfo message for specific errors.
- Verify the NC server's configuration and connectivity.
- Restart the NC server and re-apply configuration.

---

#### Warning: Configuration State Warning
**Description:** The NC server's `configurationState.status` is `Warning`. This may indicate a non-critical issue that could become a failure if not addressed.
**Example Failure:**  
```json
"configurationState": {
    "status": "Warning",
    "detailedInfo": [
        {
            "source": "SoftwareLoadBalancerManager",
            "message": "Host is reachable but configuration is incomplete.",
            "code": "Warning"
        }
    ]
}
```
**Remediation Steps:**  
- Investigate the warning message in `detailedInfo`.
- Complete any pending configuration steps.
- Monitor the server for further issues.

---

#### Failure: No NC Servers Found
**Description:** The validator could not retrieve any NC servers. This usually means a connectivity or configuration issue.
**Example Failure:**  
```
No NC servers found
```
**Remediation Steps:**  
- Ensure NC servers are deployed and accessible.
- Check network connectivity and firewall settings.
- Validate NC server registration in the environment.

---

#### Failure: Unable to Set NC Connection
**Description:** The validator failed to establish a connection to the NC REST API, possibly due to certificate or DNS issues.
**Example Failure:**  
```
Unable to set connection to NC
```
**Remediation Steps:**  
- Verify the NC REST API FQDN and certificate.
- Ensure the client has access to the required certificate.
- Check DNS resolution and network connectivity.

---

#### Failure: DetailedInfo Code Indicates Error
**Description:** The `detailedInfo.code` in the configuration state is `Error`, indicating a specific issue reported by the NC server.
**Example Failure:**  
```json
"detailedInfo": [
    {
        "source": "SoftwareLoadBalancerManager",
        "message": "Host is unreachable.",
        "code": "Error"
    }
]
```
**Remediation Steps:**  
- Review the error message for actionable details.
- Check host connectivity and status.
- Resolve any reported issues and re-run the validator.

---

#### Warning: DetailedInfo Code Indicates Warning
**Description:** The `detailedInfo.code` is `Warning`, which may indicate a potential issue that should be monitored.
**Example Failure:**  
```json
"detailedInfo": [
    {
        "source": "SoftwareLoadBalancerManager",
        "message": "Host is running with degraded performance.",
        "code": "Warning"
    }
]
```
**Remediation Steps:**  
- Investigate the warning for root cause.
- Monitor server health and performance.
- Address any underlying issues to prevent escalation.
