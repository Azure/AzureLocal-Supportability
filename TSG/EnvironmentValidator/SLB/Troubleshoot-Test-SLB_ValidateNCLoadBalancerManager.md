# Troubleshoot-Test-SLB_ValidateNCLoadBalancerManager

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; margin-bottom:1em;">
    <tr>
        <th style="text-align:left; width: 180px;">Name</th>
        <td><strong>SLB_ValidateNCLoadBalancerManager</strong></td>
    </tr>
    <tr>
        <th style="text-align:left; width: 180px;">Severity</th>
        <td><strong>Critical</strong>: This validator will block operations until remediated.</td>
    </tr>
    <tr>
        <th style="text-align:left;width: 180px;">Applicable Scenarios</th>
        <td><strong>Pre-Update, Post-Update, Add Node, SLB Scale-in, SLB Scale-out</strong></td>
    </tr>
</table>

## Overview
The `Test-SLB_ValidateNCLoadBalancerManager` function validates the provisioning state of the Network Controller (NC) Load Balancer Manager in your Azure Local environment. It connects to the NC using the appropriate certificate, retrieves the load balancer manager resource, and checks if its provisioning state is healthy (`Succeeded`). If the state is not healthy or missing, the function returns a failure result with details for remediation. Use this validator to proactively detect and resolve issues with the NC Load Balancer Manager before they impact your environment.

## Requirements

- Azure Local environment is deployed and accessible.
- The `AzStackHci` PowerShell module is installed and imported.
- You have permissions to query and modify Software Load Balancer (SLB) nodes and Multiplexer (MUX) instances.
- The `Test-SLB_ValidateNCLoadBalancerManager` function is available in your environment.
- All target hosts are online and reachable from the management system.
- You have administrative privileges on both the management system and all target hosts.

## Troubleshooting Steps

### Review Environment Validator Output

- Run the `Test-SLB_ValidateNCLoadBalancerManager` validator and review the result object it returns.
- Pay close attention to any failure indicators, especially within the `AdditionalData` section. The `Detail` field provides specific information about the current status and any issues affecting the Load Balancer Manager.
- For reference, see the example output below:

```json
{
    "Name":  "AzStackHci_NetworkSLB_Test-SLB_ValidateNCLoadBalancerManager",
    "DisplayName":  "Network Controller (NC) load balancer manager state",
    "Tags":  {},
    "Title":  "Network Controller (NC) load balancer manager state",
    "Status":  1,
    "Severity":  2,
    "Description":  "Test if all NC load balancer manager provisioning state are healthy.",
    "Remediation": "<Remediation URL>",
    "TargetResourceID":  "NCLoadBalancerManager",
    "TargetResourceName":  "NCLoadBalancerManager",
    "TargetResourceType":  "Network Controller load balancer manager",
    "Timestamp":  "\/Date(1761019775518)\/",
    "AdditionalData":  {
                            "Detail":  "Network Controller (NC) load balancer manager provisioning state are not healthy. Please investigate provisioning state [Failed] and resolve the issue.",
                            "Status":  "FAILURE",
                            "TimeStamp":  "10/21/2025 04:09:35",
                            "Resource":  "Network Controller load balancer manager",
                            "Source":  "<Node IP Address>"
                        },
    "HealthCheckSource":  "ScaleSLB\\Standard\\Medium\\NetworkSLB\\c2440959"
}
```

### Failure Results

Below are possible failure return results from `Test-SLB_ValidateNCLoadBalancerManager`, including example messages and recommended remediation steps.

---

#### Failure: Provisioning State Not Succeeded

**Description:**  
The provisioning state of the NC Load Balancer Manager is not `"Succeeded"`. This indicates that the resource is not healthy and may block further operations.

**Example Failure:**  

```text
Detail    : Network Controller (NC) load balancer manager provisioning state are not healthy. Please investigate provisioning state [Failed] and resolve the issue.
Status    : FAILURE
TimeStamp : <timestamp>
Resource  : Network Controller load balancer manager
Source    : <Node IP Address>
```

**Remediation Steps:**  

- Review the NC Load Balancer Manager resource in the Azure Local environment.
- Check for errors in the NC logs and event viewer on the affected node.
- To manually verify the Load Balancer Manager resource on the host, run the PowerShell script below. The output should match the example shown above.

```powershell
$packagePath = Get-ASArtifactPath -NugetName "Microsoft.AS.Network.Deploy.NC" -Verbose:$false 3>$null 4>$null
Import-Module "$packagePath\content\Powershell\Roles\NC\Common.psm1" -Force -DisableNameChecking
$subjectCN = "$($env:USERDOMAIN)-nc.$($env:USERDNSDOMAIN)"
$certs = Get-ChildItem "Cert:\localmachine\my"
$clientCert = Get-CertificateByHostName -certs $certs -hostName $subjectCN -isServer $false
Set-NCConnection -RestName "$($env:USERDOMAIN)-nc.$($env:USERDNSDOMAIN)" -NCCertificate $clientCert
Get-NCLoadbalancerManager
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

### Example NC Load Balancer Manager resource

Below is a sample of a healthy `loadBalancerManager` resource retrieved from the Network Controller. Use this as a reference when validating your environment.

```json
{
    "resourceRef":  "/loadBalancerManager/config",
    "resourceId":  "config",
    "properties":  {
                    "loadBalancerManagerIPAddress":  "<LB manager IP address>",
                    "outboundNatIPExemptions":  ["<IP address>/32"],
                    "vipIpPools":  [ { "resourceRef":  "<Reference to IP pools>" } ],
                    "loadBalancerMuxMode": "BgpPeering"
    }
    // ... more
}
```

#### Validation Criteria

- `provisioningState` is `Succeeded`

If your output matches this structure and values, the Load Balancer Manager is considered healthy.

---
