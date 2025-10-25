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
        <td><strong>Pre-Update, Post-Update, Add Node, Scale-In, Scale-Out</strong></td>
    </tr>
</table>

## Overview

The `Test-SLB_ValidateNCServers` function validates the health and configuration state of all Network Controller (NC) servers in your Azure Local environment. It connects to each NC server, checks provisioning and configuration status, and reports any unhealthy states or errors. The validator ensures that all NC servers are correctly configured and operational, which is critical for network reliability and SLB functionality. If any server is misconfigured or not healthy, the function returns detailed failure results and remediation guidance to help you resolve issues before they impact your environment.

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

- Execute the `Test-SLB_ValidateNCServers` validator to assess the health and configuration of all NC servers.
- Carefully examine the result object, prioritizing any entries marked as failures.
- Review the `AdditionalData` section for each failure, as it contains detailed diagnostic information.
- Pay close attention to the `Detail` field, which summarizes the specific issue and current state for each affected NC server.
- Refer to the example output below to understand how issues are reported and what information to look for when troubleshooting.

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCServers",
    "DisplayName":  "All Network Controller (NC) server state",
    "Tags":  {},
    "Title":  "All Network Controller (NC) server state",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if all NC servers configuration and provisioning state are healthy.",
    "Remediation":  "NC server configuration and provisioning state are not healthy.",
    "TargetResourceID":  "NC server: <Node Name>, Host is not Connected.",
    "TargetResourceName":  "HostNotConnectedToController",
    "TargetResourceType":  "SoftwareLoadBalancerManager",
    "Timestamp":  "\/Date(1761019789100)\/",
    "AdditionalData":  {
                            "Detail":  "\"NC server provisioning and configuration state are not healthy. Please investigate NC server id [<Node Name>], provisioning state [Succeeded], configuration state [Warning] and resolve the issue [Host is not Connected.]\"",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 04:09:49",
                            "Resource":  "SoftwareLoadBalancerManager",
                            "Source":  "<Node IP Address>"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\c2440959"
}
```

### Failure Results

Below are all possible failure return results from `Test-SLB_ValidateNCServers`, including example messages and recommended remediation steps.

#### Failure: NC Server Provisioning or Configuration State Not Healthy

**Description:**  
The NC server's `provisioningState` is not `Succeeded` or its `configurationState.status` is not `Success`. This means the server was either not provisioned correctly or is misconfigured, which can block SLB operations and impact network reliability.

**Example Failure:**  

```text
Detail    : NC server provisioning and configuration state are not healthy. Please investigate NC server id [<Node Name>], provisioning state [Succeeded], configuration state [Warning] and resolve the issue [Host is not Connected.].
Status    : FAILURE
TimeStamp : 2025-06-01T12:34:56Z
Resource  : SoftwareLoadBalancerManager
Source    : <Node IP Address>
```

**Remediation Steps:**

- Review deployment and configuration logs for errors.
- Re-run the provisioning or configuration process for the affected NC server.
- Verify network connectivity and required permissions.
- Address any reported issues in the `detailedInfo` section.
- After remediation, re-run the validator to confirm resolution.
- To manually verify the Load Balancer MUX resource on the host, run the PowerShell script below. The output should match the example shown below.

```powershell
$packagePath = Get-ASArtifactPath -NugetName "Microsoft.AS.Network.Deploy.NC" -Verbose:$false 3>$null 4>$null
Import-Module "$packagePath\content\Powershell\Roles\NC\Common.psm1" -Force -DisableNameChecking
$subjectCN = "$($env:USERDOMAIN)-nc.$($env:USERDNSDOMAIN)"
$certs = Get-ChildItem "Cert:\localmachine\my"
$clientCert = Get-CertificateByHostName -certs $certs -hostName $subjectCN -isServer $false
Set-NCConnection -RestName "$($env:USERDOMAIN)-nc.$($env:USERDNSDOMAIN)" -NCCertificate $clientCert
Get-NCServer
```

- Verify the SLB and NC Host Agent status on the affected host.

```powershell
# Check if the SLB and NC Host Agent services are running
Get-Service -Name SlbHostAgent
Get-Service -Name NCHostAgent

# If either service is not running, restart it (do not use -Force)
if ((Get-Service -Name SlbHostAgent).Status -ne 'Running') {
    Restart-Service -Name SlbHostAgent
}
if ((Get-Service -Name NCHostAgent).Status -ne 'Running') {
    Restart-Service -Name NCHostAgent
}
```

> **Important:** Restarting the NC Host Agent or SLB Host Agent may temporarily impact network operations on the host. Verify that critical workloads will not be disrupted before restarting services.

---

### Example NC servers resource

Below is a sample of a healthy `Servers` resource retrieved from the Network Controller. Use this as a reference when validating your environment.

```json
[
    {
        "resourceId": "Node-01",
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
            /* Additional properties */
        }
    },
    {
        "resourceId": "Node-02",
        "properties": {
              "provisioningState": "Succeeded",
              "configurationState": {
                  "status": "Success",
                  "detailedInfo": [
                      {
                          "source": "SoftwareLoadBalancerManager",
                          "message": "Host is Connected.",
                          "code": "Success"
                      }
                  ]
              }
              /* Additional properties */
        }
    },
]
```

#### Validation Criteria

To consider an NC server healthy, ensure the following conditions are met:

- The `provisioningState` property must be set to `Succeeded`.  
    *This confirms the server was provisioned correctly and is operational.*
- The `configurationState.status` property must be `Success`.  
    *This indicates the server is properly configured and connected.*

If both criteria are satisfied in your output, the NC server meets the health requirements and no further remediation is needed.

---

<!--
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
-->