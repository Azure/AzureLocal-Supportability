# Troubleshoot-Test-SLB_ValidateNCLoadBalancerMux

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLB_ValidateNCLoadBalancerMux</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Informational</strong>: This validator provides informational output and does not block operations.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Pre-Update, Post-Update, Add Node, SLB Scale-In, SLB Scale-Out, Post-SLB</strong></td>
    </tr>
</table>

## Overview

The `Test-SLB_ValidateNCLoadBalancerMux` function checks the configuration and provisioning state of all Software Load Balancer (SLB) Multiplexer (MUX) instances managed by the Network Controller (NC) in your Azure Local environment. It connects to the NC, retrieves SLB MUX resources, and evaluates their health by inspecting both provisioning and configuration states. Each MUX must be connected to the SLB Manager service (SLBM) of the NC. If any MUX is found unhealthy, the validator returns a failure result with specific details and recommended remediation steps. Running this validator helps you identify and address SLB MUX issues early, supporting network reliability and high availability.

---

## Requirements

- Azure Local environment is deployed and accessible.
- The `AzStackHci` PowerShell module is installed and imported.
- You have permissions to query and modify Software Load Balancer (SLB) nodes and Multiplexer (MUX) instances.
- The `SLB_ValidateNCLoadBalancerMux` function is available in your environment.
- All target hosts are online and reachable from the management system.
- You have administrative privileges on both the management system and all target hosts.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the validator and review the result object.
- Look for failures related to `SLB_ValidateNCLoadBalancerMux` in the validator output. Pay particular attention to the `AdditionalData` section, especially the `Detail` field, which provides specific information about the state of each Load Balancer Mux. This field will highlight which MUX instances are unhealthy and describe the exact issue detected, helping you target your troubleshooting efforts.
- Example output: The following is a sample of the expected output when you run this command. Use it to verify that your results match the documented behavior.

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCLoadBalancerMux",
    "DisplayName":  "All Software Load Balancer (SLB) Multiplexer (MUX) state on Network Controller (NC)",
    "Tags":  {},
    "Title":  "All Software Load Balancer (SLB) Multiplexer (MUX) state on Network Controller (NC)",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if all SLB MUX configuration and provisioning state are healthy.",
    "Remediation": "<Remediation URL>",
    "TargetResourceID":  "SLB MUX: <SLB Name>, Loadbalancer Mux is not connected to SLBM. Network Error Code: 10054, Error Message: An existing connection was forcibly closed by the remote host.",
    "TargetResourceName":  "VirtualServerUnreachable",
    "TargetResourceType":  "SoftwareLoadBalancerManager",
    "Timestamp":  "\/Date(1761019761682)\/",
    "AdditionalData":  {
                            "Detail":  "Network Controller (NC) load balancer MUX state is not healthy. Please investigate Loadbalancer Mux ID [<SLB Name>], provisioning state [Succeeded], configuration state [Failure] and resolve the issue [Loadbalancer Mux is not connected to SLBM. Network Error Code: 10054, Error Message: An existing connection was forcibly closed by the remote host.].",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 04:09:21",
                            "Resource":  "SoftwareLoadBalancerManager",
                            "Source":  "x.x.x.x"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\c2440959"
}
```

### Failure Results

Below are possible failure return results from `SLB_ValidateNCLoadBalancerMux`. For each result, example detail messages from the `AdditionalData` field are provided, along with recommended remediation steps to resolve the issue.

#### Failure: SLB MUX Provisioning or Configuration State Not Healthy

**Description:**  
The validator has identified that one or more SLB Multiplexer (MUX) instances managed by the Network Controller are not in a healthy provisioning or configuration state. This may indicate that a MUX is not fully deployed, is stuck in a transitional state (such as 'Updating' or 'Deleting'), or has failed to initialize. Additionally, unhealthy configuration states can result from misconfiguration, missing parameters, or unsuccessful application of settings.

**Example Failure:**  

```text
Detail    : Network Controller (NC) load balancer MUX state is not healthy. Please investigate load balancer MUX ID [<SLB Name>], provisioning state [Succeeded], configuration state [Failure] and resolve the issue [Loadbalancer Mux is not connected to SLBM. Network Error Code: 10054, Error Message: An existing connection was forcibly closed by the remote host.].
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : SoftwareLoadBalancerManager
Source    : <Node IP Address>
```

**Remediation Steps:**

- Review the detailed error message for the affected MUX.
- Check the Network Controller and SLB MUX event logs for related errors.
- Ensure all required network and infrastructure dependencies are available.
- Retry the operation or redeploy the affected MUX if necessary.
- Correct any invalid or missing settings (e.g., BGP router configuration).
- To manually verify the Load Balancer MUX resource on the host, run the PowerShell script below. The output should match the example shown below.

```powershell
$packagePath = Get-ASArtifactPath -NugetName "Microsoft.AS.Network.Deploy.NC" -Verbose:$false 3>$null 4>$null
Import-Module "$packagePath\content\Powershell\Roles\NC\Common.psm1" -Force -DisableNameChecking
$subjectCN = "$($env:USERDOMAIN)-nc.$($env:USERDNSDOMAIN)"
$certs = Get-ChildItem "Cert:\localmachine\my"
$clientCert = Get-CertificateByHostName -certs $certs -hostName $subjectCN -isServer $false
Set-NCConnection -RestName "$($env:USERDOMAIN)-nc.$($env:USERDNSDOMAIN)" -NCCertificate $clientCert
Get-NCLoadBalancerMux
```

- List all FCNC-related microservices and check their status:  
    (This command lists all cluster services related to FCNC, excluding HCI and MOC services.)

```powershell
Get-ClusterResource | Where-Object {
        $_.ResourceType -eq 'Generic Service' -and
        $_.Name -notlike "*HCI*" -and
        $_.Name -notlike "*MOC*"
}
```

- If the `SlbManagerService` is offline, restart it safely:

```powershell
# Check if SlbManagerService is offline
$slbmService = Get-ClusterResource -Name SlbManagerService -ErrorAction SilentlyContinue
if ($slbmService.State -eq 'Offline') {
    # Attempt to bring the service online
    Start-ClusterResource -Name SlbManagerService
}
```

- If the issue persists, you can collect an SDN trace for further analysis. [Learn how to collect an SDN trace](https://github.com/Azure/AzureLocal-Supportability/blob/main/TSG/Networking/Diagnostics/HowTo-Diagnostic-SendNetworkingLogs.md)

---

### Example NC Load Balancer MUX resource

Below is a sample of a healthy `loadBalancerMuxes` resource retrieved from the Network Controller. Use this as a reference when validating your environment.

```json
[
    {
        "resourceRef":  "/loadBalancerMuxes/<Mux-01 name>",
        "resourceId":  "<Mux-01 name>",
        "properties": {
            "provisioningState": "Succeeded",
            "routerConfiguration": {
            "localASN": <Local ASN>,
            "peerRouterConfigurations": [
                {
                    "localIPAddress": "<Local IP Address>",
                    "routerName": "BGPGateway-<Local ASN>-<Peer ASN>",
                    "routerIPAddress": "<Router IP Address>",
                    "peerASN": <Peer ASN>
                }
            ]
            },
            "configurationState": {
                "status": "Success",
                "detailedInfo": [
                    {
                    "source": "SoftwareLoadBalancerManager",
                    "message": "Loadbalancer Mux is Healthy.",
                    "code": "Success"
                    }
                ]
            }
            // ... more
        }
    },
    {
        "resourceRef":  "/loadBalancerMuxes/<Mux-02 name>",
        "resourceId":  "<Mux-02 name>",
        // ... more
    }
]
```

#### Validation Criteria

- `provisioningState` is `Succeeded`
- `configurationState.status` is `Success`
- BGP router configuration parameters are present and correct

If your output matches this structure and values, the SLB MUX is considered healthy.

---
